// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/config/config_field_descriptor.dart';
import 'package:genaisys/core/config/config_field_registry.dart';
import 'package:genaisys/core/config/config_registry_service.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('config_registry_test');
    Directory('${root.path}/.genaisys').createSync(recursive: true);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  void writeConfig(String content) {
    File('${root.path}/.genaisys/config.yml').writeAsStringSync(content);
  }

  String readConfig() =>
      File('${root.path}/.genaisys/config.yml').readAsStringSync();

  final service = ConfigRegistryService();

  group('readValues', () {
    test('covers every registered field', () {
      writeConfig('project:\n  name: "demo"\n');

      final values = service.readValues(root.path);

      expect(values.length, configFieldRegistry.length);
      for (final field in configFieldRegistry) {
        expect(
          values.containsKey(field.qualifiedKey),
          isTrue,
          reason: '${field.qualifiedKey} must be readable',
        );
      }
    });

    test('falls back to the descriptor default for absent keys', () {
      writeConfig('project:\n  name: "demo"\n');

      final values = service.readValues(root.path);

      for (final field in configFieldRegistry) {
        expect(
          values[field.qualifiedKey],
          field.defaultValue,
          reason: '${field.qualifiedKey} should fall back to its default',
        );
      }
    });

    test('reads nested section paths', () {
      writeConfig('''
policies:
  diff_budget:
    max_files: 42
''');

      expect(
        service.readValues(root.path)['policies.diff_budget.max_files'],
        42,
      );
    });

    test('returns defaults when the config file is missing entirely', () {
      final values = service.readValues(root.path);

      expect(values.length, configFieldRegistry.length);
      expect(
        values['policies.diff_budget.max_files'],
        service.descriptorFor('policies.diff_budget.max_files')!.defaultValue,
      );
    });

    test(
      'falls back to the default when a stored value has the wrong type',
      () {
        writeConfig('''
policies:
  diff_budget:
    max_files: "not a number"
''');

        final descriptor = service.descriptorFor(
          'policies.diff_budget.max_files',
        )!;
        expect(
          service.readValues(root.path)['policies.diff_budget.max_files'],
          descriptor.defaultValue,
        );
      },
    );

    test('survives a corrupt config file rather than throwing', () {
      writeConfig('this: is: not: valid: yaml:\n  - [');

      expect(service.readValues(root.path).length, configFieldRegistry.length);
    });
  });

  group('validate', () {
    test('rejects an unknown key', () {
      final error = service.validate('nope.not_a_key', 1);

      expect(error, isNotNull);
      expect(error!.kind, ConfigValueErrorKind.unknownKey);
    });

    test('rejects a value below the declared minimum', () {
      final error = service.validate('policies.diff_budget.max_files', 0);

      expect(error, isNotNull);
      expect(error!.kind, ConfigValueErrorKind.belowMinimum);
    });

    test('rejects a value outside validValues', () {
      final error = service.validate(
        'policies.shell_allowlist_profile',
        'wide-open',
      );

      expect(error, isNotNull);
      expect(error!.kind, ConfigValueErrorKind.notInValidValues);
    });

    test('accepts a value inside validValues', () {
      expect(
        service.validate('policies.shell_allowlist_profile', 'minimal'),
        isNull,
      );
    });

    test('rejects the wrong type', () {
      final error = service.validate(
        'policies.diff_budget.max_files',
        'twelve',
      );

      expect(error, isNotNull);
      expect(error!.kind, ConfigValueErrorKind.wrongType);
    });

    test('rejects null on a non-nullable field', () {
      final error = service.validate('policies.diff_budget.max_files', null);

      expect(error, isNotNull);
      expect(error!.kind, ConfigValueErrorKind.notNullable);
    });

    test('accepts null on a nullable field', () {
      final nullable = configFieldRegistry.firstWhere((f) => f.nullable);

      expect(service.validate(nullable.qualifiedKey, null), isNull);
    });

    test('every registered default passes its own validation', () {
      for (final field in configFieldRegistry) {
        expect(
          service.validate(field.qualifiedKey, field.defaultValue),
          isNull,
          reason:
              '${field.qualifiedKey} has a default that its own constraints '
              'reject',
        );
      }
    });
  });

  group('writeValues', () {
    test('writes a nested value and reads it back', () {
      writeConfig('project:\n  name: "demo"\n');

      final changed = service.writeValues(root.path, {
        'policies.diff_budget.max_files': 7,
      });

      expect(changed, {'policies.diff_budget.max_files'});
      expect(
        service.readValues(root.path)['policies.diff_budget.max_files'],
        7,
      );
    });

    test('preserves comments and unrelated keys', () {
      writeConfig('''
# Keep me
project:
  name: "demo" # trailing note
policies:
  diff_budget:
    max_files: 3
''');

      service.writeValues(root.path, {'policies.diff_budget.max_files': 9});

      final raw = readConfig();
      expect(raw, contains('# Keep me'));
      expect(raw, contains('# trailing note'));
      expect(raw, contains('name: "demo"'));
      expect(raw, contains('max_files: 9'));
    });

    test('creates missing intermediate sections', () {
      writeConfig('project:\n  name: "demo"\n');

      service.writeValues(root.path, {
        'policies.diff_budget.max_additions': 500,
      });

      expect(
        service.readValues(root.path)['policies.diff_budget.max_additions'],
        500,
      );
    });

    test('is atomic: one invalid value rejects the whole batch', () {
      writeConfig('''
policies:
  diff_budget:
    max_files: 3
''');
      final before = readConfig();

      expect(
        () => service.writeValues(root.path, {
          'policies.diff_budget.max_files': 11,
          'policies.diff_budget.max_additions': -5,
        }),
        throwsA(isA<ConfigValidationException>()),
      );

      expect(
        readConfig(),
        before,
        reason: 'A rejected batch must not touch the file',
      );
    });

    test('reports every invalid value, not just the first', () {
      writeConfig('project:\n  name: "demo"\n');

      try {
        service.writeValues(root.path, {
          'policies.diff_budget.max_files': -1,
          'policies.diff_budget.max_additions': -2,
        });
        fail('Expected ConfigValidationException');
      } on ConfigValidationException catch (e) {
        expect(e.errors.length, 2);
      }
    });

    test('returns an empty set when nothing actually changes', () {
      writeConfig('''
policies:
  diff_budget:
    max_files: 5
''');

      final changed = service.writeValues(root.path, {
        'policies.diff_budget.max_files': 5,
      });

      expect(changed, isEmpty);
    });

    test('throws when there is no config file to edit', () {
      expect(
        () => service.writeValues(root.path, {
          'policies.diff_budget.max_files': 5,
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('round-trips a value for every registered field', () {
      writeConfig('project:\n  name: "demo"\n');

      for (final field in configFieldRegistry) {
        final probe = _probeValueFor(field);
        if (probe == null) {
          continue;
        }
        service.writeValues(root.path, {field.qualifiedKey: probe});
        expect(
          service.readValues(root.path)[field.qualifiedKey],
          probe,
          reason: '${field.qualifiedKey} did not round-trip',
        );
      }
    });
  });

  group('resetToDefaults', () {
    test('restores the descriptor default', () {
      writeConfig('''
policies:
  diff_budget:
    max_files: 99
''');
      final descriptor = service.descriptorFor(
        'policies.diff_budget.max_files',
      )!;

      service.resetToDefaults(root.path, ['policies.diff_budget.max_files']);

      expect(
        service.readValues(root.path)['policies.diff_budget.max_files'],
        descriptor.defaultValue,
      );
    });

    test('rejects an unknown key', () {
      writeConfig('project:\n  name: "demo"\n');

      expect(
        () => service.resetToDefaults(root.path, ['nope.not_a_key']),
        throwsA(isA<ConfigValidationException>()),
      );
    });
  });

  group('modifiedKeys', () {
    test('is empty for a config that only holds defaults', () {
      writeConfig('project:\n  name: "demo"\n');

      expect(service.modifiedKeys(root.path), isEmpty);
    });

    test('reports exactly the keys that differ from their default', () {
      final descriptor = service.descriptorFor(
        'policies.diff_budget.max_files',
      )!;
      final changed = (descriptor.defaultValue! as int) + 1;
      writeConfig('''
policies:
  diff_budget:
    max_files: $changed
''');

      expect(service.modifiedKeys(root.path), {
        'policies.diff_budget.max_files',
      });
    });
  });

  group('sections', () {
    test('are unique and in registry order', () {
      final sections = service.sections;

      expect(sections.toSet().length, sections.length);
      expect(sections.first, configFieldRegistry.first.section);
    });
  });
}

/// A valid, non-default probe value for a descriptor, or `null` when no safe
/// probe exists (e.g. a bounded range with a single legal value).
Object? _probeValueFor(ConfigFieldDescriptor field) {
  switch (field.type) {
    case ConfigFieldType.bool_:
      return !(field.defaultValue as bool? ?? false);
    case ConfigFieldType.string_:
      final allowed = field.validValues;
      if (allowed == null) {
        return 'probe-value';
      }
      return allowed.firstWhere(
        (v) => v != field.defaultValue,
        orElse: () => allowed.first,
      );
    case ConfigFieldType.int_:
    case ConfigFieldType.duration:
      final base = (field.defaultValue as int?) ?? 1;
      final candidate = base + 1;
      final max = field.maxValue;
      if (max != null && candidate > max) {
        return null;
      }
      return candidate;
    case ConfigFieldType.double_:
      final base = (field.defaultValue as num?)?.toDouble() ?? 1.0;
      final candidate = base + 0.5;
      final max = field.maxValue;
      if (max != null && candidate > max) {
        return null;
      }
      return candidate;
  }
}
