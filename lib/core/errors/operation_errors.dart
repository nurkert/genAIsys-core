// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../security/redaction_service.dart';

class OperationError implements Exception {
  OperationError(String message, {this.cause, this.stackTrace})
    : message = _redactionService.sanitizeText(message).value;

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  static final RedactionService _redactionService = RedactionService.shared;

  @override
  String toString() => message;
}

class TransientError extends OperationError {
  TransientError(super.message, {super.cause, super.stackTrace});
}

class ValidationError extends OperationError {
  ValidationError(super.message, {super.cause, super.stackTrace});
}

class NotFoundError extends OperationError {
  NotFoundError(super.message, {super.cause, super.stackTrace});
}

class ConflictError extends OperationError {
  ConflictError(super.message, {super.cause, super.stackTrace});
}

class PolicyViolationError extends OperationError {
  PolicyViolationError(super.message, {super.cause, super.stackTrace});
}

class QuotaPauseError extends TransientError {
  QuotaPauseError(
    super.message, {
    required this.pauseFor,
    this.resumeAt,
    super.cause,
    super.stackTrace,
  });

  final Duration pauseFor;
  final DateTime? resumeAt;
}

class PermanentError extends OperationError {
  PermanentError(super.message, {super.cause, super.stackTrace});
}

OperationError classifyOperationError(Object error, StackTrace stackTrace) {
  if (error is OperationError) {
    return error;
  }

  if (error is FileSystemException ||
      error is ProcessException ||
      error is SocketException ||
      error is TimeoutException) {
    return TransientError(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (error is ArgumentError) {
    final message = (error.message ?? 'Invalid input.').toString();
    return ValidationError(message, cause: error, stackTrace: stackTrace);
  }

  if (error is StateError) {
    final message = error.message.toString();
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('policy violation')) {
      return PolicyViolationError(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (normalized.contains('not found')) {
      return NotFoundError(message, cause: error, stackTrace: stackTrace);
    }
    if (normalized.contains('not unique') ||
        normalized.contains('already done') ||
        normalized.contains('invalid workflow transition') ||
        normalized.contains('already exists')) {
      return ConflictError(message, cause: error, stackTrace: stackTrace);
    }
    if (_isTransientStateErrorMessage(message)) {
      return TransientError(message, cause: error, stackTrace: stackTrace);
    }
    // Unrecognized StateErrors remain permanent — the explicit transient
    // patterns above catch known-temporary git/state conditions.
    return PermanentError(message, cause: error, stackTrace: stackTrace);
  }

  return PermanentError(
    'Unexpected error: $error',
    cause: error,
    stackTrace: stackTrace,
  );
}

bool _isTransientStateErrorMessage(String message) {
  final normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  final hasTransportFailure =
      normalized.contains('unable to push') ||
      normalized.contains('unable to fetch') ||
      normalized.contains('unable to pull');
  if (hasTransportFailure) {
    if (_looksCredentialOrPermissionIssue(normalized)) {
      return false;
    }
    return true;
  }

  return normalized.contains('network is unreachable') ||
      normalized.contains('temporary failure in name resolution') ||
      normalized.contains('could not resolve host') ||
      normalized.contains('connection timed out') ||
      normalized.contains('connection reset') ||
      normalized.contains('remote end hung up unexpectedly') ||
      normalized.contains('tls handshake timeout') ||
      normalized.contains('autopilot is already running') ||
      normalized.contains('review agent failed') ||
      normalized.contains('review agent crashed') ||
      normalized.contains('no eligible provider configured') ||
      normalized.contains('failed to checkout') ||
      normalized.contains('failed to create branch') ||
      normalized.contains('cannot lock ref') ||
      normalized.contains('index.lock');
}

bool _looksCredentialOrPermissionIssue(String normalized) {
  return normalized.contains('authentication failed') ||
      normalized.contains('permission denied') ||
      normalized.contains('access denied') ||
      normalized.contains('repository not found') ||
      normalized.contains('could not read from remote repository') ||
      normalized.contains('remote rejected') ||
      normalized.contains('not authorized');
}

