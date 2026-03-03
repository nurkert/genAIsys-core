import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/observability/architecture_health_service.dart';
import 'package:genaisys/core/services/import_graph_service.dart';

void main() {
  late ArchitectureHealthService service;
  late ImportGraphService importGraphService;

  setUp(() {
    importGraphService = ImportGraphService();
    service = ArchitectureHealthService(importGraphService: importGraphService);
  });

  group('layer violation detection', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('arch_health_');
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('core importing ui is a critical violation', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');

      final report = service.check(temp.path);

      expect(report.passed, isFalse);
      expect(report.violations, hasLength(1));
      expect(report.violations.first.type, 'layer_violation');
      expect(report.violations.first.file, 'lib/core/service.dart');
      expect(report.violations.first.importedFile, 'lib/ui/widget.dart');
      expect(report.violations.first.severity, ArchViolationSeverity.critical);
    });

    test('core importing app is a critical violation', () {
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/app/state.dart';
''');
      _createDartFile(temp, 'lib/app/state.dart', '');

      final report = service.check(temp.path);

      expect(report.passed, isFalse);
      expect(report.violations, isNotEmpty);
      expect(report.violations.first.message, contains('core'));
      expect(report.violations.first.message, contains('app'));
    });

    test('core importing cli is allowed (cli is under core/)', () {
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/core/cli/runner.dart';
''');
      _createDartFile(temp, 'lib/core/cli/runner.dart', '');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('core importing desktop is a critical violation', () {
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/desktop/adapter.dart';
''');
      _createDartFile(temp, 'lib/desktop/adapter.dart', '');

      final report = service.check(temp.path);

      expect(report.passed, isFalse);
      expect(report.violations, isNotEmpty);
      expect(report.violations.first.message, contains('core'));
      expect(report.violations.first.message, contains('desktop'));
    });

    test('ui importing desktop is allowed', () {
      _createDartFile(temp, 'lib/desktop/services/window_service.dart', '');
      _createDartFile(temp, 'lib/ui/desktop/widget.dart', '''
import 'package:test_pkg/desktop/services/window_service.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('ui importing core is allowed', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/ui/widget.dart', '''
import 'package:test_pkg/core/base.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('ui importing app is allowed', () {
      _createDartFile(temp, 'lib/app/state.dart', '');
      _createDartFile(temp, 'lib/ui/widget.dart', '''
import 'package:test_pkg/app/state.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('app importing core is allowed', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/app/state.dart', '''
import 'package:test_pkg/core/base.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('cli importing core is allowed', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/cli/runner.dart', '''
import 'package:test_pkg/core/base.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('desktop importing core is allowed', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/desktop/adapter.dart', '''
import 'package:test_pkg/core/base.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('desktop importing app is allowed', () {
      _createDartFile(temp, 'lib/app/state.dart', '');
      _createDartFile(temp, 'lib/desktop/adapter.dart', '''
import 'package:test_pkg/app/state.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('same-layer imports are allowed', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'base.dart';
''');

      final report = service.check(temp.path);

      expect(report.violations, isEmpty);
    });

    test('multiple violations are collected', () {
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
      expect(report.passed, isFalse);
    });
  });

  group('circular dependency detection', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('arch_circ_');
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('detects simple circular dependency', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'b.dart';
''');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path);

      expect(report.warnings, isNotEmpty);
      expect(
        report.warnings.any((w) => w.type == 'circular_dependency'),
        isTrue,
      );
    });

    test('no circular dependency when imports are one-way', () {
      _createDartFile(temp, 'lib/core/a.dart', '');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path);

      expect(
        report.warnings.where((w) => w.type == 'circular_dependency'),
        isEmpty,
      );
    });
  });

  group('fan-out detection', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('arch_fanout_');
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('detects high fan-out with low threshold', () {
      // Create many files and one file that imports them all.
      for (var i = 0; i < 5; i++) {
        _createDartFile(temp, 'lib/core/dep_$i.dart', '');
      }
      final imports = StringBuffer();
      for (var i = 0; i < 5; i++) {
        imports.writeln("import 'dep_$i.dart';");
      }
      _createDartFile(temp, 'lib/core/hub.dart', imports.toString());

      final report = service.check(temp.path, fanOutThreshold: 3);

      expect(report.warnings.any((w) => w.type == 'high_fan_out'), isTrue);
      final fanOutWarning = report.warnings.firstWhere(
        (w) => w.type == 'high_fan_out',
      );
      expect(fanOutWarning.file, 'lib/core/hub.dart');
    });

    test('no fan-out warning below threshold', () {
      _createDartFile(temp, 'lib/core/a.dart', '');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path, fanOutThreshold: 15);

      expect(report.warnings.where((w) => w.type == 'high_fan_out'), isEmpty);
    });
  });

  group('score computation', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('arch_score_');
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('perfect score for clean architecture', () {
      _createDartFile(temp, 'lib/core/a.dart', '');
      _createDartFile(temp, 'lib/core/b.dart', '''
import 'a.dart';
''');

      final report = service.check(temp.path);

      expect(report.score, 1.0);
      expect(report.passed, isTrue);
    });

    test('violations reduce score', () {
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');

      final report = service.check(temp.path);

      expect(report.score, lessThan(1.0));
      expect(report.passed, isFalse);
    });

    test('score is clamped to 0.0 minimum', () {
      // Create many violations.
      _createDartFile(temp, 'lib/ui/widget.dart', '');
      for (var i = 0; i < 20; i++) {
        _createDartFile(temp, 'lib/core/service_$i.dart', '''
import 'package:test_pkg/ui/widget.dart';
''');
      }

      final report = service.check(temp.path);

      expect(report.score, greaterThanOrEqualTo(0.0));
    });

    test('empty project scores 1.0', () {
      // No lib/ directory at all — empty graph.
      final report = service.check(temp.path);

      expect(report.score, 1.0);
    });
  });

  group('report serialization', () {
    test('toJson produces valid output for clean report', () {
      const report = ArchitectureHealthReport(
        violations: [],
        warnings: [],
        score: 1.0,
      );

      final json = report.toJson();

      expect(json['passed'], isTrue);
      expect(json['score'], 1.0);
      expect(json['violation_count'], 0);
      expect(json['warning_count'], 0);
    });

    test('toJson includes violations and warnings', () {
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
        warnings: const [
          ArchViolation(
            type: 'high_fan_out',
            file: 'lib/core/hub.dart',
            importedFile: '',
            severity: ArchViolationSeverity.warning,
            message: 'High fan-out: 20 imports',
          ),
        ],
        score: 0.88,
      );

      final json = report.toJson();

      expect(json['passed'], isFalse);
      expect(json['violation_count'], 1);
      expect(json['warning_count'], 1);
      final violations = json['violations'] as List;
      expect(violations.first, isA<Map>());
      expect((violations.first as Map)['type'], 'layer_violation');
    });
  });

  group('real project architecture check', () {
    test('genaisys lib/ passes architecture health check', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final report = service.check(projectRoot);

      // The real project should have no critical layer violations.
      expect(
        report.passed,
        isTrue,
        reason:
            'Expected no critical architecture violations in the '
            'real project but found ${report.violations.length}: '
            '${report.violations.map((v) => v.message).join('; ')}',
      );
      expect(report.score, greaterThan(0.5));
    });
  });
}

/// Creates a Dart file in the temporary project structure.
void _createDartFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Finds the project root by looking for pubspec.yaml.
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
