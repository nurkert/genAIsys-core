// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _InitHandler {
  const _InitHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final overwrite = options.contains('--overwrite');
    final asJson = options.contains('--json');
    final staticMode = options.contains('--static');
    final fromSource = _runner._readOptionValue(options, '--from');
    final sprintSizeRaw = _runner._readOptionValue(options, '--sprint-size');
    final sprintSize = _runner._parsePositiveIntOrNull(sprintSizeRaw);
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final validationError = _validateRoot(root);
    if (validationError != null) {
      _writeUsageError(asJson: asJson, message: validationError);
      return;
    }

    final result = await _runner._api.initializeProject(
      root,
      overwrite: overwrite,
      fromSource: fromSource,
      staticMode: staticMode,
      sprintSize: sprintSize,
    );
    final data = requireCliResultData(
      result,
      asJson: asJson,
      stderr: _runner.stderr,
      writeJsonError: ({required String code, required String message}) {
        _runner._jsonPresenter.writeError(
          _runner.stdout,
          code: code,
          message: message,
        );
      },
      setExitCode: (code) => _runner.exitCode = code,
    );
    if (data == null) {
      return;
    }

    if (asJson) {
      _runner._jsonPresenter.writeInit(_runner.stdout, data);
      return;
    }
    _runner._textPresenter.writeInit(_runner.stdout, data);
  }

  String? _validateRoot(String root) {
    final type = FileSystemEntity.typeSync(root, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      return 'Target path does not exist: $root';
    }
    if (type != FileSystemEntityType.directory) {
      return 'Target path is not a directory: $root';
    }
    return null;
  }

  void _writeUsageError({required bool asJson, required String message}) {
    if (asJson) {
      _runner._writeJsonError(code: 'invalid_option', message: message);
    } else {
      _runner.stderr.writeln(message);
    }
    _runner.exitCode = 64;
  }
}
