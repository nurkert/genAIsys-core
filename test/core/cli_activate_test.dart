import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI activate sets active task title in STATE.json', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_activate_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P2] [CORE] Second
- [ ] [P1] [CORE] First
''');

    await runner.run(['activate', temp.path]);

    final state = StateStore(layout.statePath).read();
    expect(state.activeTaskTitle, 'First');
    expect(state.workflowStage, WorkflowStage.planning);
  });
}
