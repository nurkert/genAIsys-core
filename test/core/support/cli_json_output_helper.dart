import 'dart:convert';

/// Extracts the first valid JSON object/line from CLI output.
///
/// Some environments prepend toolchain log text (for example build-hook logs)
/// before the JSON payload. This helper keeps JSON contract tests stable by
/// locating and validating the first decodable JSON segment.
String firstJsonPayload(String output) {
  for (final String rawLine in output.split('\n')) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final int jsonStart = line.indexOf('{');
    if (jsonStart < 0) {
      continue;
    }

    final String candidate = line.substring(jsonStart).trim();
    if (candidate.isEmpty) {
      continue;
    }

    try {
      final Object? decoded = jsonDecode(candidate);
      if (decoded is Map || decoded is List) {
        return candidate;
      }
    } on FormatException {
      // Ignore non-JSON fragments and keep scanning.
    }
  }
  return '';
}
