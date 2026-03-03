import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/storage/crc32.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  group('Corrupt state recovery', () {
    late Directory temp;
    late String statePath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_corrupt_state_');
      statePath = '${temp.path}/STATE.json';
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('invalid JSON returns ProjectState.initial()', () {
      File(statePath).writeAsStringSync('this is not json at all {{{');

      final diagnostics = <String>[];
      final store = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          diagnostics.add('$expected -> $computed');
        },
      );

      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first, contains('valid_json'));
      expect(diagnostics.first, contains('parse_error'));
    });

    test('truncated JSON returns ProjectState.initial()', () {
      File(statePath).writeAsStringSync('{"active_task_id": "task-1", "last_');

      final diagnostics = <String>[];
      final store = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          diagnostics.add('$expected -> $computed');
        },
      );

      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first, contains('valid_json'));
    });

    test('checksum-mismatch JSON returns ProjectState.initial()', () {
      // Build valid state JSON with correct checksum, then tamper with it.
      final stateJson = <String, dynamic>{
        'active_task_id': 'task-1',
        'active_task_title': 'My task',
        'last_updated': '2026-01-01T00:00:00Z',
        'workflow_stage': 'idle',
      };
      final payload = const JsonEncoder.withIndent('  ').convert(stateJson);
      final correctChecksum = Crc32.hexOfString(payload);

      // Write with a wrong checksum.
      stateJson[StateStore.checksumKey] = 'deadbeef';
      final fullPayload = const JsonEncoder.withIndent('  ').convert(stateJson);
      File(statePath).writeAsStringSync(fullPayload);

      final diagnostics = <({String path, String expected, String computed})>[];
      final store = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          diagnostics.add((path: path, expected: expected, computed: computed));
        },
      );

      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.expected, 'deadbeef');
      expect(diagnostics.first.computed, correctChecksum);
    });

    test('empty file returns ProjectState.initial()', () {
      File(statePath).writeAsStringSync('');

      final store = StateStore(statePath);
      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
    });

    test('non-object JSON returns ProjectState.initial()', () {
      File(statePath).writeAsStringSync('"just a string"');

      final diagnostics = <String>[];
      final store = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          diagnostics.add('$expected -> $computed');
        },
      );

      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first, contains('object'));
    });

    test('missing file returns ProjectState.initial()', () {
      final store = StateStore(statePath);
      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
    });

    test('valid JSON with correct checksum reads normally', () {
      final stateStore = StateStore(statePath);
      final original = ProjectState(
        lastUpdated: '2026-01-01T00:00:00Z',
        activeTask: ActiveTaskState(id: 'test-task', title: 'Test Task'),
      );
      stateStore.write(original);

      final diagnostics = <String>[];
      final readStore = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          diagnostics.add('$expected -> $computed');
        },
      );

      final state = readStore.read();
      expect(state.activeTaskId, 'test-task');
      expect(state.activeTaskTitle, 'Test Task');
      expect(diagnostics, isEmpty, reason: 'No corruption should be detected');
    });

    test('autopilot can proceed after state corruption recovery', () {
      // Write corrupt state.
      File(statePath).writeAsStringSync('corrupt{data');

      final store = StateStore(statePath);
      final recovered = store.read();
      expect(recovered.workflowStage, WorkflowStage.idle);

      // Write a new valid state (simulating autopilot proceeding).
      final newState = ProjectState(
        lastUpdated: '2026-02-01T00:00:00Z',
        activeTask: ActiveTaskState(id: 'new-task', title: 'New Task'),
      );
      store.write(newState);

      // Read back and verify.
      final readBack = store.read();
      expect(readBack.activeTaskId, 'new-task');
      expect(readBack.activeTaskTitle, 'New Task');
    });
  });
}
