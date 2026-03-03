import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI activate rejects using id and title together', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_title_id_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    exitCode = 0;
    await runner.run([
      'activate',
      '--id',
      'alpha-0',
      '--title',
      'Alpha',
      temp.path,
    ]);

    expect(exitCode, 64);
  });
}
