import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI status runs with active task id', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_status_id_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    final seeded = stateStore.read().copyWith(
      activeTask: ActiveTaskState(title: 'Seed Task', id: 'seed-task-1'),
    );
    stateStore.write(seeded);

    await runner.run(['status', temp.path]);

    final state = stateStore.read();
    expect(state.activeTaskId, 'seed-task-1');
  });
}
