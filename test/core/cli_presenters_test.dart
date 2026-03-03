import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/presenters/json_presenter.dart';
import 'package:genaisys/core/cli/presenters/text_presenter.dart';

const _autopilotHealthSummary = AutopilotHealthSummaryDto(
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

Future<String> _captureOutput(void Function(IOSink sink) writer) async {
  final tempDir = Directory.systemTemp.createTempSync('genaisys_presenter_');
  addTearDown(() {
    tempDir.deleteSync(recursive: true);
  });
  final file = File('${tempDir.path}/out.txt');
  final sink = file.openWrite();
  writer(sink);
  await sink.flush();
  await sink.close();
  return file.readAsStringSync();
}

void main() {
  test('JsonPresenter.writeStatus outputs stable JSON payload', () async {
    const dto = AppStatusSnapshotDto(
      projectRoot: '/tmp/project',
      tasksTotal: 5,
      tasksOpen: 3,
      tasksDone: 1,
      tasksBlocked: 1,
      activeTaskTitle: null,
      activeTaskId: null,
      reviewStatus: null,
      reviewUpdatedAt: null,
      cycleCount: 7,
      lastUpdated: null,
      workflowStage: 'coding',
      health: AppHealthSnapshotDto(
        agent: AppHealthCheckDto(ok: true, message: 'Agent ok'),
        allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ok'),
        git: AppHealthCheckDto(ok: true, message: 'Git ok'),
        review: AppHealthCheckDto(ok: true, message: 'Review ok'),
      ),
      telemetry: AppRunTelemetryDto(
        recentEvents: [],
        errorClass: null,
        errorKind: null,
        errorMessage: null,
        agentExitCode: null,
        agentStderrExcerpt: null,
        lastErrorEvent: null,
      ),
    );

    final output = await _captureOutput(
      (sink) => const JsonPresenter().writeStatus(sink, dto),
    );

    final expected = jsonEncode(<String, Object?>{
      'project_root': '/tmp/project',
      'tasks_total': 5,
      'tasks_open': 3,
      'tasks_blocked': 1,
      'tasks_done': 1,
      'active_task': '(none)',
      'active_task_id': '(none)',
      'review_status': '(none)',
      'review_updated_at': '(none)',
      'workflow_stage': 'coding',
      'cycle_count': 7,
      'last_updated': '(unknown)',
      'last_error': null,
      'last_error_class': null,
      'last_error_kind': null,
      'health': <String, Object?>{
        'all_ok': true,
        'agent': <String, Object?>{'ok': true, 'message': 'Agent ok'},
        'allowlist': <String, Object?>{'ok': true, 'message': 'Allowlist ok'},
        'git': <String, Object?>{'ok': true, 'message': 'Git ok'},
        'review': <String, Object?>{'ok': true, 'message': 'Review ok'},
      },
      'telemetry': <String, Object?>{
        'error_class': null,
        'error_kind': null,
        'error_message': null,
        'agent_exit_code': null,
        'agent_stderr_excerpt': null,
        'last_error_event': null,
        'recent_events': [],
      },
    });

    expect(output, '$expected\n');
  });

  test(
    'JsonPresenter.writeStatus includes telemetry health summary and event correlation fields',
    () async {
      const dto = AppStatusSnapshotDto(
        projectRoot: '/tmp/project',
        tasksTotal: 1,
        tasksOpen: 1,
        tasksDone: 0,
        tasksBlocked: 0,
        activeTaskTitle: null,
        activeTaskId: null,
        reviewStatus: null,
        reviewUpdatedAt: null,
        cycleCount: 1,
        lastUpdated: '2026-02-11T00:00:00Z',
        workflowStage: 'idle',
        health: AppHealthSnapshotDto(
          agent: AppHealthCheckDto(ok: true, message: 'Agent ok'),
          allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ok'),
          git: AppHealthCheckDto(ok: true, message: 'Git ok'),
          review: AppHealthCheckDto(ok: true, message: 'Review ok'),
        ),
        telemetry: AppRunTelemetryDto(
          recentEvents: [
            AppRunLogEventDto(
              timestamp: '2026-02-11T00:00:01Z',
              eventId: 'evt-1',
              correlationId: 'step_id:step-1|task_id:task-1',
              event: 'orchestrator_run_step',
              message: 'Step completed',
              correlation: {'task_id': 'task-1', 'step_id': 'step-1'},
              data: {'retry_count': 1},
            ),
          ],
          errorClass: null,
          errorKind: null,
          errorMessage: null,
          agentExitCode: null,
          agentStderrExcerpt: null,
          lastErrorEvent: null,
          healthSummary: AppRunHealthSummaryDto(
            failureTrend: AppRunFailureTrendDto(
              direction: 'stable',
              recentFailures: 0,
              previousFailures: 0,
              windowSeconds: 900,
              sampleSize: 1,
              dominantErrorKind: null,
            ),
            retryDistribution: AppRunRetryDistributionDto(
              samples: 1,
              retry0: 0,
              retry1: 1,
              retry2Plus: 0,
              maxRetry: 1,
            ),
            cooldown: AppRunCooldownDto(
              active: false,
              totalSeconds: 0,
              remainingSeconds: 0,
              until: null,
              sourceEvent: null,
              reason: null,
            ),
          ),
        ),
      );

      final output = await _captureOutput(
        (sink) => const JsonPresenter().writeStatus(sink, dto),
      );
      final payload = jsonDecode(output) as Map<String, dynamic>;
      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expect(telemetry['health_summary'], isA<Map<String, dynamic>>());

      final event =
          (telemetry['recent_events'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(event['event_id'], 'evt-1');
      expect(event['correlation_id'], 'step_id:step-1|task_id:task-1');
      expect(event['correlation'], isA<Map<String, dynamic>>());
    },
  );

  test('TextPresenter.writeTasks prints expected lines with ids', () async {
    const dto = AppTaskListDto(
      total: 2,
      tasks: [
        AppTaskDto(
          id: 'alpha-1',
          title: 'Alpha',
          section: 'Backlog',
          priority: 'p1',
          category: 'core',
          status: AppTaskStatus.open,
        ),
        AppTaskDto(
          id: 'beta-2',
          title: 'Beta',
          section: 'InProgress',
          priority: 'p2',
          category: 'docs',
          status: AppTaskStatus.done,
        ),
      ],
    );

    final output = await _captureOutput(
      (sink) => const TextPresenter().writeTasks(sink, dto, showIds: true),
    );

    const expected =
        '[Backlog] open P1 CORE - Alpha [id: alpha-1]\n'
        '[InProgress] done P2 DOCS - Beta [id: beta-2]\n';

    expect(output, expected);
  });

  test(
    'JsonPresenter.writeAutopilotStatus outputs stable JSON payload',
    () async {
      const dto = AutopilotStatusDto(
        autopilotRunning: true,
        pid: 4242,
        startedAt: '2026-02-05T10:00:00Z',
        lastLoopAt: '2026-02-05T10:05:00Z',
        consecutiveFailures: 1,
        lastError: null,
        subtaskQueue: ['Subtask A'],
        currentSubtask: 'Subtask A',
        health: AppHealthSnapshotDto(
          agent: AppHealthCheckDto(ok: true, message: 'Agent ok'),
          allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ok'),
          git: AppHealthCheckDto(ok: true, message: 'Git ok'),
          review: AppHealthCheckDto(ok: true, message: 'Review ok'),
        ),
        telemetry: AppRunTelemetryDto(
          recentEvents: [],
          errorClass: null,
          errorKind: null,
          errorMessage: null,
          agentExitCode: null,
          agentStderrExcerpt: null,
          lastErrorEvent: null,
        ),
        healthSummary: _autopilotHealthSummary,
        stallReason: null,
        stallDetail: null,
        lastStepSummary: AutopilotStepSummaryDto(
          stepId: 'run-20260205-1',
          taskId: 'alpha-1',
          subtaskId: 'Subtask A',
          decision: 'approve',
          event: 'orchestrator_run_step',
          timestamp: '2026-02-05T10:04:59Z',
        ),
      );

      final output = await _captureOutput(
        (sink) => const JsonPresenter().writeAutopilotStatus(sink, dto),
      );

      final expected = jsonEncode(<String, Object?>{
        'autopilot_running': true,
        'pid': 4242,
        'started_at': '2026-02-05T10:00:00Z',
        'last_loop_at': '2026-02-05T10:05:00Z',
        'consecutive_failures': 1,
        'last_error': null,
        'last_error_class': null,
        'last_error_kind': null,
        'subtask_queue': ['Subtask A'],
        'current_subtask': 'Subtask A',
        'stall_reason': null,
        'stall_detail': null,
        'health': <String, Object?>{
          'all_ok': true,
          'agent': <String, Object?>{'ok': true, 'message': 'Agent ok'},
          'allowlist': <String, Object?>{'ok': true, 'message': 'Allowlist ok'},
          'git': <String, Object?>{'ok': true, 'message': 'Git ok'},
          'review': <String, Object?>{'ok': true, 'message': 'Review ok'},
        },
        'telemetry': <String, Object?>{
          'error_class': null,
          'error_kind': null,
          'error_message': null,
          'agent_exit_code': null,
          'agent_stderr_excerpt': null,
          'last_error_event': null,
          'recent_events': [],
        },
        'health_summary': <String, Object?>{
          'failure_trend': <String, Object?>{
            'direction': 'stable',
            'recent_failures': 0,
            'previous_failures': 0,
            'window_seconds': 900,
            'sample_size': 0,
            'dominant_error_kind': null,
          },
          'retry_distribution': <String, Object?>{
            'samples': 0,
            'retry_0': 0,
            'retry_1': 0,
            'retry_2_plus': 0,
            'max_retry': 0,
          },
          'cooldown': <String, Object?>{
            'active': false,
            'total_seconds': 0,
            'remaining_seconds': 0,
            'until': null,
            'source_event': null,
            'reason': null,
          },
        },
        'hitl_gate_pending': false,
        'last_step_summary': <String, Object?>{
          'step_id': 'run-20260205-1',
          'task_id': 'alpha-1',
          'subtask_id': 'Subtask A',
          'decision': 'approve',
          'event': 'orchestrator_run_step',
          'timestamp': '2026-02-05T10:04:59Z',
        },
      });

      expect(output, '$expected\n');
    },
  );

  test(
    'JsonPresenter.writeAutopilotStatus includes hitl_gate_event when gate is pending',
    () async {
      const dto = AutopilotStatusDto(
        autopilotRunning: true,
        pid: null,
        startedAt: null,
        lastLoopAt: null,
        consecutiveFailures: 0,
        lastError: null,
        subtaskQueue: [],
        currentSubtask: null,
        lastStepSummary: null,
        stallReason: null,
        stallDetail: null,
        hitlGatePending: true,
        hitlGateEvent: 'before_sprint',
        health: AppHealthSnapshotDto(
          agent: AppHealthCheckDto(ok: true, message: ''),
          allowlist: AppHealthCheckDto(ok: true, message: ''),
          git: AppHealthCheckDto(ok: true, message: ''),
          review: AppHealthCheckDto(ok: true, message: ''),
        ),
        telemetry: AppRunTelemetryDto(
          recentEvents: [],
          errorClass: null,
          errorKind: null,
          errorMessage: null,
          agentExitCode: null,
          agentStderrExcerpt: null,
          lastErrorEvent: null,
        ),
        healthSummary: _autopilotHealthSummary,
      );

      final output = await _captureOutput(
        (sink) => const JsonPresenter().writeAutopilotStatus(sink, dto),
      );

      final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(decoded['hitl_gate_pending'], isTrue);
      expect(decoded['hitl_gate_event'], 'before_sprint');
    },
  );
}
