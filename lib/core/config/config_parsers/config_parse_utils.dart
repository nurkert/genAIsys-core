// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class ConfigKeyValue {
  ConfigKeyValue(this.key, this.value);

  final String key;
  final String value;
}

int indentCount(String line) {
  var count = 0;
  while (count < line.length && line[count] == ' ') {
    count += 1;
  }
  return count;
}

ConfigKeyValue? parseKeyValue(String line) {
  final index = line.indexOf(':');
  if (index == -1) {
    return null;
  }
  final key = line.substring(0, index).trim();
  final value = line.substring(index + 1).trim();
  if (key.isEmpty) {
    return null;
  }
  return ConfigKeyValue(key, stripQuotes(value));
}

String stripQuotes(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

List<String> parseInlineList(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 2) {
    return const [];
  }
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
    return const [];
  }
  final inner = trimmed.substring(1, trimmed.length - 1).trim();
  if (inner.isEmpty) {
    return const [];
  }
  return inner
      .split(',')
      .map((entry) => stripQuotes(entry.trim()))
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

int parsePositiveIntOrFallback(String raw, {required int fallback}) {
  final value = int.tryParse(raw.trim());
  if (value == null || value < 1) {
    return fallback;
  }
  return value;
}

int parseNonNegativeIntOrFallback(String raw, {required int fallback}) {
  final value = int.tryParse(raw.trim());
  if (value == null || value < 0) {
    return fallback;
  }
  return value;
}

int? parseNullablePositiveIntOrFallback(String raw, {required int? fallback}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  final value = int.tryParse(trimmed);
  if (value == null || value < 1) {
    return fallback;
  }
  return value;
}

int parsePercentOrFallback(String raw, {required int fallback}) {
  final value = int.tryParse(raw.trim());
  if (value == null) {
    return fallback;
  }
  if (value < 0) {
    return fallback;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}
