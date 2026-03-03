import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/shared/cli_app_error_mapper.dart';

void main() {
  test('mapCliAppError maps invalid input to input error class', () {
    final route = mapCliAppError(AppError.invalidInput('Bad flag'));

    expect(route.jsonCode, 'state_error');
    expect(route.exitCode, 2);
    expect(route.errorClass, 'input');
    expect(route.errorKind, 'invalid_input');
  });

  test('mapCliAppError maps policy violations to policy class', () {
    final route = mapCliAppError(AppError.policyViolation('Denied'));

    expect(route.jsonCode, 'state_error');
    expect(route.exitCode, 2);
    expect(route.errorClass, 'policy');
    expect(route.errorKind, 'policy_violation');
  });

  test('mapCliAppError maps null errors to unknown class', () {
    final route = mapCliAppError(null);

    expect(route.jsonCode, 'state_error');
    expect(route.exitCode, 2);
    expect(route.errorClass, 'unknown');
    expect(route.errorKind, 'unknown_error');
  });
}
