// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../app/app.dart';

class CliAppErrorRoute {
  const CliAppErrorRoute({
    required this.jsonCode,
    required this.exitCode,
    required this.errorClass,
    required this.errorKind,
  });

  final String jsonCode;
  final int exitCode;
  final String errorClass;
  final String errorKind;
}

CliAppErrorRoute mapCliAppError(AppError? error) {
  return CliAppErrorRoute(
    jsonCode: 'state_error',
    exitCode: 2,
    errorClass: _mapErrorClass(error?.kind),
    errorKind: error?.code ?? 'unknown_error',
  );
}

String _mapErrorClass(AppErrorKind? kind) {
  switch (kind) {
    case AppErrorKind.invalidInput:
      return 'input';
    case AppErrorKind.preconditionFailed:
    case AppErrorKind.notFound:
      return 'state';
    case AppErrorKind.conflict:
      return 'conflict';
    case AppErrorKind.policyViolation:
      return 'policy';
    case AppErrorKind.ioFailure:
      return 'io';
    case AppErrorKind.unknown:
    case null:
      return 'unknown';
  }
}
