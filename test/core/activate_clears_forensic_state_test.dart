import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('activate clears forensic state from previous task', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_forensic_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] New task to activate
''');

    // Seed STATE.json with stale forensic data (as if a previous task
    // underwent forensic recovery and was then abandoned).
    final stateStore = StateStore(layout.statePath);
    final seeded = stateStore.read().copyWith(
      activeTask: const ActiveTaskState(
        forensicRecoveryAttempted: true,
        forensicGuidance: 'Previous task had spec issues',
      ),
    );
    stateStore.write(seeded);

    // Verify the seeded state.
    final beforeActivate = stateStore.read();
    expect(beforeActivate.forensicRecoveryAttempted, isTrue);
    expect(beforeActivate.forensicGuidance, 'Previous task had spec issues');

    // Activate a new task — forensic state should be cleared.
    await runner.run(['activate', temp.path]);

    final afterActivate = stateStore.read();
    expect(afterActivate.activeTaskTitle, 'New task to activate');
    expect(afterActivate.forensicRecoveryAttempted, isFalse);
    expect(afterActivate.forensicGuidance, isNull);
  });
}
