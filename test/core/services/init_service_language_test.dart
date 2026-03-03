import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/config/quality_gate_profile.dart';
import 'package:genaisys/core/services/init_service.dart';
import 'package:genaisys/core/templates/default_files.dart';

/// Tests for InitService multi-language init flow.
///
/// For each supported project type, verifies that:
/// - `.genaisys/` directory is created
/// - `config.yml` contains the correct `project.type`
/// - Quality-gate commands match the profile defaults
/// - Safe-write roots match the profile defaults
/// - Shell allowlist includes language-specific extensions
/// - Dart projects produce byte-identical output to the legacy template
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_init_lang_');
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

  String readConfig() {
    return File(
      '${tempDir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}config.yml',
    ).readAsStringSync();
  }

  group('InitService — multi-language init', () {
    test('Dart/Flutter project produces byte-identical legacy config', () {
      createMarker('pubspec.yaml');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      // The temp dir is not a git repo, so InitService detects hasRemote=false.
      // The expected template must match this remote detection result.
      final legacyConfig = DefaultFiles.configYaml(hasRemote: false);

      expect(
        config,
        legacyConfig,
        reason:
            'Dart/Flutter init must produce byte-identical output to legacy template',
      );
    });

    test('Dart/Flutter config does NOT contain project.type field', () {
      createMarker('pubspec.yaml');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      // Legacy Dart template does not include project.type
      expect(config, isNot(contains('type: "dart_flutter"')));
    });

    test('Node project init detects type and generates correct config', () {
      createMarker('package.json');
      final result = InitService().initialize(tempDir.path);

      expect(result.genaisysDir, endsWith('.genaisys'));
      expect(Directory(result.genaisysDir).existsSync(), isTrue);

      final config = readConfig();
      expect(config, contains('type: "node"'));
      // Quality gate commands from profile
      expect(config, contains('npx prettier --check .'));
      expect(config, contains('npx eslint .'));
      expect(config, contains('npm test'));
      // Shell allowlist extensions
      expect(config, contains('"npm"'));
      expect(config, contains('"npx"'));
      expect(config, contains('"node"'));
      // Safe-write roots
      expect(config, contains('"package.json"'));
      expect(config, contains('"tsconfig.json"'));
      // Non-Dart flags
      expect(config, contains('adaptive_by_diff: false'));
      expect(config, contains('prefer_dart_test_for_lib_dart_only: false'));
    });

    test('Python project init detects type and generates correct config', () {
      createMarker('pyproject.toml');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "python"'));
      expect(config, contains('ruff format --check .'));
      expect(config, contains('ruff check .'));
      expect(config, contains('pytest'));
      expect(config, contains('"pip"'));
      expect(config, contains('"python"'));
      expect(config, contains('"pyproject.toml"'));
    });

    test('Python detected from requirements.txt', () {
      createMarker('requirements.txt');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "python"'));
    });

    test('Rust project init detects type and generates correct config', () {
      createMarker('Cargo.toml');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "rust"'));
      expect(config, contains('cargo fmt --check'));
      expect(config, contains('cargo clippy -- -D warnings'));
      expect(config, contains('cargo test'));
      expect(config, contains('"cargo"'));
      expect(config, contains('"rustc"'));
      expect(config, contains('"Cargo.toml"'));
    });

    test('Go project init detects type and generates correct config', () {
      createMarker('go.mod');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "go"'));
      expect(config, contains('gofmt -l .'));
      expect(config, contains('golangci-lint run'));
      expect(config, contains('go test ./...'));
      expect(config, contains('"go"'));
      expect(config, contains('"golangci-lint"'));
      expect(config, contains('"go.mod"'));
    });

    test('Java project init detects type and generates correct config', () {
      createMarker('pom.xml');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "java"'));
      expect(config, contains('mvn compile'));
      expect(config, contains('mvn test'));
      expect(config, contains('"mvn"'));
      expect(config, contains('"gradle"'));
      expect(config, contains('"pom.xml"'));
    });

    test('Java detected from build.gradle', () {
      createMarker('build.gradle');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "java"'));
    });

    test('Java detected from build.gradle.kts', () {
      createMarker('build.gradle.kts');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "java"'));
    });

    test('unknown project type produces disabled quality gate', () {
      // No marker files — unknown project
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('type: "unknown"'));
      expect(config, contains('enabled: false'));
    });

    test(
      '.genaisys directory structure is created for all project types',
      () {
        createMarker('package.json');
        final result = InitService().initialize(tempDir.path);

        final hDir = result.genaisysDir;
        expect(Directory(hDir).existsSync(), isTrue);
        expect(
          File('$hDir${Platform.pathSeparator}config.yml').existsSync(),
          isTrue,
        );
        expect(
          File('$hDir${Platform.pathSeparator}VISION.md').existsSync(),
          isTrue,
        );
        expect(
          File('$hDir${Platform.pathSeparator}RULES.md').existsSync(),
          isTrue,
        );
        expect(
          File('$hDir${Platform.pathSeparator}TASKS.md').existsSync(),
          isTrue,
        );
        expect(
          File('$hDir${Platform.pathSeparator}STATE.json').existsSync(),
          isTrue,
        );
      },
    );

    test('all non-Dart configs contain base shell allowlist entries', () {
      for (final marker in [
        'package.json',
        'pyproject.toml',
        'Cargo.toml',
        'go.mod',
        'pom.xml',
      ]) {
        final dir = Directory.systemTemp.createTempSync(
          'genaisys_init_base_allow_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));

        File(
          '${dir.path}${Platform.pathSeparator}$marker',
        ).writeAsStringSync('');
        InitService().initialize(dir.path);

        final config = File(
          '${dir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}config.yml',
        ).readAsStringSync();

        for (final base in QualityGateProfile.baseShellAllowlist) {
          expect(
            config,
            contains('"$base"'),
            reason: 'Config for $marker should contain base entry "$base"',
          );
        }
      }
    });

    test('non-Dart configs use custom shell_allowlist_profile', () {
      createMarker('package.json');
      InitService().initialize(tempDir.path);

      final config = readConfig();
      expect(config, contains('shell_allowlist_profile: "custom"'));
    });

    test('overwrite replaces existing config for non-Dart project', () {
      createMarker('package.json');

      // First init
      InitService().initialize(tempDir.path);
      final firstConfig = readConfig();
      expect(firstConfig, contains('type: "node"'));

      // Overwrite
      InitService().initialize(tempDir.path, overwrite: true);
      final secondConfig = readConfig();
      expect(secondConfig, contains('type: "node"'));
      expect(secondConfig, firstConfig);
    });

    test('run log records detected project type', () {
      createMarker('Cargo.toml');
      InitService().initialize(tempDir.path);

      final runLog = File(
        '${tempDir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}RUN_LOG.jsonl',
      ).readAsStringSync();

      expect(runLog, contains('detected_project_type'));
      expect(runLog, contains('rust'));
    });
  });

  group('DefaultFiles.configYaml — profile integration', () {
    test('null profile produces legacy Dart config', () {
      final yaml = DefaultFiles.configYaml();
      final yamlWithNull = DefaultFiles.configYaml(profile: null);
      expect(yaml, yamlWithNull);
    });

    test('dartFlutter profile produces legacy Dart config', () {
      final legacy = DefaultFiles.configYaml();
      final dartProfile = QualityGateProfile.forProjectType(
        ProjectType.dartFlutter,
      );
      final withProfile = DefaultFiles.configYaml(profile: dartProfile);
      expect(withProfile, legacy);
    });

    test('Node profile produces config with type: "node"', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.node);
      final yaml = DefaultFiles.configYaml(profile: profile);
      expect(yaml, contains('type: "node"'));
      expect(yaml, contains('npm test'));
    });

    test('Python profile produces config with type: "python"', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.python);
      final yaml = DefaultFiles.configYaml(profile: profile);
      expect(yaml, contains('type: "python"'));
      expect(yaml, contains('pytest'));
    });

    test('unknown profile produces config with disabled quality gate', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.unknown);
      final yaml = DefaultFiles.configYaml(profile: profile);
      expect(yaml, contains('type: "unknown"'));
      expect(yaml, contains('enabled: false'));
    });

    test('all non-Dart profiles have adaptive_by_diff: false', () {
      for (final type in ProjectType.values) {
        if (type == ProjectType.dartFlutter) continue;
        final profile = QualityGateProfile.forProjectType(type);
        final yaml = DefaultFiles.configYaml(profile: profile);
        expect(
          yaml,
          contains('adaptive_by_diff: false'),
          reason: '${type.configKey} should have adaptive_by_diff: false',
        );
      }
    });
  });
}
