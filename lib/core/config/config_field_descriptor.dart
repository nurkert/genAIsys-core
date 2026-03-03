// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Describes the type of a config field for parsing and validation.
enum ConfigFieldType {
  bool_,
  int_,
  double_,
  string_,
  duration,
}

/// Unit for [ConfigFieldType.duration] fields.
enum DurationUnit { seconds, minutes, hours }

/// Declarative description of a single config field.
///
/// Every scalar config key that follows the simple `section.yaml_key: value`
/// pattern can be described by one [ConfigFieldDescriptor]. Complex fields
/// (provider pools, agent profiles, list-based fields) remain in their
/// specialised parsers.
class ConfigFieldDescriptor {
  const ConfigFieldDescriptor({
    required this.section,
    required this.yamlKey,
    required this.dartFieldName,
    required this.type,
    required this.defaultValue,
    this.durationUnit = DurationUnit.seconds,
    this.validValues,
    this.minValue,
    this.maxValue,
    this.nullable = false,
    this.deprecated = false,
    this.description,
  });

  /// Dotted section path in the YAML config, e.g. `'autopilot'`,
  /// `'policies.diff_budget'`, `'review'`.
  final String section;

  /// The key name as it appears in the YAML file, e.g. `'max_task_retries'`.
  final String yamlKey;

  /// The corresponding field name on [ProjectConfig],
  /// e.g. `'autopilotMaxTaskRetries'`.
  final String dartFieldName;

  /// The value type for parsing and validation.
  final ConfigFieldType type;

  /// Default value. `null` only when [nullable] is `true`.
  final Object? defaultValue;

  /// Unit for [ConfigFieldType.duration] fields.
  final DurationUnit durationUnit;

  /// Allowed string values (e.g. `['low', 'medium', 'high']`).
  /// Only applicable to [ConfigFieldType.string_] fields.
  final List<String>? validValues;

  /// Minimum numeric value (inclusive). For int/double/duration fields.
  final num? minValue;

  /// Maximum numeric value (inclusive). For int/double fields.
  final num? maxValue;

  /// Whether the field can be `null` on [ProjectConfig].
  final bool nullable;

  /// Whether the field is deprecated (warn on use).
  final bool deprecated;

  /// Human-readable description of the field.
  final String? description;

  /// Compound key: `'autopilot.max_task_retries'`.
  String get qualifiedKey => '$section.$yamlKey';
}
