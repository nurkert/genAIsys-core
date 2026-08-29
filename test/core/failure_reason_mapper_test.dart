import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/errors/failure_reason_mapper.dart';

void main() {
  group('FailureReasonMapper', () {
    test('maps preflight schema errors', () {
      final reason = FailureReasonMapper.normalize(
        errorClass: 'preflight',
        errorKind: 'state_schema',
      );

      expect(reason.errorClass, 'preflight');
      expect(reason.errorKind, 'state_schema');
    });

    test('maps provider failures', () {
      final reason = FailureReasonMapper.normalize(errorKind: 'provider_quota');

      expect(reason.errorClass, 'provider');
      expect(reason.errorKind, 'provider_quota');
    });

    test('maps quality gate failures', () {
      final reason = FailureReasonMapper.normalize(
        event: 'quality_gate_reject',
        message: 'Policy violation: quality_gate command failed: dart analyze',
      );

      expect(reason.errorClass, 'quality_gate');
      expect(reason.errorKind, 'analyze_failed');
    });

    test('maps review gate failures', () {
      final reason = FailureReasonMapper.normalize(
        errorKind: 'review_rejected',
      );

      expect(reason.errorClass, 'review');
      expect(reason.errorKind, 'review_rejected');
    });

    test('maps git delivery failures', () {
      final reason = FailureReasonMapper.normalize(errorKind: 'git_dirty');

      expect(reason.errorClass, 'delivery');
      expect(reason.errorKind, 'git_dirty');
    });

    test('maps locking/concurrency failures', () {
      final reason = FailureReasonMapper.normalize(errorKind: 'lock_held');

      expect(reason.errorClass, 'locking');
      expect(reason.errorKind, 'lock_held');
    });

    test('maps safe_write_scope failures', () {
      final reason = FailureReasonMapper.normalize(
        message:
            'Policy violation: safe_write_scope blocked "lib/core/x.dart".',
      );

      expect(reason.errorClass, 'policy');
      expect(reason.errorKind, 'safe_write_scope');
    });

    test('falls back to unknown for unmapped inputs', () {
      final reason = FailureReasonMapper.normalize(
        message: 'Totally opaque failure with no known marker.',
      );

      expect(reason.errorClass, 'unknown');
      expect(reason.errorKind, 'unknown');
    });
  });
}
