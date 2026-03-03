import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/config/quality_gate_profile.dart';
import 'package:genaisys/core/services/init_service.dart';
import 'package:genaisys/core/templates/default_files.dart';

/// Multi-language init regression test.
///
/// Initializes all 7 project types in separate temp directories, loads the
/// generated `config.yml` via [ProjectConfig.load], and verifies:
/// - Valid config parse (no exceptions)
/// - Correct quality-gate commands match profile
/// - Correct safe-write roots match profile
/// - Shell allowlist contains language extensions
/// - Dart regression: configYaml() without profile == configYaml(profile: dartProfile)
void main() {
  group('Multi-language init regression', () {
    final markerFiles = <ProjectType, String?>{
      ProjectType.dartFlutter: 'pubspec.yaml',
      ProjectType.node: 'package.json',
      ProjectType.python: 'pyproject.toml',
      ProjectType.rust: 'Cargo.toml',
      ProjectType.go: 'go.mod',
      ProjectType.java: 'pom.xml',
      ProjectType.unknown: null,
    };

    for (final entry in markerFiles.entries) {
      final type = entry.key;
      final marker = entry.value;

      test('${type.configKey} init produces loadable config', () {
        final dir = Directory.systemTemp.createTempSync(
          'genaisys_regression_${type.configKey}_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));

        if (marker != null) {
          File(
            '${dir.path}${Platform.pathSeparator}$marker',
          ).writeAsStringSync('');
        }

        final result = InitService().initialize(dir.path);
        expect(Directory(result.genaisysDir).existsSync(), isTrue);

        // Load the generated config — must not throw
        final config = ProjectConfig.load(dir.path);

        if (type == ProjectType.dartFlutter) {
          // Dart init does not write project.type (backward compat)
          expect(config.projectType, isNull);
        } else {
          expect(
            config.projectType,
            type.configKey,
            reason: '${type.configKey} should have projectType set',
          );
        }
      });
    }

    test('all non-Dart inits produce quality gate commands from profile', () {
      for (final type in ProjectType.values) {
        if (type == ProjectType.dartFlutter) continue;

        final dir = Directory.systemTemp.createTempSync(
          'genaisys_qg_${type.configKey}_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));

        final marker = markerFiles[type];
        if (marker != null) {
          File(
            '${dir.path}${Platform.pathSeparator}$marker',
          ).writeAsStringSync('');
        }

        InitService().initialize(dir.path);
        final config = ProjectConfig.load(dir.path);
        final profile = QualityGateProfile.forProjectType(type);

        if (type == ProjectType.unknown) {
          expect(
            config.qualityGateEnabled,
            isFalse,
            reason: 'unknown should have quality gate disabled',
          );
        } else {
          expect(
            config.qualityGateCommands,
            profile.qualityGateCommands,
            reason: '${type.configKey} quality gate commands should match',
          );
        }
      }
    });

    test('all non-Dart inits produce safe-write roots from profile', () {
      for (final type in ProjectType.values) {
        if (type == ProjectType.dartFlutter) continue;

        final dir = Directory.systemTemp.createTempSync(
          'genaisys_sw_${type.configKey}_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));

        final marker = markerFiles[type];
        if (marker != null) {
          File(
            '${dir.path}${Platform.pathSeparator}$marker',
          ).writeAsStringSync('');
        }

        InitService().initialize(dir.path);
        final config = ProjectConfig.load(dir.path);
        final profile = QualityGateProfile.forProjectType(type);

        expect(
          config.safeWriteRoots,
          profile.safeWriteRoots,
          reason: '${type.configKey} safe-write roots should match',
        );
      }
    });

    test('all non-Dart inits include language shell allowlist extensions', () {
      for (final type in ProjectType.values) {
        if (type == ProjectType.dartFlutter) continue;

        final dir = Directory.systemTemp.createTempSync(
          'genaisys_al_${type.configKey}_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));

        final marker = markerFiles[type];
        if (marker != null) {
          File(
            '${dir.path}${Platform.pathSeparator}$marker',
          ).writeAsStringSync('');
        }

        InitService().initialize(dir.path);
        final config = ProjectConfig.load(dir.path);
        final profile = QualityGateProfile.forProjectType(type);

        // Base entries must be present
        for (final base in QualityGateProfile.baseShellAllowlist) {
          expect(
            config.shellAllowlist,
            contains(base),
            reason:
                '${type.configKey} shell allowlist should contain base "$base"',
          );
        }

        // Language extensions must be present
        for (final ext in profile.shellAllowlistExtensions) {
          expect(
            config.shellAllowlist,
            contains(ext),
            reason:
                '${type.configKey} shell allowlist should contain extension "$ext"',
          );
        }
      }
    });

    group('Dart backward compatibility', () {
      test(
        'configYaml() without profile == configYaml(profile: dartProfile)',
        () {
          final legacy = DefaultFiles.configYaml();
          final dartProfile = QualityGateProfile.forProjectType(
            ProjectType.dartFlutter,
          );
          final withDartProfile = DefaultFiles.configYaml(profile: dartProfile);

          expect(
            withDartProfile,
            legacy,
            reason: 'Dart profile must produce byte-identical legacy output',
          );
        },
      );

      test('Dart init produces standard shell_allowlist_profile', () {
        final dir = Directory.systemTemp.createTempSync(
          'genaisys_dart_regression_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        File(
          '${dir.path}${Platform.pathSeparator}pubspec.yaml',
        ).writeAsStringSync('');

        InitService().initialize(dir.path);
        final config = ProjectConfig.load(dir.path);

        expect(config.shellAllowlistProfile, 'standard');
        expect(config.qualityGateAdaptiveByDiff, isTrue);
      });

      test('Dart quality gate defaults match ProjectConfig constants', () {
        final dartProfile = QualityGateProfile.forProjectType(
          ProjectType.dartFlutter,
        );

        expect(
          dartProfile.qualityGateCommands,
          ProjectConfig.defaultQualityGateCommands,
          reason: 'Dart profile commands must reference ProjectConfig defaults',
        );
        expect(
          dartProfile.safeWriteRoots,
          ProjectConfig.defaultSafeWriteRoots,
          reason:
              'Dart profile safe-write roots must reference ProjectConfig defaults',
        );
      });

      test('Dart init preserves all legacy config sections', () {
        final dir = Directory.systemTemp.createTempSync(
          'genaisys_dart_sections_',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        File(
          '${dir.path}${Platform.pathSeparator}pubspec.yaml',
        ).writeAsStringSync('');

        InitService().initialize(dir.path);
        final configText = File(
          '${dir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}config.yml',
        ).readAsStringSync();

        // All expected sections present
        expect(configText, contains('project:'));
        expect(configText, contains('providers:'));
        expect(configText, contains('git:'));
        expect(configText, contains('agents:'));
        expect(configText, contains('policies:'));
        expect(configText, contains('workflow:'));
        expect(configText, contains('autopilot:'));
      });
    });
  });
}
