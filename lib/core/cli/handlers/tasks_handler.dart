// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _TasksHandler {
  const _TasksHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final openOnly = options.contains('--open');
    final doneOnly = options.contains('--done');
    final blockedOnly = options.contains('--blocked');
    final activeOnly = options.contains('--active');
    final showIds = options.contains('--show-ids');
    final asJson = options.contains('--json');
    final sortByPriority = options.contains('--sort-priority');
    final sectionFilter = _runner._readOptionValue(options, '--section');

    final result = await _runner._api.listTasks(
      root,
      query: TaskListQuery(
        openOnly: openOnly,
        doneOnly: doneOnly,
        blockedOnly: blockedOnly,
        activeOnly: activeOnly,
        sectionFilter: sectionFilter,
        sortByPriority: sortByPriority,
      ),
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
      _runner._jsonPresenter.writeTasks(_runner.stdout, data);
      return;
    }
    _runner._textPresenter.writeTasks(_runner.stdout, data, showIds: showIds);
  }
}
