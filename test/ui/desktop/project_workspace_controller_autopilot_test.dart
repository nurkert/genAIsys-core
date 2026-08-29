import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/ui/desktop/controllers/project_workspace_controller.dart';

void main() {
  group('ProjectWorkspaceController autopilot live sync', () {
    test('polls status repeatedly while attached', () async {
      final _FakeAutopilotStatusUseCase fakeStatusUseCase =
          _FakeAutopilotStatusUseCase(<AutopilotStatusDto>[
            _buildStatus(running: false, subtask: 'Subtask A'),
            _buildStatus(running: true, subtask: 'Subtask B'),
          ]);

      final ProjectWorkspaceController controller = ProjectWorkspaceController(
        projectRootPath: '/tmp/genaisys',
        autopilotStatusUseCase: fakeStatusUseCase,
        autopilotPollIntervalRunning: const Duration(milliseconds: 20),
        autopilotPollIntervalIdle: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.attachAutopilotLiveSync();
      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(fakeStatusUseCase.callCount, greaterThanOrEqualTo(2));
      expect(controller.autopilotStatus?.currentSubtask, isNotEmpty);
    });

    test('stops polling after detaching all listeners', () async {
      final _FakeAutopilotStatusUseCase fakeStatusUseCase =
          _FakeAutopilotStatusUseCase(<AutopilotStatusDto>[
            _buildStatus(running: false, subtask: 'Queued A'),
            _buildStatus(running: false, subtask: 'Queued B'),
          ]);

      final ProjectWorkspaceController controller = ProjectWorkspaceController(
        projectRootPath: '/tmp/genaisys',
        autopilotStatusUseCase: fakeStatusUseCase,
        autopilotPollIntervalRunning: const Duration(milliseconds: 20),
        autopilotPollIntervalIdle: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.attachAutopilotLiveSync();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      controller.detachAutopilotLiveSync();
      final int callsAtDetach = fakeStatusUseCase.callCount;

      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(fakeStatusUseCase.callCount, callsAtDetach);
    });
  });
}

AutopilotStatusDto _buildStatus({
  required bool running,
  required String subtask,
}) {
  return AutopilotStatusDto(
    autopilotRunning: running,
    pid: running ? 1234 : null,
    startedAt: running ? '2026-02-12T12:00:00.000Z' : null,
    lastLoopAt: '2026-02-12T12:00:01.000Z',
    consecutiveFailures: 0,
    lastError: null,
    lastErrorClass: null,
    lastErrorKind: null,
    subtaskQueue: const <String>['Queued one', 'Queued two'],
    currentSubtask: subtask,
    lastStepSummary: const AutopilotStepSummaryDto(
      stepId: 'step-1',
      taskId: 'T-1',
      subtaskId: 'S-1',
      decision: 'approve',
      event: 'orchestrator_run_step',
      timestamp: '2026-02-12T12:00:01.000Z',
    ),
    health: const AppHealthSnapshotDto(
      agent: AppHealthCheckDto(ok: true, message: 'ok'),
      allowlist: AppHealthCheckDto(ok: true, message: 'ok'),
      git: AppHealthCheckDto(ok: true, message: 'ok'),
      review: AppHealthCheckDto(ok: true, message: 'ok'),
    ),
    telemetry: const AppRunTelemetryDto(
      recentEvents: <AppRunLogEventDto>[
        AppRunLogEventDto(
          timestamp: '2026-02-12T12:00:01.000Z',
          event: 'orchestrator_run_step',
        ),
      ],
    ),
    healthSummary: const AutopilotHealthSummaryDto(
      failureTrend: AutopilotFailureTrendDto(
        direction: 'stable',
        recentFailures: 0,
        previousFailures: 0,
        windowSeconds: 900,
        sampleSize: 0,
        dominantErrorKind: null,
      ),
      retryDistribution: AutopilotRetryDistributionDto(
        samples: 0,
        retry0: 0,
        retry1: 0,
        retry2Plus: 0,
        maxRetry: 0,
      ),
      cooldown: AutopilotCooldownDto(
        active: false,
        totalSeconds: 0,
        remainingSeconds: 0,
        until: null,
        sourceEvent: null,
        reason: null,
      ),
    ),
    stallReason: null,
    stallDetail: null,
  );
}

class _FakeAutopilotStatusUseCase extends AutopilotStatusUseCase {
  _FakeAutopilotStatusUseCase(this._statuses);

  final List<AutopilotStatusDto> _statuses;
  int callCount = 0;

  @override
  Future<AppResult<AutopilotStatusDto>> load(String projectRoot) async {
    final int index = callCount < _statuses.length
        ? callCount
        : _statuses.length - 1;
    callCount += 1;
    return AppResult.success(_statuses[index]);
  }
}
