import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'CLI done --json keeps output parity after handler extraction',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_handler_json_',
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
        ..markTaskDoneHandler = (projectRoot) async {
          requestedRoot = projectRoot;
          return AppResult.success(_donePayload);
        };

      exitCode = 0;
      try {
        await CliRunner(
          api: api,
          stdout: stdoutSink,
          stderr: stderrSink,
        ).run(['done', '--json', '${temp.path}${Platform.pathSeparator}.']);
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
      expect(decoded['done'], true);
      expect(decoded['task_title'], 'Alpha');
    },
  );

  test('CLI done --json keeps JSON error mapping on app failure', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_handler_error_',
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
      ..markTaskDoneHandler = (projectRoot) async =>
          AppResult.failure(AppError.conflict('Review approval required'));

    exitCode = 0;
    try {
      await CliRunner(
        api: api,
        stdout: stdoutSink,
        stderr: stderrSink,
      ).run(['done', '--json', temp.path]);
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
    expect(decoded['error'], 'Review approval required');
  });
}

const _donePayload = TaskDoneDto(done: true, taskTitle: 'Alpha');
