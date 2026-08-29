import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'CLI deactivate --json keeps output parity after handler extraction',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_deactivate_handler_json_',
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
      bool? requestedKeepReview;
      final api = FakeGenaisysApi()
        ..deactivateTaskHandler = (projectRoot, {keepReview = false}) async {
          requestedRoot = projectRoot;
          requestedKeepReview = keepReview;
          return AppResult.success(_deactivatePayload);
        };

      exitCode = 0;
      try {
        await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
          'deactivate',
          '--json',
          '--keep-review',
          '${temp.path}${Platform.pathSeparator}.',
        ]);
        await stdoutSink.flush();
        await stderrSink.flush();
      } finally {
        await stdoutSink.close();
        await stderrSink.close();
        await stdoutSink.done;
        await stderrSink.done;
      }

      expect(requestedRoot, Directory(temp.path).absolute.path);
      expect(requestedKeepReview, isTrue);
      expect(exitCode, 0);
      expect(stderrFile.readAsStringSync(), isEmpty);

      final decoded =
          jsonDecode(stdoutFile.readAsStringSync().trim())
              as Map<String, dynamic>;
      expect(decoded['deactivated'], true);
      expect(decoded['keep_review'], true);
      expect(decoded['active_task'], isNull);
      expect(decoded['active_task_id'], isNull);
      expect(decoded['review_status'], 'approved');
      expect(decoded['review_updated_at'], '2026-02-10T00:00:00Z');
    },
  );

  test(
    'CLI deactivate --json keeps JSON error mapping on app failure',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_deactivate_handler_error_',
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
        ..deactivateTaskHandler = (projectRoot, {keepReview = false}) async =>
            AppResult.failure(AppError.notFound('Missing active task'));

      exitCode = 0;
      try {
        await CliRunner(
          api: api,
          stdout: stdoutSink,
          stderr: stderrSink,
        ).run(['deactivate', '--json', temp.path]);
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
      expect(decoded['error'], 'Missing active task');
    },
  );
}

const _deactivatePayload = TaskDeactivationDto(
  deactivated: true,
  keepReview: true,
  activeTaskTitle: null,
  activeTaskId: null,
  reviewStatus: 'approved',
  reviewUpdatedAt: '2026-02-10T00:00:00Z',
);
