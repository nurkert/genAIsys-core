import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test(
    'CLI activate allows auto-cycle blocked task when reactivation is enabled',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_blocked_autocycle_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final configFile = File(layout.configPath);
      configFile.writeAsStringSync(
        configFile.readAsStringSync().replaceFirst(
          'reactivate_blocked: false',
          'reactivate_blocked: true',
        ),
      );

      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [BLOCKED] [P1] [CORE] Retry provider fallback (Reason: Auto-cycle: review rejected 3 time(s))
''');

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final target = tasks.first;

      exitCode = 0;
      await runner.run(['activate', '--id', target.id, temp.path]);

      expect(exitCode, 0);
      final state = StateStore(layout.statePath).read();
      expect(
        state.activeTaskTitle,
        'Retry provider fallback (Reason: Auto-cycle: review rejected 3 time(s))',
      );
    },
  );

  test(
    'CLI activate rejects non-auto-cycle blocked task when reactivation is enabled',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_blocked_manual_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final configFile = File(layout.configPath);
      configFile.writeAsStringSync(
        configFile.readAsStringSync().replaceFirst(
          'reactivate_blocked: false',
          'reactivate_blocked: true',
        ),
      );

      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [BLOCKED] [P2] [CORE] Native runtime wave task
''');

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final target = tasks.first;

      exitCode = 0;
      await runner.run(['activate', '--id', target.id, temp.path]);

      expect(exitCode, 2);
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskTitle, isNull);
    },
  );
}
