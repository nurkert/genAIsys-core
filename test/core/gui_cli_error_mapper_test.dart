import 'package:test/test.dart';

import 'package:genaisys/core/cli/gui_cli_error_mapper.dart';
import 'package:genaisys/core/cli/models/cli_models.dart';

void main() {
  test('mapCliError maps known CLI error codes', () {
    expect(
      mapCliError(CliErrorResponse(code: 'unknown_command', message: 'x')),
      GuiCliErrorKind.unknownCommand,
    );
    expect(
      mapCliError(CliErrorResponse(code: 'missing_subcommand', message: 'x')),
      GuiCliErrorKind.missingSubcommand,
    );
    expect(
      mapCliError(CliErrorResponse(code: 'unknown_decision', message: 'x')),
      GuiCliErrorKind.unknownDecision,
    );
    expect(
      mapCliError(CliErrorResponse(code: 'missing_prompt', message: 'x')),
      GuiCliErrorKind.missingPrompt,
    );
    expect(
      mapCliError(CliErrorResponse(code: 'state_error', message: 'x')),
      GuiCliErrorKind.stateError,
    );
  });

  test('mapCliError falls back to unknown for null or unrecognized code', () {
    expect(mapCliError(null), GuiCliErrorKind.unknown);
    expect(
      mapCliError(CliErrorResponse(code: 'something_else', message: 'x')),
      GuiCliErrorKind.unknown,
    );
  });
}
