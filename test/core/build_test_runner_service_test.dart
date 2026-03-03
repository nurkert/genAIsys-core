import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';

void main() {
  test(
    'BuildTestRunnerService executes configured quality gate commands',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 15
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 120),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 340),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(outcome.summary, isNotNull);
      expect(
        outcome.summary,
        contains('Quality Gate: passed (2 checks, profile=configured)'),
      );
      expect(outcome.profile, 'configured');
      expect(outcome.summary, contains('`dart analyze`'));
      expect(outcome.summary, contains('`dart test`'));
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'dart test',
      ]);
      // With remaining-budget tracking, each command gets
      // min(remaining_budget, qualityGateTimeout).  Since the fake runner
      // returns instantly, remaining budget is near-full for every command.
      for (final inv in runner.invocations) {
        expect(
          inv.timeout.inMilliseconds,
          greaterThanOrEqualTo(14900),
          reason: 'Each fast command should receive nearly the full budget',
        );
      }
    },
  );

  test('BuildTestRunnerService fails hard on first failing command', () async {
    final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 20
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart test"
      - "dart test integration"
''');

    final runner = _FakeShellCommandRunner([
      const ShellCommandResult(
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration(milliseconds: 100),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'test failure',
        duration: Duration(milliseconds: 220),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration(milliseconds: 50),
        timedOut: false,
      ),
    ]);
    final service = BuildTestRunnerService(commandRunner: runner);

    await expectLater(
      () => service.run(root),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Policy violation: quality_gate command failed'),
        ),
      ),
    );

    expect(runner.invocations.length, 2);
    expect(runner.invocations.last.command, 'dart test');
  });

  test('BuildTestRunnerService skips execution when disabled', () async {
    final root = _createProject('''
policies:
  quality_gate:
    enabled: false
''');

    final runner = _FakeShellCommandRunner(const []);
    final service = BuildTestRunnerService(commandRunner: runner);

    final outcome = await service.run(root);

    expect(outcome.executed, isFalse);
    expect(outcome.summary, isNull);
    expect(runner.invocations, isEmpty);
  });

  test(
    'BuildTestRunnerService auto-formats changed Dart files before gate',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
''');
      final libDir = Directory('$root/lib')..createSync(recursive: true);
      File('${libDir.path}/demo.dart').writeAsStringSync('void main( ) {}\n');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'formatted',
          stderr: '',
          duration: Duration(milliseconds: 80),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.autoFormatChangedDartFiles(
        root,
        changedPaths: const ['lib/demo.dart', 'README.md'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.files, 1);
      expect(runner.invocations, hasLength(1));
      expect(runner.invocations.single.command, 'dart format lib/demo.dart');
    },
  );

  test('BuildTestRunnerService skips auto-format when no Dart diff', () async {
    final root = _createProject('''
policies:
  quality_gate:
    enabled: true
''');
    final runner = _FakeShellCommandRunner(const []);
    final service = BuildTestRunnerService(commandRunner: runner);

    final outcome = await service.autoFormatChangedDartFiles(
      root,
      changedPaths: const ['docs/notes.md'],
    );

    expect(outcome.executed, isFalse);
    expect(outcome.files, 0);
    expect(runner.invocations, isEmpty);
  });

  test(
    'BuildTestRunnerService blocks command not covered by shell allowlist',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: minimal
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: Duration(milliseconds: 10),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Policy violation: shell_allowlist blocked quality_gate command "dart analyze"',
            ),
          ),
        ),
      );
      expect(runner.invocations, isEmpty);
    },
  );

  test(
    'BuildTestRunnerService blocks command chaining even when prefix matches',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "dart analyze"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze && rm -rf /"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: Duration(milliseconds: 10),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Policy violation: shell_allowlist blocked quality_gate command "dart analyze && rm -rf /"',
            ),
          ),
        ),
      );
      expect(runner.invocations, isEmpty);
    },
  );

  test(
    'BuildTestRunnerService allows command covered by custom shell allowlist',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "dart analyze"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze --fatal-infos"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 150),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze --fatal-infos',
      ]);
    },
  );

  test(
    'BuildTestRunnerService skips test commands for docs-only diffs',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 120),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['docs/vision/notes.md', 'README.md'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'docs_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
      ]);
    },
  );

  test(
    'BuildTestRunnerService rewrites flutter test to dart test for lib dart-only diffs',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "dart test"
    - "dart analyze"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --coverage"
''');
      _writePubspecWithTestDevDependency(root);

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 180),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/core/services/a.dart', 'lib/ui/b.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'lib_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'dart test --coverage',
      ]);
    },
  );

  test(
    'BuildTestRunnerService does not rewrite flutter test to dart test when test dev_dependency is missing',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "flutter test"
    - "dart analyze"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --coverage"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 180),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/core/services/a.dart', 'lib/ui/b.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'lib_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'flutter test --coverage',
      ]);
    },
  );

  test(
    'BuildTestRunnerService narrows lib-only flutter tests to related domain tests when available',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "dart analyze"
    - "flutter test"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --no-pub"
''');
      _writeFakePackageConfig(root);

      final changedLibFile = File(
        '$root/lib/core/cli/handlers/tasks_handler.dart',
      )..createSync(recursive: true);
      changedLibFile.writeAsStringSync('void handleTasks() {}\n');

      final testCoreDir = Directory('$root/test/core')
        ..createSync(recursive: true);
      File('${testCoreDir.path}/cli_tasks_json_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("cli", () => expect(1, 1)); }\n',
      );
      File('${testCoreDir.path}/cli_status_json_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("status", () => expect(1, 1)); }\n',
      );
      File('${testCoreDir.path}/task_store_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("task-store", () => expect(1, 1)); }\n',
      );

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 200),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/core/cli/handlers/tasks_handler.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'lib_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'flutter test --no-pub test/core/cli_status_json_test.dart test/core/cli_tasks_json_test.dart',
      ]);
    },
  );

  test(
    'BuildTestRunnerService narrows test commands to changed test files for test-only diffs',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --no-pub"
''');
      _writeFakePackageConfig(root);

      final testCoreDir = Directory('$root/test/core')
        ..createSync(recursive: true);
      File('${testCoreDir.path}/a_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("a", () => expect(1, 1)); }\n',
      );
      File('${testCoreDir.path}/b_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("b", () => expect(1, 1)); }\n',
      );

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 80),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 180),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['test/core/a_test.dart', 'test/core/b_test.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'test_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'flutter test --no-pub test/core/a_test.dart test/core/b_test.dart',
      ]);
    },
  );

  test(
    'BuildTestRunnerService excludes non-test Dart helpers from narrowed flutter test command',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "flutter test --no-pub"
''');
      _writeFakePackageConfig(root);

      final testCoreDir = Directory('$root/test/core')
        ..createSync(recursive: true);
      File('${testCoreDir.path}/a_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("a", () => expect(1, 1)); }\n',
      );
      final testSupportDir = Directory('$root/test/core/support')
        ..createSync(recursive: true);
      File(
        '${testSupportDir.path}/helper.dart',
      ).writeAsStringSync('String helper() => "ok";\n');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 80),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 180),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const [
          'test/core/a_test.dart',
          'test/core/support/helper.dart',
        ],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'test_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'flutter test --no-pub test/core/a_test.dart',
      ]);
    },
  );

  test(
    'BuildTestRunnerService scopes format check and narrows tests for mixed lib+test Dart diffs',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart format --output=none --set-exit-if-changed ."
      - "dart analyze"
      - "flutter test --no-pub"
''');
      _writeFakePackageConfig(root);

      final testCoreDir = Directory('$root/test/core')
        ..createSync(recursive: true);
      File('${testCoreDir.path}/a_test.dart').writeAsStringSync(
        'import "package:test/test.dart";\n'
        'void main() { test("a", () => expect(1, 1)); }\n',
      );
      final libCoreDir = Directory('$root/lib/core')
        ..createSync(recursive: true);
      File(
        '${libCoreDir.path}/a.dart',
      ).writeAsStringSync('int value() => 1;\n');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'format ok',
          stderr: '',
          duration: Duration(milliseconds: 40),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 90),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 160),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/core/a.dart', 'test/core/a_test.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(outcome.profile, 'lib_test_dart_only');
      expect(runner.invocations.map((entry) => entry.command), [
        'dart format --output=none --set-exit-if-changed lib/core/a.dart test/core/a_test.dart',
        'dart analyze',
        'flutter test --no-pub test/core/a_test.dart',
      ]);
    },
  );

  test(
    'BuildTestRunnerService auto-formats repository baseline when global format check is configured and diff has no Dart files',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart format --output=none --set-exit-if-changed ."
      - "dart analyze"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'baseline format ok',
          stderr: '',
          duration: Duration(milliseconds: 60),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'format check ok',
          stderr: '',
          duration: Duration(milliseconds: 40),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 120),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['.genaisys/task_specs/task.md'],
      );

      expect(outcome.executed, isTrue);
      expect(runner.invocations.map((entry) => entry.command), [
        'dart format .',
        'dart format --output=none --set-exit-if-changed .',
        'dart analyze',
      ]);
    },
  );

  test(
    'BuildTestRunnerService auto-formats repository baseline when global format check remains after Dart diffs',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart format --output=none --set-exit-if-changed ."
      - "dart analyze"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'baseline format ok',
          stderr: '',
          duration: Duration(milliseconds: 60),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'format check ok',
          stderr: '',
          duration: Duration(milliseconds: 40),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 120),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/core/a.dart', 'docs/notes.md'],
      );

      expect(outcome.executed, isTrue);
      expect(runner.invocations.map((entry) => entry.command), [
        'dart format .',
        'dart format --output=none --set-exit-if-changed .',
        'dart analyze',
      ]);
    },
  );

  test('BuildTestRunnerService reruns flaky test command once', () async {
    final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    flake_retry_count: 1
    commands:
      - "dart analyze"
      - "dart test"
''');

    final runner = _FakeShellCommandRunner([
      const ShellCommandResult(
        exitCode: 0,
        stdout: 'analysis ok',
        stderr: '',
        duration: Duration(milliseconds: 100),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'transient failure',
        duration: Duration(milliseconds: 90),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 0,
        stdout: 'retry success',
        stderr: '',
        duration: Duration(milliseconds: 110),
        timedOut: false,
      ),
    ]);
    final service = BuildTestRunnerService(commandRunner: runner);

    final outcome = await service.run(root);

    expect(outcome.executed, isTrue);
    expect(runner.invocations.map((entry) => entry.command), [
      'dart analyze',
      'dart test',
      'dart test',
    ]);
    expect(outcome.summary, contains('attempts=2'));
  });

  test(
    'BuildTestRunnerService returns failure when test command times out',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 10
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 124,
          stdout: '',
          stderr: '',
          duration: Duration(seconds: 10),
          timedOut: true,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Policy violation: quality_gate command timed out'),
              contains('"dart test"'),
            ),
          ),
        ),
      );

      expect(runner.invocations.length, 2);
      expect(runner.invocations.last.command, 'dart test');
    },
  );

  test(
    'BuildTestRunnerService runs flutter pub get before no-pub tests when package_config is missing',
    () async {
      final root = _createProject('''
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "flutter pub get"
    - "dart analyze"
    - "dart test"
  quality_gate:
    enabled: true
    commands:
      - "dart analyze"
      - "dart test --no-pub"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'got deps',
          stderr: '',
          duration: Duration(milliseconds: 250),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 60),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 120),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(
        root,
        changedPaths: const ['lib/a.dart'],
      );

      expect(outcome.executed, isTrue);
      expect(runner.invocations.map((entry) => entry.command), [
        'flutter pub get',
        'dart analyze',
        'dart test --no-pub',
      ]);
    },
  );

  test(
    'BuildTestRunnerService treats dart test exit 65 with no-test output as pass',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 65,
          stdout: '',
          stderr: 'No test suites ran.',
          duration: Duration(milliseconds: 50),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(outcome.summary, isNotNull);
      expect(
        outcome.summary,
        contains('Quality Gate: passed (2 checks, profile=configured)'),
      );
      expect(runner.invocations.map((entry) => entry.command), [
        'dart analyze',
        'dart test',
      ]);

      final layout = ProjectLayout(root);
      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('quality_gate_command_no_tests'));
    },
  );

  test(
    'BuildTestRunnerService treats flutter test exit 65 with no-test output as pass',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "flutter test --no-pub"
''');
      _writeFakePackageConfig(root);

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 100),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 65,
          stdout: 'No test suites ran.',
          stderr: '',
          duration: Duration(milliseconds: 30),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(
        outcome.summary,
        contains('Quality Gate: passed (2 checks, profile=configured)'),
      );
    },
  );

  test(
    'BuildTestRunnerService still fails dart test exit 1 (real failure)',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    flake_retry_count: 0
    commands:
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'Some tests failed.',
          duration: Duration(milliseconds: 200),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Policy violation: quality_gate command failed'),
          ),
        ),
      );
    },
  );

  test(
    'BuildTestRunnerService still fails dart test exit 65 without no-test output',
    () async {
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    flake_retry_count: 0
    commands:
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 65,
          stdout: '',
          stderr: 'Unexpected error in test runner.',
          duration: Duration(milliseconds: 150),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Policy violation: quality_gate command failed'),
          ),
        ),
      );
    },
  );

  test(
    'BuildTestRunnerService caps per-command timeout to remaining budget',
    () async {
      // Configure a 200ms total budget with two commands.
      // The first command takes ~120ms (real delay), so the second command
      // should receive a timeout capped at roughly 80ms (remaining budget).
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 1
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner(
        [
          const ShellCommandResult(
            exitCode: 0,
            stdout: 'analysis ok',
            stderr: '',
            duration: Duration(milliseconds: 500),
            timedOut: false,
          ),
          const ShellCommandResult(
            exitCode: 0,
            stdout: 'tests ok',
            stderr: '',
            duration: Duration(milliseconds: 100),
            timedOut: false,
          ),
        ],
        delays: const [Duration(milliseconds: 500), Duration.zero],
      );
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(runner.invocations.length, 2);

      // The first command should get close to the full 1s budget.
      final firstTimeout = runner.invocations[0].timeout;
      expect(
        firstTimeout.inMilliseconds,
        greaterThanOrEqualTo(900),
        reason: 'First command should receive nearly the full budget',
      );

      // The second command should get the remaining budget (~500ms less).
      final secondTimeout = runner.invocations[1].timeout;
      expect(
        secondTimeout.inMilliseconds,
        lessThan(600),
        reason: 'Second command timeout must be capped to remaining budget',
      );
      expect(
        secondTimeout.inMilliseconds,
        greaterThan(0),
        reason: 'Second command should still have some budget left',
      );
    },
  );

  test(
    'BuildTestRunnerService stops execution when time budget is exhausted',
    () async {
      // Configure a 150ms budget.  The first command consumes all of it.
      // The second command must never start.
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 1
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner(
        [
          const ShellCommandResult(
            exitCode: 0,
            stdout: 'analysis ok',
            stderr: '',
            duration: Duration(seconds: 1),
            timedOut: false,
          ),
          const ShellCommandResult(
            exitCode: 0,
            stdout: 'tests ok',
            stderr: '',
            duration: Duration(milliseconds: 50),
            timedOut: false,
          ),
        ],
        delays: const [Duration(seconds: 1), Duration.zero],
      );
      final service = BuildTestRunnerService(commandRunner: runner);

      await expectLater(
        () => service.run(root),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('quality_gate time budget exhausted'),
              contains('"dart test"'),
              contains('was not started'),
            ),
          ),
        ),
      );

      // Only the first command should have executed.
      expect(runner.invocations.length, 1);
      expect(runner.invocations.first.command, 'dart analyze');
    },
  );

  test(
    'BuildTestRunnerService gives fast commands the full remaining budget',
    () async {
      // Three commands, all instant.  Each should receive nearly the
      // full budget since elapsed time is near zero.
      final root = _createProject('''
policies:
  quality_gate:
    enabled: true
    timeout_seconds: 30
    flake_retry_count: 0
    commands:
      - "dart analyze"
      - "dart format --output=none --set-exit-if-changed lib/"
      - "dart test"
''');

      final runner = _FakeShellCommandRunner([
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'analysis ok',
          stderr: '',
          duration: Duration(milliseconds: 10),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'format ok',
          stderr: '',
          duration: Duration(milliseconds: 10),
          timedOut: false,
        ),
        const ShellCommandResult(
          exitCode: 0,
          stdout: 'tests ok',
          stderr: '',
          duration: Duration(milliseconds: 10),
          timedOut: false,
        ),
      ]);
      final service = BuildTestRunnerService(commandRunner: runner);

      final outcome = await service.run(root);

      expect(outcome.executed, isTrue);
      expect(runner.invocations.length, 3);

      // All commands should receive nearly the full 30s budget.
      for (final inv in runner.invocations) {
        expect(
          inv.timeout.inMilliseconds,
          greaterThanOrEqualTo(29000),
          reason:
              'Fast commands should each receive nearly the full remaining budget',
        );
      }
    },
  );
}

String _createProject(String configYaml) {
  final temp = Directory.systemTemp.createTempSync('genaisys_quality_gate_');
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

void _writePubspecWithTestDevDependency(String root) {
  File('$root/pubspec.yaml').writeAsStringSync('''
name: tmp
description: "tmp"
version: 0.0.0
environment:
  sdk: ^3.0.0
dev_dependencies:
  test: any
''');
}

class _FakeShellCommandRunner implements ShellCommandRunner {
  _FakeShellCommandRunner(this._results, {List<Duration>? delays})
    : _delays = delays;

  final List<ShellCommandResult> _results;
  final List<Duration>? _delays;
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
    final delay = _delays != null && _index < _delays.length
        ? _delays[_index]
        : Duration.zero;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
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
