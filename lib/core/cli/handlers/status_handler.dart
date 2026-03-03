// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _StatusHandler {
  const _StatusHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');

    final result = await _runner._api.getStatus(root);
    final snapshot = requireCliResultData(
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
    if (snapshot == null) {
      return;
    }

    // Also load autopilot status (best-effort — don't fail if unavailable).
    AutopilotStatusDto? autopilotDto;
    try {
      final autopilotResult = await _runner._autopilotStatus.load(root);
      if (autopilotResult.ok) {
        autopilotDto = autopilotResult.data;
      }
    } catch (_) {
      // Ignore — autopilot state is supplementary.
    }

    if (asJson) {
      _runner._jsonPresenter.writeStatus(_runner.stdout, snapshot);
      return;
    }
    _runner._textPresenter.writeStatus(_runner.stdout, snapshot);
    if (autopilotDto != null) {
      _runner.stdout.writeln('');
      if (autopilotDto.autopilotRunning) {
        _runner.stdout.writeln('Autopilot: RUNNING (PID ${autopilotDto.pid ?? 'unknown'})');
      } else {
        _runner.stdout.writeln('Autopilot: stopped');
      }
    }
  }
}
