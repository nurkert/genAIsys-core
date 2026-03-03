import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test(
    'CLI activate rejects interaction task with missing GUI parity metadata',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_parity_missing_',
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
''');

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        '[INTERACTION] Add CLI status command',
        temp.path,
      ]);

      expect(exitCode, 2);
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskTitle, isNull);

      final last = _readLastRunLogEvent(layout);
      expect(last['event'], 'activate_task_policy_blocked');
      final data = last['data'] as Map<String, dynamic>;
      expect(data['error_class'], 'policy');
      expect(data['error_kind'], 'cli_gui_parity_missing');
    },
  );

  test(
    'CLI activate rejects interaction task with broken GUI parity link',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_parity_broken_link_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] [INTERACTION] [GUI_PARITY:missing-ui-123] Add CLI status command
''');

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        '[INTERACTION] [GUI_PARITY:missing-ui-123] Add CLI status command',
        temp.path,
      ]);

      expect(exitCode, 2);
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskTitle, isNull);
    },
  );

  test(
    'CLI activate accepts interaction task with GUI_PARITY:DONE marker',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_parity_done_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] [INTERACTION] [GUI_PARITY:DONE] Add CLI status command
''');

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        '[INTERACTION] [GUI_PARITY:DONE] Add CLI status command',
        temp.path,
      ]);

      expect(exitCode, 0);
      final state = StateStore(layout.statePath).read();
      expect(
        state.activeTaskTitle,
        '[INTERACTION] [GUI_PARITY:DONE] Add CLI status command',
      );
    },
  );

  test(
    'CLI activate accepts interaction task with deferred GUI parity task id',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_parity_linked_ui_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P2] [UI] Build GUI status controls
- [ ] [P1] [CORE] [INTERACTION] [GUI_PARITY:GUI_TASK_ID] Add CLI status command
''');

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final uiTask = tasks.firstWhere(
        (task) => task.category == TaskCategory.ui,
      );
      final updated = File(
        layout.tasksPath,
      ).readAsStringSync().replaceAll('GUI_TASK_ID', uiTask.id);
      File(layout.tasksPath).writeAsStringSync(updated);

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        '[INTERACTION] [GUI_PARITY:${uiTask.id}] Add CLI status command',
        temp.path,
      ]);

      expect(exitCode, 0);
      final state = StateStore(layout.statePath).read();
      expect(
        state.activeTaskTitle,
        '[INTERACTION] [GUI_PARITY:${uiTask.id}] Add CLI status command',
      );
    },
  );
}

Map<String, dynamic> _readLastRunLogEvent(ProjectLayout layout) {
  final lines = File(
    layout.runLogPath,
  ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
  final last = lines.isEmpty ? '{}' : lines.last;
  return Map<String, dynamic>.from(jsonDecode(last) as Map);
}
