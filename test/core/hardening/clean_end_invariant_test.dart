import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

/// Clean-end invariant regression tests.
///
/// These tests verify that the worktree is always left in a clean state
/// after orchestrator operations, regardless of the outcome (approve, reject,
/// error). This is a release-blocking invariant for unattended mode
/// (see AGENTS.md § 8 & 13).
void main() {
  group('Clean-end invariant', () {
    // -----------------------------------------------------------------------
    // 1. Autopilot lock file is cleaned up after run completes normally.
    // -----------------------------------------------------------------------
    test(
      'autopilot lock file is removed after run completes normally',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_clean_end_lock_normal_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        final service = _TestRunService(
          stepService: _FakeStepService([]),
          sleep: (_) async {},
        );

        await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 1,
          maxConsecutiveFailures: 3,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        expect(
          File(layout.autopilotLockPath).existsSync(),
          isFalse,
          reason: 'Lock file should be deleted after normal run completion',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 2. Autopilot lock file is cleaned up after safety halt.
    // -----------------------------------------------------------------------
    test('autopilot lock file is removed after safety halt', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_clean_end_lock_halt_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final service = _TestRunService(
        stepService: _FakeStepService([
          _StepCase.error(TransientError('Simulated 1')),
          _StepCase.error(TransientError('Simulated 2')),
        ]),
        sleep: (_) async {},
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Advance',
        maxSteps: 10,
        maxConsecutiveFailures: 2,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      expect(result.stoppedBySafetyHalt, isTrue);
      expect(
        File(layout.autopilotLockPath).existsSync(),
        isFalse,
        reason: 'Lock file should be deleted after safety halt',
      );
    });

    // -----------------------------------------------------------------------
    // 3. Autopilot state is cleared after run completes.
    // -----------------------------------------------------------------------
    test('autopilot running state is cleared after run completes', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_clean_end_state_cleared_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final service = _TestRunService(
        stepService: _FakeStepService([_StepCase.result(_idleResult())]),
        sleep: (_) async {},
      );

      await service.run(
        temp.path,
        codingPrompt: 'Advance',
        maxSteps: 1,
        maxConsecutiveFailures: 3,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      final state = StateStore(layout.statePath).read();
      expect(state.autopilotRunning, isFalse);
      expect(state.currentMode, isNull);
    });

    // -----------------------------------------------------------------------
    // 4. OrchestratorStepService stashes dirty worktree before step and
    //    preserves the stash (no pop) when step errors in unattended mode.
    // -----------------------------------------------------------------------
    test(
      'step-level auto-stash on error leaves worktree clean (no stash pop)',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_clean_end_step_stash_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);
        File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
        final store = StateStore(layout.statePath);
        store.write(
          store.read().copyWith(
            activeTask: ActiveTaskState(id: 'task-1', title: 'Task 1'),
          ),
        );
        File(layout.tasksPath).writeAsStringSync(
          '# Tasks\n\n- [ ] [P1] Task 1\n',
        );

        // Sequence: [1] _persistPostStepCleanup→isClean=true (no pre-existing
        // changes), [2] _prepareGitGuard→isClean=true (clean for guard, no
        // pre-step stash), [3] error-path isClean=false (dirty→stash push),
        // [4] error-path isClean=false (still dirty→stash push again),
        // [5] error-path isClean=true (clean after 2nd stash).
        final git = _SequencedGitService([true, true, false, false, true]);
        final service = OrchestratorStepService(
          activateService: ActivateService(gitService: git),
          taskCycleService: _QuotaPauseTaskCycleService(),
          plannerService: _FakePlannerService(),
          architecturePlanningService: _NoopArchitecturePlanningService(),
          visionEvaluationService: _NoopVisionEvaluationService(),
          gitService: git,
        );

        await expectLater(
          () => service.run(temp.path, codingPrompt: 'Base Prompt'),
          throwsA(isA<QuotaPauseError>()),
        );

        // Error-path auto-stash should have happened; no pop.
        expect(git.stashPushCalls, 2);
        expect(git.stashPopCalls, 0);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"event":"git_step_error_autostash"'));
      },
    );

    // -----------------------------------------------------------------------
    // 5. Run-level stop signal terminates with clean state.
    // -----------------------------------------------------------------------
    test(
      'stop signal terminates run with clean final state and run log evidence',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_clean_end_stop_signal_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        // The stop signal must be written DURING execution because
        // _acquireRunLock clears any pre-existing stop file.
        final service = _TestRunService(
          stepService: _StopSignalStepService(temp.path),
          sleep: (_) async {},
        );

        await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 5,
          maxConsecutiveFailures: 3,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        // Stop signal should clean up lock and mark run as stopped.
        expect(
          File(layout.autopilotLockPath).existsSync(),
          isFalse,
          reason: 'Lock file should be deleted after stop signal',
        );
        final state = StateStore(layout.statePath).read();
        expect(state.autopilotRunning, isFalse);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"event":"orchestrator_run_stop_requested"'));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

class _TestRunService extends OrchestratorRunService {
  _TestRunService({super.stepService, super.sleep})
    : super(autopilotPreflightService: _AlwaysPassPreflightService());
}

class _AlwaysPassPreflightService extends AutopilotPreflightService {
  @override
  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    return const AutopilotPreflightResult.ok();
  }
}

OrchestratorStepResult _idleResult() {
  return OrchestratorStepResult(
    executedCycle: false,
    activatedTask: false,
    activeTaskId: null,
    activeTaskTitle: null,
    plannedTasksAdded: 0,
    reviewDecision: null,
    retryCount: 0,
    blockedTask: false,
    deactivatedTask: false,
    currentSubtask: null,
    autoMarkedDone: false,
    approvedDiffStats: null,
  );
}

class _StepCase {
  _StepCase.result(this.result) : error = null;
  _StepCase.error(this.error) : result = null;

  final OrchestratorStepResult? result;
  final Object? error;
}

class _FakeStepService extends OrchestratorStepService {
  _FakeStepService(this.cases);

  final List<_StepCase> cases;
  var _index = 0;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    if (_index >= cases.length) {
      return _idleResult();
    }
    final current = cases[_index];
    _index += 1;
    if (current.error != null) {
      throw current.error!;
    }
    return current.result!;
  }
}

/// Step service that writes the stop signal file after the first step.
/// The stop check happens at the top of the run loop, so the signal is
/// detected before the second step begins.
class _StopSignalStepService extends OrchestratorStepService {
  _StopSignalStepService(this._projectRoot);

  final String _projectRoot;
  var _callCount = 0;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    _callCount += 1;
    if (_callCount == 1) {
      // Write the stop signal so the next iteration detects it.
      final layout = ProjectLayout(_projectRoot);
      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotStopPath).writeAsStringSync('stop');
    }
    return _idleResult();
  }
}

// OrchestratorStepService-level helpers for test 4.

class _SequencedGitService extends GitServiceImpl {
  _SequencedGitService(this._cleanSequence);

  final List<bool> _cleanSequence;
  var _cleanCalls = 0;
  var stashPushCalls = 0;
  var stashPopCalls = 0;

  @override
  bool isGitRepo(String path) => true;

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool isClean(String path) {
    if (_cleanCalls >= _cleanSequence.length) {
      return _cleanSequence.isEmpty ? true : _cleanSequence.last;
    }
    final value = _cleanSequence[_cleanCalls];
    _cleanCalls += 1;
    return value;
  }

  @override
  bool hasChanges(String path) => !isClean(path);

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    stashPushCalls += 1;
    return true;
  }

  @override
  void stashPop(String path) {
    stashPopCalls += 1;
  }
}

class _QuotaPauseTaskCycleService extends TaskCycleService {
  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    throw QuotaPauseError(
      'Simulated quota exhaustion',
      pauseFor: const Duration(seconds: 30),
    );
  }
}

class _FakePlannerService extends VisionBacklogPlannerService {
  @override
  Future<PlannerSyncResult> syncBacklogStrategically(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) async {
    return PlannerSyncResult(
      openBefore: 0,
      openAfter: 0,
      added: 0,
      addedTitles: const [],
    );
  }

  @override
  PlannerSyncResult syncBacklogFromVision(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) {
    return PlannerSyncResult(
      openBefore: 0,
      openAfter: 0,
      added: 0,
      addedTitles: const [],
    );
  }
}

class _NoopArchitecturePlanningService extends ArchitecturePlanningService {
  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    return null;
  }
}

class _NoopVisionEvaluationService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return null;
  }
}
