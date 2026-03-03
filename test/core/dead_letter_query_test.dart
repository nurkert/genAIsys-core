import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/dead_letter_query_service.dart';
import 'package:genaisys/core/storage/run_log_store.dart';

void main() {
  group('DeadLetterQueryService', () {
    late Directory temp;
    late DeadLetterQueryService service;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_dead_letter_');
      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.auditDir).createSync(recursive: true);
      service = DeadLetterQueryService();
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('returns empty list when no run log exists', () {
      final entries = service.query(temp.path);
      expect(entries, isEmpty);
    });

    test('returns empty list when run log has no dead-letter events', () {
      final layout = ProjectLayout(temp.path);
      RunLogStore(layout.runLogPath).append(
        event: 'task_cycle_start',
        message: 'Task cycle started',
        data: {'root': temp.path},
      );
      RunLogStore(layout.runLogPath).append(
        event: 'task_blocked',
        message: 'Blocked task',
        data: {'root': temp.path, 'task': 'Some task', 'reason': 'manual'},
      );

      final entries = service.query(temp.path);
      expect(entries, isEmpty);
    });

    test('parses task_dead_letter events with full diagnostics', () {
      final layout = ProjectLayout(temp.path);
      RunLogStore(layout.runLogPath).append(
        event: 'task_dead_letter',
        message: 'Task quarantined after exhausting retries',
        data: {
          'root': temp.path,
          'task': 'Implement feature X',
          'task_id': 'feat-x-42',
          'subtask_id': 'Write unit tests',
          'blocking_stage': 'review_reject',
          'retry_count': 3,
          'reason': 'Auto-cycle: review rejected 3 time(s)',
          'last_error': 'Agent exited with code 1',
          'last_error_class': 'provider',
          'last_error_kind': 'agent_failure',
        },
      );

      final entries = service.query(temp.path);
      expect(entries, hasLength(1));

      final entry = entries.first;
      expect(entry.task, 'Implement feature X');
      expect(entry.taskId, 'feat-x-42');
      expect(entry.subtaskId, 'Write unit tests');
      expect(entry.blockingStage, 'review_reject');
      expect(entry.retryCount, 3);
      expect(entry.reason, 'Auto-cycle: review rejected 3 time(s)');
      expect(entry.lastError, 'Agent exited with code 1');
      expect(entry.lastErrorClass, 'provider');
      expect(entry.lastErrorKind, 'agent_failure');
      expect(entry.timestamp, isNotEmpty);
    });

    test('parses entries without optional fields', () {
      final layout = ProjectLayout(temp.path);
      RunLogStore(layout.runLogPath).append(
        event: 'task_dead_letter',
        message: 'Task quarantined after exhausting retries',
        data: {
          'root': temp.path,
          'task': 'Fix bug Y',
          'blocking_stage': 'no_diff',
          'retry_count': 2,
          'reason': 'Auto-cycle: no diff after 2 attempt(s)',
        },
      );

      final entries = service.query(temp.path);
      expect(entries, hasLength(1));

      final entry = entries.first;
      expect(entry.task, 'Fix bug Y');
      expect(entry.taskId, isNull);
      expect(entry.subtaskId, isNull);
      expect(entry.blockingStage, 'no_diff');
      expect(entry.retryCount, 2);
      expect(entry.lastError, isNull);
      expect(entry.lastErrorClass, isNull);
      expect(entry.lastErrorKind, isNull);
    });

    test('collects multiple dead-letter entries in order', () {
      final layout = ProjectLayout(temp.path);
      final store = RunLogStore(layout.runLogPath);

      store.append(
        event: 'task_dead_letter',
        message: 'Quarantined',
        data: {
          'task': 'Task A',
          'blocking_stage': 'review_reject',
          'retry_count': 3,
          'reason': 'rejected 3x',
        },
      );
      store.append(
        event: 'task_cycle_start',
        message: 'Unrelated event',
        data: {'root': temp.path},
      );
      store.append(
        event: 'task_dead_letter',
        message: 'Quarantined',
        data: {
          'task': 'Task B',
          'blocking_stage': 'no_diff',
          'retry_count': 2,
          'reason': 'no diff 2x',
        },
      );

      final entries = service.query(temp.path);
      expect(entries, hasLength(2));
      expect(entries[0].task, 'Task A');
      expect(entries[1].task, 'Task B');
    });

    test('skips malformed JSON lines gracefully', () {
      final layout = ProjectLayout(temp.path);
      final file = File(layout.runLogPath);
      // Write one valid and one malformed line.
      final valid = jsonEncode({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': 'task_dead_letter',
        'data': {
          'task': 'Valid task',
          'blocking_stage': 'review_reject',
          'retry_count': 1,
          'reason': 'rejected',
        },
      });
      file.writeAsStringSync('$valid\n{broken json\n');

      final entries = service.query(temp.path);
      expect(entries, hasLength(1));
      expect(entries.first.task, 'Valid task');
    });

    test('skips entries where task is empty', () {
      final layout = ProjectLayout(temp.path);
      RunLogStore(layout.runLogPath).append(
        event: 'task_dead_letter',
        message: 'Quarantined',
        data: {
          'task': '',
          'blocking_stage': 'review_reject',
          'retry_count': 1,
          'reason': 'rejected',
        },
      );

      final entries = service.query(temp.path);
      expect(entries, isEmpty);
    });

    test('toJson round-trip preserves all fields', () {
      const entry = DeadLetterEntry(
        timestamp: '2026-02-13T12:00:00.000Z',
        task: 'Sample task',
        taskId: 'sample-42',
        subtaskId: 'sub-1',
        blockingStage: 'review_reject',
        retryCount: 3,
        reason: 'rejected 3x',
        lastError: 'exit code 1',
        lastErrorClass: 'provider',
        lastErrorKind: 'agent_failure',
      );

      final json = entry.toJson();
      expect(json['timestamp'], '2026-02-13T12:00:00.000Z');
      expect(json['task'], 'Sample task');
      expect(json['task_id'], 'sample-42');
      expect(json['subtask_id'], 'sub-1');
      expect(json['blocking_stage'], 'review_reject');
      expect(json['retry_count'], 3);
      expect(json['reason'], 'rejected 3x');
      expect(json['last_error'], 'exit code 1');
      expect(json['last_error_class'], 'provider');
      expect(json['last_error_kind'], 'agent_failure');
    });

    test('toJson omits null optional fields', () {
      const entry = DeadLetterEntry(
        timestamp: '2026-02-13T12:00:00.000Z',
        task: 'Minimal task',
        blockingStage: 'no_diff',
        retryCount: 1,
        reason: 'no diff',
      );

      final json = entry.toJson();
      expect(json.containsKey('task_id'), isFalse);
      expect(json.containsKey('subtask_id'), isFalse);
      expect(json.containsKey('last_error'), isFalse);
      expect(json.containsKey('last_error_class'), isFalse);
      expect(json.containsKey('last_error_kind'), isFalse);
    });
  });
}
