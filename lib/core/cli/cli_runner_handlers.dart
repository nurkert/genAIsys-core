// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'cli_runner.dart';

extension _CliRunnerHandlers on CliRunner {
  Future<void> _handleInit(List<String> options) async {
    await _InitHandler(this).run(options);
  }

  Future<void> _handleStatus(List<String> options) async {
    await _StatusHandler(this).run(options);
  }

  Future<void> _handleTasks(List<String> options) async {
    await _TasksHandler(this).run(options);
  }

  Future<void> _handleActivate(List<String> options) async {
    await _ActivateHandler(this).run(options);
  }

  Future<void> _handleDeactivate(List<String> options) async {
    await _DeactivateHandler(this).run(options);
  }

  Future<void> _handleAppSettings(List<String> options) async {
    await _AppSettingsHandler(this).run(options);
  }

  Future<void> _handleDone(List<String> options) async {
    await _DoneHandler(this).run(options);
  }

  Future<void> _handleBlock(List<String> options) async {
    await _BlockHandler(this).run(options);
  }

  Future<void> _handleConfig(List<String> options) async {
    final asJson = options.contains('--json');
    if (options.isEmpty || options.first.startsWith('-')) {
      if (asJson) {
        _writeJsonError(
          code: 'missing_subcommand',
          message: 'Missing subcommand. Use: config validate|diff [path]',
        );
      } else {
        this.stderr.writeln(
          'Missing subcommand. Use: config validate|diff [path]',
        );
      }
      exitCode = 64;
      return;
    }

    final subcommand = options.first.toLowerCase();
    final subOptions = options.sublist(1);
    switch (subcommand) {
      case 'validate':
        await _ConfigValidateHandler(this).run(subOptions);
        return;
      case 'diff':
        await _ConfigDiffHandler(this).run(subOptions);
        return;
      default:
        if (asJson) {
          _writeJsonError(
            code: 'unknown_subcommand',
            message:
                'Unknown subcommand: $subcommand. Use: config validate|diff',
          );
        } else {
          this.stderr.writeln(
            'Unknown subcommand: $subcommand. Use: config validate|diff',
          );
        }
        exitCode = 64;
        return;
    }
  }

  Future<void> _handleHealth(List<String> options) async {
    await _HealthHandler(this).run(options);
  }

  Future<void> _handleAutopilotDiagnostics(List<String> options) async {
    await _DiagnosticsHandler(this).run(options);
  }

  Future<void> _handleScaffold(List<String> options) async {
    final asJson = options.contains('--json');
    if (options.isEmpty || options.first.startsWith('-')) {
      if (asJson) {
        _writeJsonError(
          code: 'missing_subcommand',
          message:
              'Missing subcommand. Use: scaffold spec|plan|subtasks [path]',
        );
      } else {
        this.stderr.writeln(
          'Missing subcommand. Use: scaffold spec|plan|subtasks [path]',
        );
      }
      exitCode = 64;
      return;
    }

    final subcommand = options.first.toLowerCase();
    // Pass subcommand options (including 'init' keyword for backward compat
    // with _SpecFilesHandler which expects 'init' as first arg).
    final subOptions = ['init', ...options.sublist(1)];
    switch (subcommand) {
      case 'spec':
        await _SpecFilesHandler(this).runSpec(subOptions);
        return;
      case 'plan':
        await _SpecFilesHandler(this).runPlan(subOptions);
        return;
      case 'subtasks':
        await _SpecFilesHandler(this).runSubtasks(subOptions);
        return;
      default:
        if (asJson) {
          _writeJsonError(
            code: 'unknown_subcommand',
            message:
                'Unknown subcommand: $subcommand. Use: scaffold spec|plan|subtasks',
          );
        } else {
          this.stderr.writeln(
            'Unknown subcommand: $subcommand. Use: scaffold spec|plan|subtasks',
          );
        }
        exitCode = 64;
        return;
    }
  }

  Future<void> _handleHitl(List<String> options) async {
    await _HitlHandler(this).run(options);
  }

  T? _requireData<T>(AppResult<T> result, {required bool asJson}) {
    return requireCliResultData(
      result,
      asJson: asJson,
      stderr: this.stderr,
      writeJsonError: _writeJsonError,
      setExitCode: (code) => exitCode = code,
    );
  }
}
