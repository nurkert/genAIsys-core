import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test(
    'CLI activate --json returns valid JSON payload for activated task',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_json_output_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha "Beta"
''');

      final result = runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'activate',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString().trim();
      expect(output, isNotEmpty);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['activated'], true);
      final task = decoded['task'] as Map<String, dynamic>;
      expect(task['title'], 'Alpha "Beta"');
      expect(task['status'], 'open');
    },
  );

  test('CLI activate --json reports false when no open task exists', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_json_none_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Finished
''');

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'activate',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['activated'], false);
    expect(decoded['task'], isNull);
  });
}
