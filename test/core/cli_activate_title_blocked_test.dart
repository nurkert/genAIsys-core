import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI activate rejects blocked title', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_title_blocked_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [BLOCKED] [P1] [CORE] Waiting on API key
''');

    exitCode = 0;
    await runner.run(['activate', '--title', 'Waiting on API key', temp.path]);

    expect(exitCode, 2);
    final state = StateStore(layout.statePath).read();
    expect(state.activeTaskTitle, isNull);
  });
}
