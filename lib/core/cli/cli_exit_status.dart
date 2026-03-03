// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum CliExitStatus { success, usageError, stateError, unknownError }

CliExitStatus cliExitStatusFromCode(int code) {
  switch (code) {
    case 0:
      return CliExitStatus.success;
    case 2:
      return CliExitStatus.stateError;
    case 64:
      return CliExitStatus.usageError;
    default:
      return CliExitStatus.unknownError;
  }
}
