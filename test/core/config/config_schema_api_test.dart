// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/app/shared/config_schema_mapper.dart';
import 'package:genaisys/core/config/config_field_registry.dart';

void main() {
  group('ConfigSchemaMapper.humanize', () {
    const mapper = ConfigSchemaMapper();

    test('turns a snake_case key into sentence case', () {
      expect(mapper.humanize('max_task_retries'), 'Max task retries');
    });

    test('keeps acronyms upper case wherever they appear', () {
      expect(mapper.humanize('hitl'), 'HITL');
      expect(mapper.humanize('lock_ttl_seconds'), 'Lock TTL seconds');
      expect(mapper.humanize('priority_weight_p1'), 'Priority weight P1');
    });

    test('leaves a single plain word capitalised', () {
      expect(mapper.humanize('enabled'), 'Enabled');
    });
  });

  group('ConfigSchemaMapper.controlFor', () {
    const mapper = ConfigSchemaMapper();

    test('assigns a control to every registered field', () {
      for (final descriptor in configFieldRegistry) {
        expect(
          () => mapper.controlFor(descriptor),
          returnsNormally,
          reason: '${descriptor.qualifiedKey} has no control mapping',
        );
      }
    });

    test('a string field with validValues becomes a choice', () {
      final descriptor = configFieldRegistry.firstWhere(
        (f) => f.validValues != null,
      );

      expect(mapper.controlFor(descriptor), ConfigFieldControl.choice);
    });
  });

  group('getConfigSchema', () {
    late Directory root;
    late InProcessGenaisysApi api;

    setUp(() {
      root = Directory.systemTemp.createTempSync('config_schema_api_test');
      Directory('${root.path}/.genaisys').createSync(recursive: true);
      File(
        '${root.path}/.genaisys/config.yml',
      ).writeAsStringSync('project:\n  name: "demo"\n');
      api = InProcessGenaisysApi();
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('exposes every registered config key', () async {
      final result = await api.getConfigSchema(root.path);

      expect(result.ok, isTrue, reason: result.error?.message);
      expect(result.data!.fieldCount, configFieldRegistry.length);
    });

    test(
      'exposes strictly more keys than the legacy typed config DTO',
      () async {
        // The point of the schema API: the hand-maintained AppConfigDto could
        // only ever surface the subset somebody had plumbed through.
        final schema = (await api.getConfigSchema(root.path)).data!;

        expect(schema.fieldCount, greaterThan(100));
      },
    );

    test('groups fields into sections with human-readable labels', () async {
      final schema = (await api.getConfigSchema(root.path)).data!;

      final diffBudget = schema.sections.firstWhere(
        (s) => s.path == 'policies.diff_budget',
      );
      expect(diffBudget.label, 'Diff budget');
      expect(diffBudget.group, 'Policies');
      expect(diffBudget.fields, isNotEmpty);
    });

    test('reports nothing as modified for a defaults-only config', () async {
      final schema = (await api.getConfigSchema(root.path)).data!;

      expect(schema.modifiedCount, 0);
    });

    test('marks a changed key as modified', () async {
      await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': 12},
      );

      final schema = (await api.getConfigSchema(root.path)).data!;
      final field = schema.fieldFor('policies.diff_budget.max_files')!;

      expect(field.value, 12);
      expect(field.isModified, isTrue);
      expect(schema.modifiedCount, 1);
    });
  });

  group('setConfigValues', () {
    late Directory root;
    late InProcessGenaisysApi api;

    setUp(() {
      root = Directory.systemTemp.createTempSync('config_set_api_test');
      Directory('${root.path}/.genaisys').createSync(recursive: true);
      File(
        '${root.path}/.genaisys/config.yml',
      ).writeAsStringSync('project:\n  name: "demo"\n');
      api = InProcessGenaisysApi();
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('reports which keys actually changed', () async {
      final result = await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': 12},
      );

      expect(result.ok, isTrue, reason: result.error?.message);
      expect(result.data!.changedKeys, {'policies.diff_budget.max_files'});
    });

    test('returns an invalid-input error instead of throwing', () async {
      final result = await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': -1},
      );

      expect(result.ok, isFalse);
      expect(result.error!.kind, AppErrorKind.invalidInput);
    });

    test('leaves the file untouched when a value is rejected', () async {
      final file = File('${root.path}/.genaisys/config.yml');
      final before = file.readAsStringSync();

      await api.setConfigValues(
        root.path,
        values: {
          'policies.diff_budget.max_files': 5,
          'policies.diff_budget.max_additions': -1,
        },
      );

      expect(file.readAsStringSync(), before);
    });

    test('writes run-log evidence for an applied change', () async {
      await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': 12},
      );

      final runLog = File('${root.path}/.genaisys/RUN_LOG.jsonl');
      expect(runLog.existsSync(), isTrue);
      final contents = runLog.readAsStringSync();
      expect(contents, contains('config_updated'));
      expect(contents, contains('policies.diff_budget.max_files'));
    });

    test('writes no run-log entry when nothing changed', () async {
      final descriptor = configFieldRegistry.firstWhere(
        (f) => f.qualifiedKey == 'policies.diff_budget.max_files',
      );

      final result = await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': descriptor.defaultValue},
      );

      expect(result.data!.changedAnything, isFalse);
      expect(
        File('${root.path}/.genaisys/RUN_LOG.jsonl').existsSync(),
        isFalse,
      );
    });
  });

  group('resetConfigValues', () {
    late Directory root;
    late InProcessGenaisysApi api;

    setUp(() {
      root = Directory.systemTemp.createTempSync('config_reset_api_test');
      Directory('${root.path}/.genaisys').createSync(recursive: true);
      File(
        '${root.path}/.genaisys/config.yml',
      ).writeAsStringSync('project:\n  name: "demo"\n');
      api = InProcessGenaisysApi();
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('restores a key to its default', () async {
      await api.setConfigValues(
        root.path,
        values: {'policies.diff_budget.max_files': 12},
      );

      final result = await api.resetConfigValues(
        root.path,
        qualifiedKeys: ['policies.diff_budget.max_files'],
      );

      expect(result.ok, isTrue, reason: result.error?.message);
      final schema = (await api.getConfigSchema(root.path)).data!;
      expect(
        schema.fieldFor('policies.diff_budget.max_files')!.isModified,
        isFalse,
      );
    });

    test('rejects an unknown key as invalid input', () async {
      final result = await api.resetConfigValues(
        root.path,
        qualifiedKeys: ['nope.not_a_key'],
      );

      expect(result.ok, isFalse);
      expect(result.error!.kind, AppErrorKind.invalidInput);
    });
  });
}
