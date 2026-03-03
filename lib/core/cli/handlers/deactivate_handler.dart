// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _DeactivateHandler {
  const _DeactivateHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final keepReview = options.contains('--keep-review');
    final asJson = options.contains('--json');

    final result = await _runner._api.deactivateTask(
      root,
      keepReview: keepReview,
    );
    final data = requireCliResultDataWithJsonPresenter(
      result,
      asJson: asJson,
      stderr: _runner.stderr,
      stdout: _runner.stdout,
      jsonPresenter: _runner._jsonPresenter,
      setExitCode: (code) => _runner.exitCode = code,
    );
    if (data == null) {
      return;
    }

    if (asJson) {
      _runner._jsonPresenter.writeDeactivate(_runner.stdout, data);
      return;
    }
    _runner._textPresenter.writeDeactivate(_runner.stdout, data);
  }
}
