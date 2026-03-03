import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/services/task_management/task_forensics_service.dart';
import 'package:genaisys/core/storage/atomic_file_write.dart';

void main() {
  late TaskForensicsService service;

  setUp(() {
    service = TaskForensicsService();
  });

  group('diagnose', () {
    late Directory temp;
    late String projectRoot;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('task_forensics_');
      projectRoot = temp.path;
      Directory('$projectRoot/.genaisys').createSync(recursive: true);
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test(
      'classifies spec_too_large when required file count exceeds threshold',
      () {
        _writeRunLog(projectRoot, []);

        final diagnosis = service.diagnose(
          projectRoot,
          taskTitle: 'My Task',
          retryCount: 3,
          requiredFileCount: 8,
        );

        expect(diagnosis.classification, ForensicClassification.specTooLarge);
        expect(diagnosis.suggestedAction, ForensicAction.redecompose);
        expect(diagnosis.guidanceText, contains('8 files'));
        expect(diagnosis.evidence, isNotEmpty);
      },
    );

    test(
      'classifies spec_too_large when review notes mention scope keywords',
      () {
        _writeRunLog(projectRoot, [
          _reviewRejectEvent(
            note:
                'The change is too large — please break down into smaller tasks.',
            task: 'My Task',
          ),
        ]);

        final diagnosis = service.diagnose(
          projectRoot,
          taskTitle: 'My Task',
          retryCount: 3,
        );

        expect(diagnosis.classification, ForensicClassification.specTooLarge);
        expect(diagnosis.suggestedAction, ForensicAction.redecompose);
      },
    );

    test('classifies policy_conflict for diff_budget error kind', () {
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
        errorKinds: ['diff_budget_exceeded'],
      );

      expect(diagnosis.classification, ForensicClassification.policyConflict);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('classifies policy_conflict for safe_write_violation', () {
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
        errorKinds: ['safe_write_violation'],
      );

      expect(diagnosis.classification, ForensicClassification.policyConflict);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('classifies persistent_test_failure for quality_gate errors', () {
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
        errorKinds: ['quality_gate_failed'],
      );

      expect(
        diagnosis.classification,
        ForensicClassification.persistentTestFailure,
      );
      expect(diagnosis.suggestedAction, ForensicAction.retryWithGuidance);
      expect(diagnosis.guidanceText, contains('test'));
    });

    test('classifies spec_incorrect when notes mention wrong files', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note:
              'You changed the wrong file — the requirement targets a '
              'different module entirely.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.classification, ForensicClassification.specIncorrect);
      expect(diagnosis.suggestedAction, ForensicAction.regenerateSpec);
    });

    test('classifies coding_approach_wrong when notes mention strategy', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note:
              'This is the wrong approach — try a different strategy entirely.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(
        diagnosis.classification,
        ForensicClassification.codingApproachWrong,
      );
      expect(diagnosis.suggestedAction, ForensicAction.retryWithGuidance);
      expect(diagnosis.guidanceText, isNotNull);
    });

    test('classifies unknown when no patterns match', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note: 'The code has some issues that need to be fixed.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.classification, ForensicClassification.unknown);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('classifies unknown when run-log is empty', () {
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.classification, ForensicClassification.unknown);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('classifies unknown when run-log file does not exist', () {
      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.classification, ForensicClassification.unknown);
    });

    test('collects evidence from multiple reject notes', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note: 'First rejection — too many changes in scope here.',
          task: 'My Task',
        ),
        _reviewRejectEvent(
          note: 'Second rejection — still too large and complex.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(diagnosis.evidence, contains(contains('review-reject note')));
    });

    test('filters reject notes by task title', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note: 'This is the wrong approach — different strategy needed.',
          task: 'Other Task',
        ),
        _reviewRejectEvent(
          note: 'Minor formatting issue with the submitted code.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      // Should NOT classify as approach_wrong because that note belongs to
      // 'Other Task', not 'My Task'.
      expect(
        diagnosis.classification,
        isNot(ForensicClassification.codingApproachWrong),
      );
    });

    test('policy_conflict takes priority over spec_too_large', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(
          note: 'Too many changes — scope is too large for this task.',
          task: 'My Task',
        ),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
        requiredFileCount: 10,
        errorKinds: ['diff_budget_exceeded'],
      );

      // Policy conflict should win over spec_too_large.
      expect(diagnosis.classification, ForensicClassification.policyConflict);
    });

    test('ignores very short reject notes', () {
      _writeRunLog(projectRoot, [
        _reviewRejectEvent(note: 'Bad.', task: 'My Task'),
      ]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      // Short note should be ignored, leading to 'unknown'.
      expect(diagnosis.classification, ForensicClassification.unknown);
    });

    test('toJson produces valid serializable output', () {
      final diagnosis = ForensicDiagnosis(
        classification: ForensicClassification.specTooLarge,
        evidence: ['Required file count: 8', 'Retry count: 3'],
        suggestedAction: ForensicAction.redecompose,
        guidanceText: 'Decompose into smaller tasks.',
      );

      final json = diagnosis.toJson();

      expect(json['classification'], 'specTooLarge');
      expect(json['suggested_action'], 'redecompose');
      expect(json['evidence'], hasLength(2));
      expect(json['guidance_text'], 'Decompose into smaller tasks.');
      // Verify it serializes to JSON string without error.
      expect(jsonEncode(json), isNotEmpty);
    });

    test('collects error_kinds from run-log when not provided', () {
      _writeRunLog(projectRoot, [_eventWithErrorKind('quality_gate_failed')]);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(
        diagnosis.classification,
        ForensicClassification.persistentTestFailure,
      );
    });

    test('classifies alreadyCompleted for task marked done in TASKS.md', () {
      // Write a TASKS.md with the task already marked [x].
      AtomicFileWrite.writeStringSync(
        '$projectRoot/.genaisys/TASKS.md',
        '## Backlog\n'
        '- [x] [P1] [CORE] My Task\n'
        '- [ ] [P2] [UI] Other Task\n',
      );
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      expect(
        diagnosis.classification,
        ForensicClassification.alreadyCompleted,
      );
      expect(diagnosis.suggestedAction, ForensicAction.block);
      expect(
        diagnosis.evidence,
        contains(contains('already marked [x]')),
      );
    });

    test('returns normal classification for task NOT marked done', () {
      // Write a TASKS.md with the task still open.
      AtomicFileWrite.writeStringSync(
        '$projectRoot/.genaisys/TASKS.md',
        '## Backlog\n'
        '- [ ] [P1] [CORE] My Task\n'
        '- [x] [P2] [UI] Other Task\n',
      );
      _writeRunLog(projectRoot, []);

      final diagnosis = service.diagnose(
        projectRoot,
        taskTitle: 'My Task',
        retryCount: 3,
      );

      // Should NOT classify as alreadyCompleted; the task is still open.
      expect(
        diagnosis.classification,
        isNot(ForensicClassification.alreadyCompleted),
      );
      // With no reject notes, error kinds, or large file count, it should
      // fall through to unknown.
      expect(diagnosis.classification, ForensicClassification.unknown);
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

/// Creates a generic event with an error_kind in data.
Map<String, Object?> _eventWithErrorKind(String errorKind) {
  return {
    'event': 'quality_gate_reject',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'message': 'Quality gate failed',
    'data': {'error_kind': errorKind},
  };
}
