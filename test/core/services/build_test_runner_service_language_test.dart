import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';

/// Tests for BuildTestRunnerService with non-Dart project types.
///
/// Verifies that:
/// - Non-Dart projects skip adaptive diff scoping and run commands as-is
/// - Flake retry works for non-Dart test commands (pytest, npm test, etc.)
/// - Auto-format baseline is skipped for non-Dart projects
/// - Dart projects remain fully backward-compatible
void main() {
  group('BuildTestRunnerService — language-agnostic quality gate', () {
    test('Node project runs npm commands without adaptive scoping', () async {
      final root = _createProject('''
project:
  type: "node"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "npx prettier"
    - "npx eslint"
    - "npm test"
  quality_gate:
    enabled: true
    timeout_seconds: 15
    adaptive_by_diff: false
    commands:
      - "npx prettier --check ."
      - "npx eslint ."
      - "npm test"
''');

      final runner = _FakeShellCommandRunner([
        _ok('prettier ok'),
        _ok('eslint ok'),
        _ok('tests ok'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['src/index.js', 'src/utils.js'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'configured');
      expect(runner.invocations.map((e) => e.command), [
        'npx prettier --check .',
        'npx eslint .',
        'npm test',
      ]);
    });

    test(
      'Python project runs ruff + pytest without adaptive scoping',
      () async {
        final root = _createProject('''
project:
  type: "python"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "ruff format"
    - "ruff check"
    - "pytest"
  quality_gate:
    enabled: true
    timeout_seconds: 20
    adaptive_by_diff: false
    commands:
      - "ruff format --check ."
      - "ruff check ."
      - "pytest"
''');

        final runner = _FakeShellCommandRunner([
          _ok('format ok'),
          _ok('lint ok'),
          _ok('tests ok'),
        ]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(
          root,
          changedPaths: const ['src/main.py', 'tests/test_main.py'],
        );

        expect(outcome.executed, isTrue);
        expect(outcome.profile, 'configured');
        expect(runner.invocations.map((e) => e.command), [
          'ruff format --check .',
          'ruff check .',
          'pytest',
        ]);
      },
    );

    test('Rust project runs cargo commands without adaptive scoping', () async {
      final root = _createProject('''
project:
  type: "rust"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "cargo fmt"
    - "cargo clippy"
    - "cargo test"
  quality_gate:
    enabled: true
    timeout_seconds: 30
    adaptive_by_diff: false
    commands:
      - "cargo fmt --check"
      - "cargo clippy -- -D warnings"
      - "cargo test"
''');

      final runner = _FakeShellCommandRunner([
        _ok('fmt ok'),
        _ok('clippy ok'),
        _ok('tests ok'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['src/main.rs', 'src/lib.rs'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'configured');
      expect(runner.invocations.map((e) => e.command), [
        'cargo fmt --check',
        'cargo clippy -- -D warnings',
        'cargo test',
      ]);
    });

    test('Go project runs go commands without adaptive scoping', () async {
      final root = _createProject('''
project:
  type: "go"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "gofmt"
    - "golangci-lint"
    - "go test"
  quality_gate:
    enabled: true
    timeout_seconds: 30
    commands:
      - "gofmt -l ."
      - "golangci-lint run"
      - "go test ./..."
''');

      final runner = _FakeShellCommandRunner([
        _ok('fmt ok'),
        _ok('lint ok'),
        _ok('tests ok'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['cmd/main.go', 'internal/handler.go'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'configured');
      expect(runner.invocations.map((e) => e.command), [
        'gofmt -l .',
        'golangci-lint run',
        'go test ./...',
      ]);
    });

    test('Java project runs mvn commands without adaptive scoping', () async {
      final root = _createProject('''
project:
  type: "java"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "mvn compile"
    - "mvn test"
  quality_gate:
    enabled: true
    timeout_seconds: 60
    commands:
      - "mvn compile"
      - "mvn test"
''');

      final runner = _FakeShellCommandRunner([
        _ok('compile ok'),
        _ok('tests ok'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'configured');
      expect(runner.invocations.map((e) => e.command), [
        'mvn compile',
        'mvn test',
      ]);
    });

    test('non-Dart project skips auto-format baseline', () async {
      final root = _createProject('''
project:
  type: "node"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "npx prettier"
    - "npm test"
  quality_gate:
    enabled: true
    timeout_seconds: 15
    adaptive_by_diff: false
    commands:
      - "npx prettier --check ."
      - "npm test"
''');

      final runner = _FakeShellCommandRunner([
        _ok('prettier ok'),
        _ok('tests ok'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      // For a Dart project, this docs-only diff would trigger
      // auto-format baseline. For Node, it should not.
      final outcome = await service.run(
        root,
        changedPaths: const ['docs/readme.md'],
      );

      expect(outcome.executed, isTrue);
      // No 'dart format .' baseline command should appear.
      expect(
        runner.invocations.map((e) => e.command),
        isNot(contains('dart format .')),
      );
      expect(runner.invocations.map((e) => e.command), [
        'npx prettier --check .',
        'npm test',
      ]);
    });

    test(
      'non-Dart project recognizes pytest as test command for flake retry',
      () async {
        final root = _createProject('''
project:
  type: "python"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "ruff check"
    - "pytest"
  quality_gate:
    enabled: true
    flake_retry_count: 1
    commands:
      - "ruff check ."
      - "pytest"
''');

        final runner = _FakeShellCommandRunner([
          _ok('lint ok'),
          // pytest fails on first try
          const ShellCommandResult(
            exitCode: 1,
            stdout: '',
            stderr: 'FAILED tests/test_main.py',
            duration: Duration(milliseconds: 200),
            timedOut: false,
          ),
          // pytest succeeds on retry
          _ok('tests pass'),
        ]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(root);

        expect(outcome.executed, isTrue);
        expect(runner.invocations.map((e) => e.command), [
          'ruff check .',
          'pytest',
          'pytest', // flake retry
        ]);
        expect(outcome.summary, contains('attempts=2'));
      },
    );

    test(
      'non-Dart project recognizes npm test as test command for flake retry',
      () async {
        final root = _createProject('''
project:
  type: "node"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "npm test"
  quality_gate:
    enabled: true
    flake_retry_count: 1
    commands:
      - "npm test"
''');

        final runner = _FakeShellCommandRunner([
          const ShellCommandResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Error: Test failed',
            duration: Duration(milliseconds: 150),
            timedOut: false,
          ),
          _ok('tests pass'),
        ]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(root);

        expect(outcome.executed, isTrue);
        expect(runner.invocations.map((e) => e.command), [
          'npm test',
          'npm test', // flake retry
        ]);
      },
    );

    test('non-Dart project recognizes cargo test for flake retry', () async {
      final root = _createProject('''
project:
  type: "rust"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "cargo test"
  quality_gate:
    enabled: true
    flake_retry_count: 1
    commands:
      - "cargo test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'test result: FAILED',
          duration: Duration(milliseconds: 200),
          timedOut: false,
        ),
        _ok('tests pass'),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(runner.invocations.map((e) => e.command), [
        'cargo test',
        'cargo test', // flake retry
      ]);
    });

    test('non-Dart lint failure is NOT retried as flaky', () async {
      final root = _createProject('''
project:
  type: "python"

policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "ruff check"
    - "pytest"
  quality_gate:
    enabled: true
    flake_retry_count: 1
    commands:
      - "ruff check ."
      - "pytest"
''');

      final runner = _FakeShellCommandRunner([
        // ruff check fails — not a test command, should not be retried
        const ShellCommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'ruff: Found 3 errors',
          duration: Duration(milliseconds: 80),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      // Non-test command failure throws StateError (hard fail, no retry).
      await expectLater(() => service.run(root), throwsA(isA<StateError>()));
      // Only one invocation — no retry for lint commands
      expect(runner.invocations.map((e) => e.command), ['ruff check .']);
    });

    test(
      'Dart project with null projectType still uses adaptive scoping',
      () async {
        // Regression guard: existing Dart projects without project.type
        // must continue to use adaptive diff logic as before.
        final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "dart test"
''');

        final runner = _FakeShellCommandRunner([
          _ok('analysis ok'),
          _ok('tests ok'),
        ]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(root);

        expect(outcome.executed, isTrue);
        // With no changedPaths and null projectType, uses configured profile
        expect(outcome.profile, 'configured');
        expect(runner.invocations.map((e) => e.command), [
          'dart analyze',
          'dart test',
        ]);
      },
    );

    test(
      'Dart project with explicit dart_flutter type uses adaptive scoping',
      () async {
        final root = _createProject('''
project:
  type: "dart_flutter"

policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --coverage"
''');
        _writeFakePackageConfig(root);

        final runner = _FakeShellCommandRunner([
          _ok('analysis ok'),
          _ok('tests ok'),
        ]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(
          root,
          changedPaths: const ['lib/core/service.dart'],
        );

        expect(outcome.executed, isTrue);
        // Explicit dart_flutter type preserves adaptive behavior
        expect(outcome.profile, 'lib_dart_only');
      },
    );

    test(
      'unknown project type with empty commands produces disabled quality gate',
      () async {
        final root = _createProject('''
project:
  type: "unknown"

policies:
  quality_gate:
    enabled: false
''');

        final runner = _FakeShellCommandRunner([]);
        final service = BuildTestRunnerService(commandRunner: runner);

        final outcome = await service.run(root);

        expect(outcome.executed, isFalse);
        expect(runner.invocations, isEmpty);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ShellCommandResult _ok(String stdout) => ShellCommandResult(
  exitCode: 0,
  stdout: stdout,
  stderr: '',
  duration: const Duration(milliseconds: 100),
  timedOut: false,
);

String _createProject(String configYaml) {
  final temp = Directory.systemTemp.createTempSync('genaisys_lang_gate_');
  addTearDown(() {
    temp.deleteSync(recursive: true);
  });

  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  final layout = ProjectLayout(temp.path);
  File(layout.configPath).writeAsStringSync(configYaml.trimLeft());
  return temp.path;
}

void _writeFakePackageConfig(String root) {
  final dir = Directory('$root/.dart_tool')..createSync(recursive: true);
  File('${dir.path}/package_config.json').writeAsStringSync('{}\n');
}

class _FakeShellCommandRunner implements ShellCommandRunner {
  _FakeShellCommandRunner(this._results);

  final List<ShellCommandResult> _results;
  final List<_Invocation> invocations = <_Invocation>[];
  var _index = 0;

  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    invocations.add(
      _Invocation(
        command: command,
        workingDirectory: workingDirectory,
        timeout: timeout,
      ),
    );
    if (_index >= _results.length) {
      throw StateError('No fake result configured for "$command"');
    }
    final result = _results[_index];
    _index += 1;
    return result;
  }
}

class _Invocation {
  const _Invocation({
    required this.command,
    required this.workingDirectory,
    required this.timeout,
  });

  final String command;
  final String workingDirectory;
  final Duration timeout;
}
