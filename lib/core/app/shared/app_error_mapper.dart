// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../errors/operation_errors.dart';
import '../contracts/app_error.dart';

AppError mapToAppError(Object error, StackTrace stackTrace) {
  if (error is AppError) {
    return error;
  }

  final classified = classifyOperationError(error, stackTrace);

  if (classified is ValidationError) {
    return AppError.invalidInput(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (classified is NotFoundError) {
    return AppError.notFound(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (classified is ConflictError) {
    return AppError.conflict(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (classified is PolicyViolationError) {
    return AppError.policyViolation(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (classified is TransientError) {
    return AppError.ioFailure(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (classified is PermanentError) {
    return AppError.preconditionFailed(
      classified.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  return AppError.unknown(
    'Unexpected error: $error',
    cause: error,
    stackTrace: stackTrace,
  );
}
