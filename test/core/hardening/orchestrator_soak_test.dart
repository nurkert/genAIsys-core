import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

/// Soak tests for the orchestrator run loop.
///
/// These tests exercise multi-step budget enforcement, no-progress detection,
/// self-restart behaviour, and safety halts — scenarios critical for overnight
/// unattended autopilot operation.
void main() {
  group('Orchestrator soak tests', () {
    // -----------------------------------------------------------------------
    // 1. Approve budget halts the run before exceeding configured limit.
    // -----------------------------------------------------------------------
    test(
      'approve budget halts autopilot before exceeding configured limit',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_soak_approve_budget_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);
        File(layout.configPath).writeAsStringSync('''
autopilot:
  approve_budget: 2
''');

        // Steps 1–3 succeed with approvals; the budget (2) is checked as a
        // gate before each step using strict-greater-than semantics (Fix 10:
        // budget=2 means "halt when approvals exceed 2", i.e. at step 4).
        // Step 4 should never execute because the gate fires first.
        final service = _TestRunService(
          stepService: _FakeStepService([
            _StepCase.result(_approvedStep()),
            _StepCase.result(_approvedStep()),
            _StepCase.result(_approvedStep()),
            _StepCase.result(_approvedStep()), // should never execute
          ]),
          sleep: (_) async {},
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 5,
          maxConsecutiveFailures: 5,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        expect(result.stoppedBySafetyHalt, isTrue);
        expect(result.successfulSteps, 3);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"error_kind":"approve_budget"'));
        expect(runLog, contains('"event":"orchestrator_run_safety_halt"'));
      },
    );

    // -----------------------------------------------------------------------
    // 2. Scope budget (cumulative file changes) halts the run.
    // -----------------------------------------------------------------------
    test(
      'scope budget halts autopilot when cumulative additions exceed limit',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_soak_scope_budget_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);
        File(layout.configPath).writeAsStringSync('''
autopilot:
  scope_max_files: 100
  scope_max_additions: 50
  scope_max_deletions: 100
''');

        // Each step adds 30 additions. After 2 steps (60 total) > 50 limit.
        final service = _TestRunService(
          stepService: _FakeStepService([
            _StepCase.result(
              _approvedStepWithDiff(files: 3, additions: 30, deletions: 5),
            ),
            _StepCase.result(
              _approvedStepWithDiff(files: 3, additions: 30, deletions: 5),
            ),
            _StepCase.result(
              _approvedStepWithDiff(files: 3, additions: 30, deletions: 5),
            ),
          ]),
          sleep: (_) async {},
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 5,
          maxConsecutiveFailures: 5,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        expect(result.stoppedBySafetyHalt, isTrue);
        // After step 2, cumulative additions = 60 > 50. Halt fires.
        expect(result.successfulSteps, 2);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"error_kind":"scope_budget"'));
      },
    );

    // -----------------------------------------------------------------------
    // 3. Self-restart resets counters and continues after no-progress.
    // -----------------------------------------------------------------------
    test(
      'self-restart resets no-progress counter and resumes execution',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_soak_self_restart_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);
        File(layout.configPath).writeAsStringSync('''
autopilot:
  no_progress_threshold: 1
  stuck_cooldown_seconds: 0
  self_restart: true
  self_heal_enabled: false
''');

        // Step 1: reject (no progress, self-heal disabled) → stuck detected
        //         → self-restart fires. Step 2: approve → success.
        final service = _TestRunService(
          stepService: _FakeStepService([
            _StepCase.result(_rejectedStep()),
            _StepCase.result(_approvedStep()),
          ]),
          sleep: (_) async {},
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 5,
          maxConsecutiveFailures: 5,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        // Self-restart fires after step 1 (reject), run continues.
        expect(result.stoppedBySafetyHalt, isFalse);
        expect(result.totalSteps, greaterThanOrEqualTo(2));
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"event":"orchestrator_run_self_restart"'));
        expect(runLog, contains('"event":"orchestrator_run_stuck"'));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Consecutive failure safety halt fires at exact threshold.
    // -----------------------------------------------------------------------
    test(
      'consecutive transient failures halt at configured max threshold',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_soak_consecutive_failures_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        final service = _TestRunService(
          stepService: _FakeStepService([
            _StepCase.error(TransientError('Simulated failure 1')),
            _StepCase.error(TransientError('Simulated failure 2')),
            _StepCase.error(TransientError('Simulated failure 3')),
          ]),
          sleep: (_) async {},
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'Advance',
          maxSteps: 10,
          maxConsecutiveFailures: 3,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        );

        expect(result.totalSteps, 3);
        expect(result.failedSteps, 3);
        expect(result.successfulSteps, 0);
        expect(result.stoppedBySafetyHalt, isTrue);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"event":"orchestrator_run_safety_halt"'));
        expect(runLog, contains('"consecutive_failures":3'));
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

OrchestratorStepResult _approvedStep() {
  return OrchestratorStepResult(
    executedCycle: true,
    activatedTask: false,
    activeTaskId: 'task-1',
    activeTaskTitle: 'Task',
    plannedTasksAdded: 0,
    reviewDecision: 'approve',
    retryCount: 0,
    blockedTask: false,
    deactivatedTask: false,
    currentSubtask: null,
    autoMarkedDone: true,
    approvedDiffStats: null,
  );
}

OrchestratorStepResult _approvedStepWithDiff({
  required int files,
  required int additions,
  required int deletions,
}) {
  return OrchestratorStepResult(
    executedCycle: true,
    activatedTask: false,
    activeTaskId: 'task-1',
    activeTaskTitle: 'Task',
    plannedTasksAdded: 0,
    reviewDecision: 'approve',
    retryCount: 0,
    blockedTask: false,
    deactivatedTask: false,
    currentSubtask: null,
    autoMarkedDone: true,
    approvedDiffStats: DiffStats(
      filesChanged: files,
      additions: additions,
      deletions: deletions,
    ),
  );
}

OrchestratorStepResult _rejectedStep() {
  return OrchestratorStepResult(
    executedCycle: true,
    activatedTask: false,
    activeTaskId: 'task-1',
    activeTaskTitle: 'Task',
    plannedTasksAdded: 0,
    reviewDecision: 'reject',
    retryCount: 1,
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
    final current = cases[_index];
    _index += 1;
    if (current.error != null) {
      throw current.error!;
    }
    return current.result!;
  }
}
