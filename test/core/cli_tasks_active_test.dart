import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test('CLI tasks supports active filter', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_tasks_active_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
- [ ] [P2] [CORE] Beta
''');

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final active = tasks.firstWhere((task) => task.title == 'Beta');
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(id: active.id, title: active.title),
      ),
    );

    exitCode = 0;
    await runner.run(['tasks', '--active', temp.path]);

    expect(exitCode, 0);

    final logFile = File(layout.runLogPath);
    final lines = logFile.readAsLinesSync();
    expect(lines, isNotEmpty);
    final last = jsonDecode(lines.last) as Map<String, dynamic>;
    final data = last['data'] as Map<String, dynamic>;
    expect(data['active_only'], true);
  });
}
