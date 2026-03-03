import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';
import 'package:genaisys/core/storage/atomic_file_write.dart';

void main() {
  late ErrorPatternRegistryService service;

  setUp(() {
    service = ErrorPatternRegistryService();
  });

  group('formatForPrompt', () {
    late Directory temp;
    late String projectRoot;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('error_pattern_inject_');
      projectRoot = temp.path;
      Directory('$projectRoot/.genaisys/audit').createSync(recursive: true);
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('returns empty string for empty registry', () {
      final result = service.formatForPrompt(projectRoot);

      expect(result, isEmpty);
    });

    test('returns empty string when registry file does not exist', () {
      final result = service.formatForPrompt(projectRoot);

      expect(result, isEmpty);
    });

    test('produces readable markdown for single pattern', () {
      _writeRegistry(projectRoot, [
        {
          'error_kind': 'diff_budget_exceeded',
          'count': 5,
          'last_seen': '2026-01-01T00:00:00Z',
          'resolution_strategy': null,
          'auto_resolved_count': 0,
        },
      ]);

      final result = service.formatForPrompt(projectRoot);

      expect(result, contains('`diff_budget_exceeded`'));
      expect(result, contains('5 occurrences'));
      expect(result, contains('No known resolution'));
    });

    test('includes resolution strategy when available', () {
      _writeRegistry(projectRoot, [
        {
          'error_kind': 'review_rejected',
          'count': 12,
          'last_seen': '2026-01-01T00:00:00Z',
          'resolution_strategy': 'Ensure all required files are touched.',
          'auto_resolved_count': 2,
        },
      ]);

      final result = service.formatForPrompt(projectRoot);

      expect(result, contains('`review_rejected`'));
      expect(result, contains('12 occurrences'));
      expect(result, contains('Ensure all required files are touched.'));
    });

    test('sorts by count descending', () {
      _writeRegistry(projectRoot, [
        {
          'error_kind': 'low_count_error',
          'count': 2,
          'last_seen': '2026-01-01T00:00:00Z',
        },
        {
          'error_kind': 'high_count_error',
          'count': 20,
          'last_seen': '2026-01-01T00:00:00Z',
        },
        {
          'error_kind': 'medium_count_error',
          'count': 8,
          'last_seen': '2026-01-01T00:00:00Z',
        },
      ]);

      final result = service.formatForPrompt(projectRoot);

      final highIndex = result.indexOf('high_count_error');
      final mediumIndex = result.indexOf('medium_count_error');
      final lowIndex = result.indexOf('low_count_error');

      expect(highIndex, lessThan(mediumIndex));
      expect(mediumIndex, lessThan(lowIndex));
    });

    test('respects maxEntries limit', () {
      _writeRegistry(projectRoot, [
        for (var i = 0; i < 10; i++)
          {
            'error_kind': 'error_$i',
            'count': 10 - i,
            'last_seen': '2026-01-01T00:00:00Z',
          },
      ]);

      final result = service.formatForPrompt(projectRoot, maxEntries: 3);

      expect(result, contains('error_0'));
      expect(result, contains('error_1'));
      expect(result, contains('error_2'));
      expect(result, isNot(contains('error_3')));
    });

    test('respects maxChars limit', () {
      _writeRegistry(projectRoot, [
        for (var i = 0; i < 20; i++)
          {
            'error_kind': 'error_kind_with_a_long_name_$i',
            'count': 100 - i,
            'last_seen': '2026-01-01T00:00:00Z',
            'resolution_strategy':
                'This is a long resolution strategy text '
                'that should contribute to exceeding the character limit.',
          },
      ]);

      final result = service.formatForPrompt(projectRoot, maxChars: 200);

      expect(result.length, lessThanOrEqualTo(200));
    });
  });

  group('config parsing for pipeline injection settings', () {
    test('default config enables error pattern injection', () {
      final config = _loadConfigFromString('');

      expect(config.pipelineErrorPatternInjectionEnabled, isTrue);
    });

    test('config can disable error pattern injection', () {
      final config = _loadConfigFromString('''
pipeline:
  error_pattern_injection_enabled: false
''');

      expect(config.pipelineErrorPatternInjectionEnabled, isFalse);
    });

    test('config can enable error pattern injection explicitly', () {
      final config = _loadConfigFromString('''
pipeline:
  error_pattern_injection_enabled: true
''');

      expect(config.pipelineErrorPatternInjectionEnabled, isTrue);
    });

    test('default config enables impact analysis', () {
      final config = _loadConfigFromString('');

      expect(config.pipelineImpactAnalysisEnabled, isTrue);
    });

    test('config can disable impact analysis', () {
      final config = _loadConfigFromString('''
pipeline:
  impact_analysis_enabled: false
''');

      expect(config.pipelineImpactAnalysisEnabled, isFalse);
    });
  });

  group('review reject registry update', () {
    late Directory temp;
    late String projectRoot;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('error_pattern_reject_');
      projectRoot = temp.path;
      Directory('$projectRoot/.genaisys/audit').createSync(recursive: true);
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('mergeObservations increments count for review_rejected', () {
      service.mergeObservations(
        projectRoot,
        errorKindCounts: {'review_rejected': 1},
      );

      final entries = service.load(projectRoot);

      expect(entries, hasLength(1));
      expect(entries.first.errorKind, 'review_rejected');
      expect(entries.first.count, 1);
    });

    test('mergeObservations increments existing count', () {
      _writeRegistry(projectRoot, [
        {
          'error_kind': 'review_rejected',
          'count': 5,
          'last_seen': '2026-01-01T00:00:00Z',
        },
      ]);

      service.mergeObservations(
        projectRoot,
        errorKindCounts: {'review_rejected': 1},
      );

      final entries = service.load(projectRoot);
      final found = entries.firstWhere((e) => e.errorKind == 'review_rejected');

      expect(found.count, 6);
    });

    test('mergeObservations with specific error_kind', () {
      service.mergeObservations(
        projectRoot,
        errorKindCounts: {'diff_budget_exceeded': 1},
      );

      final entries = service.load(projectRoot);

      expect(entries, hasLength(1));
      expect(entries.first.errorKind, 'diff_budget_exceeded');
      expect(entries.first.count, 1);
    });
  });
}

/// Writes registry entries to the standard error pattern registry path.
void _writeRegistry(String projectRoot, List<Map<String, Object?>> entries) {
  final path = '$projectRoot/.genaisys/audit/error_patterns.json';
  final parent = File(path).parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  AtomicFileWrite.writeStringSync(path, jsonEncode(entries));
}

/// Loads a ProjectConfig from a YAML string, using the real parser.
ProjectConfig _loadConfigFromString(String yamlContent) {
  final temp = Directory.systemTemp.createTempSync('config_parse_');
  try {
    final configFile = File('${temp.path}/config.yml');
    configFile.writeAsStringSync(yamlContent);
    return ProjectConfig.loadFromFile(configFile.path);
  } finally {
    temp.deleteSync(recursive: true);
  }
}
