import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI review reject --json returns valid JSON payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_reject_json_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(title: 'Alpha "Beta"'),
      ),
    );

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'review',
      'reject',
      '--note',
      'Still "failing"',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['review_recorded'], true);
    expect(decoded['decision'], 'rejected');
    expect(decoded['task_title'], 'Alpha "Beta"');
    expect(decoded['note'], 'Still "failing"');
  });

  test(
    'CLI review reject --json returns JSON error when no active task',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_reject_json_error_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final result = runLockedDartSync(<String>[
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'review',
        'reject',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 2);
      final output = result.stdout.toString().trim();
      expect(output, isNotEmpty);
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['code'], 'state_error');
      expect(decoded['error'], 'No active task set. Use: activate');
    },
  );
}
