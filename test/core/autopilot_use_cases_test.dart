import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/models/health_snapshot.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/observability/health_check_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/observability/run_telemetry_service.dart';

class _FakeStepService implements OrchestratorStepService {
  _FakeStepService(this.handler);

  final Future<OrchestratorStepResult> Function(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  })
  handler;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) {
    return handler(
      projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary,
      overwriteArtifacts: overwriteArtifacts,
      minOpenTasks: minOpenTasks,
      maxPlanAdd: maxPlanAdd,
      maxTaskRetries: maxTaskRetries,
    );
  }
}

class _FakeHealthCheckService extends HealthCheckService {
  _FakeHealthCheckService(this.snapshot);

  final HealthSnapshot snapshot;

  @override
  HealthSnapshot check(String projectRoot, {Map<String, String>? environment}) {
    return snapshot;
  }
}

class _FakeRunTelemetryService extends RunTelemetryService {
  _FakeRunTelemetryService(this.snapshot);

  final RunTelemetrySnapshot snapshot;

  @override
  RunTelemetrySnapshot load(String projectRoot, {int recentLimit = 5}) {
    return snapshot;
  }
}

class _FakeRunService implements OrchestratorRunService {
  _FakeRunService({this.onRun, this.onGetStatus, this.onStop});

  @override
  void Function()? heartbeatWriterForTest;

  Future<OrchestratorRunResult> Function(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts,
    int? minOpenTasks,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle,
    int? maxConsecutiveFailures,
    int? maxTaskRetries,
    bool? unattendedMode,
    bool? overrideSafety,
  })?
  onRun;

  AutopilotStatus Function(String projectRoot)? onGetStatus;

  Future<void> Function(String projectRoot)? onStop;

  @override
  void requestStop(String projectRoot) {}

  @override
  AutopilotStatus getStatus(String projectRoot) {
    final handler = onGetStatus;
    if (handler == null) {
      throw UnimplementedError('onGetStatus not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<void> stop(String projectRoot) {
    final handler = onStop;
    if (handler == null) {
      throw UnimplementedError('onStop not configured');
    }
    return handler(projectRoot);
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
      throw UnimplementedError('onRun not configured');
    }
    return handler(
      projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary,
      overwriteArtifacts: overwriteArtifacts,
      minOpenTasks: minOpenTasks,
      maxPlanAdd: maxPlanAdd,
      stepSleep: stepSleep,
      idleSleep: idleSleep,
      maxSteps: maxSteps,
      stopWhenIdle: stopWhenIdle,
      maxConsecutiveFailures: maxConsecutiveFailures,
      maxTaskRetries: maxTaskRetries,
      unattendedMode: unattendedMode,
      overrideSafety: overrideSafety,
    );
  }

  @override
  int? pidOrNull() => null;
}

void main() {
  group('AutopilotStepUseCase', () {
    test('maps OrchestratorStepResult to AutopilotStepDto', () async {
      String? lastProjectRoot;
      String? lastPrompt;
      String? lastTestSummary;
      bool? lastOverwrite;
      int? lastMinOpen;
      int? lastMaxPlanAdd;

      final service = _FakeStepService((
        projectRoot, {
        required String codingPrompt,
        String? testSummary,
        bool overwriteArtifacts = false,
        int? minOpenTasks,
        int? maxPlanAdd,
        int? maxTaskRetries,
      }) {
        lastProjectRoot = projectRoot;
        lastPrompt = codingPrompt;
        lastTestSummary = testSummary;
        lastOverwrite = overwriteArtifacts;
        lastMinOpen = minOpenTasks;
        lastMaxPlanAdd = maxPlanAdd;
        return Future.value(
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: true,
            activeTaskId: 'alpha-1',
            activeTaskTitle: 'Alpha',
            plannedTasksAdded: 2,
            reviewDecision: 'approved',
            retryCount: 1,
            blockedTask: false,
            deactivatedTask: true,
            currentSubtask: null,
            autoMarkedDone: true,
            approvedDiffStats: null,
          ),
        );
      });

      final useCase = AutopilotStepUseCase(service: service);
      final result = await useCase.run(
        '/tmp/project',
        prompt: 'Implement step',
        testSummary: 'All green',
        overwrite: true,
        minOpen: 3,
        maxPlanAdd: 2,
      );

      expect(result.ok, isTrue);
      expect(result.data!.executedCycle, isTrue);
      expect(result.data!.activatedTask, isTrue);
      expect(result.data!.activeTaskTitle, 'Alpha');
      expect(result.data!.plannedTasksAdded, 2);
      expect(result.data!.reviewDecision, 'approved');
      expect(result.data!.retryCount, 1);
      expect(result.data!.deactivatedTask, isTrue);
      expect(lastProjectRoot, '/tmp/project');
      expect(lastPrompt, 'Implement step');
      expect(lastTestSummary, 'All green');
      expect(lastOverwrite, isTrue);
      expect(lastMinOpen, 3);
      expect(lastMaxPlanAdd, 2);
    });

    test('maps StateError to AppErrorKind.notFound', () async {
      final service = _FakeStepService((
        projectRoot, {
        required String codingPrompt,
        String? testSummary,
        bool overwriteArtifacts = false,
        int? minOpenTasks,
        int? maxPlanAdd,
        int? maxTaskRetries,
      }) {
        throw StateError('Task not found');
      });

      final useCase = AutopilotStepUseCase(service: service);
      final result = await useCase.run('/tmp/project', prompt: 'Step');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.notFound);
      expect(result.error?.code, 'not_found');
    });
  });

  group('AutopilotRunUseCase', () {
    test('maps OrchestratorRunResult to AutopilotRunDto', () async {
      String? lastProjectRoot;
      String? lastPrompt;
      bool? lastOverwrite;
      int? lastMinOpen;
      int? lastMaxPlanAdd;
      int? lastMaxSteps;
      bool? lastStopWhenIdle;
      int? lastMaxFailures;
      int? lastMaxTaskRetries;
      bool? lastOverrideSafety;

      final service = _FakeRunService(
        onRun:
            (
              projectRoot, {
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
              bool? unattendedMode,
              bool? overrideSafety,
            }) {
              lastProjectRoot = projectRoot;
              lastPrompt = codingPrompt;
              lastOverwrite = overwriteArtifacts;
              lastMinOpen = minOpenTasks;
              lastMaxPlanAdd = maxPlanAdd;
              lastMaxSteps = maxSteps;
              lastStopWhenIdle = stopWhenIdle;
              lastMaxFailures = maxConsecutiveFailures;
              lastMaxTaskRetries = maxTaskRetries;
              lastOverrideSafety = overrideSafety ?? false;
              return Future.value(
                OrchestratorRunResult(
                  totalSteps: 5,
                  successfulSteps: 4,
                  idleSteps: 1,
                  failedSteps: 0,
                  stoppedByMaxSteps: true,
                  stoppedWhenIdle: false,
                  stoppedBySafetyHalt: false,
                ),
              );
            },
      );

      final useCase = AutopilotRunUseCase(service: service);
      final result = await useCase.run(
        '/tmp/project',
        prompt: 'Implement step',
        overwrite: true,
        minOpen: 2,
        maxPlanAdd: 1,
        maxSteps: 5,
        stopWhenIdle: true,
        maxFailures: 7,
        maxTaskRetries: 2,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      expect(result.ok, isTrue);
      expect(result.data!.totalSteps, 5);
      expect(result.data!.successfulSteps, 4);
      expect(result.data!.stoppedByMaxSteps, isTrue);
      expect(lastProjectRoot, '/tmp/project');
      expect(lastPrompt, 'Implement step');
      expect(lastOverwrite, isTrue);
      expect(lastMinOpen, 2);
      expect(lastMaxPlanAdd, 1);
      expect(lastMaxSteps, 5);
      expect(lastStopWhenIdle, isTrue);
      expect(lastMaxFailures, 7);
      expect(lastMaxTaskRetries, 2);
      expect(lastOverrideSafety, isFalse);
    });

    test('maps ArgumentError to AppErrorKind.invalidInput', () async {
      final service = _FakeRunService(
        onRun:
            (
              projectRoot, {
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
              bool? unattendedMode,
              bool? overrideSafety,
            }) {
              throw ArgumentError('Invalid input');
            },
      );

      final useCase = AutopilotRunUseCase(service: service);
      final result = await useCase.run('/tmp/project', prompt: 'Step');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.invalidInput);
      expect(result.error?.code, 'invalid_input');
    });
  });

  group('AutopilotStatusUseCase', () {
    test('maps AutopilotStatus to AutopilotStatusDto', () async {
      final healthSnapshot = HealthSnapshot(
        agent: HealthCheck(ok: true, message: 'Agent ok'),
        allowlist: HealthCheck(ok: true, message: 'Allowlist ok'),
        git: HealthCheck(ok: true, message: 'Git ok'),
        review: HealthCheck(ok: true, message: 'Review ok'),
      );
      final telemetrySnapshot = RunTelemetrySnapshot(
        recentEvents: const [],
        errorClass: null,
        errorKind: null,
        errorMessage: null,
        agentExitCode: null,
        agentStderrExcerpt: null,
        lastErrorEvent: null,
      );
      final service = _FakeRunService(
        onGetStatus: (projectRoot) {
          return AutopilotStatus(
            isRunning: true,
            pid: 4242,
            startedAt: '2024-01-01T00:00:00Z',
            lastLoopAt: '2024-01-01T00:10:00Z',
            consecutiveFailures: 1,
            lastError: 'last error',
            subtaskQueue: const ['One', 'Two'],
            currentSubtask: 'One',
            lastStepSummary: AutopilotStepSummary(
              stepId: 'run-20240101-1',
              taskId: 'alpha-1',
              subtaskId: 'Subtask A',
              decision: 'approve',
              event: 'orchestrator_run_step',
              timestamp: '2024-01-01T00:09:00Z',
            ),
          );
        },
      );

      final useCase = AutopilotStatusUseCase(
        service: service,
        healthService: _FakeHealthCheckService(healthSnapshot),
        telemetryService: _FakeRunTelemetryService(telemetrySnapshot),
      );
      final result = await useCase.load('/tmp/project');

      expect(result.ok, isTrue);
      expect(result.data!.autopilotRunning, isTrue);
      expect(result.data!.pid, 4242);
      expect(result.data!.subtaskQueue.length, 2);
      expect(result.data!.currentSubtask, 'One');
      expect(result.data!.lastStepSummary?.stepId, 'run-20240101-1');
      expect(result.data!.lastStepSummary?.taskId, 'alpha-1');
      expect(result.data!.health.agent.ok, isTrue);
      expect(result.data!.telemetry.recentEvents.length, 0);
      expect(result.data!.healthSummary.failureTrend.direction, 'stable');
      expect(result.data!.healthSummary.retryDistribution.samples, 0);
      expect(result.data!.healthSummary.cooldown.active, isFalse);
      expect(result.data!.stallReason, 'last_error');
      expect(result.data!.stallDetail, 'last error');
    });

    test('derives stall details for telemetry failure kinds', () async {
      final healthSnapshot = HealthSnapshot(
        agent: HealthCheck(ok: true, message: 'Agent ok'),
        allowlist: HealthCheck(ok: true, message: 'Allowlist ok'),
        git: HealthCheck(ok: true, message: 'Git ok'),
        review: HealthCheck(ok: true, message: 'Review ok'),
      );
      const cases = {
        'no_diff': 'Coding agent produced no diff.',
        'review_rejected': 'Review rejected the last change.',
        'policy_violation': 'A policy violation blocked progress.',
        'analyze_failed': 'Static analysis failed in quality gate.',
        'test_failed': 'Test command failed in quality gate.',
      };
      for (final entry in cases.entries) {
        final telemetrySnapshot = RunTelemetrySnapshot(
          recentEvents: const [],
          errorClass: 'state',
          errorKind: entry.key,
          errorMessage: null,
          agentExitCode: null,
          agentStderrExcerpt: null,
          lastErrorEvent: 'orchestrator_run_error',
        );
        final service = _FakeRunService(
          onGetStatus: (projectRoot) {
            return AutopilotStatus(
              isRunning: true,
              pid: null,
              startedAt: null,
              lastLoopAt: null,
              consecutiveFailures: 0,
              lastError: null,
              subtaskQueue: const [],
              currentSubtask: null,
              lastStepSummary: null,
            );
          },
        );
        final useCase = AutopilotStatusUseCase(
          service: service,
          healthService: _FakeHealthCheckService(healthSnapshot),
          telemetryService: _FakeRunTelemetryService(telemetrySnapshot),
        );

        final result = await useCase.load('/tmp/project');

        expect(result.ok, isTrue);
        expect(result.data!.stallReason, entry.key);
        expect(result.data!.stallDetail, entry.value);
      }
    });

    test('maps FileSystemException to AppErrorKind.ioFailure', () async {
      final service = _FakeRunService(
        onGetStatus: (projectRoot) {
          throw FileSystemException('disk failure');
        },
      );

      final useCase = AutopilotStatusUseCase(service: service);
      final result = await useCase.load('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.ioFailure);
      expect(result.error?.code, 'io_failure');
    });
  });

  group('AutopilotStopUseCase', () {
    test('returns AutopilotStopDto on success', () async {
      String? stoppedRoot;
      final service = _FakeRunService(
        onStop: (projectRoot) {
          stoppedRoot = projectRoot;
          return Future.value();
        },
      );

      final useCase = AutopilotStopUseCase(service: service);
      final result = await useCase.run('/tmp/project');

      expect(result.ok, isTrue);
      expect(result.data!.autopilotStopped, isTrue);
      expect(stoppedRoot, '/tmp/project');
    });

    test(
      'maps StateError policy violations to AppErrorKind.policyViolation',
      () async {
        final service = _FakeRunService(
          onStop: (projectRoot) {
            throw StateError('Policy violation: safety lock');
          },
        );

        final useCase = AutopilotStopUseCase(service: service);
        final result = await useCase.run('/tmp/project');

        expect(result.ok, isFalse);
        expect(result.error?.kind, AppErrorKind.policyViolation);
        expect(result.error?.code, 'policy_violation');
      },
    );
  });

  group('AutopilotHealUseCase', () {
    test('creates incident bundle and maps successful heal step', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_use_case_heal_success_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final layout = ProjectLayout(temp.path);
      final statusService = _FakeRunService(
        onGetStatus: (projectRoot) {
          return AutopilotStatus(
            isRunning: false,
            pid: null,
            startedAt: null,
            lastLoopAt: '2026-02-08T12:00:00Z',
            consecutiveFailures: 2,
            lastError: 'stuck sk-ABCDEFGHIJKLMNOP123456',
            subtaskQueue: const ['Subtask A'],
            currentSubtask: 'Subtask A',
            lastStepSummary: null,
          );
        },
      );
      final telemetryService = _FakeRunTelemetryService(
        RunTelemetrySnapshot(
          recentEvents: const [],
          errorClass: 'stuck',
          errorKind: 'stuck',
          errorMessage: 'No progress threshold reached',
          agentExitCode: null,
          agentStderrExcerpt: null,
          lastErrorEvent: 'orchestrator_run_stuck',
        ),
      );

      String? capturedPrompt;
      final stepService = _FakeStepService((
        projectRoot, {
        required String codingPrompt,
        String? testSummary,
        bool overwriteArtifacts = false,
        int? minOpenTasks,
        int? maxPlanAdd,
        int? maxTaskRetries,
      }) {
        capturedPrompt = codingPrompt;
        return Future.value(
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: true,
            activeTaskId: 'alpha-1',
            activeTaskTitle: 'Fix deadlock',
            plannedTasksAdded: 0,
            reviewDecision: 'approve',
            retryCount: 0,
            blockedTask: false,
            deactivatedTask: true,
            currentSubtask: null,
            autoMarkedDone: true,
            approvedDiffStats: null,
          ),
        );
      });

      final useCase = AutopilotHealUseCase(
        stepService: stepService,
        runService: statusService,
        telemetryService: telemetryService,
      );
      final result = await useCase.run(
        temp.path,
        reason: 'Stuck Loop',
        detail: 'Quality gate loop',
      );

      expect(result.ok, isTrue);
      final dto = result.data!;
      expect(dto.reason, 'stuck_loop');
      expect(dto.detail, 'Quality gate loop');
      expect(dto.recovered, isTrue);
      expect(dto.reviewDecision, 'approve');
      expect(File(dto.bundlePath).existsSync(), isTrue);
      final bundle = File(dto.bundlePath).readAsStringSync();
      expect(bundle, contains('"reason": "stuck_loop"'));
      expect(bundle, contains('"detail": "Quality gate loop"'));
      expect(bundle, isNot(contains('sk-ABCDEFGHIJKLMNOP123456')));
      expect(bundle, contains('[REDACTED:OPENAI_TOKEN]'));
      expect(bundle, contains('"redaction"'));
      expect(capturedPrompt, contains('AUTOPILOT INCIDENT HEAL MODE'));
      expect(
        capturedPrompt,
        contains('Incident bundle path: ${dto.bundlePath}'),
      );
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"incident_heal_start"'));
      expect(runLog, contains('"event":"incident_heal_end"'));
    });

    test('marks heal as unrecovered on reject', () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_use_case_heal_reject_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final stepService = _FakeStepService((
        projectRoot, {
        required String codingPrompt,
        String? testSummary,
        bool overwriteArtifacts = false,
        int? minOpenTasks,
        int? maxPlanAdd,
        int? maxTaskRetries,
      }) {
        return Future.value(
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: false,
            activeTaskId: 'alpha-2',
            activeTaskTitle: 'Fix formatter loop',
            plannedTasksAdded: 0,
            reviewDecision: 'reject',
            retryCount: 1,
            blockedTask: false,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: false,
            approvedDiffStats: null,
          ),
        );
      });

      final useCase = AutopilotHealUseCase(stepService: stepService);
      final result = await useCase.run(temp.path, reason: 'review_rejected');

      expect(result.ok, isTrue);
      expect(result.data!.recovered, isFalse);
      expect(result.data!.reviewDecision, 'reject');
    });
  });
}
