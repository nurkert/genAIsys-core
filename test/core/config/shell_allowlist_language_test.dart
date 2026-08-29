import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/config/quality_gate_profile.dart';
import 'package:genaisys/core/services/init_service.dart';

/// Tests for language-specific shell-allowlist generation.
///
/// Verifies that:
/// - Each language's init produces the correct shell-allowlist extensions
/// - No cross-contamination between language allowlists
/// - All generated allowlists contain the base shell commands
/// - No shell operators appear in any allowlist
void main() {
  group('Shell allowlist per language — generated config', () {
    test('Node allowlist contains npm/npx/node but not pip/cargo', () {
      final config = _initAndReadConfig('package.json');
      expect(config, contains('"npm"'));
      expect(config, contains('"npx"'));
      expect(config, contains('"node"'));
      // Cross-contamination checks
      expect(config, isNot(contains('"pip"')));
      expect(config, isNot(contains('"cargo"')));
      expect(config, isNot(contains('"pytest"')));
      expect(config, isNot(contains('"mvn"')));
      expect(config, isNot(contains('"go"')));
    });

    test(
      'Python allowlist contains pip/pytest/ruff/python but not npm/cargo',
      () {
        final config = _initAndReadConfig('pyproject.toml');
        expect(config, contains('"pip"'));
        expect(config, contains('"pytest"'));
        expect(config, contains('"ruff"'));
        expect(config, contains('"python"'));
        expect(config, contains('"python3"'));
        // Cross-contamination checks
        expect(config, isNot(contains('"npm"')));
        expect(config, isNot(contains('"npx"')));
        expect(config, isNot(contains('"cargo"')));
      },
    );

    test('Rust allowlist contains cargo/rustc/rustfmt but not pip/npm', () {
      final config = _initAndReadConfig('Cargo.toml');
      expect(config, contains('"cargo"'));
      expect(config, contains('"rustc"'));
      expect(config, contains('"rustfmt"'));
      // Cross-contamination checks
      expect(config, isNot(contains('"pip"')));
      expect(config, isNot(contains('"npm"')));
      expect(config, isNot(contains('"mvn"')));
    });

    test('Go allowlist contains go/golangci-lint/gofmt but not pip/cargo', () {
      final config = _initAndReadConfig('go.mod');
      expect(config, contains('"go"'));
      expect(config, contains('"golangci-lint"'));
      expect(config, contains('"gofmt"'));
      // Cross-contamination checks
      expect(config, isNot(contains('"pip"')));
      expect(config, isNot(contains('"cargo"')));
      expect(config, isNot(contains('"npm"')));
    });

    test('Java allowlist contains mvn/gradle/java/javac but not pip/cargo', () {
      final config = _initAndReadConfig('pom.xml');
      expect(config, contains('"mvn"'));
      expect(config, contains('"gradle"'));
      expect(config, contains('"java"'));
      expect(config, contains('"javac"'));
      // Cross-contamination checks
      expect(config, isNot(contains('"pip"')));
      expect(config, isNot(contains('"cargo"')));
      expect(config, isNot(contains('"npm"')));
    });

    test('unknown project has empty language extensions — only base', () {
      final config = _initAndReadConfig(null);
      // Base entries present
      for (final base in QualityGateProfile.baseShellAllowlist) {
        expect(
          config,
          contains('"$base"'),
          reason: 'Unknown project should contain base entry "$base"',
        );
      }
      // No language-specific entries
      expect(config, isNot(contains('"npm"')));
      expect(config, isNot(contains('"pip"')));
      expect(config, isNot(contains('"cargo"')));
      expect(config, isNot(contains('"go"')));
      expect(config, isNot(contains('"mvn"')));
    });

    test('all generated allowlists contain base shell commands', () {
      final markers = {
        'package.json': 'node',
        'pyproject.toml': 'python',
        'Cargo.toml': 'rust',
        'go.mod': 'go',
        'pom.xml': 'java',
      };

      for (final entry in markers.entries) {
        final config = _initAndReadConfig(entry.key);
        for (final base in QualityGateProfile.baseShellAllowlist) {
          expect(
            config,
            contains('"$base"'),
            reason: '${entry.value} config should contain base entry "$base"',
          );
        }
      }
    });
  });

  group('Shell allowlist — injection safety', () {
    test('no shell operators in any profile allowlist extensions', () {
      final dangerousPatterns = ['&&', '||', ';', '|', '>', '<', '`', '\$'];

      for (final type in ProjectType.values) {
        final profile = QualityGateProfile.forProjectType(type);
        for (final ext in profile.shellAllowlistExtensions) {
          for (final pattern in dangerousPatterns) {
            expect(
              ext,
              isNot(contains(pattern)),
              reason:
                  '${type.configKey} allowlist extension "$ext" contains '
                  'dangerous pattern "$pattern"',
            );
          }
        }
      }
    });

    test('no shell operators in base shell allowlist', () {
      final dangerousPatterns = ['&&', '||', ';', '|', '>', '<', '`', '\$'];

      for (final entry in QualityGateProfile.baseShellAllowlist) {
        for (final pattern in dangerousPatterns) {
          expect(
            entry,
            isNot(contains(pattern)),
            reason:
                'Base allowlist entry "$entry" contains '
                'dangerous pattern "$pattern"',
          );
        }
      }
    });

    test('no shell operators in quality gate commands', () {
      final dangerousPatterns = ['&&', '||', ';', '|', '>', '<', '`', '\$'];

      for (final type in ProjectType.values) {
        final profile = QualityGateProfile.forProjectType(type);
        for (final cmd in profile.qualityGateCommands) {
          for (final pattern in dangerousPatterns) {
            expect(
              cmd,
              isNot(contains(pattern)),
              reason:
                  '${type.configKey} quality gate command "$cmd" '
                  'contains dangerous pattern "$pattern"',
            );
          }
        }
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a temp directory, optionally adds a marker file, runs InitService,
/// and returns the generated config.yml content.
String _initAndReadConfig(String? markerFileName) {
  final dir = Directory.systemTemp.createTempSync('genaisys_allowlist_');
  addTearDown(() => dir.deleteSync(recursive: true));

  if (markerFileName != null) {
    File(
      '${dir.path}${Platform.pathSeparator}$markerFileName',
    ).writeAsStringSync('');
  }

  InitService().initialize(dir.path);

  return File(
    '${dir.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}config.yml',
  ).readAsStringSync();
}
