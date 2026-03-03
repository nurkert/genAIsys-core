import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI done requires review approval', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_done_review_');
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
    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(
      activeTask: ActiveTaskState(title: 'Alpha'),
    ));

    exitCode = 0;
    await runner.run(['done', temp.path]);

    expect(exitCode, 2);
  });
}
