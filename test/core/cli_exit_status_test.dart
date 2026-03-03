import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_exit_status.dart';

void main() {
  test('cliExitStatusFromCode maps known exit codes', () {
    expect(cliExitStatusFromCode(0), CliExitStatus.success);
    expect(cliExitStatusFromCode(2), CliExitStatus.stateError);
    expect(cliExitStatusFromCode(64), CliExitStatus.usageError);
  });

  test('cliExitStatusFromCode maps unknown exit codes', () {
    expect(cliExitStatusFromCode(1), CliExitStatus.unknownError);
    expect(cliExitStatusFromCode(127), CliExitStatus.unknownError);
  });
}
