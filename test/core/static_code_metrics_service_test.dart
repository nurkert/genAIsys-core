import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  late Directory temp;
  late StaticCodeMetricsService service;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_metrics_');
    service = StaticCodeMetricsService();
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  void writeFile(String name, String content) {
    File(
      '${temp.path}${Platform.pathSeparator}$name',
    ).writeAsStringSync(content);
  }

  test('analyze counts lines correctly', () {
    writeFile('small.dart', 'class A {}\n');
    final snapshots = service.analyze(temp.path, ['small.dart']);
    expect(snapshots, hasLength(1));
    expect(snapshots.first.lineCount, 1);
    expect(snapshots.first.filePath, 'small.dart');
  });

  test('analyze extracts method count', () {
    writeFile('methods.dart', '''
class Foo {
  void bar() {
    print('hello');
  }

  int baz(int x) {
    return x + 1;
  }
}
''');
    final snapshots = service.analyze(temp.path, ['methods.dart']);
    expect(snapshots.first.methodCount, greaterThanOrEqualTo(2));
  });

  test('analyze measures method line count', () {
    // A method with 10 lines in the body.
    final lines = <String>[
      'class Foo {',
      '  void bigMethod() {',
      for (var i = 0; i < 10; i++) '    print($i);',
      '  }',
      '}',
      '',
    ];
    writeFile('big.dart', lines.join('\n'));
    final snapshots = service.analyze(temp.path, ['big.dart']);
    // Method spans from 'void bigMethod()' to closing '}'.
    expect(snapshots.first.maxMethodLines, greaterThanOrEqualTo(10));
  });

  test('analyze measures nesting depth', () {
    writeFile('nested.dart', '''
class Foo {
  void deep() {
    if (true) {
      if (true) {
        if (true) {
          print('deep');
        }
      }
    }
  }
}
''');
    final snapshots = service.analyze(temp.path, ['nested.dart']);
    expect(snapshots.first.maxNestingDepth, greaterThanOrEqualTo(3));
  });

  test('analyze counts parameters', () {
    writeFile('params.dart', '''
class Foo {
  void manyParams(int a, int b, int c, int d, int e) {
    print(a + b + c + d + e);
  }
}
''');
    final snapshots = service.analyze(temp.path, ['params.dart']);
    expect(snapshots.first.maxParameterCount, 5);
  });

  test('analyze skips non-existent files', () {
    final snapshots = service.analyze(temp.path, ['does_not_exist.dart']);
    expect(snapshots, isEmpty);
  });

  test('analyze handles empty file', () {
    writeFile('empty.dart', '');
    final snapshots = service.analyze(temp.path, ['empty.dart']);
    expect(snapshots, hasLength(1));
    // readAsLinesSync on empty file returns empty list.
    expect(snapshots.first.lineCount, 0);
    expect(snapshots.first.methodCount, 0);
  });

  test('evaluate returns empty for clean metrics', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'clean.dart',
        lineCount: 50,
        maxMethodLines: 10,
        maxNestingDepth: 2,
        maxParameterCount: 3,
        methodCount: 5,
      ),
    ];
    final signals = service.evaluate(metrics);
    expect(signals, isEmpty);
  });

  test('evaluate detects file over line threshold', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'big.dart',
        lineCount: 600,
        maxMethodLines: 10,
        maxNestingDepth: 2,
        maxParameterCount: 3,
        methodCount: 20,
      ),
    ];
    final signals = service.evaluate(metrics, maxFileLines: 500);
    expect(signals, hasLength(1));
    expect(signals.first.layer, HealthSignalLayer.static);
    expect(signals.first.finding, contains('600 lines'));
    expect(signals.first.affectedFiles, ['big.dart']);
  });

  test('evaluate detects method over line threshold', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'long_method.dart',
        lineCount: 200,
        maxMethodLines: 100,
        maxNestingDepth: 2,
        maxParameterCount: 3,
        methodCount: 3,
      ),
    ];
    final signals = service.evaluate(metrics, maxMethodLines: 80);
    expect(signals, hasLength(1));
    expect(signals.first.finding, contains('100 lines'));
  });

  test('evaluate detects deep nesting', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'deep.dart',
        lineCount: 100,
        maxMethodLines: 30,
        maxNestingDepth: 7,
        maxParameterCount: 2,
        methodCount: 3,
      ),
    ];
    final signals = service.evaluate(metrics, maxNestingDepth: 5);
    expect(signals, hasLength(1));
    expect(signals.first.finding, contains('nesting depth 7'));
  });

  test('evaluate detects too many parameters', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'params.dart',
        lineCount: 50,
        maxMethodLines: 10,
        maxNestingDepth: 1,
        maxParameterCount: 8,
        methodCount: 2,
      ),
    ];
    final signals = service.evaluate(metrics, maxParameterCount: 6);
    expect(signals, hasLength(1));
    expect(signals.first.finding, contains('8 parameters'));
  });

  test('evaluate confidence is proportional to overshoot', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'a.dart',
        lineCount: 1000,
        maxMethodLines: 10,
        maxNestingDepth: 1,
        maxParameterCount: 1,
        methodCount: 1,
      ),
    ];
    // 1000 lines with threshold 500 → 1000 / (500*2) = 1.0
    final signals = service.evaluate(metrics, maxFileLines: 500);
    expect(signals.first.confidence, 1.0);

    // 600 lines with threshold 500 → 600 / 1000 = 0.6
    final metrics2 = [
      const FileHealthSnapshot(
        filePath: 'b.dart',
        lineCount: 600,
        maxMethodLines: 10,
        maxNestingDepth: 1,
        maxParameterCount: 1,
        methodCount: 1,
      ),
    ];
    final signals2 = service.evaluate(metrics2, maxFileLines: 500);
    expect(signals2.first.confidence, closeTo(0.6, 0.01));
  });

  test('evaluate multiple violations from single file', () {
    final metrics = [
      const FileHealthSnapshot(
        filePath: 'messy.dart',
        lineCount: 600,
        maxMethodLines: 100,
        maxNestingDepth: 7,
        maxParameterCount: 8,
        methodCount: 10,
      ),
    ];
    final signals = service.evaluate(
      metrics,
      maxFileLines: 500,
      maxMethodLines: 80,
      maxNestingDepth: 5,
      maxParameterCount: 6,
    );
    expect(signals, hasLength(4));
    expect(
      signals.every((s) => s.affectedFiles.contains('messy.dart')),
      isTrue,
    );
  });
}
