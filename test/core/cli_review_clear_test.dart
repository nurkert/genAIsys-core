import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI review clear resets review fields', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_clear_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(
          reviewStatus: 'approved',
          reviewUpdatedAt: '2026-02-03T00:00:00Z',
        ),
        workflowStage: WorkflowStage.review,
      ),
    );

    exitCode = 0;
    await runner.run(['review', 'clear', temp.path]);

    expect(exitCode, 0);
    final updated = stateStore.read();
    expect(updated.reviewStatus, isNull);
    expect(updated.reviewUpdatedAt, isNull);
    expect(updated.workflowStage, WorkflowStage.execution);
  });
}
