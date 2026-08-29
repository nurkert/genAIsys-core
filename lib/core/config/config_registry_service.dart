// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../project_layout.dart';
import 'config_field_descriptor.dart';
import 'config_field_registry.dart';

/// Why a value was rejected. Machine-readable so callers can map it to a
/// message without string matching.
enum ConfigValueErrorKind {
  unknownKey,
  wrongType,
  notNullable,
  belowMinimum,
  aboveMaximum,
  notInValidValues,
}

/// A single rejected value.
class ConfigValueError {
  const ConfigValueError({
    required this.qualifiedKey,
    required this.kind,
    required this.message,
  });

  final String qualifiedKey;
  final ConfigValueErrorKind kind;
  final String message;

  @override
  String toString() => '$qualifiedKey: $message';
}

/// Thrown when a write is rejected. The write is all-or-nothing, so the config
/// file is untouched when this is thrown.
class ConfigValidationException implements Exception {
  const ConfigValidationException(this.errors);

  final List<ConfigValueError> errors;

  @override
  String toString() =>
      'ConfigValidationException: ${errors.map((e) => e.toString()).join('; ')}';
}

/// Generic, registry-driven read/write access to every scalar config key.
///
/// The typed [ProjectConfig] path requires a hand-written field, parser entry,
/// and DTO member per key, so consumers such as the GUI could only ever reach
/// the subset somebody had plumbed through. This service instead drives
/// everything off [configFieldRegistry]: a new [ConfigFieldDescriptor] is
/// immediately readable, validatable, and writable by every consumer.
///
/// Writes go through [YamlEditor], so comments and formatting in `config.yml`
/// survive an edit.
class ConfigRegistryService {
  ConfigRegistryService({List<ConfigFieldDescriptor>? fields})
    : fields = fields ?? configFieldRegistry;

  /// Every scalar config field, in registry order.
  final List<ConfigFieldDescriptor> fields;

  /// Section paths in registry order, without duplicates.
  List<String> get sections {
    final seen = <String>{};
    final ordered = <String>[];
    for (final field in fields) {
      if (seen.add(field.section)) {
        ordered.add(field.section);
      }
    }
    return ordered;
  }

  ConfigFieldDescriptor? descriptorFor(String qualifiedKey) {
    for (final field in fields) {
      if (field.qualifiedKey == qualifiedKey) {
        return field;
      }
    }
    return null;
  }

  /// Current value of every registered key, falling back to the descriptor
  /// default when the key is absent from `config.yml`.
  ///
  /// A missing or unparseable config file yields the full set of defaults
  /// rather than an error: callers rendering a settings surface need a complete
  /// map, and an absent file legitimately means "everything is default".
  Map<String, Object?> readValues(String projectRoot) {
    final document = _readDocument(projectRoot);
    final values = <String, Object?>{};
    for (final field in fields) {
      final raw = _readAt(document, _pathOf(field));
      values[field.qualifiedKey] = raw == null
          ? field.defaultValue
          : _coerce(field, raw) ?? field.defaultValue;
    }
    return values;
  }

  /// Whether the project actually has a config file to read and write.
  ///
  /// [readValues] deliberately falls back to defaults for a missing file, which
  /// is right for a caller that just wants effective values. A caller offering
  /// an *editor* needs to know the difference: there is nothing to write to.
  bool hasConfigFile(String projectRoot) =>
      File(ProjectLayout(projectRoot).configPath).existsSync();

  /// Keys whose current value differs from the descriptor default.
  Set<String> modifiedKeys(String projectRoot) {
    final values = readValues(projectRoot);
    final modified = <String>{};
    for (final field in fields) {
      if (values[field.qualifiedKey] != field.defaultValue) {
        modified.add(field.qualifiedKey);
      }
    }
    return modified;
  }

  /// Validates one value against its descriptor. Returns `null` when valid.
  ConfigValueError? validate(String qualifiedKey, Object? value) {
    final field = descriptorFor(qualifiedKey);
    if (field == null) {
      return ConfigValueError(
        qualifiedKey: qualifiedKey,
        kind: ConfigValueErrorKind.unknownKey,
        message: 'Unknown config key.',
      );
    }

    if (value == null) {
      if (field.nullable) {
        return null;
      }
      return ConfigValueError(
        qualifiedKey: qualifiedKey,
        kind: ConfigValueErrorKind.notNullable,
        message: 'This setting cannot be empty.',
      );
    }

    switch (field.type) {
      case ConfigFieldType.bool_:
        if (value is! bool) {
          return _typeError(qualifiedKey, 'a true/false value');
        }
      case ConfigFieldType.string_:
        if (value is! String) {
          return _typeError(qualifiedKey, 'text');
        }
        final allowed = field.validValues;
        if (allowed != null && !allowed.contains(value)) {
          return ConfigValueError(
            qualifiedKey: qualifiedKey,
            kind: ConfigValueErrorKind.notInValidValues,
            message: 'Must be one of: ${allowed.join(', ')}.',
          );
        }
      case ConfigFieldType.int_:
      case ConfigFieldType.duration:
        if (value is! int) {
          return _typeError(qualifiedKey, 'a whole number');
        }
        return _rangeError(field, value);
      case ConfigFieldType.double_:
        if (value is! num) {
          return _typeError(qualifiedKey, 'a number');
        }
        return _rangeError(field, value);
    }
    return null;
  }

  /// Applies [changes] to `config.yml`, keyed by qualified key.
  ///
  /// Fail-closed and atomic: every value is validated first, and a single
  /// invalid value rejects the whole batch without touching the file. Values
  /// equal to the descriptor default are still written, so the file states the
  /// user's intent explicitly rather than relying on an implicit fallback.
  ///
  /// Returns the keys that were actually changed on disk.
  Set<String> writeValues(String projectRoot, Map<String, Object?> changes) {
    final errors = <ConfigValueError>[];
    for (final entry in changes.entries) {
      final error = validate(entry.key, entry.value);
      if (error != null) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) {
      throw ConfigValidationException(errors);
    }

    final layout = ProjectLayout(projectRoot);
    final file = File(layout.configPath);
    if (!file.existsSync()) {
      throw StateError('No config file at ${layout.configPath}');
    }

    final current = readValues(projectRoot);
    final effective = <String, Object?>{};
    for (final entry in changes.entries) {
      if (current[entry.key] != entry.value) {
        effective[entry.key] = entry.value;
      }
    }
    if (effective.isEmpty) {
      return const <String>{};
    }

    final editor = YamlEditor(file.readAsStringSync());
    for (final entry in effective.entries) {
      final field = descriptorFor(entry.key)!;
      _upsert(editor, _pathOf(field), entry.value);
    }

    final updated = editor.toString();
    file.writeAsStringSync(updated.endsWith('\n') ? updated : '$updated\n');
    return effective.keys.toSet();
  }

  /// Restores [qualifiedKeys] to their descriptor defaults.
  Set<String> resetToDefaults(
    String projectRoot,
    Iterable<String> qualifiedKeys,
  ) {
    final changes = <String, Object?>{};
    for (final key in qualifiedKeys) {
      final field = descriptorFor(key);
      if (field == null) {
        throw ConfigValidationException([
          ConfigValueError(
            qualifiedKey: key,
            kind: ConfigValueErrorKind.unknownKey,
            message: 'Unknown config key.',
          ),
        ]);
      }
      changes[key] = field.defaultValue;
    }
    return writeValues(projectRoot, changes);
  }

  // ── internals ────────────────────────────────────────────────────────────

  ConfigValueError _typeError(String qualifiedKey, String expected) {
    return ConfigValueError(
      qualifiedKey: qualifiedKey,
      kind: ConfigValueErrorKind.wrongType,
      message: 'Expected $expected.',
    );
  }

  ConfigValueError? _rangeError(ConfigFieldDescriptor field, num value) {
    final min = field.minValue;
    if (min != null && value < min) {
      return ConfigValueError(
        qualifiedKey: field.qualifiedKey,
        kind: ConfigValueErrorKind.belowMinimum,
        message: 'Must be at least $min.',
      );
    }
    final max = field.maxValue;
    if (max != null && value > max) {
      return ConfigValueError(
        qualifiedKey: field.qualifiedKey,
        kind: ConfigValueErrorKind.aboveMaximum,
        message: 'Must be at most $max.',
      );
    }
    return null;
  }

  List<Object> _pathOf(ConfigFieldDescriptor field) {
    return <Object>[...field.section.split('.'), field.yamlKey];
  }

  Object? _readDocument(String projectRoot) {
    final file = File(ProjectLayout(projectRoot).configPath);
    if (!file.existsSync()) {
      return null;
    }
    try {
      return loadYaml(file.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  Object? _readAt(Object? document, List<Object> path) {
    var node = document;
    for (final segment in path) {
      if (node is! Map) {
        return null;
      }
      if (!node.containsKey(segment)) {
        return null;
      }
      node = node[segment];
    }
    return node;
  }

  /// Narrows a raw YAML scalar to the descriptor's type. Returns `null` when
  /// the stored value does not fit, so the caller falls back to the default
  /// instead of surfacing a corrupt value.
  Object? _coerce(ConfigFieldDescriptor field, Object raw) {
    switch (field.type) {
      case ConfigFieldType.bool_:
        return raw is bool ? raw : null;
      case ConfigFieldType.string_:
        return raw is String ? raw : null;
      case ConfigFieldType.int_:
      case ConfigFieldType.duration:
        if (raw is int) {
          return raw;
        }
        return raw is num ? raw.toInt() : null;
      case ConfigFieldType.double_:
        return raw is num ? raw.toDouble() : null;
    }
  }

  void _upsert(YamlEditor editor, List<Object> path, Object? value) {
    _ensureMapPath(editor, path.sublist(0, path.length - 1));
    editor.update(path, value);
  }

  void _ensureMapPath(YamlEditor editor, List<Object> path) {
    final current = <Object>[];
    for (final segment in path) {
      current.add(segment);
      YamlNode? node;
      try {
        node = editor.parseAt(current);
      } catch (_) {
        node = null;
      }
      if (node is YamlMap) {
        continue;
      }
      editor.update(current, <String, Object?>{});
    }
  }
}
