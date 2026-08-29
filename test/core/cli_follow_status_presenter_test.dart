import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/output/cli_output.dart';
import 'package:genaisys/core/cli/shared/cli_follow_status_presenter.dart';

const _healthySnapshot = AppHealthSnapshotDto(
  agent: AppHealthCheckDto(ok: true, message: 'agent ok'),
  allowlist: AppHealthCheckDto(ok: true, message: 'allowlist ok'),
  git: AppHealthCheckDto(ok: true, message: 'git ok'),
  review: AppHealthCheckDto(ok: true, message: 'review ok'),
);

const _emptyTelemetry = AppRunTelemetryDto(
  recentEvents: [],
  errorClass: null,
  errorKind: null,
  errorMessage: null,
  agentExitCode: null,
  agentStderrExcerpt: null,
  lastErrorEvent: null,
);

const _healthSummary = AutopilotHealthSummaryDto(
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
);

void main() {
  test('formatCliFollowStatus plain: renders expected status line', () {
    const dto = AutopilotStatusDto(
      autopilotRunning: true,
      pid: 42,
      startedAt: '2026-02-11T10:00:00Z',
      lastLoopAt: '2026-02-11T10:05:00Z',
      consecutiveFailures: 3,
      lastError: '  provider timeout  ',
      subtaskQueue: ['A'],
      currentSubtask: 'A',
      lastStepSummary: AutopilotStepSummaryDto(
        stepId: 'step-1',
        taskId: 'task-1',
      ),
      health: _healthySnapshot,
      telemetry: _emptyTelemetry,
      healthSummary: _healthSummary,
      stallReason: null,
      stallDetail: null,
    );

    final line = formatCliFollowStatus(
      dto,
      output: CliOutput.plain,
      nowUtc: DateTime.parse('2026-02-11T11:00:00Z'),
    );

    expect(
      line,
      '11:00:00 status=RUNNING last_loop=10:05:00'
      ' active="task-1" failures=3 error="provider timeout"',
    );
  });

  test('formatCliFollowStatus plain: falls back to telemetry error and step id',
      () {
    const dto = AutopilotStatusDto(
      autopilotRunning: false,
      pid: null,
      startedAt: null,
      lastLoopAt: null,
      consecutiveFailures: 0,
      lastError: null,
      subtaskQueue: [],
      currentSubtask: null,
      lastStepSummary: AutopilotStepSummaryDto(stepId: 'step-9'),
      health: _healthySnapshot,
      telemetry: AppRunTelemetryDto(
        recentEvents: [],
        errorClass: null,
        errorKind: null,
        errorMessage: '  stalled  ',
        agentExitCode: null,
        agentStderrExcerpt: null,
        lastErrorEvent: null,
      ),
      healthSummary: _healthSummary,
      stallReason: 'cooldown',
      stallDetail: null,
    );

    final line = formatCliFollowStatus(
      dto,
      output: CliOutput.plain,
      nowUtc: DateTime.parse('2026-02-11T11:10:00Z'),
    );

    expect(
      line,
      '11:10:00 status=STOPPED last_loop=(none)'
      ' active="step-9" failures=0 error="stalled"',
    );
  });

  test('formatCliFollowStatus rich: includes bold status and bullet separators',
      () {
    const dto = AutopilotStatusDto(
      autopilotRunning: true,
      pid: 42,
      startedAt: '2026-02-11T10:00:00Z',
      lastLoopAt: '2026-02-11T10:05:00Z',
      consecutiveFailures: 0,
      lastError: null,
      subtaskQueue: [],
      currentSubtask: null,
      lastStepSummary: AutopilotStepSummaryDto(
        stepId: 'step-1',
        taskId: 'my-task',
      ),
      health: _healthySnapshot,
      telemetry: _emptyTelemetry,
      healthSummary: _healthSummary,
      stallReason: null,
      stallDetail: null,
    );

    final line = formatCliFollowStatus(
      dto,
      output: CliOutput.rich,
      nowUtc: DateTime.parse('2026-02-11T11:00:00Z'),
    );

    expect(line, contains('RUNNING'));
    expect(line, contains('·'));
    expect(line, contains('my-task'));
    expect(line, contains('0 failures'));
  });
}
