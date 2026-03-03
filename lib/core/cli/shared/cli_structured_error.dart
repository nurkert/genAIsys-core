// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../security/redaction_service.dart';

/// Shared structured error for CLI diagnostic handlers.
///
/// All Phase 4 handlers use this class to emit machine-readable error
/// responses with actionable remediation hints.
class CliStructuredError {
  const CliStructuredError({
    required this.errorCode,
    required this.message,
    this.errorClass,
    this.errorKind,
    this.remediationHint,
  });

  final String errorCode;
  final String? errorClass;
  final String? errorKind;
  final String message;
  final String? remediationHint;

  Map<String, Object?> toJson() => <String, Object?>{
    'error_code': errorCode,
    'error_class': errorClass,
    'error_kind': errorKind,
    'message': message,
    'remediation_hint': remediationHint,
  };

  /// Writes a single JSON-line error to [out] with redaction.
  static void write(IOSink out, CliStructuredError error) {
    final raw = jsonEncode(error.toJson());
    final sanitized = RedactionService.shared.sanitizeText(raw).value;
    out.writeln(sanitized);
  }
}
