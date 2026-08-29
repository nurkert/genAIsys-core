import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  late Directory temp;
  late String projectRoot;
  late HealthLedgerStore ledgerStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_ch_');
    projectRoot = temp.path;
    // Create .genaisys directory and required files.
    final hepDir = Directory(
      '$projectRoot${Platform.pathSeparator}.genaisys',
    );
    hepDir.createSync();
    // Create TASKS.md.
    File(
      '${hepDir.path}${Platform.pathSeparator}TASKS.md',
    ).writeAsStringSync('# Tasks\n\n## Backlog\n');
    // Create RUN_LOG.jsonl (empty).
    File(
      '${hepDir.path}${Platform.pathSeparator}RUN_LOG.jsonl',
    ).writeAsStringSync('');
    final ledgerPath =
        '${hepDir.path}${Platform.pathSeparator}health_ledger.jsonl';
    ledgerStore = HealthLedgerStore(ledgerPath);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  ProjectConfig config({
    bool enabled = true,
    bool autoCreate = true,
    double minConfidence = 0.6,
    double maxRefactorRatio = 0.3,
    int maxFileLines = 500,
    int maxMethodLines = 80,
    int maxNestingDepth = 5,
    int maxParameterCount = 6,
    double hotspotThreshold = 0.3,
    int hotspotWindow = 20,
    int patchClusterMin = 3,
  }) {
    return ProjectConfig(
      codeHealthEnabled: enabled,
      codeHealthAutoCreateTasks: autoCreate,
      codeHealthMinConfidence: minConfidence,
      codeHealthMaxRefactorRatio: maxRefactorRatio,
      codeHealthMaxFileLines: maxFileLines,
      codeHealthMaxMethodLines: maxMethodLines,
      codeHealthMaxNestingDepth: maxNestingDepth,
      codeHealthMaxParameterCount: maxParameterCount,
      codeHealthHotspotThreshold: hotspotThreshold,
      codeHealthHotspotWindow: hotspotWindow,
      codeHealthPatchClusterMin: patchClusterMin,
    );
  }

  void writeSourceFile(String relativePath, String content) {
    final fullPath = '$projectRoot${Platform.pathSeparator}$relativePath';
    final dir = File(fullPath).parent;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File(fullPath).writeAsStringSync(content);
  }

  test('returns empty when disabled', () async {
    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/a.dart'],
      taskId: 'task-1',
      taskTitle: 'Test task',
      config: config(enabled: false),
    );
    expect(report.signals, isEmpty);
    expect(report.shouldCreateTask, isFalse);
  });

  test('returns empty for no touched files', () async {
    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: [],
      taskId: 'task-1',
      taskTitle: 'Test task',
      config: config(),
    );
    expect(report.signals, isEmpty);
    expect(report.shouldCreateTask, isFalse);
  });

  test('clean code produces no signals', () async {
    writeSourceFile('lib/clean.dart', '''
class Clean {
  void doSomething() {
    print('hello');
  }
}
''');
    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/clean.dart'],
      taskId: 'task-1',
      taskTitle: 'Clean task',
      config: config(),
    );
    expect(report.signals, isEmpty);
    expect(report.shouldCreateTask, isFalse);
  });

  test('large file triggers Layer 1 signal', () async {
    // Create a file with 600 lines.
    final lines = List.generate(600, (i) => '// line $i');
    writeSourceFile('lib/big.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/big.dart'],
      taskId: 'task-2',
      taskTitle: 'Big file task',
      config: config(maxFileLines: 500),
    );
    expect(report.signals, isNotEmpty);
    expect(
      report.signals.any((s) => s.layer == HealthSignalLayer.static),
      isTrue,
    );
  });

  test('Layer 1 + Layer 2 signals produce P1 priority', () async {
    // Pre-populate ledger with hotspot data.
    for (var i = 0; i < 5; i++) {
      ledgerStore.append(
        DeliveryHealthEntry(
          timestamp: DateTime.now().toUtc().toIso8601String(),
          files: [
            const FileHealthSnapshot(
              filePath: 'lib/hot.dart',
              lineCount: 600,
              maxMethodLines: 20,
              maxNestingDepth: 2,
              maxParameterCount: 3,
              methodCount: 5,
            ),
          ],
        ),
      );
    }

    // Create the file (over line threshold).
    final lines = List.generate(600, (i) => '// line $i');
    writeSourceFile('lib/hot.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/hot.dart'],
      taskId: 'task-3',
      taskTitle: 'Hot file',
      config: config(
        maxFileLines: 500,
        hotspotThreshold: 0.3,
        hotspotWindow: 10,
      ),
    );

    // Should have signals from both layers → P1.
    final layers = report.signals.map((s) => s.layer).toSet();
    expect(layers, contains(HealthSignalLayer.static));
    expect(layers, contains(HealthSignalLayer.dejaVu));
    expect(report.recommendedPriority, TaskPriority.p1);
  });

  test('single layer high confidence produces P2', () async {
    // Large file but no hotspot history → single layer.
    final lines = List.generate(1000, (i) => '// line $i');
    writeSourceFile('lib/huge.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/huge.dart'],
      taskId: 'task-4',
      taskTitle: 'Huge file',
      config: config(maxFileLines: 500),
    );

    expect(report.signals, isNotEmpty);
    // Only static layer → confidence = 1000/(500*2) = 1.0 → P2.
    expect(report.recommendedPriority, TaskPriority.p2);
  });

  test('below min confidence does not create task', () async {
    // File just slightly over threshold → low confidence.
    final lines = List.generate(510, (i) => '// line $i');
    writeSourceFile('lib/barely.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/barely.dart'],
      taskId: 'task-5',
      taskTitle: 'Barely over',
      config: config(maxFileLines: 500, minConfidence: 0.6),
    );

    // 510 / 1000 = 0.51 confidence < 0.6 threshold.
    expect(report.shouldCreateTask, isFalse);
  });

  test('refactor ratio cap prevents task creation', () async {
    // Pre-populate backlog with many refactor tasks.
    final tasksPath =
        '$projectRoot${Platform.pathSeparator}'
        '.genaisys${Platform.pathSeparator}TASKS.md';
    File(tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P2] [REF] Refactor A | AC: done
- [ ] [P2] [REF] Refactor B | AC: done
- [ ] [P2] [REF] Refactor C | AC: done
- [ ] [P2] [CORE] Feature D | AC: done
''');

    // 3/4 = 75% refactor ratio, cap is 30%.
    final lines = List.generate(1000, (i) => '// line $i');
    writeSourceFile('lib/big.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/big.dart'],
      taskId: 'task-6',
      taskTitle: 'Capped',
      config: config(maxFileLines: 500, maxRefactorRatio: 0.3),
    );

    expect(report.signals, isNotEmpty);
    expect(report.shouldCreateTask, isFalse);
  });

  test('auto create disabled still reports signals', () async {
    final lines = List.generate(1000, (i) => '// line $i');
    writeSourceFile('lib/big.dart', lines.join('\n'));

    final service = CodeHealthService(ledgerStore: ledgerStore);
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/big.dart'],
      taskId: 'task-7',
      taskTitle: 'No auto create',
      config: config(autoCreate: false),
    );

    expect(report.signals, isNotEmpty);
    // shouldCreateTask reports policy decision, but auto-create is disabled.
  });

  test('run log event is emitted', () async {
    writeSourceFile('lib/a.dart', 'class A {}\n');

    final service = CodeHealthService(ledgerStore: ledgerStore);
    await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/a.dart'],
      taskId: 'task-8',
      taskTitle: 'Log test',
      config: config(),
    );

    final runLogPath =
        '$projectRoot${Platform.pathSeparator}'
        '.genaisys${Platform.pathSeparator}RUN_LOG.jsonl';
    final logLines = File(
      runLogPath,
    ).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(logLines, isNotEmpty);
    final lastEvent = jsonDecode(logLines.last) as Map<String, Object?>;
    expect(lastEvent['event'], 'code_health_evaluation');
  });

  test('ledger records entry on evaluation', () async {
    writeSourceFile('lib/tracked.dart', 'class X {}\n');

    final service = CodeHealthService(ledgerStore: ledgerStore);
    await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/tracked.dart'],
      taskId: 'task-9',
      taskTitle: 'Track test',
      config: config(),
    );

    final entries = ledgerStore.readRecent();
    expect(entries, isNotEmpty);
    expect(entries.last.taskId, 'task-9');
  });

  test('duplicate task title is handled gracefully', () async {
    // Create a task that will cause a duplicate.
    final lines = List.generate(1000, (i) => '// line $i');
    writeSourceFile('lib/dup.dart', lines.join('\n'));

    // First evaluation creates the task.
    final service = CodeHealthService(ledgerStore: ledgerStore);
    await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/dup.dart'],
      taskId: 'task-10',
      taskTitle: 'Dup test',
      config: config(maxFileLines: 500),
    );

    // Second evaluation with same files should not throw.
    final report = await service.evaluateDelivery(
      projectRoot,
      touchedFiles: ['lib/dup.dart'],
      taskId: 'task-11',
      taskTitle: 'Dup test 2',
      config: config(maxFileLines: 500),
    );
    // Should complete without error.
    expect(report.signals, isNotEmpty);
  });
}
