// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../app/app.dart';
import '../presenters/json_presenter.dart';
import 'cli_app_error_mapper.dart';

typedef CliJsonErrorWriter =
    void Function({required String code, required String message});
typedef CliExitCodeWriter = void Function(int code);

T? requireCliResultData<T>(
  AppResult<T> result, {
  required bool asJson,
  required IOSink stderr,
  required CliJsonErrorWriter writeJsonError,
  required CliExitCodeWriter setExitCode,
}) {
  if (!result.ok || result.data == null) {
    presentCliAppError(
      result.error,
      asJson: asJson,
      stderr: stderr,
      writeJsonError: writeJsonError,
      setExitCode: setExitCode,
    );
    return null;
  }
  return result.data;
}

void presentCliAppError(
  AppError? error, {
  required bool asJson,
  required IOSink stderr,
  required CliJsonErrorWriter writeJsonError,
  required CliExitCodeWriter setExitCode,
}) {
  final route = mapCliAppError(error);
  final message = error?.message ?? 'Unknown error.';
  if (asJson) {
    writeJsonError(code: route.jsonCode, message: message);
  } else {
    stderr.writeln(message);
  }
  setExitCode(route.exitCode);
}

T? requireCliResultDataWithJsonPresenter<T>(
  AppResult<T> result, {
  required bool asJson,
  required IOSink stderr,
  required IOSink stdout,
  required JsonPresenter jsonPresenter,
  required CliExitCodeWriter setExitCode,
}) {
  return requireCliResultData(
    result,
    asJson: asJson,
    stderr: stderr,
    writeJsonError: ({required String code, required String message}) {
      jsonPresenter.writeError(stdout, code: code, message: message);
    },
    setExitCode: setExitCode,
  );
}
