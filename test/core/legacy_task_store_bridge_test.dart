import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/task_store.dart' as storage;
import 'package:genaisys/core/tasks/task_store.dart' as legacy;

void main() {
  test('legacy TaskStore listTasks delegates to shared task parser', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_legacy_task_store_list_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
- [x] [P2] [UI] Beta
- [ ] [BLOCKED] [P1] [SEC] Gamma (Reason: Waiting)
''');

    final tasks = legacy.TaskStore(temp.path).listTasks();

    expect(tasks.length, 3);
    expect(tasks[0].title, 'Alpha');
    expect(tasks[0].priority, 'P1');
    expect(tasks[0].category, 'CORE');
    expect(tasks[0].status, legacy.TaskStatus.open);

    expect(tasks[1].title, 'Beta');
    expect(tasks[1].status, legacy.TaskStatus.done);
    expect(tasks[1].category, 'UI');

    expect(tasks[2].title, 'Gamma (Reason: Waiting)');
    expect(tasks[2].status, legacy.TaskStatus.blocked);
    expect(tasks[2].category, 'SEC');
  });

  test('legacy TaskStore markDone delegates to shared task writer', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_legacy_task_store_done_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    legacy.TaskStore(temp.path).markDone('Alpha');
    final parsed = storage.TaskStore(layout.tasksPath).readTasks();

    expect(parsed.single.completion.name, 'done');
  });

  test('legacy TaskStore markBlocked delegates to shared task writer', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_legacy_task_store_blocked_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    legacy.TaskStore(temp.path).markBlocked('Alpha', 'Needs input');
    final parsed = storage.TaskStore(layout.tasksPath).readTasks();

    expect(parsed.single.blocked, isTrue);
    expect(parsed.single.blockReason, 'Needs input');
  });
}
