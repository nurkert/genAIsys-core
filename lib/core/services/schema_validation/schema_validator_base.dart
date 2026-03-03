// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Shared utilities for schema validation across STATE, CONFIG, and TASKS
/// artifacts.
abstract class SchemaValidatorBase {
  String readRequiredFile(String path, {required String artifact}) {
    final file = File(path);
    if (!file.existsSync()) {
      throw schemaError(
        artifact: artifact,
        field: r'$',
        message: 'file not found at $path.',
      );
    }
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      throw schemaError(
        artifact: artifact,
        field: r'$',
        message: 'file must not be empty.',
      );
    }
    return content;
  }

  Object? decodeJson(String payload, {required String artifact}) {
    try {
      return jsonDecode(payload);
    } on FormatException catch (error) {
      throw schemaError(
        artifact: artifact,
        field: r'$',
        message: 'invalid JSON: ${error.message}.',
      );
    }
  }

  Object? decodeYaml(String payload, {required String artifact}) {
    try {
      return loadYaml(payload);
    } on YamlException catch (error) {
      throw schemaError(
        artifact: artifact,
        field: r'$',
        message: 'invalid YAML: ${error.message}.',
      );
    }
  }

  Map<String, Object?> asObjectMap(
    Object? value, {
    required String artifact,
    required String field,
  }) {
    if (value is! Map) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected object/map but found ${value.runtimeType}.',
      );
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final rawKey = entry.key;
      if (rawKey is! String || rawKey.trim().isEmpty) {
        throw schemaError(
          artifact: artifact,
          field: field,
          message: 'all keys must be non-empty strings.',
        );
      }
      result[rawKey] = entry.value;
    }
    return result;
  }

  List<Object?> asList(
    Object? value, {
    required String artifact,
    required String field,
  }) {
    if (value is! List) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected list but found ${value.runtimeType}.',
      );
    }
    return value.cast<Object?>();
  }

  void assertOnlyAllowedKeys(
    Map<String, Object?> data, {
    required Set<String> allowed,
    required String artifact,
    required String field,
  }) {
    for (final key in data.keys) {
      if (!allowed.contains(key)) {
        throw schemaError(
          artifact: artifact,
          field: field,
          message: 'unknown key "$key".',
        );
      }
    }
  }

  Map<String, Object?>? optionalMap(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
  }) {
    final value = data[key];
    if (value == null) {
      return null;
    }
    final field = parent == null ? key : '$parent.$key';
    return asObjectMap(value, artifact: artifact, field: field);
  }

  void requiredString(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
    bool iso8601 = false,
    Set<String>? allowed,
  }) {
    final field = parent == null ? key : '$parent.$key';
    final value = data[key];
    if (value == null) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'required value is missing.',
      );
    }
    validateStringValue(
      value,
      artifact: artifact,
      field: field,
      iso8601: iso8601,
      allowed: allowed,
    );
  }

  void optionalString(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
    bool iso8601 = false,
    Set<String>? allowed,
  }) {
    final value = data[key];
    if (value == null) {
      return;
    }
    final field = parent == null ? key : '$parent.$key';
    validateStringValue(
      value,
      artifact: artifact,
      field: field,
      iso8601: iso8601,
      allowed: allowed,
    );
  }

  void optionalMachineToken(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
  }) {
    final value = data[key];
    if (value == null) {
      return;
    }
    final field = parent == null ? key : '$parent.$key';
    validateStringValue(
      value,
      artifact: artifact,
      field: field,
      iso8601: false,
    );
    final normalized = value.toString().trim().toLowerCase();
    final valid = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!valid.hasMatch(normalized)) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message:
            'must be a machine token (lowercase snake_case, e.g. "preflight" or "git_dirty").',
      );
    }
  }

  void validateStringValue(
    Object? value, {
    required String artifact,
    required String field,
    required bool iso8601,
    Set<String>? allowed,
  }) {
    if (value is! String) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected string but found ${value.runtimeType}.',
      );
    }
    if (value.trim().isEmpty) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'must not be empty.',
      );
    }
    if (iso8601 && DateTime.tryParse(value.trim()) == null) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected ISO-8601 timestamp string.',
      );
    }
    if (allowed != null) {
      final normalized = value.trim().toLowerCase();
      if (!allowed.contains(normalized)) {
        throw schemaError(
          artifact: artifact,
          field: field,
          message:
              'unsupported value "$value"; allowed: ${allowed.join(', ')}.',
        );
      }
    }
  }

  void optionalInt(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
    int? minimum,
    int? maximum,
  }) {
    final value = data[key];
    if (value == null) {
      return;
    }
    final field = parent == null ? key : '$parent.$key';
    if (value is! int) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected integer but found ${value.runtimeType}.',
      );
    }
    if (minimum != null && value < minimum) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'must be >= $minimum.',
      );
    }
    if (maximum != null && value > maximum) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'must be <= $maximum.',
      );
    }
  }

  void optionalBool(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
  }) {
    final value = data[key];
    if (value == null) {
      return;
    }
    final field = parent == null ? key : '$parent.$key';
    if (value is! bool) {
      throw schemaError(
        artifact: artifact,
        field: field,
        message: 'expected boolean but found ${value.runtimeType}.',
      );
    }
  }

  void requireStringList(
    Object? value, {
    required String artifact,
    required String field,
  }) {
    final list = asList(value, artifact: artifact, field: field);
    for (var i = 0; i < list.length; i += 1) {
      final item = list[i];
      if (item is! String || item.trim().isEmpty) {
        throw schemaError(
          artifact: artifact,
          field: '$field[$i]',
          message: 'expected non-empty string.',
        );
      }
    }
  }

  static StateError schemaError({
    required String artifact,
    required String field,
    required String message,
  }) {
    return StateError(
      'Schema validation failed for $artifact at "$field": $message',
    );
  }
}
