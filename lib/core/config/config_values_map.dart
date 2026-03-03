// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'config_field_descriptor.dart';
import 'config_field_registry.dart';

/// Flat key-value store populated during config parsing.
///
/// Replaces the 230-line mutable [ConfigParserState] for registry-tracked
/// fields. Keys are qualified names (`'section.yaml_key'`), values are the
/// parsed Dart values.
class ConfigValuesMap {
  final _values = <String, Object?>{};
  final _explicitlySet = <String>{};

  /// Store a parsed value.
  void set(String qualifiedKey, Object? value) {
    _values[qualifiedKey] = value;
    _explicitlySet.add(qualifiedKey);
  }

  /// Whether the user explicitly set this key (vs. using the default).
  bool wasExplicitlySet(String qualifiedKey) =>
      _explicitlySet.contains(qualifiedKey);

  /// Apply preset values for keys not explicitly set by the user.
  ///
  /// Preset values sit between registry defaults and explicit YAML values
  /// in the layering order. They are stored in [_values] but NOT marked
  /// as explicitly set.
  void applyPreset(Map<String, Object> presetValues) {
    for (final entry in presetValues.entries) {
      if (!wasExplicitlySet(entry.key)) {
        _values[entry.key] = entry.value;
      }
    }
  }

  /// Get a typed value, falling back to the registry default.
  T get<T>(ConfigFieldDescriptor field) =>
      (_values[field.qualifiedKey] ?? field.defaultValue) as T;

  /// Nullable variant — returns `null` when neither set nor defaulted.
  T? getOrNull<T>(ConfigFieldDescriptor field) {
    final raw = _values[field.qualifiedKey] ?? field.defaultValue;
    return raw as T?;
  }

  int getInt(ConfigFieldDescriptor field) => get<int>(field);
  int? getIntOrNull(ConfigFieldDescriptor field) => getOrNull<int>(field);
  bool getBool(ConfigFieldDescriptor field) => get<bool>(field);
  String getString(ConfigFieldDescriptor field) => get<String>(field);
  double getDouble(ConfigFieldDescriptor field) => get<double>(field);

  Duration getDuration(ConfigFieldDescriptor field) {
    final raw = get<int>(field);
    switch (field.durationUnit) {
      case DurationUnit.seconds:
        return Duration(seconds: raw);
      case DurationUnit.minutes:
        return Duration(minutes: raw);
      case DurationUnit.hours:
        return Duration(hours: raw);
    }
  }
}

/// Parse a raw string value into the typed value described by [field] and
/// store it in [values].
///
/// Unknown keys (not in the registry) are silently ignored — the schema
/// validator catches them.
void parseRegistryKeyValue(
  ConfigValuesMap values,
  String section,
  String yamlKey,
  String rawValue,
) {
  final field = registryFieldByQualifiedKey('$section.$yamlKey');
  if (field == null) return;

  final parsed = _parseValue(field, rawValue);
  if (parsed != null || field.nullable) {
    values.set(field.qualifiedKey, parsed);
  }
}

Object? _parseValue(ConfigFieldDescriptor field, String raw) {
  switch (field.type) {
    case ConfigFieldType.bool_:
      return raw.toLowerCase() == 'true';

    case ConfigFieldType.int_:
    case ConfigFieldType.duration:
      // Duration fields store raw int seconds (or minutes/hours).
      if (field.nullable) {
        return _parseNullableInt(raw, minValue: field.minValue?.toInt());
      }
      return _parseInt(raw, field);

    case ConfigFieldType.double_:
      return _parseDouble(raw, field);

    case ConfigFieldType.string_:
      return _parseString(raw, field);
  }
}

int _parseInt(String raw, ConfigFieldDescriptor field) {
  final trimmed = raw.trim();
  final value = int.tryParse(trimmed);
  if (value == null) return field.defaultValue as int;

  final min = field.minValue?.toInt();
  if (min != null && value < min) return field.defaultValue as int;

  final max = field.maxValue?.toInt();
  if (max != null && value > max) {
    // Percent-style fields clamp to max.
    return max;
  }
  return value;
}

int? _parseNullableInt(String raw, {int? minValue}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null) return null;
  if (minValue != null && value < minValue) return null;
  return value;
}

double _parseDouble(String raw, ConfigFieldDescriptor field) {
  final value = double.tryParse(raw.trim());
  if (value == null) return field.defaultValue as double;

  final min = field.minValue?.toDouble();
  if (min != null && value < min) return field.defaultValue as double;

  final max = field.maxValue?.toDouble();
  if (max != null && value > max) return field.defaultValue as double;

  return value;
}

String _parseString(String raw, ConfigFieldDescriptor field) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return field.defaultValue as String;

  if (field.validValues != null) {
    final lower = trimmed.toLowerCase();
    if (field.validValues!.contains(lower)) return lower;
    return field.defaultValue as String;
  }
  return trimmed;
}
