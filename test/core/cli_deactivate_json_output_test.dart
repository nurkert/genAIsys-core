import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI deactivate --json reports cleared active task', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_deactivate_json_output_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: ActiveTaskState(title: 'Alpha', id: 'alpha-1'),
      ),
    );

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'deactivate',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['deactivated'], true);
    expect(decoded['keep_review'], false);
    expect(decoded['active_task'], isNull);
    expect(decoded['active_task_id'], isNull);
    expect(decoded['review_status'], isNull);
    expect(decoded['review_updated_at'], isNull);
  });

  test('CLI deactivate --json keeps review status when requested', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_deactivate_json_keep_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: ActiveTaskState(
          title: 'Alpha',
          id: 'alpha-1',
          reviewStatus: 'approved "manual"',
          reviewUpdatedAt: '2026-02-03T00:00:00Z',
        ),
      ),
    );

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'deactivate',
      '--keep-review',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['deactivated'], true);
    expect(decoded['keep_review'], true);
    expect(decoded['active_task'], isNull);
    expect(decoded['active_task_id'], isNull);
    expect(decoded['review_status'], 'approved "manual"');
    expect(decoded['review_updated_at'], '2026-02-03T00:00:00Z');
  });
}
