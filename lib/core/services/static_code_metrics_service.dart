// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';
import 'dart:math' as math;

import '../models/code_health_models.dart';

/// Layer 1: Fast, deterministic, per-file static analysis.
///
/// Extracts approximate complexity metrics from Dart source files using
/// regex-based heuristics. No LLM involvement.
class StaticCodeMetricsService {
  /// Analyze the given files and return per-file metrics.
  ///
  /// Files that don't exist or can't be read are silently skipped.
  List<FileHealthSnapshot> analyze(
    String projectRoot,
    List<String> filePaths,
  ) {
    final snapshots = <FileHealthSnapshot>[];
    for (final relativePath in filePaths) {
      final fullPath = relativePath.startsWith('/')
          ? relativePath
          : '$projectRoot${Platform.pathSeparator}$relativePath';
      final file = File(fullPath);
      if (!file.existsSync()) continue;

      List<String> lines;
      try {
        lines = file.readAsLinesSync();
      } catch (_) {
        continue;
      }

      snapshots.add(_analyzeFile(relativePath, lines));
    }
    return snapshots;
  }

  /// Evaluate metrics against thresholds, returning signals for violations.
  List<CodeHealthSignal> evaluate(
    List<FileHealthSnapshot> metrics, {
    int maxFileLines = 500,
    int maxMethodLines = 80,
    int maxNestingDepth = 5,
    int maxParameterCount = 6,
  }) {
    final signals = <CodeHealthSignal>[];
    for (final m in metrics) {
      if (m.lineCount > maxFileLines) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.static,
          confidence: _overshootConfidence(m.lineCount, maxFileLines),
          finding: '${m.filePath} has ${m.lineCount} lines '
              '(threshold: $maxFileLines)',
          affectedFiles: [m.filePath],
          suggestedAction: 'Consider splitting into smaller modules',
        ));
      }
      if (m.maxMethodLines > maxMethodLines) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.static,
          confidence: _overshootConfidence(m.maxMethodLines, maxMethodLines),
          finding: '${m.filePath} has a method with ${m.maxMethodLines} lines '
              '(threshold: $maxMethodLines)',
          affectedFiles: [m.filePath],
          suggestedAction: 'Extract method into smaller helper functions',
        ));
      }
      if (m.maxNestingDepth > maxNestingDepth) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.static,
          confidence: _overshootConfidence(m.maxNestingDepth, maxNestingDepth),
          finding: '${m.filePath} has nesting depth ${m.maxNestingDepth} '
              '(threshold: $maxNestingDepth)',
          affectedFiles: [m.filePath],
          suggestedAction: 'Reduce nesting with early returns or extraction',
        ));
      }
      if (m.maxParameterCount > maxParameterCount) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.static,
          confidence:
              _overshootConfidence(m.maxParameterCount, maxParameterCount),
          finding:
              '${m.filePath} has a method with ${m.maxParameterCount} parameters '
              '(threshold: $maxParameterCount)',
          affectedFiles: [m.filePath],
          suggestedAction: 'Consider grouping parameters into a data class',
        ));
      }
    }
    return signals;
  }

  /// Confidence proportional to overshoot: 2x over threshold → 1.0.
  static double _overshootConfidence(int actual, int threshold) {
    if (threshold <= 0) return 1.0;
    return math.min(1.0, actual / (threshold * 2));
  }

  FileHealthSnapshot _analyzeFile(String filePath, List<String> lines) {
    final lineCount = lines.length;
    final methods = _extractMethods(lines);
    final methodCount = methods.length;
    var maxMethodLines = 0;
    var maxNestingDepth = 0;
    var maxParameterCount = 0;

    for (final method in methods) {
      if (method.lineCount > maxMethodLines) {
        maxMethodLines = method.lineCount;
      }
      if (method.maxNestingDepth > maxNestingDepth) {
        maxNestingDepth = method.maxNestingDepth;
      }
      if (method.parameterCount > maxParameterCount) {
        maxParameterCount = method.parameterCount;
      }
    }

    return FileHealthSnapshot(
      filePath: filePath,
      lineCount: lineCount,
      maxMethodLines: maxMethodLines,
      maxNestingDepth: maxNestingDepth,
      maxParameterCount: maxParameterCount,
      methodCount: methodCount,
    );
  }

  /// Scan for Dart function/method declarations and extract metrics.
  List<_MethodInfo> _extractMethods(List<String> lines) {
    final methods = <_MethodInfo>[];
    // Match Dart function/method declarations (approximate).
    // Covers: returnType name(params) { or name(params) async {
    final methodPattern = RegExp(
      r'^\s*(?:static\s+)?'
      r'(?:Future<[^>]*>|Stream<[^>]*>|[A-Za-z_]\w*(?:<[^>]*>)?(?:\?)?)\s+'
      r'(?:get\s+)?'
      r'([A-Za-z_]\w*)\s*'
      r'\(',
    );
    // Also match constructors: ClassName( or ClassName.named(
    final constructorPattern = RegExp(
      r'^\s*(?:const\s+)?([A-Z]\w*(?:\.\w+)?)\s*\(',
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (methodPattern.hasMatch(line) ||
          constructorPattern.hasMatch(line)) {
        // Find the opening brace.
        final braceStart = _findOpeningBrace(lines, i);
        if (braceStart < 0) continue;

        // Find the matching closing brace.
        final braceEnd = _findMatchingCloseBrace(lines, braceStart);
        if (braceEnd < 0) continue;

        final methodLines = braceEnd - i + 1;
        final nesting = _maxBraceDepth(lines, braceStart, braceEnd);
        final params = _countParameters(lines, i);

        methods.add(_MethodInfo(
          lineCount: methodLines,
          maxNestingDepth: nesting,
          parameterCount: params,
        ));

        // Skip past this method to avoid double-counting inner methods.
        // But don't skip to allow nested class methods to be found.
      }
    }
    return methods;
  }

  /// Find the line containing the opening `{` for a method starting at [startLine].
  int _findOpeningBrace(List<String> lines, int startLine) {
    for (var i = startLine; i < lines.length && i < startLine + 20; i++) {
      if (lines[i].contains('{')) return i;
      // Arrow functions (=>) don't have braces — skip them.
      if (lines[i].contains('=>')) return -1;
    }
    return -1;
  }

  /// Find the line of the matching `}` for an opening `{` on [startLine].
  int _findMatchingCloseBrace(List<String> lines, int startLine) {
    var depth = 0;
    for (var i = startLine; i < lines.length; i++) {
      final line = _stripStringsAndComments(lines[i]);
      for (var c = 0; c < line.length; c++) {
        if (line[c] == '{') depth++;
        if (line[c] == '}') {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }

  /// Maximum brace nesting depth within a method body.
  int _maxBraceDepth(List<String> lines, int startLine, int endLine) {
    var depth = 0;
    var maxDepth = 0;
    for (var i = startLine; i <= endLine && i < lines.length; i++) {
      final line = _stripStringsAndComments(lines[i]);
      for (var c = 0; c < line.length; c++) {
        if (line[c] == '{') {
          depth++;
          if (depth > maxDepth) maxDepth = depth;
        }
        if (line[c] == '}') depth--;
      }
    }
    // Subtract 1 for the method's own braces.
    return math.max(0, maxDepth - 1);
  }

  /// Count parameters for a method declaration starting at [startLine].
  int _countParameters(List<String> lines, int startLine) {
    // Collect text from the opening `(` to the matching `)`.
    final buffer = StringBuffer();
    var started = false;
    var depth = 0;
    for (var i = startLine; i < lines.length && i < startLine + 20; i++) {
      for (var c = 0; c < lines[i].length; c++) {
        final ch = lines[i][c];
        if (ch == '(') {
          depth++;
          if (!started) {
            started = true;
            continue; // Don't include the opening paren.
          }
        }
        if (ch == ')') {
          depth--;
          if (depth == 0 && started) {
            final params = buffer.toString().trim();
            if (params.isEmpty) return 0;
            // Count commas at depth 0 within the param string.
            return _countTopLevelCommas(params) + 1;
          }
        }
        if (started && depth >= 1) {
          buffer.write(ch);
        }
      }
      if (started) buffer.write(' ');
    }
    return 0;
  }

  /// Count commas not inside nested parens/brackets/braces.
  int _countTopLevelCommas(String text) {
    var depth = 0;
    var commas = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '(' || ch == '[' || ch == '{' || ch == '<') depth++;
      if (ch == ')' || ch == ']' || ch == '}' || ch == '>') depth--;
      if (ch == ',' && depth == 0) commas++;
    }
    return commas;
  }

  /// Strip string literals and comments from a line to avoid false brace matches.
  static String _stripStringsAndComments(String line) {
    // Remove line comments.
    final commentIdx = line.indexOf('//');
    var result = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
    // Remove string literals (simple approximation).
    result = result.replaceAll(RegExp(r"'[^']*'"), '""');
    result = result.replaceAll(RegExp(r'"[^"]*"'), '""');
    return result;
  }
}

class _MethodInfo {
  const _MethodInfo({
    required this.lineCount,
    required this.maxNestingDepth,
    required this.parameterCount,
  });

  final int lineCount;
  final int maxNestingDepth;
  final int parameterCount;
}
