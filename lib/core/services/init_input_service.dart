// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

enum InitInputType { plainText, pdf, stdin }

class InitInputResult {
  InitInputResult({
    required this.normalizedText,
    required this.sourcePayload,
    required this.type,
  });

  final String normalizedText;

  /// Raw path to the source file, or `'<stdin>'` for standard input.
  final String sourcePayload;

  final InitInputType type;
}

/// Normalizes various input sources (text, file, PDF, stdin) into a single
/// [InitInputResult] for use by the init orchestration pipeline.
class InitInputService {
  /// Wraps an inline [text] string.
  InitInputResult fromText(String text) {
    return InitInputResult(
      normalizedText: text,
      sourcePayload: '<inline>',
      type: InitInputType.plainText,
    );
  }

  /// Reads a plain-text or Markdown file at [path].
  InitInputResult fromFile(String path) {
    final text = File(path).readAsStringSync();
    return InitInputResult(
      normalizedText: text,
      sourcePayload: path,
      type: InitInputType.plainText,
    );
  }

  /// Extracts text from a PDF at [path] using `pdftotext`.
  ///
  /// Throws [StateError] if `pdftotext` is not found or returns a non-zero
  /// exit code.
  InitInputResult fromPdf(String path) {
    final ProcessResult result;
    try {
      result = Process.runSync('pdftotext', ['-layout', path, '-']);
    } on ProcessException catch (e) {
      throw StateError('pdftotext not found or failed: ${e.message}');
    }
    if (result.exitCode != 0) {
      final errText = (result.stderr as String).trim();
      throw StateError(
        'pdftotext not found or failed: exit ${result.exitCode}. $errText',
      );
    }
    return InitInputResult(
      normalizedText: result.stdout as String,
      sourcePayload: path,
      type: InitInputType.pdf,
    );
  }

  /// Reads all lines from stdin until EOF.
  InitInputResult fromStdin() {
    final lines = <String>[];
    String? line;
    while ((line = stdin.readLineSync()) != null) {
      lines.add(line!);
    }
    return InitInputResult(
      normalizedText: lines.join('\n'),
      sourcePayload: '<stdin>',
      type: InitInputType.stdin,
    );
  }

  /// Auto-detects the input type from [source]:
  /// - `null` → reads from stdin
  /// - ends with `.pdf` → PDF extraction via `pdftotext`
  /// - otherwise → plain file read
  InitInputResult autoDetect(String? source) {
    if (source == null) {
      return fromStdin();
    }
    if (source.toLowerCase().endsWith('.pdf')) {
      return fromPdf(source);
    }
    return fromFile(source);
  }
}
