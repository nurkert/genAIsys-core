import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'CLI init --json keeps output parity after handler extraction',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_init_handler_json_',
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
      bool? requestedOverwrite;
      final api = FakeGenaisysApi()
        ..initializeProjectHandler = (projectRoot, {overwrite = false}) async {
          requestedRoot = projectRoot;
          requestedOverwrite = overwrite;
          return AppResult.success(_initPayload);
        };

      exitCode = 0;
      try {
        await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
          'init',
          '--json',
          '--overwrite',
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
      expect(requestedOverwrite, isTrue);
      expect(exitCode, 0);
      expect(stderrFile.readAsStringSync(), isEmpty);

      final decoded =
          jsonDecode(stdoutFile.readAsStringSync().trim())
              as Map<String, dynamic>;
      expect(decoded['initialized'], true);
      expect(decoded['genaisys_dir'], '/tmp/project/.genaisys');
    },
  );

  test('CLI init --json keeps JSON error mapping on app failure', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_init_handler_error_',
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
      ..initializeProjectHandler = (projectRoot, {overwrite = false}) async =>
          AppResult.failure(AppError.conflict('Already initialized'));

    exitCode = 0;
    try {
      await CliRunner(
        api: api,
        stdout: stdoutSink,
        stderr: stderrSink,
      ).run(['init', '--json', temp.path]);
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
    expect(decoded['error'], 'Already initialized');
  });

  test(
    'CLI init rejects missing target directory with usage error and no API call',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_init_handler_missing_target_',
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

      var apiCalled = false;
      final api = FakeGenaisysApi()
        ..initializeProjectHandler = (projectRoot, {overwrite = false}) async {
          apiCalled = true;
          return AppResult.success(_initPayload);
        };

      final missingRoot = '${temp.path}/missing-target';

      exitCode = 0;
      try {
        await CliRunner(
          api: api,
          stdout: stdoutSink,
          stderr: stderrSink,
        ).run(['init', '--json', missingRoot]);
        await stdoutSink.flush();
        await stderrSink.flush();
      } finally {
        await stdoutSink.close();
        await stderrSink.close();
        await stdoutSink.done;
        await stderrSink.done;
      }

      expect(apiCalled, isFalse);
      expect(exitCode, 64);
      expect(stderrFile.readAsStringSync(), isEmpty);
      expect(Directory(missingRoot).existsSync(), isFalse);

      final decoded =
          jsonDecode(stdoutFile.readAsStringSync().trim())
              as Map<String, dynamic>;
      expect(decoded['code'], 'invalid_option');
      expect(decoded['error'], contains('Target path does not exist'));
    },
  );

  test(
    'CLI init rejects file target path with usage error and no API call',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_init_handler_file_target_',
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
      final fileTarget = File('${temp.path}/not_a_directory.txt')
        ..writeAsStringSync('sentinel');

      var apiCalled = false;
      final api = FakeGenaisysApi()
        ..initializeProjectHandler = (projectRoot, {overwrite = false}) async {
          apiCalled = true;
          return AppResult.success(_initPayload);
        };

      exitCode = 0;
      try {
        await CliRunner(
          api: api,
          stdout: stdoutSink,
          stderr: stderrSink,
        ).run(['init', fileTarget.path]);
        await stdoutSink.flush();
        await stderrSink.flush();
      } finally {
        await stdoutSink.close();
        await stderrSink.close();
        await stdoutSink.done;
        await stderrSink.done;
      }

      expect(apiCalled, isFalse);
      expect(exitCode, 64);
      expect(stdoutFile.readAsStringSync(), isEmpty);
      expect(
        stderrFile.readAsStringSync(),
        contains('Target path is not a directory'),
      );
      expect(Directory('${fileTarget.path}/.genaisys').existsSync(), isFalse);
    },
  );

  test(
    'CLI init --from passes fromSource to API and does not treat it as path',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_init_from_flag_',
      );
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        exitCode = 0;
      });

      final stdoutSink = File('${temp.path}/out.txt').openWrite();
      final stderrSink = File('${temp.path}/err.txt').openWrite();

      String? capturedRoot;
      final api = FakeGenaisysApi()
        ..initializeProjectHandler = (
          projectRoot, {
          overwrite = false,
        }) async {
          capturedRoot = projectRoot;
          return AppResult.success(_initPayload);
        };

      exitCode = 0;
      try {
        await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
          'init',
          '--json',
          '--from',
          '/docs/spec.txt',
          temp.path,
        ]);
        await stdoutSink.flush();
        await stderrSink.flush();
      } finally {
        await stdoutSink.close();
        await stderrSink.close();
        await stdoutSink.done;
        await stderrSink.done;
      }

      expect(exitCode, 0);
      // The project root must be the temp path, not the --from value.
      expect(capturedRoot, Directory(temp.path).absolute.path);
      expect(api.lastInitFromSource, '/docs/spec.txt');
      expect(api.lastInitStaticMode, isFalse);
    },
  );

  test('CLI init --static passes staticMode=true to API', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_init_static_flag_',
    );
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      exitCode = 0;
    });

    final stdoutSink = File('${temp.path}/out.txt').openWrite();
    final stderrSink = File('${temp.path}/err.txt').openWrite();

    final api = FakeGenaisysApi()
      ..initializeProjectHandler = (
        projectRoot, {
        overwrite = false,
      }) async => AppResult.success(_initPayload);

    exitCode = 0;
    try {
      await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
        'init',
        '--json',
        '--from',
        '/docs/spec.txt',
        '--static',
        temp.path,
      ]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 0);
    expect(api.lastInitStaticMode, isTrue);
    expect(api.lastInitFromSource, '/docs/spec.txt');
  });

  test('CLI init without --from passes fromSource=null to API', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_init_no_from_',
    );
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      exitCode = 0;
    });

    final stdoutSink = File('${temp.path}/out.txt').openWrite();
    final stderrSink = File('${temp.path}/err.txt').openWrite();

    final api = FakeGenaisysApi()
      ..initializeProjectHandler = (
        projectRoot, {
        overwrite = false,
      }) async => AppResult.success(_initPayload);

    exitCode = 0;
    try {
      await CliRunner(api: api, stdout: stdoutSink, stderr: stderrSink).run([
        'init',
        '--json',
        temp.path,
      ]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 0);
    expect(api.lastInitFromSource, isNull);
  });
}

const _initPayload = ProjectInitializationDto(
  initialized: true,
  genaisysDir: '/tmp/project/.genaisys',
);
