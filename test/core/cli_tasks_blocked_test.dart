import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI tasks supports blocked filter', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_blocked_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [BLOCKED] [P1] [CORE] Waiting on API key (Reason: Missing creds)
- [ ] [P2] [CORE] Unblocked task
''');

    exitCode = 0;
    await runner.run(['tasks', '--blocked', temp.path]);

    expect(exitCode, 0);
  });
}
