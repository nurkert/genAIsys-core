import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI status supports json output', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_status_json_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(workflowStage: WorkflowStage.execution),
    );
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    exitCode = 0;
    await runner.run(['status', '--json', temp.path]);
    expect(exitCode, 0);
  });
}
