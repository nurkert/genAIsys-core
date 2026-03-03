import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  late Directory temp;
  late String ledgerPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_ledger_');
    ledgerPath = '${temp.path}${Platform.pathSeparator}health_ledger.jsonl';
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  DeliveryHealthEntry entry0({
    String? taskId,
    String? taskTitle,
    String timestamp = '2026-02-21T10:00:00Z',
    List<FileHealthSnapshot> files = const [],
  }) {
    return DeliveryHealthEntry(
      taskId: taskId,
      taskTitle: taskTitle,
      timestamp: timestamp,
      files: files,
    );
  }

  FileHealthSnapshot snapshot({
    String filePath = 'lib/foo.dart',
    int lineCount = 100,
    int maxMethodLines = 20,
    int maxNestingDepth = 2,
    int maxParameterCount = 3,
    int methodCount = 5,
  }) {
    return FileHealthSnapshot(
      filePath: filePath,
      lineCount: lineCount,
      maxMethodLines: maxMethodLines,
      maxNestingDepth: maxNestingDepth,
      maxParameterCount: maxParameterCount,
      methodCount: methodCount,
    );
  }

  test('append and readRecent round-trip', () {
    final store = HealthLedgerStore(ledgerPath);
    final entry = entry0(
      taskId: 'task-1',
      taskTitle: 'Fix bug',
      files: [snapshot()],
    );

    store.append(entry);

    final entries = store.readRecent();
    expect(entries, hasLength(1));
    expect(entries.first.taskId, 'task-1');
    expect(entries.first.taskTitle, 'Fix bug');
    expect(entries.first.files, hasLength(1));
    expect(entries.first.files.first.filePath, 'lib/foo.dart');
    expect(entries.first.files.first.lineCount, 100);
    expect(entries.first.files.first.maxMethodLines, 20);
    expect(entries.first.files.first.maxNestingDepth, 2);
    expect(entries.first.files.first.maxParameterCount, 3);
    expect(entries.first.files.first.methodCount, 5);
  });

  test('readRecent respects maxEntries', () {
    final store = HealthLedgerStore(ledgerPath);
    for (var i = 0; i < 10; i++) {
      store.append(entry0(taskId: 'task-$i'));
    }

    final entries = store.readRecent(maxEntries: 3);
    expect(entries, hasLength(3));
    expect(entries.first.taskId, 'task-7');
    expect(entries.last.taskId, 'task-9');
  });

  test('readRecent returns empty for non-existent file', () {
    final store = HealthLedgerStore(
      '${temp.path}${Platform.pathSeparator}does_not_exist.jsonl',
    );
    expect(store.readRecent(), isEmpty);
  });

  test('readRecent skips malformed JSONL lines', () {
    final file = File(ledgerPath);
    file.writeAsStringSync(
      '{"task_id":"a","timestamp":"t","files":[]}\n'
      'NOT VALID JSON\n'
      '{"task_id":"b","timestamp":"t","files":[]}\n',
    );

    final store = HealthLedgerStore(ledgerPath);
    final entries = store.readRecent();
    expect(entries, hasLength(2));
    expect(entries[0].taskId, 'a');
    expect(entries[1].taskId, 'b');
  });

  test('fileTouchFrequency counts across deliveries', () {
    final store = HealthLedgerStore(ledgerPath);
    store.append(
      entry0(
        files: [
          snapshot(filePath: 'lib/a.dart'),
          snapshot(filePath: 'lib/b.dart'),
        ],
      ),
    );
    store.append(
      entry0(
        files: [
          snapshot(filePath: 'lib/a.dart'),
          snapshot(filePath: 'lib/c.dart'),
        ],
      ),
    );
    store.append(entry0(files: [snapshot(filePath: 'lib/a.dart')]));

    final freq = store.fileTouchFrequency(windowSize: 10);
    expect(freq['lib/a.dart'], 3);
    expect(freq['lib/b.dart'], 1);
    expect(freq['lib/c.dart'], 1);
  });

  test('fileTouchFrequency respects windowSize', () {
    final store = HealthLedgerStore(ledgerPath);
    // First 3 entries touch file X.
    for (var i = 0; i < 3; i++) {
      store.append(entry0(files: [snapshot(filePath: 'lib/x.dart')]));
    }
    // Next 2 entries touch file Y only.
    for (var i = 0; i < 2; i++) {
      store.append(entry0(files: [snapshot(filePath: 'lib/y.dart')]));
    }

    // Window of 2: only the last 2 entries (Y touches).
    final freq = store.fileTouchFrequency(windowSize: 2);
    expect(freq.containsKey('lib/x.dart'), isFalse);
    expect(freq['lib/y.dart'], 2);
  });

  test('empty ledger returns empty frequency', () {
    final store = HealthLedgerStore(ledgerPath);
    expect(store.fileTouchFrequency(), isEmpty);
  });

  test('multiple files per delivery are all counted', () {
    final store = HealthLedgerStore(ledgerPath);
    store.append(
      entry0(
        files: [
          snapshot(filePath: 'lib/a.dart'),
          snapshot(filePath: 'lib/b.dart'),
          snapshot(filePath: 'lib/c.dart'),
        ],
      ),
    );

    final freq = store.fileTouchFrequency();
    expect(freq, hasLength(3));
    expect(freq.values.every((v) => v == 1), isTrue);
  });

  test('DeliveryHealthEntry without optional fields round-trips', () {
    final store = HealthLedgerStore(ledgerPath);
    store.append(entry0()); // no taskId, no taskTitle, no files

    final entries = store.readRecent();
    expect(entries, hasLength(1));
    expect(entries.first.taskId, isNull);
    expect(entries.first.taskTitle, isNull);
    expect(entries.first.files, isEmpty);
  });
}
