import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/contracts/app_error.dart';
import 'package:genaisys/core/app/shared/app_error_mapper.dart';
import 'package:genaisys/core/errors/operation_errors.dart';

void main() {
  test('mapToAppError maps ValidationError to invalid_input', () {
    final error = ValidationError('Bad input');

    final mapped = mapToAppError(error, StackTrace.current);

    expect(mapped.kind, AppErrorKind.invalidInput);
    expect(mapped.code, 'invalid_input');
  });

  test('mapToAppError maps NotFoundError to not_found', () {
    final error = NotFoundError('Missing task');

    final mapped = mapToAppError(error, StackTrace.current);

    expect(mapped.kind, AppErrorKind.notFound);
    expect(mapped.code, 'not_found');
  });

  test('mapToAppError maps ConflictError to conflict', () {
    final error = ConflictError('Task already exists');

    final mapped = mapToAppError(error, StackTrace.current);

    expect(mapped.kind, AppErrorKind.conflict);
    expect(mapped.code, 'conflict');
  });

  test('mapToAppError maps PolicyViolationError to policy_violation', () {
    final error = PolicyViolationError('Policy violation');

    final mapped = mapToAppError(error, StackTrace.current);

    expect(mapped.kind, AppErrorKind.policyViolation);
    expect(mapped.code, 'policy_violation');
  });

  test('mapToAppError maps TransientError to io_failure', () {
    final error = TransientError('Temporary IO issue');

    final mapped = mapToAppError(error, StackTrace.current);

    expect(mapped.kind, AppErrorKind.ioFailure);
    expect(mapped.code, 'io_failure');
  });
}
