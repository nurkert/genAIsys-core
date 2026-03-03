import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test('CLI activate supports show ids', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_activate_ids_');
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

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final expectedId = tasks.first.id;

    exitCode = 0;
    await runner.run(['activate', '--show-ids', temp.path]);

    expect(exitCode, 0);
    expect(expectedId, isNotEmpty);
  });
}
