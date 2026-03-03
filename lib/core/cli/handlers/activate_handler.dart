// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _ActivateHandler {
  const _ActivateHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');
    final showIds = options.contains('--show-ids');

    final requestedId = _runner._readOptionValue(options, '--id');
    final requestedTitle = _runner._readOptionValue(options, '--title');
    final sectionFilter = _runner._readOptionValue(options, '--section');
    if (requestedId != null &&
        requestedId.trim().isNotEmpty &&
        requestedTitle != null &&
        requestedTitle.trim().isNotEmpty) {
      _runner.stderr.writeln('Use only one of --id or --title');
      _runner.exitCode = 64;
      return;
    }

    // When --section is given and no --id/--title, find the next task in that
    // section first, then activate by its ID.
    String? activateId = requestedId;
    if (activateId == null &&
        requestedTitle == null &&
        sectionFilter != null &&
        sectionFilter.trim().isNotEmpty) {
      final nextResult = await _runner._api.getNextTask(
        root,
        sectionFilter: sectionFilter,
      );
      if (!nextResult.ok || nextResult.data == null) {
        if (asJson) {
          _runner._jsonPresenter.writeActivate(
            _runner.stdout,
            TaskActivationDto(activated: false, task: null),
          );
        } else {
          _runner.stdout.writeln('No open tasks found in section: $sectionFilter');
        }
        return;
      }
      activateId = nextResult.data!.id;
    }

    final result = await _runner._api.activateTask(
      root,
      id: activateId,
      title: requestedTitle,
    );
    final data = _runner._requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _runner._jsonPresenter.writeActivate(_runner.stdout, data);
      return;
    }
    if (!data.activated || data.task == null) {
      _runner.stdout.writeln('No open tasks found.');
      return;
    }
    final idSuffix = showIds ? ' [id: ${data.task!.id}]' : '';
    _runner.stdout.writeln('Activated: ${data.task!.title}$idSuffix');
  }
}
