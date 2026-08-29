import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/services/observability/architecture_health_service.dart';
import 'package:genaisys/core/services/import_graph_service.dart';
import 'package:genaisys/core/config/project_config.dart';

void main() {
  group('architecture gate config', () {
    test('default config has architecture gate enabled', () {
      final config = ProjectConfig.empty();

      expect(config.pipelineArchitectureGateEnabled, isTrue);
    });

    test('config parses architecture_gate_enabled: false', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_cfg_');
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/.genaisys').createSync();
      File('${temp.path}/.genaisys/config.yml').writeAsStringSync('''
pipeline:
  architecture_gate_enabled: false
''');
      File(
        '${temp.path}/.genaisys/STATE.json',
      ).writeAsStringSync('{"last_updated": "2025-01-01T00:00:00Z"}');
      File(
        '${temp.path}/.genaisys/TASKS.md',
      ).writeAsStringSync('# Tasks\n## Backlog\n- [ ] [P2] [CORE] Test task\n');

      final config = ProjectConfig.load(temp.path);

      expect(config.pipelineArchitectureGateEnabled, isFalse);
    });

    test('config parses architecture_gate_enabled: true', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_cfg_');
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/.genaisys').createSync();
      File('${temp.path}/.genaisys/config.yml').writeAsStringSync('''
pipeline:
  architecture_gate_enabled: true
''');
      File(
        '${temp.path}/.genaisys/STATE.json',
      ).writeAsStringSync('{"last_updated": "2025-01-01T00:00:00Z"}');
      File(
        '${temp.path}/.genaisys/TASKS.md',
      ).writeAsStringSync('# Tasks\n## Backlog\n- [ ] [P2] [CORE] Test task\n');

      final config = ProjectConfig.load(temp.path);

      expect(config.pipelineArchitectureGateEnabled, isTrue);
    });
  });

  group('architecture health service integration', () {
    late ArchitectureHealthService service;
    late ImportGraphService importGraphService;

    setUp(() {
      importGraphService = ImportGraphService();
      service = ArchitectureHealthService(
        importGraphService: importGraphService,
      );
    });

    test('layer violation produces reject-worthy report', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');

      final report = service.check(temp.path);

      expect(report.passed, isFalse);
      expect(report.violations, hasLength(1));
      expect(report.violations.first.severity, ArchViolationSeverity.critical);
    });

    test('clean architecture produces passing report', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      _createDartFile(temp, 'lib/core/a.dart', '');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path);

      expect(report.passed, isTrue);
      expect(report.violations, isEmpty);
    });

    test('warnings do not cause failure', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      // Create circular dependency (warning, not violation).
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'b.dart';
''');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path);

      expect(report.passed, isTrue);
      expect(report.warnings, isNotEmpty);
    });

    test('violation message contains file paths', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations.first.file, 'lib/core/service.dart');
      expect(report.violations.first.importedFile, 'lib/ui/widget.dart');
    });

    test('report score reflects violation count', () {
      final temp = Directory.systemTemp.createTempSync('arch_gate_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      _createDartFile(temp, 'lib/app/state.dart', '');
      _createDartFile(temp, 'lib/core/service_a.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');
      _createDartFile(temp, 'lib/core/service_b.dart', '''
import 'package:test_pkg/app/state.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, hasLength(2));
      expect(report.score, lessThan(1.0));
      expect(report.passed, isFalse);
    });

    test('report toJson includes violation details', () {
      final report = ArchitectureHealthReport(
        violations: const [
          ArchViolation(
            type: 'layer_violation',
            file: 'lib/core/a.dart',
            importedFile: 'lib/ui/b.dart',
            severity: ArchViolationSeverity.critical,
            message: 'core must not import ui',
          ),
        ],
        warnings: const [],
        score: 0.9,
      );

      final json = report.toJson();

      expect(json['passed'], isFalse);
      expect(json['violation_count'], 1);
      final violations = json['violations'] as List;
      expect((violations.first as Map)['type'], 'layer_violation');
    });
  });

  group('architecture gate disabled', () {
    test('gate disabled skips architecture check in config', () {
      // Verify that the config field defaults to true and can be disabled.
      final config = ProjectConfig(pipelineArchitectureGateEnabled: false);

      expect(config.pipelineArchitectureGateEnabled, isFalse);
    });
  });

  group('architecture warnings for review', () {
    late ArchitectureHealthService service;
    late ImportGraphService importGraphService;

    setUp(() {
      importGraphService = ImportGraphService();
      service = ArchitectureHealthService(
        importGraphService: importGraphService,
      );
    });

    test('fan-out warnings are collected for review context', () {
      final temp = Directory.systemTemp.createTempSync('arch_warn_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
      for (var i = 0; i < 5; i++) {
        _createDartFile(temp, 'lib/core/dep_$i.dart', '');
      }
      final imports = StringBuffer();
      for (var i = 0; i < 5; i++) {
        imports.writeln("import 'dep_$i.dart';");
      }
      _createDartFile(temp, 'lib/core/hub.dart', imports.toString());

      final report = service.check(temp.path, fanOutThreshold: 3);

      expect(report.passed, isTrue);
      expect(report.warnings.any((w) => w.type == 'high_fan_out'), isTrue);
    });
  });

  group('real project architecture gate', () {
    test('genaisys lib/ passes architecture gate', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final importGraphService = ImportGraphService();
      final service = ArchitectureHealthService(
        importGraphService: importGraphService,
      );
      final report = service.check(projectRoot);

      expect(
        report.passed,
        isTrue,
        reason:
            'Expected no critical architecture violations in the '
            'real project but found ${report.violations.length}: '
            '${report.violations.map((v) => v.message).join('; ')}',
      );
    });
  });
}

void _createDartFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

String? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return null;
}
