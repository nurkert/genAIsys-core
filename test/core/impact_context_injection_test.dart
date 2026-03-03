import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/architecture_context_service.dart';
import 'package:genaisys/core/services/import_graph_service.dart';

void main() {
  late ArchitectureContextService contextService;
  late ImportGraphService importGraphService;

  setUp(() {
    importGraphService = ImportGraphService();
    contextService = ArchitectureContextService(
      importGraphService: importGraphService,
    );
  });

  group('assembleImpactContext', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('impact_context_');
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('returns empty string for empty targetFiles', () {
      final result = contextService.assembleImpactContext(temp.path, []);

      expect(result, isEmpty);
    });

    test('returns empty string when no dependents exist', () {
      _createDartFile(temp, 'lib/a.dart', '');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/a.dart',
      ]);

      expect(result, isEmpty);
    });

    test('includes target files in output', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'base.dart';
''');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      expect(result, contains('`lib/core/base.dart`'));
      expect(result, contains('Target files'));
    });

    test('includes dependent modules in output', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'base.dart';
''');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      expect(result, contains('`lib/core/service.dart`'));
      expect(result, contains('Dependent modules'));
    });

    test('includes transitive dependents', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'base.dart';
''');
      _createDartFile(temp, 'lib/core/controller.dart', '''
import 'service.dart';
''');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      expect(result, contains('`lib/core/service.dart`'));
      expect(result, contains('`lib/core/controller.dart`'));
    });

    test('shows layer boundary crossings', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/app/state.dart', '''
import 'package:test_pkg/core/base.dart';
''');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      expect(result, contains('Layer boundaries crossed'));
      expect(result, contains('app'));
    });

    test('does not show layer boundary when same layer', () {
      _createDartFile(temp, 'lib/core/base.dart', '');
      _createDartFile(temp, 'lib/core/service.dart', '''
import 'base.dart';
''');

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      // No layer boundary message since both are in 'core'.
      expect(result, isNot(contains('Layer boundaries crossed')));
    });

    test('respects maxChars limit', () {
      // Create many dependents to produce large output.
      _createDartFile(temp, 'lib/core/base.dart', '');
      for (var i = 0; i < 30; i++) {
        _createDartFile(
          temp,
          'lib/core/service_$i.dart',
          "import 'base.dart';\n",
        );
      }

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ], maxChars: 300);

      expect(result.length, lessThanOrEqualTo(300));
    });

    test('handles missing lib directory gracefully', () {
      // Remove lib directory.
      final libDir = Directory('${temp.path}/lib');
      if (libDir.existsSync()) {
        libDir.deleteSync(recursive: true);
      }

      final result = contextService.assembleImpactContext(temp.path, [
        'lib/core/base.dart',
      ]);

      expect(result, isEmpty);
    });
  });

  group('assembleImpactContext on real project', () {
    test('produces impact context for known file', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final result = contextService.assembleImpactContext(projectRoot, [
        'lib/core/project_layout.dart',
      ]);

      // project_layout.dart is widely imported; should have dependents.
      expect(result, isNotEmpty);
      expect(result, contains('Target files'));
      expect(result, contains('Dependent modules'));
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
