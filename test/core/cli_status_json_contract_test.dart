import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'support/cli_json_contract_test_helper.dart';

void main() {
  test(
    'status --json contract keeps required legacy keys in idle state',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_contract_idle_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      await CliRunner().run(['init', temp.path]);

      final payload = runCliJsonCommand(['status', '--json', temp.path]);

      final requiredKeys = <String>[
        'project_root',
        'tasks_total',
        'tasks_open',
        'tasks_blocked',
        'tasks_done',
        'active_task',
        'active_task_id',
        'review_status',
        'review_updated_at',
        'workflow_stage',
        'cycle_count',
        'last_updated',
        'last_error',
        'last_error_class',
        'last_error_kind',
        'health',
        'telemetry',
      ];
      expectStrictKeySet(payload, requiredKeys: requiredKeys);
      expectStableFieldTypes(
        payload,
        typeByKey: <String, Matcher>{
          'tasks_total': isA<int>(),
          'tasks_open': isA<int>(),
          'tasks_blocked': isA<int>(),
          'tasks_done': isA<int>(),
          'cycle_count': isA<int>(),
          'health': isA<Map<String, dynamic>>(),
          'telemetry': isA<Map<String, dynamic>>(),
        },
      );

      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expectMachineReadableErrorFields(telemetry);
      expect(telemetry.containsKey('recent_events'), isTrue);
      expect(telemetry['health_summary'], isA<Map<String, dynamic>>());

      final healthSummary = telemetry['health_summary'] as Map<String, dynamic>;
      expect(healthSummary['failure_trend'], isA<Map<String, dynamic>>());
      expect(healthSummary['retry_distribution'], isA<Map<String, dynamic>>());
      expect(healthSummary['cooldown'], isA<Map<String, dynamic>>());
    },
  );

  test(
    'status --json contract includes machine-readable reason for preflight blocked state',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_contract_preflight_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      await CliRunner().run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          autopilotRun: AutopilotRunState(
            lastError: 'Preflight blocked due to git dirty state.',
            lastErrorClass: 'preflight',
            lastErrorKind: 'git_dirty',
          ),
        ),
      );
      _appendRunLog(
        layout,
        event: 'preflight_failed',
        message: 'Preflight failed before step execution',
        data: <String, Object?>{
          'error_class': 'preflight',
          'error_kind': 'git_dirty',
          'step_id': 'step-preflight-1',
          'task_id': 'task-alpha',
          'subtask_id': 'subtask-alpha',
        },
      );

      final payload = runCliJsonCommand(['status', '--json', temp.path]);

      expect(payload['last_error_class'], 'preflight');
      expect(payload['last_error_kind'], 'git_dirty');

      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expectMachineReadableErrorFields(telemetry);
      expect(telemetry['error_class'], 'preflight');
      expect(telemetry['error_kind'], 'git_dirty');
      expect(telemetry['last_error_event'], 'preflight_failed');

      final recentEvents = telemetry['recent_events'] as List<dynamic>;
      final preflightEvent = recentEvents
          .cast<Map<String, dynamic>>()
          .lastWhere((entry) => entry['event'] == 'preflight_failed');
      expect(preflightEvent['event_id'], isA<String>());
      expect(preflightEvent['correlation_id'], isA<String>());
      final data = preflightEvent['data'] as Map<String, dynamic>;
      expect(data['error_class'], 'preflight');
      expect(data['error_kind'], 'git_dirty');
      expect(data['step_id'], 'step-preflight-1');
      expect(data['task_id'], 'task-alpha');
      expect(data['subtask_id'], 'subtask-alpha');
      final correlation = preflightEvent['correlation'] as Map<String, dynamic>;
      expect(correlation['step_id'], 'step-preflight-1');
      expect(correlation['task_id'], 'task-alpha');
      expect(correlation['subtask_id'], 'subtask-alpha');
    },
  );

  test(
    'status --json contract preserves compatibility keys for progress-failure and safety-halt edges',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_contract_progress_halt_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      await CliRunner().run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: stateStore.read().activeTask.copyWith(
            reviewStatus: 'rejected',
            reviewUpdatedAt: '2026-02-09T00:00:00Z',
          ),
          autopilotRun: AutopilotRunState(
            lastError: 'Safety halt after repeated no-progress failures.',
            lastErrorClass: 'reliability',
            lastErrorKind: 'deterministic_halt',
          ),
        ),
      );
      _appendRunLog(
        layout,
        event: 'review_reject',
        message: 'Review decision recorded',
        data: <String, Object?>{
          'error_class': 'review',
          'error_kind': 'review_rejected',
          'task_id': 'task-review',
        },
      );
      _appendRunLog(
        layout,
        event: 'orchestrator_run_safety_halt',
        message: 'Autopilot halted: deterministic halt threshold reached',
        data: <String, Object?>{
          'error_class': 'reliability',
          'error_kind': 'deterministic_halt',
          'task_id': 'task-review',
        },
      );

      final payload = runCliJsonCommand(['status', '--json', temp.path]);
      expect(payload.containsKey('active_task'), isTrue);
      expect(payload.containsKey('active_task_id'), isTrue);
      expect(payload.containsKey('review_status'), isTrue);
      expect(payload.containsKey('review_updated_at'), isTrue);
      expect(payload.containsKey('last_updated'), isTrue);

      expect(payload['last_error_class'], 'reliability');
      expect(payload['last_error_kind'], 'deterministic_halt');

      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expectMachineReadableErrorFields(telemetry);
      expect(telemetry['error_class'], 'reliability');
      expect(telemetry['error_kind'], 'deterministic_halt');
      expect(telemetry['last_error_event'], 'orchestrator_run_safety_halt');
    },
  );
}

void _appendRunLog(
  ProjectLayout layout, {
  required String event,
  required String message,
  required Map<String, Object?> data,
}) {
  final eventId = 'evt-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  final correlation = <String, Object?>{
    if (data['task_id'] != null) 'task_id': data['task_id'],
    if (data['subtask_id'] != null) 'subtask_id': data['subtask_id'],
    if (data['step_id'] != null) 'step_id': data['step_id'],
    if (data['attempt_id'] != null) 'attempt_id': data['attempt_id'],
    if (data['review_id'] != null) 'review_id': data['review_id'],
  };
  final correlationId = correlation.isEmpty
      ? eventId
      : correlation.entries
            .map((entry) => '${entry.key}:${entry.value}')
            .join('|');
  final payload = <String, Object?>{
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'event_id': eventId,
    'correlation_id': correlationId,
    'event': event,
    'message': message,
    if (correlation.isNotEmpty) 'correlation': correlation,
    'data': data,
  };
  final line = '${jsonEncode(payload)}\n';
  File(layout.runLogPath).writeAsStringSync(line, mode: FileMode.append);
}
