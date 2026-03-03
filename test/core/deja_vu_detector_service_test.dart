import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  late Directory temp;
  late String ledgerPath;
  late HealthLedgerStore ledgerStore;
  late DejaVuDetectorService service;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_dejavu_');
    ledgerPath = '${temp.path}${Platform.pathSeparator}health_ledger.jsonl';
    ledgerStore = HealthLedgerStore(ledgerPath);
    service = DejaVuDetectorService(ledgerStore: ledgerStore);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  FileHealthSnapshot snap({
    String filePath = 'lib/a.dart',
    int lineCount = 100,
    int maxMethodLines = 20,
  }) {
    return FileHealthSnapshot(
      filePath: filePath,
      lineCount: lineCount,
      maxMethodLines: maxMethodLines,
      maxNestingDepth: 2,
      maxParameterCount: 3,
      methodCount: 5,
    );
  }

  void addEntry({List<FileHealthSnapshot> files = const [], String? taskId}) {
    ledgerStore.append(
      DeliveryHealthEntry(
        taskId: taskId,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        files: files,
      ),
    );
  }

  test('empty ledger returns no signals', () {
    final signals = service.detect(temp.path);
    expect(signals, isEmpty);
  });

  test('detects file hotspot above threshold', () {
    // File A appears in 4 out of 5 deliveries (80% rate).
    for (var i = 0; i < 5; i++) {
      final files = i < 4
          ? [snap(filePath: 'lib/hot.dart')]
          : [snap(filePath: 'lib/cold.dart')];
      addEntry(files: files);
    }

    final signals = service.detect(
      temp.path,
      windowSize: 5,
      hotspotThreshold: 0.3,
    );
    final hotspotSignals = signals
        .where((s) => s.finding.contains('rate'))
        .toList();
    expect(hotspotSignals, isNotEmpty);
    expect(hotspotSignals.first.affectedFiles, ['lib/hot.dart']);
    expect(hotspotSignals.first.confidence, closeTo(0.8, 0.01));
  });

  test('no hotspot when below threshold', () {
    // File appears in 1 out of 5 deliveries (20% rate).
    addEntry(files: [snap(filePath: 'lib/rare.dart')]);
    for (var i = 0; i < 4; i++) {
      addEntry(files: [snap(filePath: 'lib/other.dart')]);
    }

    final signals = service.detect(
      temp.path,
      windowSize: 5,
      hotspotThreshold: 0.3,
    );
    final rareSignals = signals
        .where((s) => s.affectedFiles.contains('lib/rare.dart'))
        .where((s) => s.finding.contains('rate'))
        .toList();
    expect(rareSignals, isEmpty);
  });

  test('detects patch cluster — consecutive deliveries', () {
    // File A in 4 consecutive deliveries.
    for (var i = 0; i < 4; i++) {
      addEntry(files: [snap(filePath: 'lib/patched.dart')]);
    }
    addEntry(files: [snap(filePath: 'lib/other.dart')]);

    final signals = service.detect(
      temp.path,
      windowSize: 10,
      patchClusterMin: 3,
    );
    final clusterSignals = signals
        .where((s) => s.finding.contains('consecutive'))
        .toList();
    expect(clusterSignals, isNotEmpty);
    expect(clusterSignals.first.affectedFiles, ['lib/patched.dart']);
    // confidence: min(1.0, 4/5) = 0.8
    expect(clusterSignals.first.confidence, closeTo(0.8, 0.01));
  });

  test('no patch cluster when interrupted', () {
    // File A in 2, then other, then A again — max consecutive is 2.
    addEntry(files: [snap(filePath: 'lib/a.dart')]);
    addEntry(files: [snap(filePath: 'lib/a.dart')]);
    addEntry(files: [snap(filePath: 'lib/b.dart')]);
    addEntry(files: [snap(filePath: 'lib/a.dart')]);

    final signals = service.detect(
      temp.path,
      windowSize: 10,
      patchClusterMin: 3,
    );
    final clusterSignals = signals
        .where((s) => s.finding.contains('consecutive'))
        .toList();
    expect(clusterSignals, isEmpty);
  });

  test('detects growing complexity', () {
    // File grows in 4 out of 5 consecutive snapshots.
    for (var i = 0; i < 5; i++) {
      addEntry(
        files: [
          snap(
            filePath: 'lib/growing.dart',
            lineCount: 100 + i * 20,
            maxMethodLines: 20 + i * 5,
          ),
        ],
      );
    }

    final signals = service.detect(temp.path, windowSize: 10);
    final growthSignals = signals
        .where((s) => s.finding.contains('growing'))
        .toList();
    expect(growthSignals, isNotEmpty);
    expect(growthSignals.first.layer, HealthSignalLayer.dejaVu);
  });

  test('no growing complexity with stable metrics', () {
    // File stays the same size in all deliveries.
    for (var i = 0; i < 5; i++) {
      addEntry(files: [snap(filePath: 'lib/stable.dart', lineCount: 100)]);
    }

    final signals = service.detect(temp.path, windowSize: 10);
    final growthSignals = signals
        .where((s) => s.finding.contains('complexity is growing'))
        .toList();
    expect(growthSignals, isEmpty);
  });

  test('respects window size for hotspot detection', () {
    // 10 entries: first 8 touch A, last 2 touch B.
    for (var i = 0; i < 8; i++) {
      addEntry(files: [snap(filePath: 'lib/old_hot.dart')]);
    }
    for (var i = 0; i < 4; i++) {
      addEntry(files: [snap(filePath: 'lib/new.dart')]);
    }

    // Window of 4: only sees the last 4 entries (all B).
    final signals = service.detect(
      temp.path,
      windowSize: 4,
      hotspotThreshold: 0.3,
    );
    final oldHotSignals = signals
        .where((s) => s.affectedFiles.contains('lib/old_hot.dart'))
        .where((s) => s.finding.contains('rate'))
        .toList();
    expect(oldHotSignals, isEmpty);
  });

  test('hotspot requires minimum 3 entries', () {
    // Only 2 entries — should not detect hotspot.
    addEntry(files: [snap(filePath: 'lib/x.dart')]);
    addEntry(files: [snap(filePath: 'lib/x.dart')]);

    final signals = service.detect(
      temp.path,
      windowSize: 10,
      hotspotThreshold: 0.3,
    );
    final hotspotSignals = signals
        .where((s) => s.finding.contains('rate'))
        .toList();
    expect(hotspotSignals, isEmpty);
  });

  test('too few entries for growing complexity', () {
    // Only 2 entries — need at least 3.
    addEntry(files: [snap(filePath: 'lib/a.dart', lineCount: 100)]);
    addEntry(files: [snap(filePath: 'lib/a.dart', lineCount: 200)]);

    final signals = service.detect(temp.path, windowSize: 10);
    final growthSignals = signals
        .where((s) => s.finding.contains('complexity is growing'))
        .toList();
    expect(growthSignals, isEmpty);
  });

  test('all signal layers are dejaVu', () {
    for (var i = 0; i < 5; i++) {
      addEntry(
        files: [snap(filePath: 'lib/x.dart', lineCount: 100 + i * 30)],
      );
    }
    final signals = service.detect(temp.path, windowSize: 5);
    for (final s in signals) {
      expect(s.layer, HealthSignalLayer.dejaVu);
    }
  });
}
