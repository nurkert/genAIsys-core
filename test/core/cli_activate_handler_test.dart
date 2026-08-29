import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'CLI activate --json keeps output parity after handler extraction',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activate_handler_json_',
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
      String? requestedId;
      String? requestedTitle;
      final api = FakeGenaisysApi()
        ..activateTaskHandler = (projectRoot, {id, title}) async {
          requestedRoot = projectRoot;
          requestedId = id;
          requestedTitle = title;
          return AppResult.success(_activationPayload);
        };

      exitCode = 0;
      try {
        await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
          'activate',
          '--json',
          '--id',
          'alpha-1',
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
      expect(requestedId, 'alpha-1');
      expect(requestedTitle, isNull);
      expect(exitCode, 0);
      expect(stderrFile.readAsStringSync(), isEmpty);

      final decoded =
          jsonDecode(stdoutFile.readAsStringSync().trim())
              as Map<String, dynamic>;
      expect(decoded['activated'], true);
      final task = decoded['task'] as Map<String, dynamic>;
      expect(task['id'], 'alpha-1');
      expect(task['title'], 'Alpha');
      expect(task['status'], 'open');
    },
  );

  test('CLI activate --json keeps JSON error mapping on app failure', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_activate_handler_error_',
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
      ..activateTaskHandler = (projectRoot, {id, title}) async =>
          AppResult.failure(AppError.notFound('Missing activation target'));

    exitCode = 0;
    try {
      await CliRunner(
        api: api,
        stdout: stdoutSink,
        stderr: stderrSink,
      ).run(['activate', '--json', temp.path]);
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
    expect(decoded['error'], 'Missing activation target');
  });
}

const _activationPayload = TaskActivationDto(activated: true, task: _taskDto);

const _taskDto = AppTaskDto(
  id: 'alpha-1',
  title: 'Alpha',
  section: 'Backlog',
  priority: 'p1',
  category: 'core',
  status: AppTaskStatus.open,
);
