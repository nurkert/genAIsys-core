// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../security/redaction_service.dart';

enum AppErrorKind {
  invalidInput,
  preconditionFailed,
  notFound,
  conflict,
  policyViolation,
  ioFailure,
  unknown,
}

class AppError {
  AppError({
    required this.code,
    required String message,
    required this.kind,
    this.cause,
    this.stackTrace,
  }) : message = _redactionService.sanitizeText(message).value;

  final String code;
  final String message;
  final AppErrorKind kind;
  final Object? cause;
  final StackTrace? stackTrace;

  static final RedactionService _redactionService = RedactionService.shared;

  static AppError invalidInput(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'invalid_input',
      message: message,
      kind: AppErrorKind.invalidInput,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError preconditionFailed(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'precondition_failed',
      message: message,
      kind: AppErrorKind.preconditionFailed,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError notFound(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'not_found',
      message: message,
      kind: AppErrorKind.notFound,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError conflict(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'conflict',
      message: message,
      kind: AppErrorKind.conflict,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError policyViolation(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'policy_violation',
      message: message,
      kind: AppErrorKind.policyViolation,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError ioFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'io_failure',
      message: message,
      kind: AppErrorKind.ioFailure,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static AppError unknown(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'unknown_error',
      message: message,
      kind: AppErrorKind.unknown,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}
