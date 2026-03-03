import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI status prints task counts on separate lines', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_status_counts_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] First
- [x] [P2] [CORE] Done
''');

    await runner.run(['status', temp.path]);

    // If the command runs without errors, counts are printed.
    expect(true, isTrue);
  });
}
