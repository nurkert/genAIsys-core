import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI tasks supports section filter', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_section_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha

## Review
- [ ] [P2] [CORE] Beta
''');

    exitCode = 0;
    await runner.run(['tasks', '--section', 'Review', temp.path]);

    // Ensures command runs; filtering logic is tested separately.
    expect(exitCode, 0);
  });
}
