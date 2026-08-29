import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/services/task_management/task_forensics_service.dart';
import 'package:genaisys/core/storage/atomic_file_write.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  group('ForensicDiagnosis suggested actions', () {
    late TaskForensicsService service;

    setUp(() {
      service = TaskForensicsService();
    });

    test('redecompose action for spec_too_large', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        requiredFileCount: 8,
      );

      expect(diagnosis.suggestedAction, ForensicAction.redecompose);
      expect(diagnosis.classification, ForensicClassification.specTooLarge);
      expect(diagnosis.guidanceText, isNotNull);
      expect(diagnosis.guidanceText, contains('8 files'));
    });

    test('block action for policy_conflict', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        errorKinds: ['diff_budget_exceeded'],
      );

      expect(diagnosis.suggestedAction, ForensicAction.block);
      expect(diagnosis.classification, ForensicClassification.policyConflict);
    });

    test('retryWithGuidance action for persistent_test_failure', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        errorKinds: ['quality_gate_failed'],
      );

      expect(diagnosis.suggestedAction, ForensicAction.retryWithGuidance);
      expect(
        diagnosis.classification,
        ForensicClassification.persistentTestFailure,
      );
      expect(diagnosis.guidanceText, isNotNull);
      expect(diagnosis.guidanceText, contains('test'));
    });

    test('regenerateSpec action for spec_incorrect', () {
      final temp = Directory.systemTemp.createTempSync('forensic_block_');
      try {
        Directory('${temp.path}/.genaisys').createSync(recursive: true);
        _writeRunLog(temp.path, [
          _reviewRejectEvent(
            note:
                'You changed the wrong file — the requirement targets a '
                'different module entirely.',
            task: 'My Task',
          ),
        ]);

        final diagnosis = service.diagnose(
          temp.path,
          taskTitle: 'My Task',
          retryCount: 3,
        );

        expect(diagnosis.suggestedAction, ForensicAction.regenerateSpec);
        expect(diagnosis.classification, ForensicClassification.specIncorrect);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('block action for unknown classification', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.suggestedAction, ForensicAction.block);
      expect(diagnosis.classification, ForensicClassification.unknown);
    });
  });

  group('Forensic state fields in ProjectState', () {
    test('default state has forensicRecoveryAttempted false', () {
      final state = ProjectState.initial();

      expect(state.forensicRecoveryAttempted, isFalse);
      expect(state.forensicGuidance, isNull);
    });

    test('can set forensicRecoveryAttempted to true', () {
      final state = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(forensicRecoveryAttempted: true),
      );

      expect(state.forensicRecoveryAttempted, isTrue);
    });

    test('can set forensicGuidance text', () {
      final state = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(forensicGuidance: 'Try a different approach.'),
      );

      expect(state.forensicGuidance, 'Try a different approach.');
    });

    test('forensicRecoveryAttempted serializes to JSON', () {
      final state = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(
          forensicRecoveryAttempted: true,
          forensicGuidance: 'Some guidance text.',
        ),
      );

      final json = state.toJson();

      expect(json['forensic_recovery_attempted'], isTrue);
      expect(json['forensic_guidance'], 'Some guidance text.');
    });

    test('forensicRecoveryAttempted deserializes from JSON', () {
      final json = {
        'last_updated': DateTime.now().toUtc().toIso8601String(),
        'forensic_recovery_attempted': true,
        'forensic_guidance': 'Decompose into smaller tasks.',
      };

      final state = ProjectState.fromJson(json);

      expect(state.forensicRecoveryAttempted, isTrue);
      expect(state.forensicGuidance, 'Decompose into smaller tasks.');
    });

    test('forensicRecoveryAttempted defaults to false in JSON', () {
      final json = {'last_updated': DateTime.now().toUtc().toIso8601String()};

      final state = ProjectState.fromJson(json);

      expect(state.forensicRecoveryAttempted, isFalse);
      expect(state.forensicGuidance, isNull);
    });

    test('copyWith resets forensic fields', () {
      final state = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(
          forensicRecoveryAttempted: true,
          forensicGuidance: 'Some guidance.',
        ),
      );

      final cleared = state.copyWith(
        activeTask: ActiveTaskState(
          forensicRecoveryAttempted: false,
          forensicGuidance: null,
        ),
      );

      expect(cleared.forensicRecoveryAttempted, isFalse);
      expect(cleared.forensicGuidance, isNull);
    });
  });

  group('Forensic state persistence', () {
    late Directory temp;
    late String statePath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('forensic_persist_');
      statePath = '${temp.path}/STATE.json';
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('forensic fields survive write-read cycle', () {
      final store = StateStore(statePath);
      final initial = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(
          forensicRecoveryAttempted: true,
          forensicGuidance: 'Focus on test coverage.',
        ),
      );

      store.write(initial);
      final loaded = store.read();

      expect(loaded.forensicRecoveryAttempted, isTrue);
      expect(loaded.forensicGuidance, 'Focus on test coverage.');
    });

    test('forensic fields default on fresh state read', () {
      final store = StateStore(statePath);
      store.write(ProjectState.initial());
      final loaded = store.read();

      expect(loaded.forensicRecoveryAttempted, isFalse);
      expect(loaded.forensicGuidance, isNull);
    });
  });

  group('ForensicDiagnosis toJson', () {
    test('produces valid serializable output with all actions', () {
      for (final action in ForensicAction.values) {
        final diagnosis = ForensicDiagnosis(
          classification: ForensicClassification.unknown,
          evidence: ['test evidence'],
          suggestedAction: action,
          guidanceText: action == ForensicAction.retryWithGuidance
              ? 'Some guidance.'
              : null,
        );

        final json = diagnosis.toJson();

        expect(json['suggested_action'], action.name);
        expect(jsonEncode(json), isNotEmpty);
      }
    });

    test('toJson includes guidance_text when present', () {
      final diagnosis = ForensicDiagnosis(
        classification: ForensicClassification.specTooLarge,
        evidence: ['Required file count: 8'],
        suggestedAction: ForensicAction.redecompose,
        guidanceText: 'Decompose the task.',
      );

      final json = diagnosis.toJson();

      expect(json['guidance_text'], 'Decompose the task.');
    });

    test('toJson omits guidance_text when null', () {
      final diagnosis = ForensicDiagnosis(
        classification: ForensicClassification.policyConflict,
        evidence: ['Policy violation'],
        suggestedAction: ForensicAction.block,
      );

      final json = diagnosis.toJson();

      expect(json.containsKey('guidance_text'), isFalse);
    });
  });

  group('Forensic guidance clearing on task change', () {
    late Directory temp;
    late String statePath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('forensic_clear_');
      statePath = '${temp.path}/STATE.json';
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('forensic fields can be cleared via copyWith', () {
      final store = StateStore(statePath);
      final stateWithForensics = ProjectState.initial().copyWith(
        activeTask: ActiveTaskState(
          id: 'task-123',
          title: 'My Task',
          forensicRecoveryAttempted: true,
          forensicGuidance: 'Some guidance text.',
        ),
      );
      store.write(stateWithForensics);

      // Simulate task change: clear active task and forensic fields.
      final state = store.read();
      store.write(
        state.copyWith(
          activeTask: ActiveTaskState(),
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );

      final cleared = store.read();

      expect(cleared.activeTaskId, isNull);
      expect(cleared.activeTaskTitle, isNull);
      expect(cleared.forensicRecoveryAttempted, isFalse);
      expect(cleared.forensicGuidance, isNull);
    });
  });

  group('Forensic classification priorities', () {
    late TaskForensicsService service;

    setUp(() {
      service = TaskForensicsService();
    });

    test('policy_conflict takes priority over all others', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        requiredFileCount: 10,
        errorKinds: ['diff_budget_exceeded', 'quality_gate_failed'],
      );

      expect(diagnosis.classification, ForensicClassification.policyConflict);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('persistent_test_failure takes priority over spec_too_large', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        requiredFileCount: 10,
        errorKinds: ['quality_gate_failed'],
      );

      expect(
        diagnosis.classification,
        ForensicClassification.persistentTestFailure,
      );
    });

    test('spec_too_large takes priority over unknown', () {
      final diagnosis = service.diagnose(
        '/nonexistent',
        taskTitle: 'My Task',
        retryCount: 3,
        requiredFileCount: 8,
      );

      expect(diagnosis.classification, ForensicClassification.specTooLarge);
    });
  });
}

/// Writes run-log entries to the standard run-log path.
void _writeRunLog(String projectRoot, List<Map<String, Object?>> entries) {
  final path = '$projectRoot/.genaisys/RUN_LOG.jsonl';
  final buffer = StringBuffer();
  for (final entry in entries) {
    buffer.writeln(jsonEncode(entry));
  }
  AtomicFileWrite.writeStringSync(path, buffer.toString());
}

/// Creates a review_reject event for the run-log.
Map<String, Object?> _reviewRejectEvent({
  required String note,
  required String task,
}) {
  return {
    'event': 'review_reject',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'message': 'Review rejected',
    'data': {'note': note, 'task': task, 'decision': 'reject'},
  };
}
