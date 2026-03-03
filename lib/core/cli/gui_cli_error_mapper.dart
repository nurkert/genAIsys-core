// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'models/cli_models.dart';

enum GuiCliErrorKind {
  unknownCommand,
  missingSubcommand,
  unknownDecision,
  missingPrompt,
  stateError,
  unknown,
}

GuiCliErrorKind mapCliError(CliErrorResponse? error) {
  final code = error?.code.trim();
  switch (code) {
    case 'unknown_command':
      return GuiCliErrorKind.unknownCommand;
    case 'missing_subcommand':
      return GuiCliErrorKind.missingSubcommand;
    case 'unknown_decision':
      return GuiCliErrorKind.unknownDecision;
    case 'missing_prompt':
      return GuiCliErrorKind.missingPrompt;
    case 'state_error':
      return GuiCliErrorKind.stateError;
    default:
      return GuiCliErrorKind.unknown;
  }
}
