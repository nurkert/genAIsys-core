import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/storage/run_log_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_tail_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String filePath(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  test('returns empty list for non-existent file', () {
    final result = RunLogStore.readTailLines(
      filePath('missing.jsonl'),
      maxLines: 10,
    );
    expect(result, isEmpty);
  });

  test('returns empty list for empty file', () {
    final path = filePath('empty.jsonl');
    File(path).writeAsStringSync('');
    final result = RunLogStore.readTailLines(path, maxLines: 10);
    expect(result, isEmpty);
  });

  test('returns all lines when file has fewer than maxLines', () {
    final path = filePath('small.jsonl');
    final lines = List.generate(5, (i) => '{"line": $i}');
    File(path).writeAsStringSync(lines.join('\n'));

    final result = RunLogStore.readTailLines(path, maxLines: 10);
    expect(result.length, 5);
    expect(result.first, '{"line": 0}');
    expect(result.last, '{"line": 4}');
  });

  test('returns exactly last N lines when file has more than maxLines', () {
    final path = filePath('many.jsonl');
    final lines = List.generate(50, (i) => '{"line": $i}');
    File(path).writeAsStringSync(lines.join('\n'));

    final result = RunLogStore.readTailLines(path, maxLines: 10);
    expect(result.length, 10);
    expect(result.first, '{"line": 40}');
    expect(result.last, '{"line": 49}');
  });

  test('handles trailing newlines correctly', () {
    final path = filePath('trailing.jsonl');
    final lines = List.generate(5, (i) => '{"line": $i}');
    File(path).writeAsStringSync('${lines.join('\n')}\n\n');

    final result = RunLogStore.readTailLines(path, maxLines: 10);
    expect(result.length, 5);
  });

  test('skips blank lines', () {
    final path = filePath('blanks.jsonl');
    File(path).writeAsStringSync('{"a":1}\n\n\n{"b":2}\n   \n{"c":3}\n');

    final result = RunLogStore.readTailLines(path, maxLines: 10);
    expect(result.length, 3);
  });

  test('handles large file with reverse-seek path', () {
    final path = filePath('large.jsonl');
    // Create a file larger than the 256KB small-file threshold.
    final lineData = '{"event":"test","data":{"key":"${'x' * 200}"}}\n';
    final raf = File(path).openSync(mode: FileMode.write);
    // Write enough lines to exceed 256KB.
    final numLines = (300 * 1024) ~/ lineData.length + 1;
    for (var i = 0; i < numLines; i++) {
      raf.writeStringSync(lineData);
    }
    raf.flushSync();
    raf.closeSync();

    final fileSize = File(path).lengthSync();
    expect(fileSize, greaterThan(256 * 1024));

    final result = RunLogStore.readTailLines(path, maxLines: 5);
    expect(result.length, 5);
    for (final line in result) {
      expect(line.trim(), isNotEmpty);
    }
  });

  test('maxLines of 1 returns only the last line', () {
    final path = filePath('single.jsonl');
    final lines = List.generate(10, (i) => '{"line": $i}');
    File(path).writeAsStringSync(lines.join('\n'));

    final result = RunLogStore.readTailLines(path, maxLines: 1);
    expect(result.length, 1);
    expect(result.first, '{"line": 9}');
  });

  test('maxLines equal to line count returns all lines', () {
    final path = filePath('exact.jsonl');
    final lines = List.generate(20, (i) => '{"line": $i}');
    File(path).writeAsStringSync(lines.join('\n'));

    final result = RunLogStore.readTailLines(path, maxLines: 20);
    expect(result.length, 20);
    expect(result.first, '{"line": 0}');
    expect(result.last, '{"line": 19}');
  });
}
