import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test(
    'CLI activate rejects deferred non-critical UI title during stabilization',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_title_deferred_ui_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Stabilize provider handling
- [ ] [P3] [UI] Improve dashboard visuals
''');

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        'Improve dashboard visuals',
        temp.path,
      ]);

      expect(exitCode, 2);
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskTitle, isNull);
    },
  );

  test(
    'CLI activate rejects deferred UI title when stabilization metadata is incomplete',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_title_deferred_ui_malformed_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] Stabilization metadata incomplete
- [ ] [P3] [UI] Improve dashboard visuals
''');

      exitCode = 0;
      await runner.run([
        'activate',
        '--title',
        'Improve dashboard visuals',
        temp.path,
      ]);

      expect(exitCode, 2);
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskTitle, isNull);
    },
  );
}
