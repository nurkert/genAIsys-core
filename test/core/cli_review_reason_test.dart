import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI review reject logs reason in run log', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_reason_',
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
        activeTask: ActiveTaskState(title: 'Alpha'),
        workflowStage: WorkflowStage.execution,
      ),
    );

    await runner.run([
      'review',
      'reject',
      '--reason',
      'Needs changes',
      temp.path,
    ]);

    final logFile = File(layout.runLogPath);
    final lines = logFile.readAsLinesSync();
    expect(lines, isNotEmpty);
    final entry = lines
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .lastWhere((item) => item['event'] == 'review_reject');
    final data = entry['data'] as Map<String, dynamic>;

    expect(data['note'], 'Needs changes');

    final updated = stateStore.read();
    expect(updated.workflowStage, WorkflowStage.execution);
  });
}
