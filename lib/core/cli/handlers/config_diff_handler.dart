// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _ConfigDiffHandler {
  const _ConfigDiffHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');

    final useCase = ConfigDiffUseCase();
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

  void _writeJson(ConfigDiffDto dto) {
    final payload = <String, Object?>{
      'has_diff': dto.hasDiff,
      'entries': dto.entries.map(_entryPayload).toList(),
    };
    _runner.stdout.writeln(jsonEncode(payload));
  }

  void _writeText(ConfigDiffDto dto) {
    if (!dto.hasDiff) {
      _runner.stdout.writeln('All config values are at their defaults.');
      return;
    }
    _runner.stdout.writeln('Non-default config values:');
    for (final entry in dto.entries) {
      _runner.stdout.writeln(
        '  ${entry.field}: ${entry.currentValue} '
        '(default: ${entry.defaultValue})',
      );
      _runner.stdout.writeln('    Effect: ${entry.effect}');
    }
  }

  Map<String, Object?> _entryPayload(ConfigDiffEntryDto entry) {
    return <String, Object?>{
      'field': entry.field,
      'current_value': entry.currentValue,
      'default_value': entry.defaultValue,
      'effect': entry.effect,
    };
  }
}
