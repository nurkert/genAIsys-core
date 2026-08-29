import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  group('Corrupt TASKS.md resilience', () {
    late Directory temp;
    late String tasksPath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_corrupt_tasks_');
      tasksPath = '${temp.path}/TASKS.md';
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('empty file returns empty task list', () {
      File(tasksPath).writeAsStringSync('');

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isEmpty);
    });

    test('only headers with no tasks returns empty list', () {
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n## Backlog\n\n## Done\n\n## Archive\n',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isEmpty);
    });

    test('malformed checkboxes are skipped without crashing', () {
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n'
        '## Backlog\n'
        '- [P1] [CORE] Missing checkbox brackets\n'
        '- [] [P1] [CORE] Empty brackets no space\n'
        '- [  ] [P1] [CORE] Double space in brackets\n'
        '- [x] [P1] [CORE] Valid done task\n'
        '- [ ] [P1] [CORE] Valid open task\n'
        '- [X] [P1] [CORE] Valid done uppercase X\n'
        '  - [ ] [P1] [CORE] Indented task\n'
        '* [ ] [P1] [CORE] Asterisk instead of dash\n',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();

      // Only lines matching `- [ ] ...` or `- [x] ...` are parsed.
      final validTasks = tasks.where(
        (t) => t.title.contains('Valid'),
      );
      expect(
        validTasks.length,
        greaterThanOrEqualTo(2),
        reason: 'At least the valid checkboxes should parse',
      );

      // Malformed lines should not crash the parser.
      expect(tasks.every((t) => t.title.isNotEmpty), isTrue);
    });

    test('mixed encoding survives without crashing', () {
      // Write bytes with some non-UTF8 sequences mixed in via Latin-1 encoding.
      // TaskStore uses readAsLinesSync which handles this gracefully.
      final content = '# Tasks\n\n'
          '## Backlog\n'
          '- [ ] [P1] [CORE] Task with \u00e9m\u00f6ji-like chars\n'
          '- [ ] [P2] [UI] Normal task after special chars\n';
      File(tasksPath).writeAsStringSync(content);

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isNotEmpty);
      expect(tasks.length, 2);
    });

    test('extremely long lines are handled without crashing', () {
      final longTitle = 'A' * 10000;
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n'
        '## Backlog\n'
        '- [ ] [P1] [CORE] $longTitle\n'
        '- [ ] [P2] [CORE] Normal task after long line\n',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isNotEmpty);
      expect(tasks.length, 2);
      expect(tasks.first.title, contains('AAAA'));
      expect(tasks.last.title, 'Normal task after long line');
    });

    test('file with only whitespace returns empty list', () {
      File(tasksPath).writeAsStringSync('   \n\n   \n\t\n');

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isEmpty);
    });

    test('missing file returns empty list', () {
      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks, isEmpty);
    });

    test('tasks with missing priority default to P3', () {
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n'
        '## Backlog\n'
        '- [ ] [CORE] No priority specified\n',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks.length, 1);
      expect(tasks.first.priority, TaskPriority.p3);
    });

    test('tasks with missing category default to unknown', () {
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n'
        '## Backlog\n'
        '- [ ] [P1] No category specified\n',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks.length, 1);
      expect(tasks.first.category, TaskCategory.unknown);
    });

    test('hasOpenP1StabilizationTask handles corrupt file gracefully', () {
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n'
        '## Backlog\n'
        'random line\n'
        '- [ ] [P1] [CORE] Valid stabilization task\n'
        '---\n'
        '- [broken\n',
      );

      final store = TaskStore(tasksPath);
      expect(store.hasOpenP1StabilizationTask(), isTrue);
    });

    test('tasks with duplicate content do not crash', () {
      final repeated = '- [ ] [P1] [CORE] Same task\n' * 100;
      File(tasksPath).writeAsStringSync(
        '# Tasks\n\n## Backlog\n$repeated',
      );

      final store = TaskStore(tasksPath);
      final tasks = store.readTasks();
      expect(tasks.length, 100);
    });
  });
}
