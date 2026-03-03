import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

/// Hardening matrix: lock contention.
///
/// Verifies the autopilot lock mechanism correctly handles:
/// - Live lock holder → blocks second run
/// - Dead PID → recovers lock
/// - TTL expiration without PID → recovers
/// - Live PID with expired TTL → does NOT recover
/// - Stop signal → clean termination between steps
void main() {
  group('Lock contention matrix', () {
    test('lock acquisition fails when a live PID holds the lock', () async {
      final temp = Directory.systemTemp.createTempSync('genaisys_lock_live_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Write a lock file with the current process PID (which is alive).
      Directory(layout.locksDir).createSync(recursive: true);
      final now = DateTime.now().toUtc().toIso8601String();
      File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=$now
last_heartbeat=$now
pid=$pid
project_root=${temp.path}
''');

      final service = _TestRunService(stepService: _IdleStepService());

      // Should throw because current PID is alive.
      expect(
        () => service.run(temp.path, codingPrompt: 'test', maxSteps: 1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already running'),
          ),
        ),
      );
    });

    test('lock recovery succeeds when lock PID is dead', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_lock_dead_pid_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // PID 999999 is almost certainly not running.
      Directory(layout.locksDir).createSync(recursive: true);
      final now = DateTime.now().toUtc().toIso8601String();
      File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=$now
last_heartbeat=$now
pid=999999
project_root=${temp.path}
''');

      final service = _TestRunService(stepService: _IdleStepService());

      final result = await service.run(
        temp.path,
        codingPrompt: 'test',
        maxSteps: 1,
      );

      // Should have recovered the lock and run.
      expect(result.totalSteps, 1);
      // Lock file should be cleaned up after run.
      expect(File(layout.autopilotLockPath).existsSync(), isFalse);

      // Verify recovery event in run log.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"orchestrator_run_lock_recovered"'));
      expect(runLog, contains('"recovery_reason":"pid_not_alive"'));
    });

    test('lock recovery on TTL expired without PID field', () async {
      final temp = Directory.systemTemp.createTempSync('genaisys_lock_ttl_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Lock with old timestamp and no PID field.
      Directory(layout.locksDir).createSync(recursive: true);
      final oldTime = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String();
      File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=$oldTime
last_heartbeat=$oldTime
project_root=${temp.path}
''');

      final service = _TestRunService(stepService: _IdleStepService());

      final result = await service.run(
        temp.path,
        codingPrompt: 'test',
        maxSteps: 1,
      );

      expect(result.totalSteps, 1);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"recovery_reason":"ttl_expired"'));
    });

    test(
      'lock is NOT recovered when PID is alive even with expired TTL',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_lock_live_ttl_',
        );
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        // Lock with current PID (alive) but old heartbeat.
        Directory(layout.locksDir).createSync(recursive: true);
        final oldTime = DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 2))
            .toIso8601String();
        File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=$oldTime
last_heartbeat=$oldTime
pid=$pid
project_root=${temp.path}
''');

        final service = _TestRunService(stepService: _IdleStepService());

        // Should NOT recover — PID is alive takes precedence over TTL.
        expect(
          () => service.run(temp.path, codingPrompt: 'test', maxSteps: 1),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already running'),
            ),
          ),
        );
      },
    );

    test(
      'stop signal detected between steps causes clean termination',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_lock_stop_',
        );
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        var stepCount = 0;
        final service = _TestRunService(
          stepService: _CallbackStepService((projectRoot) {
            stepCount += 1;
            if (stepCount == 1) {
              // After first step, write stop signal.
              final stopFile = File(layout.autopilotStopPath);
              stopFile.parent.createSync(recursive: true);
              stopFile.writeAsStringSync(
                DateTime.now().toUtc().toIso8601String(),
              );
            }
            return _idleResult();
          }),
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'test',
          maxSteps: 10,
        );

        // Should have stopped after step 1 (stop signal checked between steps).
        expect(result.totalSteps, lessThanOrEqualTo(2));
        // Lock must be released.
        expect(File(layout.autopilotLockPath).existsSync(), isFalse);

        final state = StateStore(layout.statePath).read();
        expect(state.autopilotRunning, isFalse);

        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('orchestrator_run_stop_requested'));
      },
    );

    test('lock file is always cleaned up even when run throws', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_lock_cleanup_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final service = _TestRunService(stepService: _CrashStepService());

      final result = await service.run(
        temp.path,
        codingPrompt: 'test',
        maxSteps: 2,
        maxConsecutiveFailures: 3,
      );

      // Lock must be released even after failures.
      expect(File(layout.autopilotLockPath).existsSync(), isFalse);
      expect(result.failedSteps, greaterThan(0));
    });
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

class _TestRunService extends OrchestratorRunService {
  _TestRunService({super.stepService})
    : super(
        autopilotPreflightService: _AlwaysPassPreflightService(),
        sleep: (_) async {},
      );
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

class _IdleStepService extends OrchestratorStepService {
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
    return _idleResult();
  }
}

class _CallbackStepService extends OrchestratorStepService {
  _CallbackStepService(this.callback);

  final OrchestratorStepResult Function(String projectRoot) callback;

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
    return callback(projectRoot);
  }
}

class _CrashStepService extends OrchestratorStepService {
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
    throw StateError('Simulated crash in step');
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
