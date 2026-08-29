import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI deactivate clears active task in STATE.json', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_deactivate_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    final seeded = stateStore.read().copyWith(
      activeTask: ActiveTaskState(title: 'Seed'),
    );
    stateStore.write(seeded);

    await runner.run(['deactivate', temp.path]);

    final state = stateStore.read();
    expect(state.activeTaskTitle, isNull);
  });
}
