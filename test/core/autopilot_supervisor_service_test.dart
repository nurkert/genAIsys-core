import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/autopilot/autopilot_supervisor_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/supervisor_state.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/supervisor_resume_policy.dart';
import 'package:genaisys/core/storage/state_store.dart';

class _FakeRunService implements OrchestratorRunService {
  _FakeRunService({this.onRun});

  Future<OrchestratorRunResult> Function(String projectRoot)? onRun;
  bool? lastUnattendedMode;

  @override
  void Function()? heartbeatWriterForTest;

  @override
  void requestStop(String projectRoot) {}

  @override
  AutopilotStatus getStatus(String projectRoot) {
    return AutopilotStatus(
      isRunning: false,
      pid: null,
      startedAt: null,
      lastLoopAt: null,
      consecutiveFailures: 0,
      lastError: null,
      subtaskQueue: const [],
      currentSubtask: null,
      lastStepSummary: null,
    );
  }

  @override
  Future<OrchestratorRunResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle = false,
    int? maxConsecutiveFailures,
    int? maxTaskRetries,
    bool unattendedMode = false,
    bool overrideSafety = false,
  }) {
    lastUnattendedMode = unattendedMode;
    final handler = onRun;
    if (handler == null) {
      throw UnimplementedError('run handler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<void> stop(String projectRoot) async {}

  @override
  int? pidOrNull() => null;
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

class _AlwaysFailPreflightService extends AutopilotPreflightService {
  @override
  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    return const AutopilotPreflightResult(
      ok: false,
      reason: 'git',
      message: 'push readiness failed',
      errorClass: 'preflight',
      errorKind: 'remote_unavailable',
    );
  }
}

class _FakeDoneService extends DoneService {
  _FakeDoneService({required this.onMarkDone});

  final Future<String> Function(String projectRoot) onMarkDone;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) =>
      onMarkDone(projectRoot);
}

void main() {
  test(
    'AutopilotSupervisorService start fails closed for invalid profile',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_profile_invalid_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      var spawnCalled = false;
      final service = AutopilotSupervisorService(
        preflightService: _AlwaysPassPreflightService(),
        spawnWorker:
            (
              projectRoot, {
              required sessionId,
              required profile,
              required prompt,
              required startReason,
              required maxRestarts,
              required restartBackoffBaseSeconds,
              required restartBackoffMaxSeconds,
              required lowSignalLimit,
              required throughputWindowMinutes,
              required throughputMaxSteps,
              required throughputMaxRejects,
              required throughputMaxHighRetries,
            }) async {
              spawnCalled = true;
              return 1234;
            },
      );

      await expectLater(
        service.start(temp.path, profile: 'invalid-profile'),
        throwsA(isA<ArgumentError>()),
      );
      expect(spawnCalled, isFalse);
      final state = StateStore(ProjectLayout(temp.path).statePath).read();
      expect(state.supervisorRunning, isFalse);
    },
  );

  test(
    'AutopilotSupervisorService start persists state and spawn metadata',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_start_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final spawnCalls = <Map<String, Object?>>[];
      final service = AutopilotSupervisorService(
        preflightService: _AlwaysPassPreflightService(),
        spawnWorker:
            (
              projectRoot, {
              required sessionId,
              required profile,
              required prompt,
              required startReason,
              required maxRestarts,
              required restartBackoffBaseSeconds,
              required restartBackoffMaxSeconds,
              required lowSignalLimit,
              required throughputWindowMinutes,
              required throughputMaxSteps,
              required throughputMaxRejects,
              required throughputMaxHighRetries,
            }) async {
              spawnCalls.add({
                'project_root': projectRoot,
                'session_id': sessionId,
                'profile': profile,
                'prompt': prompt,
                'start_reason': startReason,
                'max_restarts': maxRestarts,
              });
              return 4242;
            },
      );

      final result = await service.start(
        temp.path,
        profile: 'pilot',
        prompt: 'custom prompt',
        startReason: 'Manual Start',
        maxRestarts: 4,
      );

      expect(result.started, isTrue);
      expect(result.profile, 'pilot');
      expect(result.pid, 4242);
      expect(result.resumeAction, 'continue_safe_step');
      expect(spawnCalls, hasLength(1));
      expect(spawnCalls.first['project_root'], temp.path);
      expect(spawnCalls.first['profile'], 'pilot');
      expect(spawnCalls.first['prompt'], 'custom prompt');
      expect(spawnCalls.first['start_reason'], 'manual_start');

      final state = StateStore(ProjectLayout(temp.path).statePath).read();
      expect(state.supervisorRunning, isTrue);
      expect(state.supervisorProfile, 'pilot');
      expect(state.supervisorPid, 4242);
      expect(state.supervisorStartReason, 'manual_start');
      expect(state.supervisorSessionId, isNotNull);
      expect(state.supervisorThroughputWindowStartedAt, isNotNull);
    },
  );

  test(
    'AutopilotSupervisorService start fails closed on preflight error',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_preflight_fail_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      var spawnCalled = false;
      final service = AutopilotSupervisorService(
        preflightService: _AlwaysFailPreflightService(),
        spawnWorker:
            (
              projectRoot, {
              required sessionId,
              required profile,
              required prompt,
              required startReason,
              required maxRestarts,
              required restartBackoffBaseSeconds,
              required restartBackoffMaxSeconds,
              required lowSignalLimit,
              required throughputWindowMinutes,
              required throughputMaxSteps,
              required throughputMaxRejects,
              required throughputMaxHighRetries,
            }) async {
              spawnCalled = true;
              return 9999;
            },
      );

      await expectLater(
        service.start(temp.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('push readiness failed'),
          ),
        ),
      );
      expect(spawnCalled, isFalse);
      final state = StateStore(ProjectLayout(temp.path).statePath).read();
      expect(state.supervisorRunning, isFalse);
    },
  );

  test(
    'AutopilotSupervisorService worker resumes approved delivery first',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_resume_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      final seeded = store.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'alpha-1',
          title: 'Alpha',
          reviewStatus: 'approved',
        ),
        workflowStage: WorkflowStage.execution,
      );
      store.write(seeded);

      var doneCalls = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: true,
          );
        },
      );
      final doneService = _FakeDoneService(
        onMarkDone: (projectRoot) async {
          doneCalls += 1;
          return 'Alpha';
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        resumePolicy: SupervisorResumePolicy(doneService: doneService),
        sleep: (_) async {},
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-1',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 2,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 4,
        lowSignalLimit: 3,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 200,
        throughputMaxRejects: 100,
        throughputMaxHighRetries: 100,
      );

      expect(doneCalls, 1);
      expect(runService.lastUnattendedMode, isTrue);
      final state = store.read();
      expect(state.supervisorRunning, isFalse);
      expect(state.supervisorLastResumeAction, 'approved_delivery');
      expect(state.supervisorLastHaltReason, 'run_safety_halt');
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"autopilot_supervisor_resume"'));
      expect(runLog, contains('"resume_action":"approved_delivery"'));
      expect(runLog, contains('"event":"autopilot_supervisor_worker_end"'));
    },
  );

  test(
    'AutopilotSupervisorService worker applies bounded restart backoff',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_restart_budget_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final sleeps = <Duration>[];
      final runService = _FakeRunService(
        onRun: (_) async => throw StateError('segment crash'),
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (duration) async {
          sleeps.add(duration);
        },
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-2',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 2,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 8,
        lowSignalLimit: 5,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      expect(sleeps, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      final state = StateStore(layout.statePath).read();
      expect(state.supervisorRunning, isFalse);
      expect(state.supervisorRestartCount, 2);
      expect(state.supervisorLastHaltReason, 'restart_budget_exhausted');
    },
  );

  test(
    'AutopilotSupervisorService worker halts on low-signal watchdog',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_watchdog_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final runService = _FakeRunService(
        onRun: (_) async {
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 0,
            idleSteps: 1,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          );
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (_) async {},
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-3',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 1,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 2,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      final state = StateStore(layout.statePath).read();
      expect(state.supervisorLastHaltReason, 'progress_watchdog');
      expect(state.supervisorLowSignalStreak, greaterThanOrEqualTo(2));
    },
  );

  test(
    'AutopilotSupervisorService worker attempts auto-heal before watchdog halt',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_auto_heal_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      var segmentCount = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          segmentCount += 1;
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 0,
            idleSteps: 1,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          );
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (_) async {},
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-heal',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 1,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 2,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      // Auto-heal runs one extra segment before halting.
      expect(segmentCount, greaterThan(2));
      final state = StateStore(layout.statePath).read();
      expect(state.supervisorLastHaltReason, 'progress_watchdog');

      // Run log contains the auto-heal event.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"autopilot_supervisor_auto_heal"'));
      expect(runLog, contains('"heal_attempted":true'));
    },
  );

  test(
    'AutopilotSupervisorService worker halts on throughput guardrail',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_throughput_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final runService = _FakeRunService(
        onRun: (_) async {
          return OrchestratorRunResult(
            totalSteps: 50,
            successfulSteps: 50,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          );
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (_) async {},
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-4',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 1,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 10,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 40,
        throughputMaxRejects: 40,
        throughputMaxHighRetries: 40,
      );

      final state = StateStore(layout.statePath).read();
      expect(state.supervisorLastHaltReason, 'throughput_steps');
      expect(state.supervisorThroughputSteps, greaterThanOrEqualTo(50));
    },
  );

  test(
    'AutopilotSupervisorService long-run soak remains bounded and releases lock',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_soak_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      var simulatedNow = DateTime.utc(2026, 2, 1, 0, 0, 0);
      var simulatedElapsed = Duration.zero;
      final sleepCalls = <Duration>[];
      final runService = _FakeRunService(
        onRun: (_) async => throw StateError('segment crash'),
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (duration) async {
          sleepCalls.add(duration);
          simulatedElapsed += duration;
          simulatedNow = simulatedNow.add(duration);
        },
        now: () => simulatedNow,
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-soak',
        profile: 'longrun',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 12,
        restartBackoffBaseSeconds: 1800,
        restartBackoffMaxSeconds: 3600,
        lowSignalLimit: 1000,
        throughputWindowMinutes: 240,
        throughputMaxSteps: 1000000,
        throughputMaxRejects: 1000000,
        throughputMaxHighRetries: 1000000,
      );

      final state = StateStore(layout.statePath).read();
      expect(simulatedElapsed >= const Duration(hours: 6), isTrue);
      expect(sleepCalls, isNotEmpty);
      expect(state.supervisorRunning, isFalse);
      expect(state.supervisorRestartCount, 12);
      expect(state.supervisorLastHaltReason, 'restart_budget_exhausted');
      expect(File(layout.autopilotSupervisorLockPath).existsSync(), isFalse);
      expect(File(layout.autopilotSupervisorStopPath).existsSync(), isFalse);
    },
  );

  test(
    'AutopilotSupervisorService relaunch continuity recovers stale state and resumes approved delivery',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_relaunch_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          supervisor: const SupervisorState(
            running: true,
            pid: 999999,
            sessionId: 'old-session',
          ),
          activeTask: const ActiveTaskState(
            id: 'alpha-1',
            title: 'Alpha',
            reviewStatus: 'approved',
          ),
          workflowStage: WorkflowStage.execution,
        ),
      );
      final staleLock = File(layout.autopilotSupervisorLockPath);
      staleLock.parent.createSync(recursive: true);
      staleLock.writeAsStringSync('stale lock marker', flush: true);

      var doneCalls = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: true,
          );
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        resumePolicy: SupervisorResumePolicy(
          doneService: _FakeDoneService(
            onMarkDone: (_) async {
              doneCalls += 1;
              return 'Alpha';
            },
          ),
        ),
        sleep: (_) async {},
      );

      final recoveredStatus = service.getStatus(temp.path);
      expect(recoveredStatus.running, isFalse);
      expect(
        store.read().supervisorLastHaltReason,
        'stale_supervisor_recovered',
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-relaunch',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 2,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 10,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      final state = store.read();
      expect(doneCalls, 1);
      expect(state.supervisorRunning, isFalse);
      expect(state.supervisorLastResumeAction, 'approved_delivery');
      expect(state.supervisorLastHaltReason, 'run_safety_halt');
      expect(File(layout.autopilotSupervisorLockPath).existsSync(), isFalse);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('"event":"autopilot_supervisor_stale_recovered"'),
      );
      expect(runLog, contains('"event":"autopilot_supervisor_resume"'));
      expect(runLog, contains('"resume_action":"approved_delivery"'));
    },
  );

  test(
    'AutopilotSupervisorService halts when interventions per hour exceeded',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_interventions_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Write config with max 2 interventions per hour.
      File(layout.configPath).writeAsStringSync('''
supervisor:
  max_interventions_per_hour: 2
''');
      final runService = _FakeRunService(
        onRun: (_) async => throw StateError('segment crash'),
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (_) async {},
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-interventions',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 10,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 50,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      final state = StateStore(layout.statePath).read();
      expect(state.supervisorLastHaltReason, 'interventions_per_hour_exceeded');
      // With limit 2, it should halt after the 3rd intervention.
      expect(state.supervisorRestartCount, lessThanOrEqualTo(3));
    },
  );

  test(
    'AutopilotSupervisorService uses supervisorCheckInterval from config',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_check_interval_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Write config with a custom check interval.
      File(layout.configPath).writeAsStringSync('''
supervisor:
  check_interval_seconds: 42
''');
      final sleeps = <Duration>[];
      var runCount = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          runCount += 1;
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          );
        },
      );
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (duration) async {
          sleeps.add(duration);
          // Stop after first segment to avoid infinite loop.
          if (runCount >= 1) {
            _writeSupervisorStopSignal(temp.path);
          }
        },
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-check-interval',
        profile: 'pilot',
        prompt: 'prompt',
        startReason: 'worker',
        maxRestarts: 1,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 2,
        lowSignalLimit: 50,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 500,
        throughputMaxRejects: 500,
        throughputMaxHighRetries: 500,
      );

      // The segment pause should be 42 seconds from config.
      expect(sleeps, contains(const Duration(seconds: 42)));
    },
  );
}

/// Helper to write the supervisor stop signal for testing.
void _writeSupervisorStopSignal(String projectRoot) {
  final layout = ProjectLayout(projectRoot);
  final stopFile = File(layout.autopilotSupervisorStopPath);
  stopFile.parent.createSync(recursive: true);
  stopFile.writeAsStringSync('stop');
}
