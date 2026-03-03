// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/task.dart';
import 'schema_validator_base.dart';

/// Validates `.genaisys/TASKS.md` schema.
class TasksSchemaValidator extends SchemaValidatorBase {
  void validate(String path) {
    const artifact = '.genaisys/TASKS.md';
    final file = File(path);
    if (!file.existsSync()) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: r'$',
        message: 'file not found at $path.',
      );
    }

    final lines = file.readAsLinesSync();
    if (lines.isEmpty) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: r'$',
        message: 'file must not be empty.',
      );
    }

    final firstContentLine = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (firstContentLine == -1 || lines[firstContentLine].trim() != '# Tasks') {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: 'line:${firstContentLine + 1}',
        message: 'first content line must be "# Tasks".',
      );
    }

    var currentSection = 'Backlog';
    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      final trimmed = line.trim();
      final sectionMatch = RegExp(r'^##\s+(.+)$').firstMatch(trimmed);
      if (sectionMatch != null) {
        final name = sectionMatch.group(1)?.trim() ?? '';
        if (name.isEmpty) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'line:${i + 1}',
            message: 'section heading must include a non-empty name.',
          );
        }
        currentSection = name;
        continue;
      }

      if (!line.trimLeft().startsWith('- [')) {
        continue;
      }
      final parsed = Task.parseLine(
        line: line,
        section: currentSection,
        lineIndex: i,
      );
      if (parsed == null) {
        throw SchemaValidatorBase.schemaError(
          artifact: artifact,
          field: 'line:${i + 1}',
          message: 'task line does not match expected task format.',
        );
      }
      if (parsed.title.trim().isEmpty) {
        throw SchemaValidatorBase.schemaError(
          artifact: artifact,
          field: 'line:${i + 1}',
          message: 'task title must not be empty.',
        );
      }
    }
  }
}
