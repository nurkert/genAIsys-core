import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

/// Hardening: heartbeat lock validation.
///
/// Verifies:
/// - Heartbeat interval respects TTL ratio: min(ttl/4, 5s)
/// - Lock stolen mid-step → abort with StateError
void main() {
  group('Heartbeat lock validation', () {
    test('heartbeat interval respects TTL/4 ratio for short TTL', () async {
      // With a 12-second TTL, the interval should be 3s (12/4 = 3 < 5).
      // We verify this by having a step that takes long enough for at least
      // one heartbeat tick to occur. With a 3s interval, a 4s step should
      // see at least one heartbeat update. With the old fixed 5s, it would
      // not have fired yet.
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_hb_ttl_ratio_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Configure a short lock TTL (12s → interval = 3s).
      File(layout.configPath).writeAsStringSync('''
autopilot:
  lock_ttl_seconds: 12
''');

      DateTime? heartbeatAtStepStart;
      DateTime? heartbeatAtStepEnd;

      final service = _TestRunService(
        stepService: _CallbackStepService((projectRoot) async {
          final lockFile = File(layout.autopilotLockPath);
          heartbeatAtStepStart = _readHeartbeatTimestamp(lockFile);

          // Wait 3.5 seconds — longer than TTL/4 (3s) but shorter than 5s.
          await Future<void>.delayed(const Duration(milliseconds: 3500));

          heartbeatAtStepEnd = _readHeartbeatTimestamp(lockFile);
          return _idleResult();
        }),
      );

      await service.run(temp.path, codingPrompt: 'test', maxSteps: 1);

      // If interval = min(12/4, 5) = 3s, the heartbeat should have been
      // updated during the 3.5s step.
      expect(heartbeatAtStepStart, isNotNull);
      expect(heartbeatAtStepEnd, isNotNull);
      expect(
        heartbeatAtStepEnd!.isAfter(heartbeatAtStepStart!),
        isTrue,
        reason: 'Heartbeat should have been updated during the step '
            '(interval=3s, step duration=3.5s)',
      );
    });

    test('heartbeat interval caps at 5s for large TTL', () async {
      // With a 600s (10 min) TTL, the interval should be 5s (min(150, 5)).
      // We verify the heartbeat fires within 6s, confirming a <= 5s interval.
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_hb_cap_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Default TTL (600s) → interval = min(150, 5) = 5s.
      File(layout.configPath).writeAsStringSync('''
autopilot:
  lock_ttl_seconds: 600
''');

      DateTime? heartbeatAtStepStart;
      DateTime? heartbeatAtStepEnd;

      final service = _TestRunService(
        stepService: _CallbackStepService((projectRoot) async {
          final lockFile = File(layout.autopilotLockPath);
          heartbeatAtStepStart = _readHeartbeatTimestamp(lockFile);

          // Wait 5.5s — just over the 5s cap.
          await Future<void>.delayed(const Duration(milliseconds: 5500));

          heartbeatAtStepEnd = _readHeartbeatTimestamp(lockFile);
          return _idleResult();
        }),
      );

      await service.run(temp.path, codingPrompt: 'test', maxSteps: 1);

      expect(heartbeatAtStepStart, isNotNull);
      expect(heartbeatAtStepEnd, isNotNull);
      expect(
        heartbeatAtStepEnd!.isAfter(heartbeatAtStepStart!),
        isTrue,
        reason: 'Heartbeat should have been updated within 5s cap interval',
      );
    });

    test('lock stolen mid-step aborts with StateError', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_hb_stolen_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Use short TTL so heartbeat fires quickly (every 1s with TTL=4).
      File(layout.configPath).writeAsStringSync('''
autopilot:
  lock_ttl_seconds: 4
''');

      final service = _TestRunService(
        stepService: _CallbackStepService((projectRoot) async {
          // Overwrite the lock file with a different PID to simulate theft.
          final lockFile = File(layout.autopilotLockPath);
          final now = DateTime.now().toUtc().toIso8601String();
          lockFile.writeAsStringSync('''
version=1
started_at=$now
last_heartbeat=$now
pid=999888
project_root=${temp.path}
''');

          // Wait for the heartbeat timer to fire and detect the theft.
          // TTL=4s → interval = 1s.
          await Future<void>.delayed(const Duration(milliseconds: 1500));

          // If ownership verification works, we should never reach here
          // because the heartbeat timer throws StateError. But if we do
          // reach here, return normally — the test expectation will catch it.
          return _idleResult();
        }),
      );

      // The run should complete (the heartbeat timer exception is caught
      // internally), but the step should be counted as a failure.
      final result = await service.run(
        temp.path,
        codingPrompt: 'test',
        maxSteps: 1,
        maxConsecutiveFailures: 3,
      );

      // The step should have failed due to lock theft.
      expect(result.failedSteps, greaterThan(0));

      // Verify the run log records the error.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        anyOf(
          contains('Lock stolen'),
          contains('lock_stolen'),
          contains('orchestrator_run_step_error'),
        ),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

DateTime? _readHeartbeatTimestamp(File lockFile) {
  try {
    final lines = lockFile.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('last_heartbeat=')) {
        final raw = line.substring('last_heartbeat='.length).trim();
        return DateTime.tryParse(raw)?.toUtc();
      }
    }
  } catch (_) {}
  return null;
}

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

class _CallbackStepService extends OrchestratorStepService {
  _CallbackStepService(this.callback);

  final Future<OrchestratorStepResult> Function(String projectRoot) callback;

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
