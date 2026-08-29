import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'CLI status --json keeps output parity after handler extraction',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_status_handler_json_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
        exitCode = 0;
      });

      final stdoutFile = File('${temp.path}/stdout.txt');
      final stderrFile = File('${temp.path}/stderr.txt');
      final stdoutSink = stdoutFile.openWrite();
      final stderrSink = stderrFile.openWrite();

      String? requestedRoot;
      final api = FakeGenaisysApi()
        ..getStatusHandler = (projectRoot) async {
          requestedRoot = projectRoot;
          return AppResult.success(_statusSnapshot);
        };

      exitCode = 0;
      try {
        await CliRunner(
          api: api,
          stdout: stdoutSink,
          stderr: stderrSink,
        ).run(['status', '--json', '${temp.path}${Platform.pathSeparator}']);
        await stdoutSink.flush();
        await stderrSink.flush();
      } finally {
        await stdoutSink.close();
        await stderrSink.close();
        await stdoutSink.done;
        await stderrSink.done;
      }

      expect(requestedRoot, Directory(temp.path).absolute.path);
      expect(exitCode, 0);
      expect(stderrFile.readAsStringSync(), isEmpty);

      final decoded =
          jsonDecode(stdoutFile.readAsStringSync().trim())
              as Map<String, dynamic>;
      expect(decoded['project_root'], '/tmp/project');
      expect(decoded['tasks_total'], 3);
      expect(decoded['tasks_open'], 2);
      expect(decoded['tasks_done'], 1);
      expect(decoded['tasks_blocked'], 0);
      expect(decoded['active_task'], 'Alpha');
      expect(decoded['active_task_id'], 'alpha-1');
      expect(decoded['review_status'], 'approved');
      expect(decoded['workflow_stage'], 'execution');
      expect(decoded['cycle_count'], 4);
    },
  );

  test('CLI status --json keeps JSON error mapping on app failure', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_status_handler_error_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();

    final api = FakeGenaisysApi()
      ..getStatusHandler = (projectRoot) async =>
          AppResult.failure(AppError.notFound('Missing state snapshot'));

    exitCode = 0;
    try {
      await CliRunner(
        api: api,
        stdout: stdoutSink,
        stderr: stderrSink,
      ).run(['status', '--json', temp.path]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 2);
    expect(stderrFile.readAsStringSync(), isEmpty);

    final decoded =
        jsonDecode(stdoutFile.readAsStringSync().trim())
            as Map<String, dynamic>;
    expect(decoded['code'], 'state_error');
    expect(decoded['error'], 'Missing state snapshot');
  });
}

const _statusSnapshot = AppStatusSnapshotDto(
  projectRoot: '/tmp/project',
  tasksTotal: 3,
  tasksOpen: 2,
  tasksDone: 1,
  tasksBlocked: 0,
  activeTaskTitle: 'Alpha',
  activeTaskId: 'alpha-1',
  reviewStatus: 'approved',
  reviewUpdatedAt: '2026-02-10T00:00:00Z',
  workflowStage: 'execution',
  cycleCount: 4,
  lastUpdated: '2026-02-10T00:00:00Z',
  health: AppHealthSnapshotDto(
    agent: AppHealthCheckDto(ok: true, message: 'Agent ready'),
    allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ready'),
    git: AppHealthCheckDto(ok: true, message: 'Git ready'),
    review: AppHealthCheckDto(ok: true, message: 'Review ready'),
  ),
  telemetry: AppRunTelemetryDto(
    recentEvents: [],
    errorClass: null,
    errorKind: null,
    errorMessage: null,
    agentExitCode: null,
    agentStderrExcerpt: null,
    lastErrorEvent: null,
  ),
);
