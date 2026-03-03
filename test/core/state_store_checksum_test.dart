import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  late Directory tempDir;
  late String statePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_checksum_');
    statePath =
        '${tempDir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}STATE.json';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('write embeds _checksum field in JSON', () {
    final store = StateStore(statePath);
    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Test')));

    final raw = File(statePath).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded.containsKey('_checksum'), isTrue);
    expect(decoded['_checksum'], isA<String>());
    expect((decoded['_checksum'] as String).length, 8);
  });

  test('read succeeds with valid checksum', () {
    final store = StateStore(statePath);
    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Valid')));

    final state = store.read();
    expect(state.activeTaskTitle, 'Valid');
  });

  test('read returns initial state on truncated JSON', () {
    var corruptionDetected = false;
    final store = StateStore(
      statePath,
      onCorruption:
          ({
            required String path,
            required String expected,
            required String computed,
          }) {
            corruptionDetected = true;
          },
    );

    // Write valid state first.
    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Good')));

    // Truncate the file to corrupt it.
    final file = File(statePath);
    final content = file.readAsStringSync();
    file.writeAsStringSync(content.substring(0, content.length ~/ 2));

    final state = store.read();
    // Should fall back to initial state.
    expect(state.activeTaskTitle, isNull);
    expect(corruptionDetected, isTrue);
  });

  test('read returns initial state on wrong checksum', () {
    var corruptionDetected = false;
    final store = StateStore(
      statePath,
      onCorruption:
          ({
            required String path,
            required String expected,
            required String computed,
          }) {
            corruptionDetected = true;
          },
    );

    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Original')));

    // Tamper with the file content (change a value but keep valid JSON).
    final file = File(statePath);
    final raw = file.readAsStringSync();
    final tampered = raw.replaceFirst('Original', 'Tampered');
    file.writeAsStringSync(tampered);

    final state = store.read();
    expect(state.activeTaskTitle, isNull); // Reset to initial.
    expect(corruptionDetected, isTrue);
  });

  test('read gracefully handles missing checksum (legacy files)', () {
    // A legacy STATE.json without _checksum should still be readable.
    final dir = File(statePath).parent;
    dir.createSync(recursive: true);
    final payload = jsonEncode({
      'version': 1,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
      'active_task_title': 'Legacy',
    });
    File(statePath).writeAsStringSync(payload);

    final store = StateStore(statePath);
    final state = store.read();
    expect(state.activeTaskTitle, 'Legacy');
  });

  test('round-trip preserves state correctly', () {
    final store = StateStore(statePath);
    final initial = store.read().copyWith(
      activeTask: const ActiveTaskState(title: 'Round-Trip'),
      cycleCount: 42,
      autopilotRun: const AutopilotRunState(consecutiveFailures: 3),
    );
    store.write(initial);

    final recovered = store.read();
    expect(recovered.activeTaskTitle, 'Round-Trip');
    expect(recovered.cycleCount, 42);
    expect(recovered.consecutiveFailures, 3);
  });

  test('corruption callback receives expected vs computed checksums', () {
    String? capturedExpected;
    String? capturedComputed;
    final store = StateStore(
      statePath,
      onCorruption:
          ({
            required String path,
            required String expected,
            required String computed,
          }) {
            capturedExpected = expected;
            capturedComputed = computed;
          },
    );

    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'A')));

    // Tamper with content.
    final file = File(statePath);
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final originalChecksum = decoded['_checksum'] as String;
    final tampered = raw.replaceFirst('"A"', '"B"');
    file.writeAsStringSync(tampered);

    store.read();
    expect(capturedExpected, originalChecksum);
    expect(capturedComputed, isNotNull);
    expect(capturedComputed, isNot(originalChecksum));
  });
}
