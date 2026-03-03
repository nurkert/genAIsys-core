import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI spec init creates spec file for active task', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_spec_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(title: 'My Task'),
        workflowStage: WorkflowStage.planning,
      ),
    );

    await runner.run(['scaffold', 'spec', temp.path]);

    final specPath =
        '${layout.taskSpecsDir}${Platform.pathSeparator}my-task.md';
    expect(File(specPath).existsSync(), isTrue);

    final updated = stateStore.read();
    expect(updated.workflowStage, WorkflowStage.execution);
  });
}
