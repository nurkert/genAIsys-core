import 'dart:io';

import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/services/project_type_detection_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ProjectTypeDetectionService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_detect_');
    service = ProjectTypeDetectionService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void createMarker(String fileName) {
    File(
      '${tempDir.path}${Platform.pathSeparator}$fileName',
    ).writeAsStringSync('');
  }

  group('ProjectTypeDetectionService', () {
    test('detects Dart/Flutter from pubspec.yaml', () {
      createMarker('pubspec.yaml');
      expect(service.detect(tempDir.path), ProjectType.dartFlutter);
    });

    test('detects Node from package.json', () {
      createMarker('package.json');
      expect(service.detect(tempDir.path), ProjectType.node);
    });

    test('detects Python from pyproject.toml', () {
      createMarker('pyproject.toml');
      expect(service.detect(tempDir.path), ProjectType.python);
    });

    test('detects Python from requirements.txt', () {
      createMarker('requirements.txt');
      expect(service.detect(tempDir.path), ProjectType.python);
    });

    test('detects Python from setup.py', () {
      createMarker('setup.py');
      expect(service.detect(tempDir.path), ProjectType.python);
    });

    test('detects Rust from Cargo.toml', () {
      createMarker('Cargo.toml');
      expect(service.detect(tempDir.path), ProjectType.rust);
    });

    test('detects Go from go.mod', () {
      createMarker('go.mod');
      expect(service.detect(tempDir.path), ProjectType.go);
    });

    test('detects Java from pom.xml', () {
      createMarker('pom.xml');
      expect(service.detect(tempDir.path), ProjectType.java);
    });

    test('detects Java from build.gradle', () {
      createMarker('build.gradle');
      expect(service.detect(tempDir.path), ProjectType.java);
    });

    test('detects Java from build.gradle.kts', () {
      createMarker('build.gradle.kts');
      expect(service.detect(tempDir.path), ProjectType.java);
    });

    test('returns unknown for empty directory', () {
      expect(service.detect(tempDir.path), ProjectType.unknown);
    });

    test('returns unknown for unrecognized files', () {
      createMarker('Makefile');
      createMarker('CMakeLists.txt');
      expect(service.detect(tempDir.path), ProjectType.unknown);
    });

    group('priority ordering', () {
      test('Dart takes precedence over Node (pubspec.yaml + package.json)', () {
        createMarker('pubspec.yaml');
        createMarker('package.json');
        expect(service.detect(tempDir.path), ProjectType.dartFlutter);
      });

      test('Node takes precedence over Python', () {
        createMarker('package.json');
        createMarker('pyproject.toml');
        expect(service.detect(tempDir.path), ProjectType.node);
      });

      test('Python takes precedence over Rust', () {
        createMarker('requirements.txt');
        createMarker('Cargo.toml');
        expect(service.detect(tempDir.path), ProjectType.python);
      });

      test('Rust takes precedence over Go', () {
        createMarker('Cargo.toml');
        createMarker('go.mod');
        expect(service.detect(tempDir.path), ProjectType.rust);
      });

      test('Go takes precedence over Java', () {
        createMarker('go.mod');
        createMarker('pom.xml');
        expect(service.detect(tempDir.path), ProjectType.go);
      });
    });
  });

  group('ProjectType', () {
    test('configKey round-trips through fromConfigKey', () {
      for (final type in ProjectType.values) {
        expect(
          ProjectType.fromConfigKey(type.configKey),
          type,
          reason: '${type.configKey} should round-trip',
        );
      }
    });

    test('fromConfigKey accepts common aliases', () {
      expect(ProjectType.fromConfigKey('dart'), ProjectType.dartFlutter);
      expect(ProjectType.fromConfigKey('flutter'), ProjectType.dartFlutter);
      expect(ProjectType.fromConfigKey('nodejs'), ProjectType.node);
      expect(ProjectType.fromConfigKey('javascript'), ProjectType.node);
      expect(ProjectType.fromConfigKey('typescript'), ProjectType.node);
      expect(ProjectType.fromConfigKey('golang'), ProjectType.go);
    });

    test('fromConfigKey returns null for unrecognized key', () {
      expect(ProjectType.fromConfigKey('cpp'), isNull);
      expect(ProjectType.fromConfigKey(''), isNull);
      expect(ProjectType.fromConfigKey('ruby'), isNull);
    });

    test('fromConfigKey is case-insensitive', () {
      expect(
        ProjectType.fromConfigKey('DART_FLUTTER'),
        ProjectType.dartFlutter,
      );
      expect(ProjectType.fromConfigKey('Node'), ProjectType.node);
      expect(ProjectType.fromConfigKey('PYTHON'), ProjectType.python);
    });
  });
}
