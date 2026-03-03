import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI block --json returns valid JSON payload with reason', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_block_json_output_',
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
    final store = StateStore(layout.statePath);
    store.write(store.read().copyWith(
      activeTask: ActiveTaskState(title: 'Alpha'),
    ));

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'block',
      '--reason',
      'Needs "input"',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['blocked'], true);
    expect(decoded['task_title'], 'Alpha');
    expect(decoded['reason'], 'Needs "input"');
  });

  test('CLI block --json returns null reason when omitted', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_block_json_no_reason_',
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
    final store = StateStore(layout.statePath);
    store.write(store.read().copyWith(
      activeTask: ActiveTaskState(title: 'Alpha'),
    ));

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'block',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['blocked'], true);
    expect(decoded['task_title'], 'Alpha');
    expect(decoded['reason'], isNull);
  });
}
