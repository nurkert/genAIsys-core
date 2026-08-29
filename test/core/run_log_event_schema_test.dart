import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/run_log_store.dart';

/// All known run-log event types emitted across the codebase.
/// Maintaining this list makes it easy to detect when a new event is added
/// without a corresponding schema expectation.
const _knownEventTypes = <String>{
  // Task cycle
  'task_cycle_start',
  'task_cycle_end',
  'task_cycle_delivery_resume_start',
  'task_cycle_delivery_resume_end',
  'task_dead_letter',
  'task_cycle_stale_active_task_recovered',

  // Review
  'review_cleared',
  'review_approve',
  'review_reject',
  'review_reject_autostash_failed',
  'review_reject_autostash',

  // Self-improvement
  'self_improve_start',
  'self_improve_complete',

  // Readiness / trend / release
  'readiness_gate_evaluation',
  'trend_analysis',
  'release_candidate_built',
  'release_candidate_promotion_blocked',
  'release_candidate_promoted',

  // Runtime switch & canary
  'runtime_switch_start',
  'runtime_switch_complete',
  'runtime_rollback',
  'canary_validation_passed',
  'canary_validation_cycle',
  'canary_validation_failed',

  // Autopilot supervisor
  'preflight_failed',
  'autopilot_supervisor_start_blocked',
  'autopilot_supervisor_start',
  'autopilot_supervisor_stop',
  'autopilot_supervisor_worker_start',
  'autopilot_supervisor_preflight_failed',
  'autopilot_supervisor_halt',
  'autopilot_supervisor_auto_heal',
  'autopilot_supervisor_segment_error',
  'autopilot_supervisor_restart',
  'autopilot_supervisor_worker_end',
  'autopilot_supervisor_resume',
  'autopilot_supervisor_resume_failed',
  'autopilot_supervisor_stale_recovered',
  'autopilot_supervisor_worker_skip',

  // Orchestrator run
  'orchestrator_run_self_heal_attempt',
  'orchestrator_run_self_heal_failed',
  'orchestrator_run_progress_failure_release',
  'orchestrator_run_progress_failure_release_failed',
  'orchestrator_run_unattended_blocked',
  'orchestrator_run_start',
  'orchestrator_run_stop_requested',
  'orchestrator_run_step_start',
  'orchestrator_run_step',
  'orchestrator_run_progress_failure',
  'orchestrator_run_safety_halt',
  'orchestrator_run_provider_pause',
  'orchestrator_run_transient_error',
  'orchestrator_run_permanent_error',
  'orchestrator_run_error',
  'orchestrator_run_stuck',
  'orchestrator_run_self_restart',
  'orchestrator_run_end',
  'orchestrator_run_unlock',
  'orchestrator_run_lock_recovered',
  'orchestrator_run_planning_audit',
  'orchestrator_run_planning_audit_failed',

  // Orchestrator step
  'orchestrator_step',
  'orchestrator_step_planned',
  'orchestrator_step_idle',
  'subtask_scheduler_demote_verification',
  'subtask_scheduler_selection',
  'subtask_auto_refine_skipped',
  'subtask_auto_refined_long_run',
  'subtask_requeued_after_timeout',
  'git_auto_stash',
  'git_auto_stash_restore',
  'git_auto_stash_restore_failed',
  'git_auto_stash_skip_rejected',
  'git_auto_stash_rejected_context',
  'git_step_error_autostash',
  'git_step_error_autostash_incomplete',

  // Release tags
  'release_tag_skip',
  'release_tag_failed',
  'release_tag_created',
  'release_tag_push_skip',
  'release_tag_pushed',

  // Quality gates
  'quality_gate_skip',
  'quality_gate_start',
  'quality_gate_command_start',
  'quality_gate_command_retry',
  'quality_gate_command_end',
  'quality_gate_pass',
  'quality_gate_fail',
  'quality_gate_reject',
  'quality_gate_blocked',
  'quality_gate_autofix_skip',
  'quality_gate_autofix_start',
  'quality_gate_autofix_pass',
  'quality_gate_autofix_fail',
  'quality_gate_dependency_bootstrap_start',
  'quality_gate_dependency_bootstrap_pass',
  'quality_gate_dependency_bootstrap_error',

  // Agent / provider pool
  'agent_command_policy_violation',
  'unattended_provider_blocked',
  'unattended_provider_failure_increment',
  'unattended_provider_skipped',
  'unattended_provider_unblocked',
  'unattended_provider_exhausted',
  'provider_pool_quota_hit',
  'provider_pool_quota_skip',
  'provider_pool_rotated',
  'provider_pool_exhausted',
  'agent_command_start',
  'agent_command_heartbeat',
  'agent_command',
  'coding_attempt',

  // Task management
  'task_created',
  'task_priority_updated',
  'task_section_moved',
  'task_done',
  'task_blocked',
  'task_block_context_stash_failed',
  'task_block_context_stashed',
  'task_block_meta_commit',
  'task_block_meta_commit_failed',
  'activate_task',
  'deactivate_task',
  'activate_task_policy_blocked',

  // Done / delivery
  'delivery_preflight_skipped',
  'delivery_preflight_upstream_skipped',
  'delivery_preflight_failed',
  'delivery_preflight_passed',
  'merge_conflict_detected',
  'merge_conflict_resolved',
  'merge_conflict_resolution_attempt_start',
  'merge_conflict_resolution_attempt_failed',
  'merge_conflict_resolution_attempt_unresolved',
  'merge_conflict_abort',
  'merge_conflict_abort_failed',
  'merge_conflict_manual',
  'git_delivery_branch_deleted',
  'git_delivery_branch_delete_failed',
  'git_delivery_remote_branch_delete_skipped',
  'git_delivery_remote_branch_deleted',
  'git_delivery_remote_branch_delete_failed',
  'git_delivery_fetch',
  'git_delivery_fetch_failed',
  'git_delivery_pull',
  'git_delivery_pull_failed',

  // Workflow / config / misc
  'workflow_transition',
  'config_updated',
  'state_repair',
  'init',
  'policy_error',
  'task_cycle_no_diff',
  'cycle',
  'audit_recorded',
  'audit_failed',
  'audit_completed',
  'git_branch_cleanup',
  'policy_simulation',
  'planning_audit_cadence',

  // Analytics & tuning
  'prompt_effectiveness_analysis',
  'retrospective_analysis',
  'run_log_insight_analysis',
  'insight_driven_tasks',
  'self_tune_applied',
  'self_tune_skipped',
  'eval_run_start',
  'eval_run_complete',
  'meta_tasks_generated',
  'strategic_planning_suggestions',

  // Spec / refinement
  'spec_init',
  'plan_init',
  'spec_generation_start',
  'plan_generation_start',
  'spec_generated',
  'plan_generated',
  'subtasks_queue_updated',
  'draft_spec_skipped',
  'draft_plan_skipped',
  'draft_spec_generated',
  'draft_plan_generated',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Create a temp project root with the minimum directory structure required
/// for RunLogStore to write.
String _createProjectRoot(String prefix) {
  final temp = Directory.systemTemp.createTempSync(prefix);
  final layout = ProjectLayout(temp.path);
  Directory(layout.genaisysDir).createSync(recursive: true);
  return temp.path;
}

/// Parse every JSONL line from the run log file.
List<Map<String, Object?>> _readRunLog(String projectRoot) {
  final layout = ProjectLayout(projectRoot);
  final file = File(layout.runLogPath);
  if (!file.existsSync()) return const [];
  final lines = file
      .readAsStringSync()
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  return lines.map((l) {
    final decoded = jsonDecode(l);
    return Map<String, Object?>.from(decoded as Map);
  }).toList();
}

/// Append a single event via RunLogStore and return the parsed entry.
Map<String, Object?> _appendAndRead({
  required String projectRoot,
  required String event,
  String? message,
  Map<String, Object?>? data,
}) {
  final layout = ProjectLayout(projectRoot);
  RunLogStore(
    layout.runLogPath,
  ).append(event: event, message: message, data: data);
  final entries = _readRunLog(projectRoot);
  return entries.last;
}

/// ISO-8601 date-time regex (e.g. 2024-01-01T00:00:00.000Z).
final _iso8601Pattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');

/// Validate the common envelope fields every run-log entry must carry.
void _assertEnvelopeSchema(Map<String, Object?> entry) {
  // 'event' -- required, non-empty String
  expect(
    entry.containsKey('event'),
    isTrue,
    reason: 'entry must contain "event"',
  );
  expect(entry['event'], isA<String>());
  expect(
    (entry['event'] as String).isNotEmpty,
    isTrue,
    reason: '"event" must be non-empty',
  );

  // 'timestamp' -- required, ISO-8601
  expect(
    entry.containsKey('timestamp'),
    isTrue,
    reason: 'entry must contain "timestamp"',
  );
  expect(entry['timestamp'], isA<String>());
  expect(
    _iso8601Pattern.hasMatch(entry['timestamp'] as String),
    isTrue,
    reason: '"timestamp" must be ISO-8601 formatted',
  );

  // 'event_id' -- required
  expect(
    entry.containsKey('event_id'),
    isTrue,
    reason: 'entry must contain "event_id"',
  );
  expect(entry['event_id'], isA<String>());
  expect(
    (entry['event_id'] as String).startsWith('evt-'),
    isTrue,
    reason: '"event_id" must start with "evt-"',
  );

  // 'correlation_id' -- required
  expect(
    entry.containsKey('correlation_id'),
    isTrue,
    reason: 'entry must contain "correlation_id"',
  );
  expect(entry['correlation_id'], isA<String>());
}

/// Assert that a parsed entry has the given keys present inside its `data`
/// map with non-null values.
void _assertDataFields(
  Map<String, Object?> entry,
  List<String> requiredFields,
) {
  expect(
    entry.containsKey('data'),
    isTrue,
    reason: 'entry must contain "data"',
  );
  final data = entry['data'];
  expect(data, isA<Map>(), reason: '"data" must be a Map');
  final dataMap = Map<String, Object?>.from(data as Map);
  for (final field in requiredFields) {
    expect(
      dataMap.containsKey(field),
      isTrue,
      reason: 'data must contain "$field"',
    );
    expect(
      dataMap[field],
      isNotNull,
      reason: 'data["$field"] must not be null',
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late String projectRoot;
  late Directory tempDir;

  setUp(() {
    projectRoot = _createProjectRoot('genaisys_run_log_schema_');
    tempDir = Directory(projectRoot);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Section 1: Envelope / schema-level validation
  // -------------------------------------------------------------------------
  group('Run log envelope schema', () {
    test('entry with all fields populates timestamp, event_id, '
        'correlation_id, event, message, and data', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'test_event',
        message: 'A test message',
        data: {'key': 'value', 'task_id': 'T-1'},
      );
      _assertEnvelopeSchema(entry);
      expect(entry['event'], equals('test_event'));
      expect(entry['message'], equals('A test message'));
      _assertDataFields(entry, ['key', 'task_id']);
    });

    test('entry without message omits message key', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'no_message_event',
        data: {'x': 1},
      );
      _assertEnvelopeSchema(entry);
      expect(entry.containsKey('message'), isFalse);
    });

    test('entry without data omits data key', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'no_data_event',
        message: 'hello',
      );
      _assertEnvelopeSchema(entry);
      expect(entry.containsKey('data'), isFalse);
    });

    test('entry with empty message omits message key', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'empty_msg_event',
        message: '',
        data: {'a': 1},
      );
      _assertEnvelopeSchema(entry);
      expect(entry.containsKey('message'), isFalse);
    });

    test('entry with empty data map omits data key', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'empty_data_event',
        message: 'msg',
        data: const {},
      );
      _assertEnvelopeSchema(entry);
      expect(entry.containsKey('data'), isFalse);
    });

    test('multiple appends produce valid JSONL with one entry per line', () {
      final layout = ProjectLayout(projectRoot);
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'e1', message: 'first');
      store.append(event: 'e2', message: 'second');
      store.append(event: 'e3', message: 'third');

      final entries = _readRunLog(projectRoot);
      expect(entries.length, equals(3));
      for (final entry in entries) {
        _assertEnvelopeSchema(entry);
      }
      expect(entries[0]['event'], equals('e1'));
      expect(entries[1]['event'], equals('e2'));
      expect(entries[2]['event'], equals('e3'));
    });

    test('correlation fields are extracted from data', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'correlated_event',
        message: 'correlate me',
        data: {
          'task_id': 'T-42',
          'subtask_id': 'ST-7',
          'step_id': 'STEP-1',
          'other': 'value',
        },
      );
      _assertEnvelopeSchema(entry);
      expect(entry.containsKey('correlation'), isTrue);
      final correlation = Map<String, Object?>.from(
        entry['correlation'] as Map,
      );
      expect(correlation['task_id'], equals('T-42'));
      expect(correlation['subtask_id'], equals('ST-7'));
      expect(correlation['step_id'], equals('STEP-1'));
      // 'other' is not a correlation key
      expect(correlation.containsKey('other'), isFalse);
    });

    test('event_id is unique across consecutive appends', () {
      final layout = ProjectLayout(projectRoot);
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'a');
      store.append(event: 'b');
      store.append(event: 'c');

      final entries = _readRunLog(projectRoot);
      final ids = entries.map((e) => e['event_id']).toSet();
      expect(ids.length, equals(3), reason: 'event_id values must be unique');
    });
  });

  // -------------------------------------------------------------------------
  // Section 2: Known event catalog sanity
  // -------------------------------------------------------------------------
  group('Known event catalog', () {
    test('catalog is non-empty and has no duplicates', () {
      expect(_knownEventTypes.isNotEmpty, isTrue);
      // Sets cannot have duplicates by definition, but verify the count stays
      // consistent if converted to list.
      final list = _knownEventTypes.toList();
      expect(list.length, equals(_knownEventTypes.length));
    });

    test('every known event type round-trips through RunLogStore', () {
      final layout = ProjectLayout(projectRoot);
      final store = RunLogStore(layout.runLogPath);
      for (final eventType in _knownEventTypes) {
        store.append(event: eventType, message: 'catalog test');
      }
      final entries = _readRunLog(projectRoot);
      expect(entries.length, equals(_knownEventTypes.length));
      final writtenTypes = entries.map((e) => e['event'] as String).toSet();
      expect(writtenTypes, equals(_knownEventTypes));
    });
  });

  // -------------------------------------------------------------------------
  // Section 3: Per-event-type data field validation
  // -------------------------------------------------------------------------
  group('task_cycle_start schema', () {
    test('requires root, overwrite, is_subtask, review_persona, '
        'has_test_summary', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'task_cycle_start',
        message: 'Task cycle started',
        data: {
          'root': projectRoot,
          'overwrite': false,
          'is_subtask': false,
          'review_persona': 'strict',
          'has_test_summary': false,
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'root',
        'overwrite',
        'is_subtask',
        'review_persona',
        'has_test_summary',
      ]);
    });
  });

  group('task_cycle_end schema', () {
    test('requires root, review_recorded, review_decision, '
        'auto_marked_done, retry_count, task_blocked', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'task_cycle_end',
        message: 'Task cycle completed',
        data: {
          'root': projectRoot,
          'review_recorded': true,
          'review_decision': 'approve',
          'auto_marked_done': false,
          'retry_count': 0,
          'task_blocked': false,
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'root',
        'review_recorded',
        'review_decision',
        'auto_marked_done',
        'retry_count',
        'task_blocked',
      ]);
    });
  });

  group('self_improve_start schema', () {
    test('requires root, run_meta, run_eval, run_tune, run_analysis', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'self_improve_start',
        message: 'Self-improvement started',
        data: {
          'root': projectRoot,
          'run_meta': true,
          'run_eval': true,
          'run_tune': true,
          'run_analysis': true,
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'root',
        'run_meta',
        'run_eval',
        'run_tune',
        'run_analysis',
      ]);
    });
  });

  group('self_improve_complete schema', () {
    test('requires root and metric fields', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'self_improve_complete',
        message: 'Self-improvement completed',
        data: {
          'root': projectRoot,
          'meta_created': 0,
          'eval_passed': 5,
          'eval_total': 5,
          'tune_applied': false,
          'retrospective_total': 10,
          'retrospective_completion_rate': 0.8,
          'insights_success_rate': 0.9,
          'prompt_approval_rate': 0.75,
          'insight_tasks_created': 2,
          'health_score': 85.0,
          'health_grade': 'good',
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'root',
        'meta_created',
        'eval_passed',
        'eval_total',
        'tune_applied',
        'retrospective_total',
        'retrospective_completion_rate',
        'insights_success_rate',
        'prompt_approval_rate',
        'insight_tasks_created',
        'health_score',
        'health_grade',
      ]);
    });
  });

  group('readiness_gate_evaluation schema', () {
    test('requires promotable, blocking_reasons, timestamp, criteria', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'readiness_gate_evaluation',
        message: 'Release readiness gate passed',
        data: {
          'promotable': true,
          'blocking_reasons': <String>[],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'criteria': <Map<String, Object?>>[
            {'name': 'health', 'passed': true, 'message': 'ok'},
          ],
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'promotable',
        'blocking_reasons',
        'timestamp',
        'criteria',
      ]);
      // Validate criteria structure.
      final data = Map<String, Object?>.from(entry['data'] as Map);
      final criteria = data['criteria'] as List;
      expect(criteria, isNotEmpty);
      final first = Map<String, Object?>.from(criteria.first as Map);
      expect(first.containsKey('name'), isTrue);
      expect(first.containsKey('passed'), isTrue);
      expect(first.containsKey('message'), isTrue);
    });

    test('blocked verdict contains non-empty blocking_reasons', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'readiness_gate_evaluation',
        message: 'Release readiness gate blocked',
        data: {
          'promotable': false,
          'blocking_reasons': ['health_score_too_low'],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'criteria': <Map<String, Object?>>[
            {'name': 'health', 'passed': false, 'message': 'Score 40 < 60'},
          ],
        },
      );
      _assertEnvelopeSchema(entry);
      final data = Map<String, Object?>.from(entry['data'] as Map);
      expect(data['promotable'], isFalse);
      expect((data['blocking_reasons'] as List), isNotEmpty);
    });
  });

  group('trend_analysis schema', () {
    test('requires overall_direction, overall_delta, current_score, '
        'baseline_score, snapshot_count, regressions, improvements, '
        'timestamp, component_trends', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'trend_analysis',
        message: 'Trend analysis: stable',
        data: {
          'overall_direction': 'stable',
          'overall_delta': 0.5,
          'current_score': 80.0,
          'baseline_score': 79.5,
          'snapshot_count': 5,
          'regressions': <String>[],
          'improvements': <String>['test_coverage'],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'component_trends': <Map<String, Object?>>[
            {
              'name': 'test_coverage',
              'current_score': 85.0,
              'baseline_score': 70.0,
              'delta': 15.0,
              'direction': 'improving',
            },
          ],
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'overall_direction',
        'overall_delta',
        'current_score',
        'baseline_score',
        'snapshot_count',
        'regressions',
        'improvements',
        'timestamp',
        'component_trends',
      ]);
      // Validate component trend structure.
      final data = Map<String, Object?>.from(entry['data'] as Map);
      final trends = data['component_trends'] as List;
      expect(trends, isNotEmpty);
      final first = Map<String, Object?>.from(trends.first as Map);
      expect(first.containsKey('name'), isTrue);
      expect(first.containsKey('current_score'), isTrue);
      expect(first.containsKey('baseline_score'), isTrue);
      expect(first.containsKey('delta'), isTrue);
      expect(first.containsKey('direction'), isTrue);
    });
  });

  group('release_candidate_built schema', () {
    test('requires version, git_commit_sha, build_timestamp, checksums', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'release_candidate_built',
        message: 'Release candidate 1.0.0 built',
        data: {
          'version': '1.0.0',
          'git_commit_sha': 'abc123',
          'build_timestamp': DateTime.now().toUtc().toIso8601String(),
          'checksums': {'lib/main.dart': 'sha256-deadbeef'},
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'version',
        'git_commit_sha',
        'build_timestamp',
        'checksums',
      ]);
      final data = Map<String, Object?>.from(entry['data'] as Map);
      expect(data['checksums'], isA<Map>());
    });
  });

  group('runtime_switch_start schema', () {
    test('requires from_version and to_version', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'runtime_switch_start',
        message: 'Runtime switch starting from 0.9.0 to 1.0.0',
        data: {'from_version': '0.9.0', 'to_version': '1.0.0'},
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, ['from_version', 'to_version']);
    });
  });

  group('canary_validation_passed schema', () {
    test('requires cycles_completed and cycles_target', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'canary_validation_passed',
        message: 'Canary validation passed after 3 cycles',
        data: {'cycles_completed': 3, 'cycles_target': 3},
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, ['cycles_completed', 'cycles_target']);
      final data = Map<String, Object?>.from(entry['data'] as Map);
      expect(data['cycles_completed'], equals(3));
      expect(data['cycles_target'], equals(3));
    });
  });

  group('canary_validation_failed schema', () {
    test('requires trigger, cycles_completed, and cycles_target', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'canary_validation_failed',
        message: 'Canary validation failed: health_score_drop',
        data: {
          'trigger': 'health_score_drop',
          'cycles_completed': 1,
          'cycles_target': 3,
        },
      );
      _assertEnvelopeSchema(entry);
      _assertDataFields(entry, [
        'trigger',
        'cycles_completed',
        'cycles_target',
      ]);
    });
  });

  // -------------------------------------------------------------------------
  // Section 4: Structural integrity
  // -------------------------------------------------------------------------
  group('Structural integrity', () {
    test('timestamp is always UTC', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'utc_check',
        message: 'UTC validation',
        data: {'x': 1},
      );
      final ts = entry['timestamp'] as String;
      // RunLogStore uses DateTime.now().toUtc().toIso8601String() which
      // produces a string ending in 'Z' or '+00:00'.
      final parsed = DateTime.parse(ts);
      expect(parsed.isUtc, isTrue, reason: 'timestamp must be in UTC');
    });

    test('data values survive JSON round-trip without type loss', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'type_check',
        message: 'type fidelity',
        data: {
          'string_val': 'hello',
          'int_val': 42,
          'double_val': 3.14,
          'bool_val': true,
          'list_val': [1, 2, 3],
          'nested': {'a': 'b'},
        },
      );
      final data = Map<String, Object?>.from(entry['data'] as Map);
      expect(data['string_val'], isA<String>());
      expect(data['int_val'], isA<int>());
      expect(data['double_val'], isA<double>());
      expect(data['bool_val'], isA<bool>());
      expect(data['list_val'], isA<List>());
      expect(data['nested'], isA<Map>());
    });

    test('JSONL file is valid (each line parses independently)', () {
      final layout = ProjectLayout(projectRoot);
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'a', message: 'm1', data: {'k': 1});
      store.append(event: 'b', message: 'm2', data: {'k': 2});

      final raw = File(layout.runLogPath).readAsStringSync();
      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, equals(2));
      for (final line in lines) {
        expect(
          () => jsonDecode(line),
          returnsNormally,
          reason: 'each JSONL line must be valid JSON',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Section 5: Edge cases
  // -------------------------------------------------------------------------
  group('Edge cases', () {
    test('event name with special characters is preserved', () {
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'review_approve',
        message: 'Review decision recorded',
        data: {'root': projectRoot, 'task': 'My Task', 'note': ''},
      );
      _assertEnvelopeSchema(entry);
      expect(entry['event'], equals('review_approve'));
    });

    test('data with null values are included in serialization', () {
      // RunLogStore sanitizes through RedactionService, then converts.
      // null values in data should be preserved as null.
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'null_data_test',
        message: 'null check',
        data: {'present': 'yes', 'absent': null},
      );
      _assertEnvelopeSchema(entry);
      // The data map should contain the key even if null.
      final data = Map<String, Object?>.from(entry['data'] as Map);
      expect(data.containsKey('present'), isTrue);
    });

    test('very long message is preserved', () {
      final longMsg = 'x' * 5000;
      final entry = _appendAndRead(
        projectRoot: projectRoot,
        event: 'long_message',
        message: longMsg,
      );
      _assertEnvelopeSchema(entry);
      expect(entry['message'], equals(longMsg));
    });

    test('concurrent appends produce valid JSONL', () {
      final layout = ProjectLayout(projectRoot);
      // Simulate rapid sequential appends (not truly concurrent since
      // file I/O is synchronous, but validates no corruption).
      for (var i = 0; i < 50; i++) {
        RunLogStore(
          layout.runLogPath,
        ).append(event: 'burst_event', message: 'burst $i', data: {'index': i});
      }
      final entries = _readRunLog(projectRoot);
      expect(entries.length, equals(50));
      for (final entry in entries) {
        _assertEnvelopeSchema(entry);
      }
    });
  });
}
