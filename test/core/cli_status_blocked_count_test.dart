import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI status logs blocked task count', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_status_blocked_',
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
- [ ] [P2] [CORE] Unblocked
''');

    await runner.run(['status', temp.path]);

    final logFile = File(layout.runLogPath);
    final lines = logFile.readAsLinesSync();
    expect(lines, isNotEmpty);
    final last = jsonDecode(lines.last) as Map<String, dynamic>;
    final data = last['data'] as Map<String, dynamic>;

    expect(data['tasks_blocked'], 1);
  });
}
