// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _DiagnosticsHandler {
  const _DiagnosticsHandler(this._runner);

  final CliRunner _runner;

  Future<void> run(List<String> options) async {
    final path = _runner._extractPath(options);
    final root = _runner._resolveRoot(path);
    final asJson = options.contains('--json');

    final useCase = AutopilotDiagnosticsUseCase();
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

  void _writeJson(AutopilotDiagnosticsDto dto) {
    final payload = <String, Object?>{
      'error_patterns': dto.errorPatterns.map(_errorPatternPayload).toList(),
      'forensic_state': dto.forensicState,
      'recent_events': dto.recentEvents,
      'supervisor_status': dto.supervisorStatus,
    };
    _runner.stdout.writeln(jsonEncode(payload));
  }

  void _writeText(AutopilotDiagnosticsDto dto) {
    _runner.stdout.writeln('Autopilot Diagnostics');
    _runner.stdout.writeln('');

    // Error patterns
    _runner.stdout.writeln('Error Patterns (top ${dto.errorPatterns.length}):');
    if (dto.errorPatterns.isEmpty) {
      _runner.stdout.writeln('  (none)');
    } else {
      for (final pattern in dto.errorPatterns) {
        _runner.stdout.writeln(
          '  ${pattern.errorKind}: ${pattern.count} occurrences '
          '(${pattern.autoResolvedCount} auto-resolved) '
          'last seen: ${pattern.lastSeen}',
        );
        if (pattern.resolutionStrategy != null) {
          _runner.stdout.writeln(
            '    strategy: ${pattern.resolutionStrategy}',
          );
        }
      }
    }
    _runner.stdout.writeln('');

    // Forensic state
    _runner.stdout.writeln('Forensic State:');
    for (final entry in dto.forensicState.entries) {
      _runner.stdout.writeln('  ${entry.key}: ${entry.value}');
    }
    _runner.stdout.writeln('');

    // Recent events
    _runner.stdout.writeln('Recent Events (last ${dto.recentEvents.length}):');
    if (dto.recentEvents.isEmpty) {
      _runner.stdout.writeln('  (none)');
    } else {
      for (final event in dto.recentEvents) {
        final ts = event['timestamp'] ?? '';
        final evt = event['event'] ?? '';
        final msg = event['message'] ?? '';
        _runner.stdout.writeln('  [$ts] $evt: $msg');
      }
    }
    _runner.stdout.writeln('');

    // Supervisor status
    _runner.stdout.writeln('Supervisor Status:');
    for (final entry in dto.supervisorStatus.entries) {
      _runner.stdout.writeln('  ${entry.key}: ${entry.value}');
    }
  }

  Map<String, Object?> _errorPatternPayload(ErrorPatternDto pattern) {
    return <String, Object?>{
      'error_kind': pattern.errorKind,
      'count': pattern.count,
      'last_seen': pattern.lastSeen,
      'auto_resolved_count': pattern.autoResolvedCount,
      'resolution_strategy': pattern.resolutionStrategy,
    };
  }
}
