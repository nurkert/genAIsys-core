// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class TaskSlugger {
  /// Maximum slug length before the line-index suffix.
  ///
  /// Git branch names become `feat/<slug>-<lineIndex>`.  Filesystem path
  /// segments are capped at 255 bytes on most OSes, so we keep the slug
  /// short enough that the full ref path stays well within limits.
  static const int maxSlugLength = 60;

  static String slug(String input) {
    final cleaned = _stripAcceptance(input);
    final lower = cleaned.toLowerCase();
    final buffer = StringBuffer();
    var lastDash = false;
    for (final code in lower.runes) {
      final char = String.fromCharCode(code);
      final isAlphaNum = RegExp(r'[a-z0-9]').hasMatch(char);
      if (isAlphaNum) {
        buffer.write(char);
        lastDash = false;
      } else if (!lastDash) {
        buffer.write('-');
        lastDash = true;
      }
    }
    final raw = buffer.toString();
    var trimmed = raw
        .replaceAll(RegExp(r'^-+'), '')
        .replaceAll(RegExp(r'-+$'), '');
    if (trimmed.length > maxSlugLength) {
      trimmed = trimmed
          .substring(0, maxSlugLength)
          .replaceAll(RegExp(r'-+$'), '');
    }
    return trimmed.isEmpty ? 'task' : trimmed;
  }

  static String _stripAcceptance(String value) {
    return value.replaceAll(
      RegExp(
        r'\s*[|()]?\s*(?:AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]\s*.+$',
        caseSensitive: false,
      ),
      '',
    );
  }
}
