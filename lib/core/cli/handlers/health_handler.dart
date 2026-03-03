// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _HealthHandler {
  const _HealthHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');

    final useCase = HealthReportUseCase();
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

  void _writeJson(HealthReportDto dto) {
    final payload = <String, Object?>{
      'ok': dto.ok,
      'checks': dto.checks.map(_checkPayload).toList(),
    };
    _runner.stdout.writeln(jsonEncode(payload));
  }

  void _writeText(HealthReportDto dto) {
    _runner.stdout.writeln(
      'Health: ${dto.ok ? "ALL CHECKS PASSED" : "ISSUES FOUND"}',
    );
    for (final check in dto.checks) {
      final icon = check.ok ? '[OK]' : '[FAIL]';
      _runner.stdout.writeln('  $icon ${check.name}: ${check.message}');
      if (check.errorKind != null) {
        _runner.stdout.writeln('       error_kind: ${check.errorKind}');
      }
    }
  }

  Map<String, Object?> _checkPayload(HealthReportCheckDto check) {
    return <String, Object?>{
      'name': check.name,
      'ok': check.ok,
      'message': check.message,
      'error_kind': check.errorKind,
    };
  }
}
