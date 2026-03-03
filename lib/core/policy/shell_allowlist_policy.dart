// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class ShellAllowlistPolicy {
  ShellAllowlistPolicy({required this.allowedPrefixes, this.enabled = true});

  final List<String> allowedPrefixes;
  final bool enabled;

  bool allows(String command) {
    if (!enabled) {
      return true;
    }
    final parsedCommand = ShellCommandTokenizer.tryParse(command);
    if (parsedCommand == null) {
      return false;
    }
    final commandTokens = parsedCommand.tokens;
    for (final prefix in allowedPrefixes) {
      final parsedPrefix = ShellCommandTokenizer.tryParse(prefix);
      if (parsedPrefix == null) {
        continue;
      }
      if (_isTokenPrefix(parsedPrefix.tokens, commandTokens)) {
        return true;
      }
    }
    return false;
  }

  bool _isTokenPrefix(List<String> prefix, List<String> candidate) {
    if (prefix.isEmpty || candidate.isEmpty) {
      return false;
    }
    if (prefix.length > candidate.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i += 1) {
      if (prefix[i] != candidate[i]) {
        return false;
      }
    }
    return true;
  }
}

class ParsedShellCommand {
  const ParsedShellCommand({required this.tokens});

  final List<String> tokens;

  String get executable => tokens.first;
  List<String> get arguments {
    if (tokens.length < 2) {
      return const [];
    }
    return tokens.sublist(1);
  }
}

class ShellCommandTokenizer {
  static ParsedShellCommand? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final tokens = <String>[];
    final buffer = StringBuffer();
    var inSingle = false;
    var inDouble = false;
    var escaping = false;

    void flushBuffer() {
      final value = buffer.toString();
      buffer.clear();
      if (value.isNotEmpty) {
        tokens.add(value);
      }
    }

    for (var i = 0; i < trimmed.length; i += 1) {
      final char = trimmed[i];
      if (escaping) {
        buffer.write(char);
        escaping = false;
        continue;
      }

      if (!inSingle && char == '\\') {
        escaping = true;
        continue;
      }

      if (!inSingle && char == '`') {
        return null;
      }

      if (!inSingle &&
          char == r'$' &&
          i + 1 < trimmed.length &&
          trimmed[i + 1] == '(') {
        return null;
      }

      if (!inDouble && char == '\'') {
        inSingle = !inSingle;
        continue;
      }

      if (!inSingle && char == '"') {
        inDouble = !inDouble;
        continue;
      }

      if (!inSingle && !inDouble) {
        if (char == '\n' || char == '\r') {
          return null;
        }
        if (_isDisallowedShellOperator(char)) {
          return null;
        }
        if (_isWhitespace(char)) {
          flushBuffer();
          continue;
        }
      }

      buffer.write(char);
    }

    if (escaping || inSingle || inDouble) {
      return null;
    }

    flushBuffer();
    if (tokens.isEmpty || tokens.first.trim().isEmpty) {
      return null;
    }
    return ParsedShellCommand(tokens: List<String>.unmodifiable(tokens));
  }

  static bool _isWhitespace(String char) =>
      char == ' ' || char == '\t' || char == '\n' || char == '\r';

  static bool _isDisallowedShellOperator(String char) {
    return char == ';' ||
        char == '&' ||
        char == '|' ||
        char == '<' ||
        char == '>';
  }
}
