import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/shared/cli_error_presenter.dart';

void main() {
  test(
    'requireCliResultData returns data on success without side effects',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'cli_error_presenter_success_',
      );
      final stderrFile = File(
        '${temp.path}${Platform.pathSeparator}stderr.txt',
      );
      final stderrSink = stderrFile.openWrite();
      addTearDown(() async {
        await stderrSink.close();
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final jsonErrors = <Map<String, String>>[];
      int? exitCode;
      final result = requireCliResultData(
        AppResult.success('ok'),
        asJson: true,
        stderr: stderrSink,
        writeJsonError: ({required code, required message}) {
          jsonErrors.add({'code': code, 'message': message});
        },
        setExitCode: (code) => exitCode = code,
      );

      await stderrSink.flush();
      expect(result, 'ok');
      expect(jsonErrors, isEmpty);
      expect(exitCode, isNull);
      expect(stderrFile.readAsStringSync(), isEmpty);
    },
  );

  test(
    'requireCliResultData maps app failure to JSON state_error and exit 2',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'cli_error_presenter_json_',
      );
      final stderrFile = File(
        '${temp.path}${Platform.pathSeparator}stderr.txt',
      );
      final stderrSink = stderrFile.openWrite();
      addTearDown(() async {
        await stderrSink.close();
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final jsonErrors = <Map<String, String>>[];
      int? exitCode;
      final result = requireCliResultData<String>(
        AppResult.failure(AppError.notFound('Missing state')),
        asJson: true,
        stderr: stderrSink,
        writeJsonError: ({required code, required message}) {
          jsonErrors.add({'code': code, 'message': message});
        },
        setExitCode: (code) => exitCode = code,
      );

      await stderrSink.flush();
      expect(result, isNull);
      expect(jsonErrors, hasLength(1));
      expect(jsonErrors.first['code'], 'state_error');
      expect(jsonErrors.first['message'], 'Missing state');
      expect(exitCode, 2);
      expect(stderrFile.readAsStringSync(), isEmpty);
    },
  );

  test(
    'requireCliResultData writes Unknown error to stderr when result has null data',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'cli_error_presenter_text_',
      );
      final stderrFile = File(
        '${temp.path}${Platform.pathSeparator}stderr.txt',
      );
      final stderrSink = stderrFile.openWrite();
      addTearDown(() async {
        await stderrSink.close();
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final jsonErrors = <Map<String, String>>[];
      int? exitCode;
      final result = requireCliResultData<String?>(
        AppResult.success<String?>(null),
        asJson: false,
        stderr: stderrSink,
        writeJsonError: ({required code, required message}) {
          jsonErrors.add({'code': code, 'message': message});
        },
        setExitCode: (code) => exitCode = code,
      );

      await stderrSink.flush();
      expect(result, isNull);
      expect(jsonErrors, isEmpty);
      expect(exitCode, 2);
      expect(stderrFile.readAsStringSync(), contains('Unknown error.'));
    },
  );
}
