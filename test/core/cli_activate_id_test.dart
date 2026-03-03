import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test('CLI activate supports id selector', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_activate_id_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
- [ ] [P1] [CORE] Beta
''');

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final target = tasks.firstWhere((task) => task.title == 'Beta');

    await runner.run(['activate', '--id', target.id, temp.path]);

    final state = StateStore(layout.statePath).read();
    expect(state.activeTaskId, target.id);
    expect(state.activeTaskTitle, 'Beta');
  });
}
