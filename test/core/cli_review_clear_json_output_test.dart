import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI review clear --json returns valid JSON payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_clear_json_',
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
        activeTask: ActiveTaskState(
          reviewStatus: 'approved',
          reviewUpdatedAt: '2026-02-03T00:00:00Z',
        ),
      ),
    );

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'review',
      'clear',
      '--note',
      'Reset "after fix"',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['review_cleared'], true);
    expect(decoded['review_status'], '(none)');
    expect(decoded['review_updated_at'], '(none)');
    expect(decoded['note'], 'Reset "after fix"');
  });

  test(
    'CLI review clear --json returns JSON error when state is missing',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_clear_json_error_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final result = runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'review',
        'clear',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 2);
      final output = result.stdout.toString().trim();
      expect(output, isNotEmpty);
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['code'], 'state_error');
      expect(
        (decoded['error'] as String),
        startsWith('No STATE.json found at:'),
      );
    },
  );
}
