import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI activate --json returns valid JSON for escaped titles', () async {
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
    expect(decoded['task']?['title'] ?? decoded['title'], 'Alpha "Beta"');
  });

  test(
    'CLI activate --json skips interaction task when GUI parity metadata is missing',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_json_parity_missing_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] [INTERACTION] Add CLI status command
- [ ] [P1] [CORE] Fallback task
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
      expect(
        decoded['task']?['title'] ?? decoded['title'],
        'Fallback task',
      );
    },
  );
}
