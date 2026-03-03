// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _SupervisorOptions {
  const _SupervisorOptions({
    required this.profile,
    required this.prompt,
    required this.reason,
    required this.maxRestarts,
    required this.backoffBase,
    required this.backoffMax,
    required this.lowSignalLimit,
    required this.throughputWindowMinutes,
    required this.throughputMaxSteps,
    required this.throughputMaxRejects,
    required this.throughputMaxHighRetries,
  });

  final String profile;
  final String? prompt;
  final String reason;
  final int maxRestarts;
  final int backoffBase;
  final int backoffMax;
  final int lowSignalLimit;
  final int throughputWindowMinutes;
  final int throughputMaxSteps;
  final int throughputMaxRejects;
  final int throughputMaxHighRetries;
}

extension _CliRunnerAutopilotSupervisorHandlers on CliRunner {
  _SupervisorOptions _parseSupervisorOptions(
    List<String> options, {
    required String defaultReason,
  }) {
    return _SupervisorOptions(
      profile: _readOptionValue(options, '--profile')?.trim() ?? 'overnight',
      prompt: _readOptionValue(options, '--prompt'),
      reason:
          _readOptionValue(options, '--reason')?.trim() ?? defaultReason,
      maxRestarts:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--max-restarts'),
          ) ??
          AutopilotSupervisorService.defaultMaxRestarts,
      backoffBase:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--restart-backoff-base'),
          ) ??
          AutopilotSupervisorService.defaultRestartBackoffBaseSeconds,
      backoffMax:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--restart-backoff-max'),
          ) ??
          AutopilotSupervisorService.defaultRestartBackoffMaxSeconds,
      lowSignalLimit:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--low-signal-limit'),
          ) ??
          AutopilotSupervisorService.defaultLowSignalLimit,
      throughputWindowMinutes:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--throughput-window-minutes'),
          ) ??
          AutopilotSupervisorService.defaultThroughputWindowMinutes,
      throughputMaxSteps:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--throughput-max-steps'),
          ) ??
          AutopilotSupervisorService.defaultThroughputMaxSteps,
      throughputMaxRejects:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--throughput-max-rejects'),
          ) ??
          AutopilotSupervisorService.defaultThroughputMaxRejects,
      throughputMaxHighRetries:
          _parsePositiveIntOrNull(
            _readOptionValue(options, '--throughput-max-high-retries'),
          ) ??
          AutopilotSupervisorService.defaultThroughputMaxHighRetries,
    );
  }

  Future<void> _handleAutopilotSupervisor(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    if (options.isEmpty) {
      this.stderr.writeln(
        'Missing supervisor subcommand. Use: supervisor start|status|stop|restart [path]',
      );
      exitCode = 64;
      return;
    }

    final subcommand = options.first.toLowerCase();
    final args = options.skip(1).toList(growable: false);

    switch (subcommand) {
      case 'start':
        await _handleAutopilotSupervisorStart(args);
        return;
      case 'status':
        await _handleAutopilotSupervisorStatus(args);
        return;
      case 'stop':
        await _handleAutopilotSupervisorStop(args);
        return;
      case 'restart':
        await _handleAutopilotSupervisorRestart(args);
        return;
      case '_worker':
        await _handleAutopilotSupervisorWorker(args);
        return;
      default:
        this.stderr.writeln(
          'Unknown supervisor subcommand: $subcommand. Use: supervisor start|status|stop|restart',
        );
        exitCode = 64;
    }
  }

  Future<void> _handleAutopilotSupervisorStart(List<String> options) async {
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final opts = _parseSupervisorOptions(
      options,
      defaultReason: 'manual_start',
    );

    final result = await _autopilotSupervisorStart.run(
      root,
      profile: opts.profile,
      prompt: opts.prompt,
      startReason: opts.reason,
      maxRestarts: opts.maxRestarts,
      restartBackoffBaseSeconds: opts.backoffBase,
      restartBackoffMaxSeconds: opts.backoffMax,
      lowSignalLimit: opts.lowSignalLimit,
      throughputWindowMinutes: opts.throughputWindowMinutes,
      throughputMaxSteps: opts.throughputMaxSteps,
      throughputMaxRejects: opts.throughputMaxRejects,
      throughputMaxHighRetries: opts.throughputMaxHighRetries,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }
    if (asJson) {
      _jsonPresenter.writeAutopilotSupervisorStart(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSupervisorStart(this.stdout, data);
  }

  Future<void> _handleAutopilotSupervisorStatus(List<String> options) async {
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final result = await _autopilotSupervisorStatus.load(root);
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }
    if (asJson) {
      _jsonPresenter.writeAutopilotSupervisorStatus(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSupervisorStatus(this.stdout, data);
  }

  Future<void> _handleAutopilotSupervisorStop(List<String> options) async {
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final reason = _readOptionValue(options, '--reason') ?? 'manual_stop';
    final result = await _autopilotSupervisorStop.run(root, reason: reason);
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }
    if (asJson) {
      _jsonPresenter.writeAutopilotSupervisorStop(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSupervisorStop(this.stdout, data);
  }

  Future<void> _handleAutopilotSupervisorRestart(List<String> options) async {
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final opts = _parseSupervisorOptions(
      options,
      defaultReason: 'manual_restart',
    );

    final result = await _autopilotSupervisorRestart.run(
      root,
      profile: opts.profile,
      prompt: opts.prompt,
      startReason: opts.reason,
      maxRestarts: opts.maxRestarts,
      restartBackoffBaseSeconds: opts.backoffBase,
      restartBackoffMaxSeconds: opts.backoffMax,
      lowSignalLimit: opts.lowSignalLimit,
      throughputWindowMinutes: opts.throughputWindowMinutes,
      throughputMaxSteps: opts.throughputMaxSteps,
      throughputMaxRejects: opts.throughputMaxRejects,
      throughputMaxHighRetries: opts.throughputMaxHighRetries,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }
    if (asJson) {
      _jsonPresenter.writeAutopilotSupervisorStart(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSupervisorStart(this.stdout, data);
  }

  Future<void> _handleAutopilotSupervisorWorker(List<String> options) async {
    // Internal-only command used by `autopilot supervisor start`.
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final sessionId =
        _readOptionValue(options, '--session-id')?.trim() ??
        'supervisor-worker';
    final opts = _parseSupervisorOptions(
      options,
      defaultReason: 'worker_start',
    );
    final prompt =
        opts.prompt ??
        'Advance the roadmap with one minimal, safe, production-grade step.';

    await _autopilotSupervisorService.runWorker(
      root,
      sessionId: sessionId,
      profile: opts.profile,
      prompt: prompt,
      startReason: opts.reason,
      maxRestarts: opts.maxRestarts,
      restartBackoffBaseSeconds: opts.backoffBase,
      restartBackoffMaxSeconds: opts.backoffMax,
      lowSignalLimit: opts.lowSignalLimit,
      throughputWindowMinutes: opts.throughputWindowMinutes,
      throughputMaxSteps: opts.throughputMaxSteps,
      throughputMaxRejects: opts.throughputMaxRejects,
      throughputMaxHighRetries: opts.throughputMaxHighRetries,
    );
  }
}
