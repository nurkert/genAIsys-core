// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _SpecFilesHandler {
  const _SpecFilesHandler(this._runner);

  final CliRunner _runner;

  Future<void> runSpec(List<String> options) async {
    final asJson = options.contains('--json');
    if ((options.isEmpty || options.first != 'init') && asJson) {
      _runner._jsonPresenter.writeError(
        _runner.stdout,
        code: 'missing_subcommand',
        message: 'Missing subcommand. Use: spec init [path] [--overwrite]',
      );
      _runner.exitCode = 64;
      return;
    }
    await _runSpecFiles(
      options,
      label: 'spec',
      asJson: asJson,
      initializer: (root, overwrite) =>
          _runner._api.initializeSpec(root, overwrite: overwrite),
    );
  }

  Future<void> runPlan(List<String> options) async {
    final asJson = options.contains('--json');
    if ((options.isEmpty || options.first != 'init') && asJson) {
      _runner._jsonPresenter.writeError(
        _runner.stdout,
        code: 'missing_subcommand',
        message: 'Missing subcommand. Use: plan init [path] [--overwrite]',
      );
      _runner.exitCode = 64;
      return;
    }
    await _runSpecFiles(
      options,
      label: 'plan',
      asJson: asJson,
      initializer: (root, overwrite) =>
          _runner._api.initializePlan(root, overwrite: overwrite),
    );
  }

  Future<void> runSubtasks(List<String> options) async {
    final asJson = options.contains('--json');
    if ((options.isEmpty || options.first != 'init') && asJson) {
      _runner._jsonPresenter.writeError(
        _runner.stdout,
        code: 'missing_subcommand',
        message: 'Missing subcommand. Use: subtasks init [path] [--overwrite]',
      );
      _runner.exitCode = 64;
      return;
    }
    await _runSpecFiles(
      options,
      label: 'subtasks',
      asJson: asJson,
      initializer: (root, overwrite) =>
          _runner._api.initializeSubtasks(root, overwrite: overwrite),
    );
  }

  Future<void> _runSpecFiles(
    List<String> options, {
    required String label,
    required bool asJson,
    required Future<AppResult<SpecInitializationDto>> Function(
      String root,
      bool overwrite,
    )
    initializer,
  }) async {
    if (options.isEmpty || options.first != 'init') {
      _runner.stderr.writeln(
        'Missing subcommand. Use: $label init [path] [--overwrite]',
      );
      _runner.exitCode = 64;
      return;
    }

    final rest = options.sublist(1);
    final overwrite = rest.contains('--overwrite');
    final path = _runner._extractPath(rest);
    final root = _runner._resolveRoot(path);

    final result = await initializer(root, overwrite);
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
      _runner._jsonPresenter.writeSpecInit(_runner.stdout, data);
      return;
    }
    _runner._textPresenter.writeSpecInit(_runner.stdout, data);
  }
}
