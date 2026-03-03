import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI subtasks init --json returns valid JSON payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_subtasks_init_json_',
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
        activeTask: ActiveTaskState(title: 'My Task'),
        workflowStage: WorkflowStage.planning,
      ),
    );

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'scaffold',
      'subtasks',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    final expectedPath =
        '${layout.taskSpecsDir}${Platform.pathSeparator}my-task-subtasks.md';

    expect(decoded['created'], true);
    expect(decoded['path'], expectedPath);
  });
}
