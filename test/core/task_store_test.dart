import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskStore parses tasks with sections, priority and category', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_tasks_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final tasksFile = File('${temp.path}${Platform.pathSeparator}TASKS.md');
    tasksFile.writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Bootstrap engine
- [x] [P2] [UI] Polish UI shell
- [ ] [BLOCKED] [P1] [SEC] Waiting on credentials (Reason: Access)

## Review
- [ ] P3: [REF] Debt cleanup
''');

    final store = TaskStore(tasksFile.path);
    final tasks = store.readTasks();

    expect(tasks.length, 4);
    expect(tasks[0].priority, TaskPriority.p1);
    expect(tasks[0].category, TaskCategory.core);
    expect(tasks[0].completion, TaskCompletion.open);
    expect(tasks[0].section, 'Backlog');

    expect(tasks[1].completion, TaskCompletion.done);
    expect(tasks[1].category, TaskCategory.ui);

    expect(tasks[2].blocked, isTrue);
    expect(tasks[2].category, TaskCategory.security);

    expect(tasks[3].section, 'Review');
    expect(tasks[3].category, TaskCategory.refactor);
  });

  test(
    'TaskStore hasOpenP1StabilizationTask reports true for open P1 stabilization and malformed metadata edges',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_tasks_stabilization_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksFile = File('${temp.path}${Platform.pathSeparator}TASKS.md');
      tasksFile.writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Closed stabilization task
- [ ] [P2] [CORE] Non-P1 stabilization
- [ ] [P1] Stabilization category missing
- [ ] [ARCH] Stabilization priority missing
''');

      final store = TaskStore(tasksFile.path);
      expect(store.hasOpenP1StabilizationTask(), isTrue);
    },
  );

  test(
    'TaskStore hasOpenP1StabilizationTask reports false when no open P1 stabilization signal exists',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_tasks_no_stabilization_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksFile = File('${temp.path}${Platform.pathSeparator}TASKS.md');
      tasksFile.writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Closed stabilization task
- [ ] [P3] [UI] Improve dashboard visuals
- [ ] [P2] [DOCS] Update docs
''');

      final store = TaskStore(tasksFile.path);
      expect(store.hasOpenP1StabilizationTask(), isFalse);
    },
  );

  test(
    'TaskStore hasOpenP1StabilizationTask reports true for open tasks in stabilization sections with missing metadata',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_tasks_stabilization_section_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksFile = File('${temp.path}${Platform.pathSeparator}TASKS.md');
      tasksFile.writeAsStringSync('''# Tasks

## Stabilization Wave 1: Runtime Correctness
- [ ] Harden scheduler replay evidence
- [x] [P1] [CORE] Closed stabilization task
''');

      final store = TaskStore(tasksFile.path);
      expect(store.hasOpenP1StabilizationTask(), isTrue);
    },
  );

  test(
    'TaskStore hasOpenP1StabilizationTask reports true for indented open P1 tasks with missing category metadata',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_tasks_indented_stabilization_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksFile = File('${temp.path}${Platform.pathSeparator}TASKS.md');
      tasksFile.writeAsStringSync('''# Tasks

## Backlog
  - [ ] [P1] Missing category should still block UI work
- [ ] [P2] [UI] Unrelated task
''');

      final store = TaskStore(tasksFile.path);
      expect(store.hasOpenP1StabilizationTask(), isTrue);
    },
  );
}
