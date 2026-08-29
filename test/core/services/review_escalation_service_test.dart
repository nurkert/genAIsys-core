import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/services/review_escalation_service.dart';

void main() {
  late ReviewEscalationService service;

  setUp(() {
    service = ReviewEscalationService();
  });

  group('computeReviewMode', () {
    test('retry 0 returns fullReview with empty contractNotes', () {
      final decision = service.computeReviewMode(
        retryCount: 0,
        contractLockEnabled: true,
        previousRejectNotes: ['Issue A', 'Issue B'],
      );
      expect(decision.mode, ReviewMode.fullReview);
      expect(decision.contractNotes, isEmpty);
    });

    test('retry 1 with rejectNotes returns verificationReview', () {
      final notes = ['Missing null check in foo()', 'No test for edge case'];
      final decision = service.computeReviewMode(
        retryCount: 1,
        contractLockEnabled: true,
        previousRejectNotes: notes,
      );
      expect(decision.mode, ReviewMode.verificationReview);
      expect(decision.contractNotes, notes);
    });

    test('retry 2+ with rejectNotes returns verificationReview', () {
      final notes = ['Remaining issue'];
      final decision = service.computeReviewMode(
        retryCount: 3,
        contractLockEnabled: true,
        previousRejectNotes: notes,
      );
      expect(decision.mode, ReviewMode.verificationReview);
      expect(decision.contractNotes, notes);
    });

    test('contractLock disabled always returns fullReview', () {
      final decision = service.computeReviewMode(
        retryCount: 5,
        contractLockEnabled: false,
        previousRejectNotes: ['Issue A'],
      );
      expect(decision.mode, ReviewMode.fullReview);
      expect(decision.contractNotes, isEmpty);
    });

    test('retry 1 with empty rejectNotes returns fullReview', () {
      final decision = service.computeReviewMode(
        retryCount: 1,
        contractLockEnabled: true,
        previousRejectNotes: [],
      );
      expect(decision.mode, ReviewMode.fullReview);
      expect(decision.contractNotes, isEmpty);
    });

    test('contractNotes are unmodifiable', () {
      final notes = ['Issue A'];
      final decision = service.computeReviewMode(
        retryCount: 1,
        contractLockEnabled: true,
        previousRejectNotes: notes,
      );
      expect(
        () => (decision.contractNotes as List).add('sneaky'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('buildFollowUpTaskLine', () {
    test('returns correct P3 QA line for single advisory', () {
      final line = service.buildFollowUpTaskLine(
        'Fix login flow',
        ['Consider adding rate limiting'],
      );
      expect(line, contains('[P3] [QA]'));
      expect(line, contains('Fix login flow'));
      expect(line, contains('Consider adding rate limiting'));
      expect(line, startsWith('- [ ]'));
    });

    test('returns correct P3 QA line for multiple advisories', () {
      final line = service.buildFollowUpTaskLine(
        'Refactor auth',
        ['Note 1', 'Note 2', 'Note 3'],
      );
      expect(line, contains('[P3] [QA]'));
      expect(line, contains('Refactor auth'));
      expect(line, contains('3 advisory findings'));
    });

    test('returns null for empty advisoryNotes', () {
      final line = service.buildFollowUpTaskLine('Some task', []);
      expect(line, isNull);
    });
  });
}
