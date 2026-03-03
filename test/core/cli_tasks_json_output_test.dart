import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI tasks --json returns valid JSON for escaped titles', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_tasks_json_output_',
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

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'tasks',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);
    final decoded = jsonDecode(output) as Map<String, dynamic>;
    final tasks = decoded['tasks'] as List<dynamic>;
    expect(tasks, hasLength(1));
    final first = tasks.first as Map<String, dynamic>;
    expect(first['title'], 'Alpha "Beta"');
  });
}
