import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'support/cli_json_output_helper.dart';
import '../support/locked_dart_runner.dart';

void main() {
  test('status --json includes normalized failure reason fields', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_status_failure_reason_json_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    await CliRunner().run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    final state = store.read().copyWith(
      autopilotRun: AutopilotRunState(
        lastError: 'Git repo has uncommitted changes.',
        lastErrorClass: 'delivery',
        lastErrorKind: 'git_dirty',
      ),
    );
    store.write(state);

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'status',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final decoded =
        jsonDecode(firstJsonPayload(result.stdout.toString()))
            as Map<String, dynamic>;
    expect(decoded['last_error'], 'Git repo has uncommitted changes.');
    expect(decoded['last_error_class'], 'delivery');
    expect(decoded['last_error_kind'], 'git_dirty');
  });

  test(
    'status --json includes provider failure reason fields',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_provider_failure_reason_json_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      await CliRunner().run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      final state = store.read().copyWith(
        autopilotRun: AutopilotRunState(
          lastError: 'Provider pool exhausted by quota limits.',
          lastErrorClass: 'provider',
          lastErrorKind: 'provider_quota',
        ),
      );
      store.write(state);

      final result = runLockedDartSync(<String>[
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'status',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final decoded =
          jsonDecode(firstJsonPayload(result.stdout.toString()))
              as Map<String, dynamic>;
      expect(decoded['last_error'], 'Provider pool exhausted by quota limits.');
      expect(decoded['last_error_class'], 'provider');
      expect(decoded['last_error_kind'], 'provider_quota');
    },
  );

  test(
    'status --json preserves compatibility placeholders for empty edge values',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_json_edge_values_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      await CliRunner().run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      final state = store.read().copyWith(
        activeTask: ActiveTaskState(
          title: '   ',
          id: '',
          reviewStatus: '',
          reviewUpdatedAt: ' ',
        ),
        lastUpdated: '',
      );
      store.write(state);

      final result = runLockedDartSync(<String>[
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'status',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final decoded =
          jsonDecode(firstJsonPayload(result.stdout.toString()))
              as Map<String, dynamic>;
      expect(decoded['active_task'], '(none)');
      expect(decoded['active_task_id'], '(none)');
      expect(decoded['review_status'], '(none)');
      expect(decoded['review_updated_at'], '(none)');
      expect(decoded['last_updated'], '(unknown)');
      expect(decoded['tasks_total'], isA<int>());
      expect(decoded['tasks_open'], isA<int>());
      expect(decoded['tasks_blocked'], isA<int>());
      expect(decoded['tasks_done'], isA<int>());
      expect(decoded['health'], isA<Map<String, dynamic>>());
      expect(decoded['telemetry'], isA<Map<String, dynamic>>());
    },
  );

}
