import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI activate supports section filter', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_section_',
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

## Review
- [ ] [P1] [CORE] Beta
''');

    exitCode = 0;
    await runner.run(['activate', '--section', 'Review', temp.path]);

    expect(exitCode, 0);
  });
}
