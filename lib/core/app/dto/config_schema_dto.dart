// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// The control a frontend should render for a setting.
///
/// Derived from the config field type plus its constraints, so the frontend
/// never has to re-derive presentation rules from raw types: a string with
/// `validValues` is a choice, a bool is a toggle, and so on.
enum ConfigFieldControl { toggle, number, duration, choice, text }

/// One setting, fully described for display and editing.
///
/// This mirrors `ConfigFieldDescriptor` across the app boundary so the UI layer
/// never imports core config internals, and so every registered key is
/// automatically presentable without per-key plumbing.
class ConfigFieldDto {
  const ConfigFieldDto({
    required this.qualifiedKey,
    required this.section,
    required this.yamlKey,
    required this.label,
    required this.control,
    required this.defaultValue,
    required this.value,
    required this.isModified,
    this.description,
    this.choices,
    this.minValue,
    this.maxValue,
    this.nullable = false,
    this.deprecated = false,
    this.durationUnit,
  });

  /// e.g. `autopilot.max_task_retries`.
  final String qualifiedKey;

  /// Dotted section path, e.g. `policies.diff_budget`.
  final String section;

  /// Raw key as written in `config.yml`.
  final String yamlKey;

  /// Human-readable name, e.g. `Max task retries`.
  final String label;

  /// Optional longer explanation of what the setting does.
  final String? description;

  final ConfigFieldControl control;

  /// Allowed values for [ConfigFieldControl.choice].
  final List<String>? choices;

  final num? minValue;
  final num? maxValue;
  final bool nullable;
  final bool deprecated;

  /// Unit name for duration fields, e.g. `seconds`.
  final String? durationUnit;

  final Object? defaultValue;

  /// Current effective value: what is in `config.yml`, or the default.
  final Object? value;

  /// Whether [value] differs from [defaultValue].
  final bool isModified;

  ConfigFieldDto copyWith({Object? value, bool? isModified}) {
    return ConfigFieldDto(
      qualifiedKey: qualifiedKey,
      section: section,
      yamlKey: yamlKey,
      label: label,
      description: description,
      control: control,
      choices: choices,
      minValue: minValue,
      maxValue: maxValue,
      nullable: nullable,
      deprecated: deprecated,
      durationUnit: durationUnit,
      defaultValue: defaultValue,
      value: value,
      isModified: isModified ?? this.isModified,
    );
  }
}

/// A group of settings that belong together, ready to render as one panel.
class ConfigSectionDto {
  const ConfigSectionDto({
    required this.path,
    required this.group,
    required this.label,
    required this.fields,
  });

  /// Dotted section path, e.g. `policies.diff_budget`.
  final String path;

  /// Top-level group this section belongs to, e.g. `Policies`. Sections that
  /// share a group are shown together under one navigation entry.
  final String group;

  /// Human-readable section name, e.g. `Diff budget`.
  final String label;

  final List<ConfigFieldDto> fields;

  /// Number of fields in this section that differ from their default.
  int get modifiedCount => fields.where((f) => f.isModified).length;
}

/// The complete, self-describing settings surface for a project.
class ConfigSchemaDto {
  const ConfigSchemaDto({required this.sections});

  final List<ConfigSectionDto> sections;

  Iterable<ConfigFieldDto> get allFields =>
      sections.expand((section) => section.fields);

  int get fieldCount => allFields.length;

  int get modifiedCount => allFields.where((f) => f.isModified).length;

  ConfigFieldDto? fieldFor(String qualifiedKey) {
    for (final field in allFields) {
      if (field.qualifiedKey == qualifiedKey) {
        return field;
      }
    }
    return null;
  }
}

/// Result of writing settings.
class ConfigWriteResultDto {
  const ConfigWriteResultDto({required this.changedKeys});

  /// Keys whose value actually changed on disk. Empty when the submitted
  /// values already matched what was stored.
  final Set<String> changedKeys;

  bool get changedAnything => changedKeys.isNotEmpty;
}
