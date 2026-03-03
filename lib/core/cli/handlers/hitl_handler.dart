// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _HitlHandler {
  const _HitlHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final asJson = options.contains('--json');

    if (options.isEmpty || options.first.startsWith('-')) {
      _writeUsageError(
        asJson: asJson,
        message: 'Missing subcommand. Use: hitl status|approve|reject [path]',
      );
      return;
    }

    final subcommand = options.first.toLowerCase();
    final subOptions = options.sublist(1);

    switch (subcommand) {
      case 'status':
        await _handleStatus(subOptions, asJson: asJson);
        return;
      case 'approve':
      case 'skip':
        await _handleDecision(subOptions, decision: 'approve', asJson: asJson);
        return;
      case 'reject':
        await _handleDecision(subOptions, decision: 'reject', asJson: asJson);
        return;
      default:
        _writeUsageError(
          asJson: asJson,
          message: 'Unknown subcommand: $subcommand. '
              'Use: hitl status|approve|reject [path]',
        );
        return;
    }
  }

  Future<void> _handleStatus(
    List<String> options, {
    required bool asJson,
  }) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);

    final result = await _runner._api.getHitlGate(root);
    final gate = _runner._requireData(result, asJson: asJson);
    if (gate == null) return;

    if (asJson) {
      _runner._jsonPresenter.writeHitlGate(_runner.stdout, gate);
      return;
    }

    if (!gate.pending) {
      _runner.stdout.writeln('No HITL gate pending.');
      return;
    }

    _runner.stdout.writeln('HITL gate pending: ${gate.event}');
    if (gate.taskId != null) {
      _runner.stdout.writeln('  task:    ${gate.taskTitle ?? gate.taskId}');
    }
    if (gate.sprintNumber != null) {
      _runner.stdout.writeln('  sprint:  ${gate.sprintNumber}');
    }
    if (gate.expiresAt != null) {
      _runner.stdout.writeln('  expires: ${gate.expiresAt}');
    }
    _runner.stdout.writeln('  →  genaisys hitl approve $root');
    _runner.stdout.writeln('  →  genaisys hitl reject  $root');
  }

  Future<void> _handleDecision(
    List<String> options, {
    required String decision,
    required bool asJson,
  }) async {
    final note = _runner._readOptionValue(options, '--note');
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);

    final result = await _runner._api.submitHitlDecision(
      root,
      decision: decision,
      note: note,
    );

    if (!result.ok) {
      _runner._requireData(result, asJson: asJson);
      return;
    }

    if (asJson) {
      _runner._jsonPresenter.writeHitlDecision(
        _runner.stdout,
        decision,
        note: note,
      );
      return;
    }
    _runner.stdout.writeln(
      'Decision submitted: $decision${note != null ? ' ($note)' : ''}',
    );
  }

  void _writeUsageError({required bool asJson, required String message}) {
    if (asJson) {
      _runner._jsonPresenter.writeError(
        _runner.stdout,
        code: 'usage_error',
        message: message,
      );
    } else {
      _runner.stderr.writeln(message);
    }
    _runner.exitCode = 64;
  }
}
