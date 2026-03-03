// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _ConfigValidateHandler {
  const _ConfigValidateHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');

    final useCase = ConfigValidateUseCase();
    final result = await useCase.run(root);
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
      _writeJson(data);
      return;
    }
    _writeText(data);
  }

  void _writeJson(ConfigValidationDto dto) {
    final payload = <String, Object?>{
      'ok': dto.ok,
      'checks': dto.checks.map(_checkPayload).toList(),
      'warnings': dto.warnings.map(_checkPayload).toList(),
    };
    _runner.stdout.writeln(jsonEncode(payload));
  }

  void _writeText(ConfigValidationDto dto) {
    _runner.stdout.writeln(
      'Config validation: ${dto.ok ? "PASS" : "FAIL"}',
    );
    for (final check in dto.checks) {
      final icon = check.ok ? '[OK]' : '[FAIL]';
      _runner.stdout.writeln('  $icon ${check.name}: ${check.message}');
      if (check.remediationHint != null) {
        _runner.stdout.writeln('       Hint: ${check.remediationHint}');
      }
    }
    if (dto.warnings.isNotEmpty) {
      _runner.stdout.writeln('Warnings:');
      for (final warning in dto.warnings) {
        _runner.stdout.writeln('  [WARN] ${warning.name}: ${warning.message}');
        if (warning.remediationHint != null) {
          _runner.stdout.writeln(
            '         Hint: ${warning.remediationHint}',
          );
        }
      }
    }
  }

  Map<String, Object?> _checkPayload(ConfigValidationCheckDto check) {
    return <String, Object?>{
      'name': check.name,
      'ok': check.ok,
      'message': check.message,
      'remediation_hint': check.remediationHint,
    };
  }
}
