import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI tasks logs show ids flag', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_tasks_ids_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'tasks',
      '--show-ids',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('[id:'));
  });
}
