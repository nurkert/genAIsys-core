import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('RunLogStore appends JSON lines with event and timestamp', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_log_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final logPath = '${temp.path}${Platform.pathSeparator}RUN_LOG.jsonl';
    final store = RunLogStore(logPath);

    store.append(
      event: 'init',
      message: 'Initialized project',
      data: {'ok': true},
    );
    store.append(event: 'status', data: {'count': 1});

    final lines = File(logPath).readAsLinesSync();
    expect(lines.length, 2);

    final first = jsonDecode(lines[0]) as Map<String, dynamic>;
    final second = jsonDecode(lines[1]) as Map<String, dynamic>;

    expect(first['event'], 'init');
    expect(first.containsKey('timestamp'), isTrue);
    expect(first['event_id'], isA<String>());
    expect(first['correlation_id'], isA<String>());
    expect(first['message'], 'Initialized project');
    expect(first['data']['ok'], true);

    expect(second['event'], 'status');
    expect(second.containsKey('timestamp'), isTrue);
    expect(second['event_id'], isA<String>());
    expect(second['correlation_id'], isA<String>());
    expect(second['data']['count'], 1);
  });

  test('RunLogStore redacts sensitive payload values', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_log_redact_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final logPath = '${temp.path}${Platform.pathSeparator}RUN_LOG.jsonl';
    final store = RunLogStore(
      logPath,
      redactionService: RedactionService(
        environment: {'OPENAI_API_KEY': 'sk-secret-value-123456789'},
      ),
    );

    store.append(
      event: 'status',
      message: 'Auth header bearer sk-secret-value-123456789',
      data: {
        'stderr_excerpt':
            'Authorization: Bearer sk-secret-value-123456789 and sk-abcdefghijklmnop',
      },
    );

    final line = File(logPath).readAsLinesSync().single;
    final payload = jsonDecode(line) as Map<String, dynamic>;
    final text = jsonEncode(payload);

    expect(text, isNot(contains('sk-secret-value-123456789')));
    expect(text, isNot(contains('sk-abcdefghijklmnop')));
    expect(text, contains('[REDACTED:OPENAI_API_KEY]'));
    expect(text, contains('[REDACTED:OPENAI_TOKEN]'));
    expect(payload['redaction']['applied'], isTrue);
  });

  test(
    'RunLogStore emits correlation metadata when identifiers are present',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_log_correlation_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final logPath = '${temp.path}${Platform.pathSeparator}RUN_LOG.jsonl';
      final store = RunLogStore(logPath);

      store.append(
        event: 'orchestrator_run_step',
        data: const {
          'task_id': 'task-alpha',
          'subtask_id': 'subtask-alpha-1',
          'step_id': 'step-42',
          'attempt_id': 'attempt-3',
        },
      );

      final line = File(logPath).readAsLinesSync().single;
      final payload = jsonDecode(line) as Map<String, dynamic>;
      final correlation = payload['correlation'] as Map<String, dynamic>;

      expect(correlation['task_id'], 'task-alpha');
      expect(correlation['subtask_id'], 'subtask-alpha-1');
      expect(correlation['step_id'], 'step-42');
      expect(correlation['attempt_id'], 'attempt-3');
      expect(payload['correlation_id'], contains('step_id:step-42'));
    },
  );

  test('RunLogStore rotates and prunes archives when max size is exceeded', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_log_rotate_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final logPath = '${temp.path}${Platform.pathSeparator}RUN_LOG.jsonl';
    final archiveDir =
        '${temp.path}${Platform.pathSeparator}logs${Platform.pathSeparator}run_log_archive';
    final store = RunLogStore(
      logPath,
      retentionPolicy: RunLogRetentionPolicy(
        maxBytes: 160,
        maxArchives: 2,
        archiveDirectoryPath: archiveDir,
      ),
    );

    for (var i = 0; i < 6; i += 1) {
      store.append(
        event: 'event-$i',
        message: 'payload-${'x' * 72}-$i',
        data: {'retry_count': i},
      );
    }

    final archiveFiles = Directory(
      archiveDir,
    ).listSync().whereType<File>().toList(growable: false);
    expect(archiveFiles.length, lessThanOrEqualTo(2));

    final activeLines = File(logPath).readAsLinesSync();
    expect(activeLines, isNotEmpty);
    final lastPayload = jsonDecode(activeLines.last) as Map<String, dynamic>;
    expect(lastPayload['event'], 'event-5');
  });
}
