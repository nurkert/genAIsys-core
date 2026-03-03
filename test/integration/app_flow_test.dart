import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/app/app_services.dart';
import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_selector.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/task_management/task_refinement_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

class _StubAgentRunner implements AgentRunner {
  const _StubAgentRunner();

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final startedAt = DateTime.now().toUtc();
    return AgentResponse(
      exitCode: 0,
      stdout: '',
      stderr: '',
      commandEvent: AgentCommandEvent(
        executable: 'codex',
        arguments: const [],
        runInShell: false,
        startedAt: startedAt.toIso8601String(),
        durationMs: 0,
        timedOut: false,
        workingDirectory: request.workingDirectory,
      ),
    );
  }
}

class _StubStepService extends OrchestratorStepService {
  _StubStepService();

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
}

class _LifecycleStepService extends OrchestratorStepService {
  _LifecycleStepService();

  final Completer<void> _firstStepEntered = Completer<void>();
  final Completer<void> _releaseFirstStep = Completer<void>();
  var _calls = 0;

  Future<void> waitForFirstStep({
    Duration timeout = const Duration(seconds: 3),
  }) {
    return _firstStepEntered.future.timeout(timeout);
  }

  void releaseFirstStep() {
    if (_releaseFirstStep.isCompleted) {
      return;
    }
    _releaseFirstStep.complete();
  }

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
    _calls += 1;
    if (_calls == 1) {
      if (!_firstStepEntered.isCompleted) {
        _firstStepEntered.complete();
      }
      await _releaseFirstStep.future;
    }
    return _idleStepResult();
  }
}

Map<String, String> _buildHealthEnv(Directory fakeBin) {
  fakeBin.createSync(recursive: true);
  final codexPath = '${fakeBin.path}${Platform.pathSeparator}codex';
  final codex = File(codexPath)
    ..writeAsStringSync(
      Platform.isWindows
          ? '@echo off\r\necho codex\r\n'
          : '#!/bin/sh\necho codex\n',
    );
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', codex.path]);
  }
  final systemPath = Platform.environment['PATH'] ?? '';
  final separator = Platform.isWindows ? ';' : ':';
  final combinedPath = systemPath.trim().isEmpty
      ? fakeBin.path
      : '${fakeBin.path}$separator$systemPath';
  return {'PATH': combinedPath};
}

TaskRefinementService _stubRefinementService() {
  final registry = AgentRegistry(
    codex: const _StubAgentRunner(),
    gemini: const _StubAgentRunner(),
  );
  final selector = AgentSelector(registry: registry);
  return TaskRefinementService(agentService: AgentService(selector: selector));
}

void main() {
  test('flow: init -> create -> refine -> move section', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_flow_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final api = InProcessGenaisysApi(
      taskRefinementService: _stubRefinementService(),
    );
    final services = AppServices(api: api);

    final init = await services.initializeProject.run(temp.path);
    expect(init.ok, isTrue);

    final create = await services.taskWriter.create(
      temp.path,
      title: 'Flow Task',
      priority: AppTaskPriority.p2,
      category: AppTaskCategory.ui,
    );
    expect(create.ok, isTrue);
    expect(create.data?.task.title, 'Flow Task');

    final refine = await services.taskRefinement.refine(
      temp.path,
      title: 'Flow Task',
      overwrite: true,
    );
    expect(refine.ok, isTrue);
    expect(refine.data?.artifacts.length, 3);

    final moved = await services.taskWriter.moveSection(
      temp.path,
      id: create.data?.task.id,
      section: 'In Progress',
    );
    expect(moved.ok, isTrue);
    expect(moved.data?.task.section, 'In Progress');

    final layout = ProjectLayout(temp.path);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final task = tasks.firstWhere((item) => item.title == 'Flow Task');
    expect(task.section, 'In Progress');

    final slug = TaskSlugger.slug('Flow Task');
    expect(
      File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}$slug-plan.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}$slug.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}$slug-subtasks.md',
      ).existsSync(),
      isTrue,
    );
  });

  test('flow: config save -> reload persists values', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final services = AppServices(api: InProcessGenaisysApi());
    final init = await services.initializeProject.run(temp.path);
    expect(init.ok, isTrue);

    final load = await services.config.load(temp.path);
    expect(load.ok, isTrue);

    final base = load.data!;
    final updated = AppConfigDto(
      gitBaseBranch: 'develop',
      gitFeaturePrefix: 'feature/',
      gitAutoStash: base.gitAutoStash,
      safeWriteEnabled: base.safeWriteEnabled,
      safeWriteRoots: base.safeWriteRoots,
      shellAllowlist: const ['flutter test', 'dart format'],
      shellAllowlistProfile: 'custom',
      diffBudgetMaxFiles: base.diffBudgetMaxFiles,
      diffBudgetMaxAdditions: base.diffBudgetMaxAdditions,
      diffBudgetMaxDeletions: base.diffBudgetMaxDeletions,
      autopilotMinOpenTasks: base.autopilotMinOpenTasks,
      autopilotMaxPlanAdd: base.autopilotMaxPlanAdd,
      autopilotStepSleepSeconds: base.autopilotStepSleepSeconds,
      autopilotIdleSleepSeconds: base.autopilotIdleSleepSeconds,
      autopilotMaxSteps: base.autopilotMaxSteps,
      autopilotMaxFailures: 9,
      autopilotMaxTaskRetries: base.autopilotMaxTaskRetries,
      autopilotSelectionMode: base.autopilotSelectionMode,
      autopilotFairnessWindow: base.autopilotFairnessWindow,
      autopilotPriorityWeightP1: base.autopilotPriorityWeightP1,
      autopilotPriorityWeightP2: base.autopilotPriorityWeightP2,
      autopilotPriorityWeightP3: base.autopilotPriorityWeightP3,
      autopilotReactivateBlocked: base.autopilotReactivateBlocked,
      autopilotReactivateFailed: base.autopilotReactivateFailed,
      autopilotBlockedCooldownSeconds: base.autopilotBlockedCooldownSeconds,
      autopilotFailedCooldownSeconds: base.autopilotFailedCooldownSeconds,
      autopilotLockTtlSeconds: base.autopilotLockTtlSeconds,
      autopilotNoProgressThreshold: base.autopilotNoProgressThreshold,
      autopilotStuckCooldownSeconds: base.autopilotStuckCooldownSeconds,
      autopilotSelfRestart: base.autopilotSelfRestart,
      autopilotScopeMaxFiles: base.autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions: base.autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions: base.autopilotScopeMaxDeletions,
      autopilotApproveBudget: base.autopilotApproveBudget,
      autopilotManualOverride: base.autopilotManualOverride,
      autopilotSelfTuneEnabled: base.autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow: base.autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples: base.autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent: base.autopilotSelfTuneSuccessPercent,
    );

    final saved = await services.config.update(temp.path, config: updated);
    expect(saved.ok, isTrue);

    final reloaded = await services.config.load(temp.path);
    expect(reloaded.ok, isTrue);
    expect(reloaded.data?.gitBaseBranch, 'develop');
    expect(reloaded.data?.gitFeaturePrefix, 'feature/');
    expect(reloaded.data?.shellAllowlist, contains('dart format'));
    expect(reloaded.data?.autopilotMaxFailures, 9);
  });

  test('flow: autopilot run writes run log events', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_autopilot_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure();
    // Autopilot preflight is fail-closed when the project is not a git repo.
    // Integration flow tests should reflect real usage by initializing git.
    Process.runSync('git', const ['init'], workingDirectory: temp.path);

    final fakeBin = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_fake_bin_',
    );
    addTearDown(() {
      fakeBin.deleteSync(recursive: true);
    });
    final env = _buildHealthEnv(fakeBin);
    await runZoned(() async {
      final runService = OrchestratorRunService(
        stepService: _StubStepService(),
        sleep: (_) async {},
      );
      final runUseCase = AutopilotRunUseCase(service: runService);
      final stopUseCase = AutopilotStopUseCase(service: runService);

      final result = await runUseCase.run(
        temp.path,
        prompt: 'noop',
        maxSteps: 1,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
        stopWhenIdle: false,
      );
      expect(result.ok, isTrue);

      await stopUseCase.run(temp.path);
    }, zoneValues: {#genaisys_test_env: env});

    final layout = ProjectLayout(temp.path);
    final log = File(layout.runLogPath).readAsStringSync();
    expect(log, contains('orchestrator_run_start'));
    expect(log, contains('orchestrator_run_end'));
    expect(log, contains('orchestrator_run_unlock'));
  });

  test('flow: autopilot lifecycle start loop stop resume', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_lifecycle_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure();
    // Autopilot preflight requires a git repository (fail-closed).
    Process.runSync('git', const ['init'], workingDirectory: temp.path);
    Process.runSync('git', const [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', const [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', const ['add', '-A'], workingDirectory: temp.path);
    Process.runSync('git', const [
      'commit',
      '--no-gpg-sign',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final fakeBin = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_fake_bin_',
    );
    addTearDown(() {
      fakeBin.deleteSync(recursive: true);
    });
    final env = _buildHealthEnv(fakeBin);
    await runZoned(() async {
      final stepService = _LifecycleStepService();
      final runService = OrchestratorRunService(
        stepService: stepService,
        sleep: (_) async {},
      );
      final runUseCase = AutopilotRunUseCase(service: runService);
      final statusUseCase = AutopilotStatusUseCase(service: runService);
      final stopUseCase = AutopilotStopUseCase(service: runService);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);

      final firstRunFuture = runUseCase.run(
        temp.path,
        prompt: 'noop',
        maxSteps: 50,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
        stopWhenIdle: false,
      );

      await stepService.waitForFirstStep();
      expect(File(layout.autopilotLockPath).existsSync(), isTrue);
      expect(File(layout.autopilotStopPath).existsSync(), isFalse);

      final runningStatus = await statusUseCase.load(temp.path);
      expect(runningStatus.ok, isTrue);
      expect(runningStatus.data?.autopilotRunning, isTrue);
      final runningState = stateStore.read();
      expect(runningState.autopilotRunning, isTrue);
      expect(runningState.currentMode, 'autopilot_run');
      expect(runningState.lastLoopAt, isNotNull);

      final stopResult = await stopUseCase.run(temp.path);
      expect(stopResult.ok, isTrue);
      expect(File(layout.autopilotStopPath).existsSync(), isTrue);

      stepService.releaseFirstStep();

      final firstRunResult = await firstRunFuture.timeout(
        // This run performs real file IO (run log/state/lock bookkeeping). Keep a
        // small bound, but avoid ultra-tight timeouts that flake on slower disks.
        const Duration(seconds: 10),
      );
      expect(firstRunResult.ok, isTrue);
      expect(firstRunResult.data?.stoppedByMaxSteps, isFalse);
      expect(firstRunResult.data?.stoppedBySafetyHalt, isFalse);
      expect(firstRunResult.data?.totalSteps, greaterThanOrEqualTo(1));

      final stoppedStatus = await statusUseCase.load(temp.path);
      expect(stoppedStatus.ok, isTrue);
      expect(stoppedStatus.data?.autopilotRunning, isFalse);

      expect(File(layout.autopilotLockPath).existsSync(), isFalse);
      expect(File(layout.autopilotStopPath).existsSync(), isFalse);
      final stoppedState = stateStore.read();
      expect(stoppedState.autopilotRunning, isFalse);
      expect(stoppedState.currentMode, isNull);

      final resumedRunResult = await runUseCase.run(
        temp.path,
        prompt: 'noop',
        maxSteps: 2,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
        stopWhenIdle: false,
      );
      expect(resumedRunResult.ok, isTrue);
      expect(resumedRunResult.data?.totalSteps, 2);
      expect(resumedRunResult.data?.stoppedByMaxSteps, isTrue);
      expect(resumedRunResult.data?.stoppedBySafetyHalt, isFalse);

      final resumedStatus = await statusUseCase.load(temp.path);
      expect(resumedStatus.ok, isTrue);
      expect(resumedStatus.data?.autopilotRunning, isFalse);
      expect(File(layout.autopilotStopPath).existsSync(), isFalse);
      final resumedState = stateStore.read();
      expect(resumedState.autopilotRunning, isFalse);
      expect(resumedState.currentMode, isNull);
      expect(resumedState.lastLoopAt, isNotNull);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(_countOccurrences(runLog, 'orchestrator_run_start'), 2);
      expect(_countOccurrences(runLog, 'orchestrator_run_end'), 2);
      expect(_countOccurrences(runLog, 'orchestrator_run_unlock'), 2);
      expect(
        _countOccurrences(runLog, 'orchestrator_run_step'),
        greaterThanOrEqualTo(2),
      );
      expect(runLog, contains('orchestrator_run_stop_requested'));
    }, zoneValues: {#genaisys_test_env: env});
  });

  test(
    'flow: autopilot crash recovery clears stale lock and resumes',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_crash_recovery_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure();

      final layout = ProjectLayout(temp.path);
      File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=1970-01-01T00:00:00Z
last_heartbeat=1970-01-01T00:00:00Z
pid=0
project_root=${temp.path}
''');
      File(layout.autopilotStopPath).writeAsStringSync('stale-stop-signal');

      final stateStore = StateStore(layout.statePath);
      final crashed = stateStore.read().copyWith(
        autopilotRun: const AutopilotRunState(
          running: true,
          currentMode: 'autopilot_run',
          consecutiveFailures: 3,
          lastError: 'simulated crash',
        ),
      );
      stateStore.write(crashed);

      final fakeBin = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_fake_bin_',
      );
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
      });
      final env = _buildHealthEnv(fakeBin);
      await runZoned(() async {
        final runService = OrchestratorRunService(
          stepService: _StubStepService(),
          sleep: (_) async {},
        );
        final statusUseCase = AutopilotStatusUseCase(service: runService);
        final runUseCase = AutopilotRunUseCase(service: runService);

        final statusAfterRecovery = await statusUseCase.load(temp.path);
        expect(statusAfterRecovery.ok, isTrue);
        expect(statusAfterRecovery.data?.autopilotRunning, isFalse);
        expect(File(layout.autopilotLockPath).existsSync(), isFalse);
        expect(File(layout.autopilotStopPath).existsSync(), isTrue);

        final stateAfterRecovery = stateStore.read();
        expect(stateAfterRecovery.autopilotRunning, isFalse);
        expect(stateAfterRecovery.currentMode, isNull);
        expect(stateAfterRecovery.consecutiveFailures, 3);
        expect(stateAfterRecovery.lastError, 'simulated crash');

        final resumedRun = await runUseCase.run(
          temp.path,
          prompt: 'noop',
          maxSteps: 1,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
          stopWhenIdle: false,
        );
        expect(resumedRun.ok, isTrue);
        expect(resumedRun.data?.totalSteps, 1);
        expect(resumedRun.data?.stoppedByMaxSteps, isTrue);
        expect(resumedRun.data?.stoppedBySafetyHalt, isFalse);
        expect(File(layout.autopilotStopPath).existsSync(), isFalse);

        final stateAfterResume = stateStore.read();
        expect(stateAfterResume.autopilotRunning, isFalse);
        expect(stateAfterResume.currentMode, isNull);
        expect(stateAfterResume.consecutiveFailures, 0);

        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('orchestrator_run_lock_recovered'));
        expect(runLog, contains('orchestrator_run_start'));
        expect(runLog, contains('orchestrator_run_end'));
      }, zoneValues: {#genaisys_test_env: env});
    },
  );

  test('flow: review actions update review status', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_review_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final services = AppServices(api: InProcessGenaisysApi());
    final init = await services.initializeProject.run(temp.path);
    expect(init.ok, isTrue);

    final activate = await services.activateTask.run(temp.path);
    expect(activate.ok, isTrue);

    final approve = await services.reviewActions.approve(
      temp.path,
      note: 'LGTM',
    );
    expect(approve.ok, isTrue);

    final statusApproved = await services.reviewStatus.load(temp.path);
    expect(statusApproved.ok, isTrue);
    expect(statusApproved.data?.status, 'approved');

    final reject = await services.reviewActions.reject(
      temp.path,
      note: 'Needs changes',
    );
    expect(reject.ok, isTrue);

    final statusRejected = await services.reviewStatus.load(temp.path);
    expect(statusRejected.ok, isTrue);
    expect(statusRejected.data?.status, 'rejected');

    final cleared = await services.reviewActions.clear(temp.path);
    expect(cleared.ok, isTrue);
    final statusCleared = await services.reviewStatus.load(temp.path);
    expect(statusCleared.ok, isTrue);
    expect(statusCleared.data?.status, '(none)');
  });
}

OrchestratorStepResult _idleStepResult() {
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

int _countOccurrences(String haystack, String needle) {
  if (needle.isEmpty) {
    return 0;
  }
  return RegExp(RegExp.escape(needle)).allMatches(haystack).length;
}
