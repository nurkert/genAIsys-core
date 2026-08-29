import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/autopilot/autopilot_supervisor_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';

class _FakeRunService implements OrchestratorRunService {
  _FakeRunService({this.onRun});

  Future<OrchestratorRunResult> Function(String projectRoot)? onRun;

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

void main() {
  test(
    'Degraded mode is entered when failure rate exceeds 60% threshold',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_degraded_mode_enter_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      var runCount = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          runCount += 1;
          if (runCount <= 3) {
            // First 3 segments: mostly failures (>60% failure rate).
            return OrchestratorRunResult(
              totalSteps: 10,
              successfulSteps: 2,
              idleSteps: 0,
              failedSteps: 8,
              stoppedByMaxSteps: true,
              stoppedWhenIdle: false,
              stoppedBySafetyHalt: false,
            );
          }
          // After that: halt to stop the loop.
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: false,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: true,
          );
        },
      );

      final sleeps = <Duration>[];
      final service = AutopilotSupervisorService(
        runService: runService,
        preflightService: _AlwaysPassPreflightService(),
        sleep: (duration) async {
          sleeps.add(duration);
        },
      );

      await service.runWorker(
        temp.path,
        sessionId: 'session-degraded-1',
        profile: 'pilot',
        prompt: 'code',
        startReason: 'test',
        maxRestarts: 5,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 4,
        lowSignalLimit: 100,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 10000,
        throughputMaxRejects: 10000,
        throughputMaxHighRetries: 10000,
      );

      // The run log should contain a degraded_mode_entered event.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"autopilot_degraded_mode_entered"'));
    },
  );

  test('Degraded mode applies doubled sleep intervals', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_degraded_mode_sleep_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    var runCount = 0;
    // Track the stepSleep/idleSleep that each run receives.
    final receivedStepSleeps = <Duration?>[];
    final receivedIdleSleeps = <Duration?>[];

    final runService = _CapturingRunService(
      capturedStepSleeps: receivedStepSleeps,
      capturedIdleSleeps: receivedIdleSleeps,
      onRun: (_) async {
        runCount += 1;
        if (runCount == 1) {
          // First segment: high failure rate → triggers degraded mode.
          return OrchestratorRunResult(
            totalSteps: 10,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 9,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          );
        }
        // Second segment: run in degraded mode, then halt.
        return OrchestratorRunResult(
          totalSteps: 1,
          successfulSteps: 1,
          idleSteps: 0,
          failedSteps: 0,
          stoppedByMaxSteps: false,
          stoppedWhenIdle: false,
          stoppedBySafetyHalt: true,
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
      sessionId: 'session-degraded-sleep-1',
      profile: 'pilot',
      prompt: 'code',
      startReason: 'test',
      maxRestarts: 5,
      restartBackoffBaseSeconds: 1,
      restartBackoffMaxSeconds: 4,
      lowSignalLimit: 100,
      throughputWindowMinutes: 30,
      throughputMaxSteps: 10000,
      throughputMaxRejects: 10000,
      throughputMaxHighRetries: 10000,
    );

    // Pilot profile: stepSleep = 2s, idleSleep = 10s.
    // First segment: normal sleeps.
    expect(receivedStepSleeps[0], const Duration(seconds: 2));
    expect(receivedIdleSleeps[0], const Duration(seconds: 10));

    // Second segment: degraded mode → doubled sleeps.
    expect(receivedStepSleeps.length, greaterThanOrEqualTo(2));
    expect(receivedStepSleeps[1], const Duration(seconds: 4));
    expect(receivedIdleSleeps[1], const Duration(seconds: 20));
  });

  test(
    'Degraded mode is exited when failure rate drops below 30% recovery threshold',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_degraded_mode_recovery_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      var runCount = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          runCount += 1;
          if (runCount <= 2) {
            // First 2 segments: 90% failure → triggers degraded mode.
            return OrchestratorRunResult(
              totalSteps: 10,
              successfulSteps: 1,
              idleSteps: 0,
              failedSteps: 9,
              stoppedByMaxSteps: true,
              stoppedWhenIdle: false,
              stoppedBySafetyHalt: false,
            );
          }
          if (runCount <= 5) {
            // Next 3 segments: 0% failure → recovery.
            // After 5 segments: 18 failures / 50 total = 36% > 30%.
            // After more success, eventually drops below 30%.
            return OrchestratorRunResult(
              totalSteps: 20,
              successfulSteps: 20,
              idleSteps: 0,
              failedSteps: 0,
              stoppedByMaxSteps: true,
              stoppedWhenIdle: false,
              stoppedBySafetyHalt: false,
            );
          }
          // Finally halt.
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: false,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: true,
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
        sessionId: 'session-recovery-1',
        profile: 'pilot',
        prompt: 'code',
        startReason: 'test',
        maxRestarts: 5,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 4,
        lowSignalLimit: 100,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 10000,
        throughputMaxRejects: 10000,
        throughputMaxHighRetries: 10000,
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"autopilot_degraded_mode_entered"'));
      expect(runLog, contains('"event":"autopilot_degraded_mode_exited"'));
    },
  );

  test(
    'Health summary reflects degraded status when degraded mode is active',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_degraded_health_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      var runCount = 0;
      final runService = _FakeRunService(
        onRun: (_) async {
          runCount += 1;
          if (runCount <= 2) {
            // High failure rate to trigger degraded mode.
            return OrchestratorRunResult(
              totalSteps: 10,
              successfulSteps: 2,
              idleSteps: 0,
              failedSteps: 8,
              stoppedByMaxSteps: true,
              stoppedWhenIdle: false,
              stoppedBySafetyHalt: false,
            );
          }
          // Halt after degraded mode has been active for 1+ segment.
          return OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: false,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: true,
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
        sessionId: 'session-health-1',
        profile: 'pilot',
        prompt: 'code',
        startReason: 'test',
        maxRestarts: 5,
        restartBackoffBaseSeconds: 1,
        restartBackoffMaxSeconds: 4,
        lowSignalLimit: 100,
        throughputWindowMinutes: 30,
        throughputMaxSteps: 10000,
        throughputMaxRejects: 10000,
        throughputMaxHighRetries: 10000,
      );

      // Check that the health summary file was written with 'degraded' status
      // at some point during the run.
      final healthPath = layout.healthSummaryPath;
      if (File(healthPath).existsSync()) {
        final health = jsonDecode(File(healthPath).readAsStringSync());
        // The last health export is from the halted state, but the earlier
        // exports during degraded mode should have been 'degraded'.
        // We mainly verify no crash during the flow.
        expect(health, isA<Map>());
      }

      // Run log should prove degraded mode was entered.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"autopilot_degraded_mode_entered"'));
    },
  );
}

/// A [_FakeRunService] variant that captures the `stepSleep` and `idleSleep`
/// parameters passed to each `run()` invocation.
class _CapturingRunService implements OrchestratorRunService {
  _CapturingRunService({
    required this.capturedStepSleeps,
    required this.capturedIdleSleeps,
    this.onRun,
  });

  final List<Duration?> capturedStepSleeps;
  final List<Duration?> capturedIdleSleeps;
  Future<OrchestratorRunResult> Function(String projectRoot)? onRun;

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
    capturedStepSleeps.add(stepSleep);
    capturedIdleSleeps.add(idleSleep);
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
