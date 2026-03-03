import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/state_repair_service.dart';
import 'package:genaisys/core/storage/atomic_file_write.dart';
import 'package:genaisys/core/storage/state_store.dart';

/// Hardening matrix: corrupt state recovery.
///
/// Verifies that [StateStore] and [StateRepairService] correctly detect and
/// recover from various forms of STATE.json corruption that can occur during
/// overnight unattended operation (power loss, disk full, concurrent write).
void main() {
  group('StateStore corruption detection', () {
    test('returns initial state on truncated JSON', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_truncated_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Simulate power-loss mid-write: truncated JSON.
      File(
        layout.statePath,
      ).writeAsStringSync('{"activeTaskId": "task-1", "ac');

      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskId, isNull);
      expect(state.autopilotRunning, isFalse);
    });

    test('returns initial state on empty file', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_empty_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      File(layout.statePath).writeAsStringSync('');

      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskId, isNull);
    });

    test('returns initial state on non-object JSON (array)', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_array_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      String? callbackPath;
      String? callbackExpected;
      String? callbackComputed;

      File(layout.statePath).writeAsStringSync('[1, 2, 3]');

      final store = StateStore(
        layout.statePath,
        onCorruption:
            ({
              required String path,
              required String expected,
              required String computed,
            }) {
              callbackPath = path;
              callbackExpected = expected;
              callbackComputed = computed;
            },
      );

      final state = store.read();
      expect(state.activeTaskId, isNull);
      expect(callbackPath, layout.statePath);
      expect(callbackExpected, 'object');
      expect(callbackComputed, contains('List'));
    });

    test('returns initial state on CRC32 mismatch', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_crc_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Write valid state first.
      final store = StateStore(layout.statePath);
      store.write(store.read().copyWith(activeTask: ActiveTaskState(id: 'task-1')));

      // Tamper: replace checksum with a wrong value.
      final content = File(layout.statePath).readAsStringSync();
      final tampered = content.replaceFirst(
        RegExp(r'"_checksum":\s*"[a-f0-9]+"'),
        '"_checksum": "deadbeef"',
      );
      File(layout.statePath).writeAsStringSync(tampered);

      String? detectedExpected;
      String? detectedComputed;
      final corruptStore = StateStore(
        layout.statePath,
        onCorruption:
            ({
              required String path,
              required String expected,
              required String computed,
            }) {
              detectedExpected = expected;
              detectedComputed = computed;
            },
      );

      final state = corruptStore.read();
      // Should fall back to initial state.
      expect(state.activeTaskId, isNull);
      expect(detectedExpected, 'deadbeef');
      expect(detectedComputed, isNot('deadbeef'));
    });

    test('rejects tampered field even when JSON is structurally valid', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_tamper_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Write valid state.
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'My Task'),
        ),
      );

      // Read the file, decode, tamper a field, re-encode WITHOUT updating checksum.
      final content = File(layout.statePath).readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, Object?>;
      final originalChecksum = decoded['_checksum'];
      decoded['active_task_title'] = 'TAMPERED';
      // Keep original checksum.
      decoded['_checksum'] = originalChecksum;
      File(
        layout.statePath,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(decoded));

      var corruptionDetected = false;
      final tamperedStore = StateStore(
        layout.statePath,
        onCorruption:
            ({
              required String path,
              required String expected,
              required String computed,
            }) {
              corruptionDetected = true;
            },
      );

      final state = tamperedStore.read();
      expect(corruptionDetected, isTrue);
      // Should NOT return the tampered value.
      expect(state.activeTaskTitle, isNot('TAMPERED'));
    });
  });

  group('StateRepairService recovery from corruption', () {
    test('recovers from binary garbage in STATE.json', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_binary_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Write binary garbage.
      File(
        layout.statePath,
      ).writeAsBytesSync(List<int>.generate(100, (i) => i % 256));

      final report = StateRepairService().repair(temp.path);

      // StateStore.read() catches FormatException and returns initial state,
      // so repair() sees a healthy initial state — the repair itself is no-op
      // because StateStore handles the corruption silently.
      // The important thing: no crash, state is readable afterwards.
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskId, isNull);
      expect(state.autopilotRunning, isFalse);
      // repair() may or may not report changes depending on what StateStore
      // returned — the key assertion is that it doesn't throw.
      expect(report, isNotNull);
    });

    test('round-trip: corrupt → repair → write → read preserves new state', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_corrupt_roundtrip_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Step 1: Write good state.
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Important Task',
          ),
        ),
      );

      // Step 2: Corrupt the file.
      File(layout.statePath).writeAsStringSync('CORRUPT!!!');

      // Step 3: Repair.
      StateRepairService().repair(temp.path);

      // Step 4: Write new state on top of repaired state.
      final repairedStore = StateStore(layout.statePath);
      final afterRepair = repairedStore.read();
      repairedStore.write(
        afterRepair.copyWith(
          activeTask: ActiveTaskState(id: 'task-2', title: 'Recovered Task'),
        ),
      );

      // Step 5: Read back and verify.
      final finalState = StateStore(layout.statePath).read();
      expect(finalState.activeTaskId, 'task-2');
      expect(finalState.activeTaskTitle, 'Recovered Task');
    });
  });

  group('AtomicFileWrite safety', () {
    test('leaves no partial .tmp file on write failure', () {
      // Root ignores chmod — permission-based assertions are meaningless when
      // running as root (common in CI containers). Skip to avoid false failure.
      final uid = Process.runSync('id', ['-u']).stdout.toString().trim();
      if (uid == '0') return;

      final temp = Directory.systemTemp.createTempSync(
        'genaisys_atomic_fail_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      // Attempt to write to a path inside a read-only directory.
      final readOnlyDir = Directory('${temp.path}/readonly');
      readOnlyDir.createSync();
      final targetPath = '${readOnlyDir.path}/state.json';

      // Make the directory read-only so the atomic write's temp file can't
      // be created or renamed.
      Process.runSync('chmod', ['555', readOnlyDir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', readOnlyDir.path]));

      // Should throw (permission denied).
      expect(
        () => AtomicFileWrite.writeStringSync(targetPath, '{"ok": true}'),
        throwsA(isA<FileSystemException>()),
      );

      // Verify no .tmp files are left behind.
      final leftover = readOnlyDir.listSync().where(
        (f) => f.path.contains('.tmp.'),
      );
      expect(leftover, isEmpty, reason: 'No .tmp remnant should be left');
    });
  });
}
