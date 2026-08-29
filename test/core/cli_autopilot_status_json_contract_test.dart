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
    'status --json contract keeps required keys in idle state',
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

      final payload = runCliJsonCommand([
        'status',
        '--json',
        temp.path,
      ]);

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
      expectRequiredKeys(payload, requiredKeys);
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
      expectMachineReadableErrorFields(
        payload,
        classKey: 'last_error_class',
        kindKey: 'last_error_kind',
      );

      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expectMachineReadableErrorFields(telemetry);
    },
  );

  test(
    'status --json keeps normalized progress-failure reasons for review edges',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_contract_review_',
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
            lastError: 'Step ended with review reject.',
            lastErrorClass: 'review',
            lastErrorKind: 'review_rejected',
            consecutiveFailures: 2,
          ),
        ),
      );
      _appendRunLog(
        layout,
        event: 'review_reject',
        message: 'Review rejected after validation.',
        data: <String, Object?>{
          'error_class': 'review',
          'error_kind': 'review_rejected',
          'step_id': 'step-review-2',
          'task_id': 'task-review-2',
        },
      );

      final payload = runCliJsonCommand([
        'status',
        '--json',
        temp.path,
      ]);

      expect(payload['last_error_class'], 'review');
      expect(payload['last_error_kind'], 'review_rejected');

      final telemetry = payload['telemetry'] as Map<String, dynamic>;
      expectMachineReadableErrorFields(telemetry);
      expect(telemetry['error_class'], 'review');
      expect(telemetry['error_kind'], 'review_rejected');
      expect(telemetry['last_error_event'], 'review_reject');
    },
  );

  test(
    'status --json maps safety-halt edge with machine-readable reason',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_contract_halt_',
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
            lastError: 'Autopilot halted after deterministic failure threshold.',
            lastErrorClass: 'reliability',
            lastErrorKind: 'deterministic_halt',
          ),
        ),
      );
      _appendRunLog(
        layout,
        event: 'orchestrator_run_safety_halt',
        message: 'Autopilot halted: deterministic threshold reached',
        data: <String, Object?>{
          'error_class': 'reliability',
          'error_kind': 'deterministic_halt',
          'task_id': 'task-halt',
          'subtask_id': 'subtask-halt',
        },
      );

      final payload = runCliJsonCommand([
        'status',
        '--json',
        temp.path,
      ]);

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
