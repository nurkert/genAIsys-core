import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/config/quality_gate_profile.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';
import 'package:test/test.dart';

import '../../support/test_workspace.dart';

void main() {
  group('QualityGateProfile', () {
    group('Dart/Flutter backward compatibility', () {
      final profile = QualityGateProfile.forProjectType(
        ProjectType.dartFlutter,
      );

      test('quality gate commands match ProjectConfig defaults', () {
        expect(
          profile.qualityGateCommands,
          ProjectConfig.defaultQualityGateCommands,
        );
      });

      test('safe-write roots match ProjectConfig defaults', () {
        expect(profile.safeWriteRoots, ProjectConfig.defaultSafeWriteRoots);
      });

      test('adaptive diff scoping is enabled', () {
        expect(profile.adaptiveByDiff, isTrue);
      });

      test('dependency bootstrap is flutter pub get', () {
        expect(profile.dependencyBootstrapCommand, 'flutter pub get');
      });
    });

    group('every project type has a profile', () {
      for (final type in ProjectType.values) {
        test('${type.name} profile is available', () {
          final profile = QualityGateProfile.forProjectType(type);
          expect(profile.projectType, type);
        });
      }
    });

    group('non-unknown profiles have quality gate commands', () {
      for (final type in ProjectType.values.where(
        (t) => t != ProjectType.unknown,
      )) {
        test('${type.name} has at least one command', () {
          final profile = QualityGateProfile.forProjectType(type);
          expect(profile.qualityGateCommands, isNotEmpty);
        });
      }
    });

    test('unknown profile has empty quality gate commands', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.unknown);
      expect(profile.qualityGateCommands, isEmpty);
    });

    group('shell allowlist extensions contain no shell operators', () {
      const shellOperators = [';', '&', '|', '<', '>', '`', r'$('];

      for (final type in ProjectType.values) {
        test('${type.name} extensions are injection-safe', () {
          final profile = QualityGateProfile.forProjectType(type);
          for (final entry in profile.shellAllowlistExtensions) {
            for (final op in shellOperators) {
              expect(
                entry.contains(op),
                isFalse,
                reason: 'Extension "$entry" contains shell operator "$op"',
              );
            }
          }
        });
      }
    });

    group('base shell allowlist contains no shell operators', () {
      const shellOperators = [';', '&', '|', '<', '>', '`', r'$('];

      test('base allowlist is injection-safe', () {
        for (final entry in QualityGateProfile.baseShellAllowlist) {
          for (final op in shellOperators) {
            expect(
              entry.contains(op),
              isFalse,
              reason: 'Base entry "$entry" contains shell operator "$op"',
            );
          }
        }
      });
    });

    group('non-Dart profiles disable adaptive diff scoping', () {
      for (final type in ProjectType.values.where(
        (t) => t != ProjectType.dartFlutter,
      )) {
        test('${type.name} has adaptiveByDiff=false', () {
          final profile = QualityGateProfile.forProjectType(type);
          expect(profile.adaptiveByDiff, isFalse);
        });
      }
    });

    group('safe-write roots always include common entries', () {
      for (final type in ProjectType.values) {
        test(
          '${type.name} includes .genaisys/agent_contexts and .github',
          () {
            final profile = QualityGateProfile.forProjectType(type);
            expect(
              profile.safeWriteRoots,
              contains('.genaisys/agent_contexts'),
            );
            expect(profile.safeWriteRoots, contains('.github'));
            expect(profile.safeWriteRoots, contains('README.md'));
          },
        );
      }
    });

    group('Node profile', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.node);

      test('includes npm, npx, node in shell extensions', () {
        expect(profile.shellAllowlistExtensions, contains('npm'));
        expect(profile.shellAllowlistExtensions, contains('npx'));
        expect(profile.shellAllowlistExtensions, contains('node'));
      });

      test('includes package.json in safe-write roots', () {
        expect(profile.safeWriteRoots, contains('package.json'));
      });

      test('has npm install as bootstrap command', () {
        expect(profile.dependencyBootstrapCommand, 'npm install');
      });
    });

    group('Python profile', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.python);

      test('includes pip, pytest, ruff, python in shell extensions', () {
        expect(profile.shellAllowlistExtensions, contains('pip'));
        expect(profile.shellAllowlistExtensions, contains('pytest'));
        expect(profile.shellAllowlistExtensions, contains('ruff'));
        expect(profile.shellAllowlistExtensions, contains('python'));
      });

      test('includes pyproject.toml in safe-write roots', () {
        expect(profile.safeWriteRoots, contains('pyproject.toml'));
      });

      test('has no bootstrap command', () {
        expect(profile.dependencyBootstrapCommand, isNull);
      });
    });

    group('Rust profile', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.rust);

      test('includes cargo, rustc, rustfmt in shell extensions', () {
        expect(profile.shellAllowlistExtensions, contains('cargo'));
        expect(profile.shellAllowlistExtensions, contains('rustc'));
        expect(profile.shellAllowlistExtensions, contains('rustfmt'));
      });

      test('includes Cargo.toml in safe-write roots', () {
        expect(profile.safeWriteRoots, contains('Cargo.toml'));
      });
    });

    group('Go profile', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.go);

      test('includes go, golangci-lint, gofmt in shell extensions', () {
        expect(profile.shellAllowlistExtensions, contains('go'));
        expect(profile.shellAllowlistExtensions, contains('golangci-lint'));
        expect(profile.shellAllowlistExtensions, contains('gofmt'));
      });

      test('includes go.mod in safe-write roots', () {
        expect(profile.safeWriteRoots, contains('go.mod'));
      });
    });

    group('Java profile', () {
      final profile = QualityGateProfile.forProjectType(ProjectType.java);

      test('includes mvn, gradle, java, javac in shell extensions', () {
        expect(profile.shellAllowlistExtensions, contains('mvn'));
        expect(profile.shellAllowlistExtensions, contains('gradle'));
        expect(profile.shellAllowlistExtensions, contains('java'));
        expect(profile.shellAllowlistExtensions, contains('javac'));
      });

      test('includes pom.xml in safe-write roots', () {
        expect(profile.safeWriteRoots, contains('pom.xml'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // §13 Test #5 — Docs-only QG explicitly skips test commands
  //
  // AGENTS.md §13 requirement:
  //   "Dynamic quality gate profile skips irrelevant tests for docs-only diffs."
  //
  // These tests verify that actual command execution is skipped (not just that
  // the profile name changes) when the diff contains only documentation files.
  // Release-blocking regression guard for unattended stability.
  // -------------------------------------------------------------------------
  group('§13 Test #5 — docs-only diff skips test commands explicitly', () {
    test(
      'docs-only diff: no test commands execute (early return, docs_only profile)',
      () async {
        final workspace = TestWorkspace.create();
        addTearDown(workspace.dispose);
        workspace.ensureStructure();
        // Configure: only a test command, no bootstrap, no allowlist overhead.
        workspace.writeConfig('''
policies:
  shell_allowlist:
    enabled: false
  quality_gate:
    enabled: true
    commands:
      - flutter test
    dependency_bootstrap_enabled: false
''');

        final runner = _RecordingShellRunner();
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(
          workspace.root.path,
          // Only documentation files → triggers docs_only path in _resolveCommandPlan.
          changedPaths: ['README.md', 'docs/architecture/overview.md'],
        );

        expect(
          outcome.profile,
          equals('docs_only'),
          reason: 'docs-only diff must select the docs_only profile',
        );
        expect(
          runner.ranCommands,
          isEmpty,
          reason:
              'No test commands must execute for a docs-only diff '
              '(early return before running any commands)',
        );
      },
    );

    test('lib-only dart diff: test commands execute (control test)', () async {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();
      // Disable adaptive-by-diff so the configured 'flutter test' is used
      // directly — avoids the dart test rewrite path that needs a pub workspace.
      workspace.writeConfig('''
policies:
  shell_allowlist:
    enabled: false
  quality_gate:
    enabled: true
    commands:
      - flutter test
    dependency_bootstrap_enabled: false
    adaptive_by_diff: false
''');

      final runner = _RecordingShellRunner();
      final service = BuildTestRunnerService(commandRunner: runner);

      await service.run(
        workspace.root.path,
        // Source files in lib/ — not docs-only, QG commands must run.
        changedPaths: ['lib/core/services/auth_service.dart'],
      );

      expect(
        runner.ranCommands,
        isNotEmpty,
        reason: 'Test commands must execute for lib-only dart diff',
      );
      expect(
        runner.ranCommands.any((c) => c.contains('test')),
        isTrue,
        reason: 'At least one test command must have been invoked',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// A [ShellCommandRunner] that records every command it receives.
// Returns success (exit code 0) for all commands.
// ---------------------------------------------------------------------------

class _RecordingShellRunner implements ShellCommandRunner {
  final List<String> ranCommands = [];

  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    ranCommands.add(command);
    return const ShellCommandResult(
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
      duration: Duration.zero,
      timedOut: false,
    );
  }
}
