import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI activate rejects non-unique title', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_title_conflict_',
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
- [ ] [P2] [CORE] Alpha
''');

    exitCode = 0;
    await runner.run(['activate', '--title', 'Alpha', temp.path]);

    expect(exitCode, 2);
    final state = StateStore(layout.statePath).read();
    expect(state.activeTaskTitle, isNull);
  });

  test('CLI activate prefix match picks shortest (most specific) title',
      () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_prefix_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Create Task model
- [ ] [P1] [CORE] Create Task model and add migration
''');

    exitCode = 0;
    await runner.run(['activate', '--title', 'Create Task', temp.path]);

    expect(exitCode, 0);
    final state = StateStore(layout.statePath).read();
    expect(state.activeTaskTitle, 'Create Task model');
  });
}
