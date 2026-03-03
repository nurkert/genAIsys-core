// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/project_config.dart';
import '../policy/shell_allowlist_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';

class BuildTestRunnerOutcome {
  const BuildTestRunnerOutcome({
    required this.executed,
    this.summary,
    this.profile = 'configured',
  });

  final bool executed;
  final String? summary;
  final String profile;
}

class AutoFormatOutcome {
  const AutoFormatOutcome({required this.executed, required this.files});

  final bool executed;
  final int files;
}

class ShellCommandResult {
  const ShellCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.timedOut,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;

  bool get ok => !timedOut && exitCode == 0;
}

abstract class ShellCommandRunner {
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  });
}

class ProcessShellCommandRunner implements ShellCommandRunner {
  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null) {
      throw StateError(
        'Policy violation: quality_gate command is invalid or contains '
        'shell operators: "$command".',
      );
    }
    final process = await Process.start(
      parsed.executable,
      parsed.arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );

    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    var timedOut = false;
    var exitCode = 0;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      process.kill();
      if (!Platform.isWindows) {
        try {
          Process.killPid(-process.pid, ProcessSignal.sigterm);
        } catch (_) {}
        process.kill(ProcessSignal.sigkill);
        try {
          Process.killPid(-process.pid, ProcessSignal.sigkill);
        } catch (_) {}
      }
      exitCode = _timeoutExitCode;
      try {
        await process.exitCode.timeout(const Duration(seconds: 1));
      } catch (_) {}
    }

    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    stopwatch.stop();

    return ShellCommandResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      duration: stopwatch.elapsed,
      timedOut: timedOut,
    );
  }

  static const int _timeoutExitCode = 124;
}

class BuildTestRunnerService {
  BuildTestRunnerService({ShellCommandRunner? commandRunner})
    : _commandRunner = commandRunner ?? ProcessShellCommandRunner();

  final ShellCommandRunner _commandRunner;
  static const String _dependencyBootstrapCommand = 'flutter pub get';
  static const String _packageConfigRelativePath =
      '.dart_tool/package_config.json';

  Future<AutoFormatOutcome> autoFormatChangedDartFiles(
    String projectRoot, {
    required List<String> changedPaths,
  }) async {
    final config = ProjectConfig.load(projectRoot);
    final dartPaths = _collectChangedDartPaths(projectRoot, changedPaths);
    if (dartPaths.isEmpty) {
      _appendLog(
        projectRoot,
        event: 'quality_gate_autofix_skip',
        message: 'No changed Dart files to auto-format',
        data: {'root': projectRoot, 'reason': 'no_dart_changes'},
      );
      return const AutoFormatOutcome(executed: false, files: 0);
    }

    final command = _buildDartFormatCommand(dartPaths);
    _enforceShellAllowlist(projectRoot, config, [command]);
    _appendLog(
      projectRoot,
      event: 'quality_gate_autofix_start',
      message: 'Auto-format started for changed Dart files',
      data: {
        'root': projectRoot,
        'files': dartPaths.length,
        'command': command,
      },
    );

    final result = await _runCommand(
      command,
      workingDirectory: projectRoot,
      timeout: config.qualityGateTimeout,
    );
    if (!result.ok) {
      final failure = _buildFailureMessage(
        command: command,
        result: result,
        timeout: config.qualityGateTimeout,
      );
      _appendLog(
        projectRoot,
        event: 'quality_gate_autofix_fail',
        message: failure,
        data: {
          'root': projectRoot,
          'files': dartPaths.length,
          'exit_code': result.exitCode,
          'timed_out': result.timedOut,
        },
      );
      throw StateError(failure);
    }
    _appendLog(
      projectRoot,
      event: 'quality_gate_autofix_pass',
      message: 'Auto-format completed for changed Dart files',
      data: {'root': projectRoot, 'files': dartPaths.length},
    );
    return AutoFormatOutcome(executed: true, files: dartPaths.length);
  }

  Future<BuildTestRunnerOutcome> run(
    String projectRoot, {
    List<String>? changedPaths,
  }) async {
    final config = ProjectConfig.load(projectRoot);
    if (!config.qualityGateEnabled) {
      _appendLog(
        projectRoot,
        event: 'quality_gate_skip',
        message: 'Quality gate is disabled',
        data: {'root': projectRoot, 'reason': 'disabled'},
      );
      return const BuildTestRunnerOutcome(executed: false);
    }

    final configuredCommands = ProjectConfig.normalizeQualityGateCommands(
      config.qualityGateCommands,
    );
    if (configuredCommands.isEmpty) {
      throw StateError(
        'Policy violation: quality_gate has no commands configured. '
        'Define policies.quality_gate.commands in .genaisys/config.yml.',
      );
    }
    final plan = _resolveCommandPlan(
      projectRoot: projectRoot,
      config: config,
      configuredCommands: configuredCommands,
      changedPaths: changedPaths ?? const [],
    );
    final commands = plan.commands;
    final timeout = config.qualityGateTimeout;
    if (commands.isEmpty) {
      _appendLog(
        projectRoot,
        event: 'quality_gate_skip',
        message: 'Quality gate skipped for docs-only changes',
        data: {'root': projectRoot, 'reason': 'docs_only_no_checks'},
      );
      return const BuildTestRunnerOutcome(
        executed: true,
        summary: 'Quality Gate: skipped checks for docs-only diff',
        profile: 'docs_only',
      );
    }
    await _autoFormatRepositoryIfGlobalFormatGuardNeedsBaseline(
      projectRoot: projectRoot,
      config: config,
      commands: commands,
      timeout: timeout,
    );
    await _bootstrapDependenciesIfNeeded(
      projectRoot: projectRoot,
      config: config,
      commands: commands,
      timeout: timeout,
    );
    _enforceShellAllowlist(projectRoot, config, commands);

    _appendLog(
      projectRoot,
      event: 'quality_gate_start',
      message: 'Quality gate started',
      data: {
        'root': projectRoot,
        'commands': commands.length,
        'profile': plan.profile,
        'timeout_seconds': timeout.inSeconds,
      },
    );

    final executions = <_CommandExecution>[];
    final budgetStopwatch = Stopwatch()..start();
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];
      final index = i + 1;

      final remaining = timeout - budgetStopwatch.elapsed;
      if (remaining <= Duration.zero) {
        _appendLog(
          projectRoot,
          event: 'quality_gate_budget_exhausted',
          message: 'Quality gate time budget exhausted before command $index',
          data: {
            'root': projectRoot,
            'index': index,
            'total': commands.length,
            'command': command,
            'elapsed_ms': budgetStopwatch.elapsedMilliseconds,
            'budget_ms': timeout.inMilliseconds,
            'error_class': 'quality_gate',
            'error_kind': 'budget_exhausted',
          },
        );
        throw StateError(
          'Policy violation: quality_gate time budget exhausted '
          'after ${budgetStopwatch.elapsed.inSeconds}s '
          '(budget ${timeout.inSeconds}s). '
          'Command "$command" was not started.',
        );
      }

      final commandTimeout = remaining < timeout ? remaining : timeout;
      _appendLog(
        projectRoot,
        event: 'quality_gate_command_start',
        message: 'Quality gate command started',
        data: {
          'root': projectRoot,
          'index': index,
          'total': commands.length,
          'command': command,
          'remaining_budget_ms': remaining.inMilliseconds,
        },
      );

      var result = await _runCommand(
        command,
        workingDirectory: projectRoot,
        timeout: commandTimeout,
      );
      var attempts = 1;
      if (!result.ok &&
          _isFlakeRetryEligible(
            command: command,
            result: result,
            retryCount: config.qualityGateFlakeRetryCount,
          )) {
        for (
          var retry = 1;
          retry <= config.qualityGateFlakeRetryCount;
          retry++
        ) {
          final retryRemaining = timeout - budgetStopwatch.elapsed;
          if (retryRemaining <= Duration.zero) {
            _appendLog(
              projectRoot,
              event: 'quality_gate_budget_exhausted',
              message:
                  'Quality gate time budget exhausted before retry $retry of command $index',
              data: {
                'root': projectRoot,
                'index': index,
                'total': commands.length,
                'command': command,
                'retry': retry,
                'elapsed_ms': budgetStopwatch.elapsedMilliseconds,
                'budget_ms': timeout.inMilliseconds,
                'error_class': 'quality_gate',
                'error_kind': 'budget_exhausted',
              },
            );
            break;
          }
          final retryTimeout =
              retryRemaining < timeout ? retryRemaining : timeout;
          _appendLog(
            projectRoot,
            event: 'quality_gate_command_retry',
            message: 'Retrying flaky quality gate test command',
            data: {
              'root': projectRoot,
              'index': index,
              'total': commands.length,
              'command': command,
              'retry': retry,
              'max_retries': config.qualityGateFlakeRetryCount,
              'remaining_budget_ms': retryRemaining.inMilliseconds,
            },
          );
          final retryResult = await _runCommand(
            command,
            workingDirectory: projectRoot,
            timeout: retryTimeout,
          );
          attempts += 1;
          result = retryResult;
          if (retryResult.ok) {
            break;
          }
        }
      }
      final execution = _CommandExecution(
        command: command,
        result: result,
        attempts: attempts,
      );
      executions.add(execution);

      _appendLog(
        projectRoot,
        event: 'quality_gate_command_end',
        message: result.ok
            ? 'Quality gate command passed'
            : 'Quality gate command failed',
        data: {
          'root': projectRoot,
          'index': index,
          'total': commands.length,
          'command': command,
          'exit_code': result.exitCode,
          'timed_out': result.timedOut,
          'duration_ms': result.duration.inMilliseconds,
          'attempts': attempts,
        },
      );

      if (!result.ok) {
        // Special handling: `dart test` / `flutter test` exit code 65 means
        // "no test files found".  This is expected during early bootstrap when
        // the test/ directory does not yet exist.  Treat as pass so the
        // quality gate does not block the autopilot on a fresh project.
        if (_isNoTestFilesResult(command: command, result: result)) {
          _appendLog(
            projectRoot,
            event: 'quality_gate_command_no_tests',
            message:
                'Quality gate test command reports no test files — treated as pass',
            data: {
              'root': projectRoot,
              'index': index,
              'total': commands.length,
              'command': command,
              'exit_code': result.exitCode,
            },
          );
          continue;
        }

        final failure = _buildFailureMessage(
          command: command,
          result: result,
          timeout: timeout,
        );
        _appendLog(
          projectRoot,
          event: 'quality_gate_fail',
          message: failure,
          data: {
            'root': projectRoot,
            'index': index,
            'total': commands.length,
            'command': command,
            'exit_code': result.exitCode,
            'timed_out': result.timedOut,
          },
        );
        throw StateError(failure);
      }
    }

    final summary = _buildSummary(executions, profile: plan.profile);
    _appendLog(
      projectRoot,
      event: 'quality_gate_pass',
      message: 'Quality gate passed',
      data: {
        'root': projectRoot,
        'profile': plan.profile,
        'commands': executions.length,
        'total_duration_ms': executions
            .map((entry) => entry.result.duration.inMilliseconds)
            .fold<int>(0, (sum, value) => sum + value),
      },
    );

    return BuildTestRunnerOutcome(
      executed: true,
      summary: summary,
      profile: plan.profile,
    );
  }

  Future<void> _autoFormatRepositoryIfGlobalFormatGuardNeedsBaseline({
    required String projectRoot,
    required ProjectConfig config,
    required List<String> commands,
    required Duration timeout,
  }) async {
    if (!_hasGlobalSetExitFormatCheck(commands)) {
      return;
    }

    const command = 'dart format .';
    _enforceShellAllowlist(projectRoot, config, [command]);
    _appendLog(
      projectRoot,
      event: 'quality_gate_autofix_start',
      message: 'Auto-format started for repository baseline',
      data: {
        'root': projectRoot,
        'reason': 'global_format_guard',
        'command': command,
      },
    );

    final result = await _runCommand(
      command,
      workingDirectory: projectRoot,
      timeout: timeout,
    );
    if (!result.ok) {
      final failure = _buildFailureMessage(
        command: command,
        result: result,
        timeout: timeout,
      );
      _appendLog(
        projectRoot,
        event: 'quality_gate_autofix_fail',
        message: failure,
        data: {
          'root': projectRoot,
          'reason': 'global_format_guard',
          'exit_code': result.exitCode,
          'timed_out': result.timedOut,
        },
      );
      throw StateError(failure);
    }

    _appendLog(
      projectRoot,
      event: 'quality_gate_autofix_pass',
      message: 'Auto-format completed for repository baseline',
      data: {'root': projectRoot, 'reason': 'global_format_guard'},
    );
  }

  Future<void> _bootstrapDependenciesIfNeeded({
    required String projectRoot,
    required ProjectConfig config,
    required List<String> commands,
    required Duration timeout,
  }) async {
    if (!_containsNoPubTestCommand(commands)) {
      return;
    }
    final packageConfigPath = '$projectRoot/$_packageConfigRelativePath';
    if (File(packageConfigPath).existsSync()) {
      return;
    }

    _enforceShellAllowlist(projectRoot, config, [_dependencyBootstrapCommand]);
    _appendLog(
      projectRoot,
      event: 'quality_gate_dependency_bootstrap_start',
      message: 'Bootstrapping Dart/Flutter dependencies before no-pub tests',
      data: {
        'root': projectRoot,
        'command': _dependencyBootstrapCommand,
        'package_config': _packageConfigRelativePath,
      },
    );

    final result = await _runCommand(
      _dependencyBootstrapCommand,
      workingDirectory: projectRoot,
      timeout: timeout,
    );
    if (!result.ok) {
      final failure = _buildDependencyBootstrapFailureMessage(
        command: _dependencyBootstrapCommand,
        result: result,
        timeout: timeout,
      );
      _appendLog(
        projectRoot,
        event: 'quality_gate_dependency_bootstrap_error',
        message: failure,
        data: {
          'root': projectRoot,
          'command': _dependencyBootstrapCommand,
          'exit_code': result.exitCode,
          'timed_out': result.timedOut,
          'error_class': 'quality_gate',
          'error_kind': 'dependency_bootstrap_failed',
        },
      );
      throw StateError(failure);
    }
    _appendLog(
      projectRoot,
      event: 'quality_gate_dependency_bootstrap_pass',
      message: 'Dependency bootstrap completed',
      data: {'root': projectRoot, 'command': _dependencyBootstrapCommand},
    );
  }

  bool _containsNoPubTestCommand(List<String> commands) {
    for (final command in commands) {
      if (!command.contains('--no-pub')) {
        continue;
      }
      if (_isTestCommand(command)) {
        return true;
      }
    }
    return false;
  }

  String _buildDependencyBootstrapFailureMessage({
    required String command,
    required ShellCommandResult result,
    required Duration timeout,
  }) {
    final detail = _preferredOutput(result);
    if (result.timedOut) {
      return 'Policy violation: quality_gate dependency bootstrap timed out '
              'after ${timeout.inSeconds}s: "$command". '
              '${detail.isEmpty ? '' : 'Output: ${_truncate(detail, _maxFailureDetail)}'}'
          .trim();
    }
    final buffer = StringBuffer()
      ..write(
        'Policy violation: quality_gate dependency bootstrap failed '
        '(exit ${result.exitCode}): "$command".',
      );
    if (detail.isNotEmpty) {
      buffer.write(' Output: ${_truncate(detail, _maxFailureDetail)}');
    }
    return buffer.toString();
  }

  Future<ShellCommandResult> _runCommand(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    try {
      return await _commandRunner.run(
        command,
        workingDirectory: workingDirectory,
        timeout: timeout,
      );
    } catch (error) {
      throw StateError(
        'Policy violation: quality_gate could not run "$command". '
        'Error: ${_truncate(error.toString(), _maxFailureDetail)}',
      );
    }
  }

  String _buildSummary(
    List<_CommandExecution> executions, {
    required String profile,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Quality Gate: passed (${executions.length} checks, profile=$profile)',
    );
    for (final execution in executions) {
      final retrySuffix = execution.attempts > 1
          ? ', attempts=${execution.attempts}'
          : '';
      buffer.writeln(
        '- PASS `${execution.command}` (${execution.result.duration.inMilliseconds}ms$retrySuffix)',
      );
    }
    return buffer.toString().trimRight();
  }

  String _buildFailureMessage({
    required String command,
    required ShellCommandResult result,
    required Duration timeout,
  }) {
    final detail = _preferredOutput(result);
    if (result.timedOut) {
      return 'Policy violation: quality_gate command timed out '
              'after ${timeout.inSeconds}s: "$command". '
              '${detail.isEmpty ? '' : 'Output: ${_truncate(detail, _maxFailureDetail)}'}'
          .trim();
    }

    final buffer = StringBuffer()
      ..write(
        'Policy violation: quality_gate command failed '
        '(exit ${result.exitCode}): "$command".',
      );
    if (detail.isNotEmpty) {
      buffer.write(' Output: ${_truncate(detail, _maxFailureDetail)}');
    }
    return buffer.toString();
  }

  void _enforceShellAllowlist(
    String projectRoot,
    ProjectConfig config,
    List<String> commands,
  ) {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: config.shellAllowlist,
      enabled: true,
    );
    for (final command in commands) {
      if (policy.allows(command)) {
        continue;
      }
      _appendLog(
        projectRoot,
        event: 'quality_gate_blocked',
        message: 'Quality gate command blocked by shell allowlist',
        data: {
          'root': projectRoot,
          'command': command,
          'shell_allowlist_profile': config.shellAllowlistProfile,
          'shell_allowlist_size': config.shellAllowlist.length,
          'error_class': 'quality_gate',
          'error_kind': 'shell_allowlist',
        },
      );
      throw StateError(
        'Policy violation: shell_allowlist blocked quality_gate command '
        '"$command". Update policies.shell_allowlist or '
        'policies.shell_allowlist_profile in .genaisys/config.yml.',
      );
    }
  }

  _CommandPlan _resolveCommandPlan({
    required String projectRoot,
    required ProjectConfig config,
    required List<String> configuredCommands,
    required List<String> changedPaths,
  }) {
    if (!config.qualityGateAdaptiveByDiff) {
      return _CommandPlan(profile: 'configured', commands: configuredCommands);
    }
    final footprint = _DiffFootprint.fromPaths(changedPaths);
    if (footprint.isEmpty) {
      return _CommandPlan(profile: 'configured', commands: configuredCommands);
    }
    if (footprint.isDocsOnly && config.qualityGateSkipTestsForDocsOnly) {
      final withoutTests = configuredCommands
          .where((entry) => !_isTestCommand(entry))
          .toList(growable: false);
      return _CommandPlan(profile: 'docs_only', commands: withoutTests);
    }
    if (footprint.isTestDartOnly) {
      final changedDartPaths = _collectChangedDartPaths(
        projectRoot,
        changedPaths,
      );
      final changedTestPaths = _collectChangedTestDartPaths(
        projectRoot,
        changedPaths,
      );
      if (changedTestPaths.isNotEmpty) {
        final narrowed = configuredCommands
            .map((entry) {
              var adapted = _scopeDartFormatCheckToPaths(
                entry,
                changedDartPaths,
              );
              if (_isTestCommand(adapted)) {
                adapted = _narrowTestCommandToChangedPaths(
                  adapted,
                  changedTestPaths,
                );
              }
              return adapted;
            })
            .toList(growable: false);
        return _CommandPlan(
          profile: 'test_dart_only',
          commands: ProjectConfig.normalizeQualityGateCommands(narrowed),
        );
      }
    }
    if (footprint.isLibTestDartOnly) {
      final changedDartPaths = _collectChangedDartPaths(
        projectRoot,
        changedPaths,
      );
      final changedTestPaths = _collectChangedTestDartPaths(
        projectRoot,
        changedPaths,
      );
      final adapted = configuredCommands
          .map((entry) {
            var next = _scopeDartFormatCheckToPaths(entry, changedDartPaths);
            if (_isTestCommand(next) && changedTestPaths.isNotEmpty) {
              next = _narrowTestCommandToChangedPaths(next, changedTestPaths);
            }
            return next;
          })
          .toList(growable: false);
      return _CommandPlan(
        profile: 'lib_test_dart_only',
        commands: ProjectConfig.normalizeQualityGateCommands(adapted),
      );
    }
    if (footprint.isLibDartOnly &&
        config.qualityGatePreferDartTestForLibDartOnly) {
      final supportsDartTest = _supportsDartTest(projectRoot);
      final changedDartPaths = _collectChangedDartPaths(
        projectRoot,
        changedPaths,
      );
      final relatedTestPaths = _collectRelatedTestDartPaths(
        projectRoot,
        changedDartPaths,
      );
      final adapted = configuredCommands
          .map((entry) {
            final scoped = _scopeDartFormatCheckToPaths(
              entry,
              changedDartPaths,
            );
            final rewritten = supportsDartTest
                ? _rewriteFlutterTestToDartTest(scoped)
                : scoped;
            if (_isTestCommand(rewritten) && relatedTestPaths.isNotEmpty) {
              return _narrowTestCommandToChangedPaths(
                rewritten,
                relatedTestPaths,
              );
            }
            if (rewritten == scoped) {
              return scoped;
            }
            if (_commandAllowedByShellAllowlist(config, rewritten)) {
              return rewritten;
            }
            return scoped;
          })
          .toList(growable: false);
      return _CommandPlan(
        profile: 'lib_dart_only',
        commands: ProjectConfig.normalizeQualityGateCommands(adapted),
      );
    }
    return _CommandPlan(profile: 'configured', commands: configuredCommands);
  }

  bool _isFlakeRetryEligible({
    required String command,
    required ShellCommandResult result,
    required int retryCount,
  }) {
    if (retryCount < 1) {
      return false;
    }
    if (result.timedOut) {
      return false;
    }
    return _isTestCommand(command);
  }

  bool _isTestCommand(String command) {
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null || parsed.tokens.isEmpty) {
      return false;
    }
    final executable = parsed.tokens[0];
    // Single-word test commands (e.g. "pytest").
    if (executable == 'pytest') {
      return true;
    }
    // Two-word test commands (e.g. "dart test", "npm test", "cargo test").
    if (parsed.tokens.length < 2) {
      return false;
    }
    final subcommand = parsed.tokens[1];
    if (subcommand == 'test') {
      return executable == 'dart' ||
          executable == 'flutter' ||
          executable == 'npm' ||
          executable == 'cargo' ||
          executable == 'go' ||
          executable == 'mvn';
    }
    return false;
  }

  /// Detects the "no test files found" condition for Dart/Flutter test runners.
  ///
  /// `dart test` and `flutter test` exit with code 65 when no test files exist.
  /// The combined stdout+stderr will contain "No test" or "no test" in that
  /// case.  We only treat this as a no-test pass when the command is actually
  /// a test command and the exit code is exactly 65.
  bool _isNoTestFilesResult({
    required String command,
    required ShellCommandResult result,
  }) {
    if (result.timedOut) {
      return false;
    }
    if (result.exitCode != 65) {
      return false;
    }
    if (!_isTestCommand(command)) {
      return false;
    }
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null || parsed.tokens.isEmpty) {
      return false;
    }
    // Only Dart/Flutter test runners use exit code 65 for "no tests".
    final executable = parsed.tokens[0];
    if (executable != 'dart' && executable != 'flutter') {
      return false;
    }
    final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    return output.contains('no test') || output.contains('no test/');
  }

  bool _supportsDartTest(String projectRoot) {
    final pubspec = File('$projectRoot/pubspec.yaml');
    if (!pubspec.existsSync()) {
      return false;
    }
    final text = pubspec.readAsStringSync();
    return _hasDevDependency(text, 'test');
  }

  bool _hasDevDependency(String pubspecText, String name) {
    final lines = const LineSplitter().convert(pubspecText);
    var inDevDependencies = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final isTopLevel = !line.startsWith(' ') && !line.startsWith('\t');
      if (isTopLevel) {
        inDevDependencies = line.trimRight() == 'dev_dependencies:';
        continue;
      }
      if (!inDevDependencies) {
        continue;
      }
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('$name:')) {
        return true;
      }
    }
    return false;
  }

  String _rewriteFlutterTestToDartTest(String command) {
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null || parsed.tokens.length < 2) {
      return command;
    }
    if (parsed.tokens[0] != 'flutter' || parsed.tokens[1] != 'test') {
      return command;
    }
    final rewritten = <String>['dart', 'test', ...parsed.tokens.skip(2)];
    return rewritten.map(_quoteShellToken).join(' ');
  }

  bool _commandAllowedByShellAllowlist(ProjectConfig config, String command) {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: config.shellAllowlist,
      enabled: true,
    );
    return policy.allows(command);
  }

  List<String> _collectChangedDartPaths(
    String projectRoot,
    List<String> changedPaths,
  ) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in changedPaths) {
      final path = raw.replaceAll('\\', '/').trim();
      if (!path.endsWith('.dart')) {
        continue;
      }
      if (!seen.add(path)) {
        continue;
      }
      final file = File(_join(projectRoot, path));
      if (!file.existsSync()) {
        continue;
      }
      normalized.add(path);
    }
    return normalized;
  }

  List<String> _collectChangedTestDartPaths(
    String projectRoot,
    List<String> changedPaths,
  ) {
    final dartPaths = _collectChangedDartPaths(projectRoot, changedPaths);
    return dartPaths
        .where(
          (path) => path.startsWith('test/') && path.endsWith('_test.dart'),
        )
        .toList(growable: false);
  }

  List<String> _collectRelatedTestDartPaths(
    String projectRoot,
    List<String> changedDartPaths,
  ) {
    if (changedDartPaths.isEmpty) {
      return const <String>[];
    }
    final prefixes = <String>{};
    for (final path in changedDartPaths) {
      final normalized = path.replaceAll('\\', '/').trim();
      if (!normalized.startsWith('lib/') || !normalized.endsWith('.dart')) {
        continue;
      }
      final segments = normalized.split('/');
      if (segments.length < 3) {
        continue;
      }
      final area = segments[1].trim();
      final domain = segments[2].trim();
      if (area.isEmpty || domain.isEmpty) {
        continue;
      }
      prefixes.add('test/$area/$domain');
    }
    if (prefixes.isEmpty) {
      return const <String>[];
    }

    final testRoot = Directory(_join(projectRoot, 'test'));
    if (!testRoot.existsSync()) {
      return const <String>[];
    }

    final projectRootNormalized = projectRoot.replaceAll('\\', '/');
    final related = <String>{};
    for (final entity in testRoot.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final fullPath = entity.path.replaceAll('\\', '/');
      if (!fullPath.endsWith('_test.dart')) {
        continue;
      }
      if (!fullPath.startsWith(projectRootNormalized)) {
        continue;
      }
      var relative = fullPath.substring(projectRootNormalized.length);
      relative = relative.replaceFirst(RegExp(r'^/+'), '');
      if (!relative.startsWith('test/')) {
        continue;
      }
      for (final prefix in prefixes) {
        if (relative.startsWith(prefix)) {
          related.add(relative);
          break;
        }
      }
    }
    final sorted = related.toList(growable: false)..sort();
    return sorted;
  }

  String _narrowTestCommandToChangedPaths(
    String command,
    List<String> changedTestPaths,
  ) {
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null || parsed.tokens.length < 2) {
      return command;
    }
    if (_testCommandAlreadyTargetsPaths(parsed.tokens)) {
      return command;
    }
    final narrowedTokens = <String>[...parsed.tokens, ...changedTestPaths];
    return narrowedTokens.map(_quoteShellToken).join(' ');
  }

  bool _testCommandAlreadyTargetsPaths(List<String> tokens) {
    for (final token in tokens.skip(2)) {
      if (token.startsWith('-')) {
        continue;
      }
      if (token.endsWith('.dart') || token.startsWith('test/')) {
        return true;
      }
    }
    return false;
  }

  String _scopeDartFormatCheckToPaths(
    String command,
    List<String> changedDartPaths,
  ) {
    if (changedDartPaths.isEmpty) {
      return command;
    }
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null || parsed.tokens.length < 2) {
      return command;
    }
    if (parsed.tokens[0] != 'dart' || parsed.tokens[1] != 'format') {
      return command;
    }

    final tokens = parsed.tokens;
    final hasSetExitIfChanged = tokens.contains('--set-exit-if-changed');
    if (!hasSetExitIfChanged) {
      return command;
    }

    final targetIndexes = <int>[];
    for (var i = 2; i < tokens.length; i++) {
      if (tokens[i].startsWith('-')) {
        continue;
      }
      targetIndexes.add(i);
    }

    if (targetIndexes.isEmpty) {
      return [...tokens, ...changedDartPaths].map(_quoteShellToken).join(' ');
    }

    final targets = targetIndexes
        .map((index) => tokens[index])
        .toList(growable: false);
    if (targets.length == 1 && targets.first == '.') {
      final rewritten = <String>[
        ...tokens.take(targetIndexes.first),
        ...changedDartPaths,
      ];
      return rewritten.map(_quoteShellToken).join(' ');
    }
    return command;
  }

  bool _hasGlobalSetExitFormatCheck(List<String> commands) {
    for (final command in commands) {
      final parsed = ShellCommandTokenizer.tryParse(command);
      if (parsed == null || parsed.tokens.length < 2) {
        continue;
      }
      if (parsed.tokens[0] != 'dart' || parsed.tokens[1] != 'format') {
        continue;
      }
      if (!parsed.tokens.contains('--set-exit-if-changed')) {
        continue;
      }
      final hasGlobalTarget = parsed.tokens.any((token) => token == '.');
      if (hasGlobalTarget) {
        return true;
      }
    }
    return false;
  }

  String _buildDartFormatCommand(List<String> paths) {
    final quoted = paths.map(_quoteShellToken).join(' ');
    return 'dart format $quoted';
  }

  String _quoteShellToken(String value) {
    if (value.isEmpty) {
      return "''";
    }
    if (!RegExp(r'''[\s'"`$]''').hasMatch(value)) {
      return value;
    }
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  String _join(String base, String relative) {
    final separator = Platform.pathSeparator;
    if (base.endsWith(separator)) {
      return '$base$relative';
    }
    return '$base$separator$relative';
  }

  String _preferredOutput(ShellCommandResult result) {
    final stderr = result.stderr.trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    return result.stdout.trim();
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  void _appendLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(
      layout.runLogPath,
    ).append(event: event, message: message, data: data);
  }

  static const int _maxFailureDetail = 600;
}

class _CommandExecution {
  const _CommandExecution({
    required this.command,
    required this.result,
    required this.attempts,
  });

  final String command;
  final ShellCommandResult result;
  final int attempts;
}

class _CommandPlan {
  const _CommandPlan({required this.profile, required this.commands});

  final String profile;
  final List<String> commands;
}

class _DiffFootprint {
  const _DiffFootprint({
    required this.isEmpty,
    required this.isDocsOnly,
    required this.isLibDartOnly,
    required this.isTestDartOnly,
    required this.isLibTestDartOnly,
  });

  factory _DiffFootprint.fromPaths(List<String> paths) {
    var hasAny = false;
    var allDocs = true;
    var allLibDart = true;
    var allTestDart = true;
    var allLibTestDart = true;
    var hasLibDart = false;
    var hasTestDart = false;
    for (final raw in paths) {
      final path = raw.replaceAll('\\', '/').trim();
      if (path.isEmpty) {
        continue;
      }
      hasAny = true;
      final isLibDart = path.startsWith('lib/') && path.endsWith('.dart');
      final isTestDart = path.startsWith('test/') && path.endsWith('.dart');
      if (!_isDocPath(path)) {
        allDocs = false;
      }
      if (!isLibDart) {
        allLibDart = false;
      } else {
        hasLibDart = true;
      }
      if (!isTestDart) {
        allTestDart = false;
      } else {
        hasTestDart = true;
      }
      if (!(isLibDart || isTestDart)) {
        allLibTestDart = false;
      }
    }
    if (!hasAny) {
      return const _DiffFootprint(
        isEmpty: true,
        isDocsOnly: false,
        isLibDartOnly: false,
        isTestDartOnly: false,
        isLibTestDartOnly: false,
      );
    }
    return _DiffFootprint(
      isEmpty: false,
      isDocsOnly: allDocs,
      isLibDartOnly: allLibDart,
      isTestDartOnly: allTestDart,
      isLibTestDartOnly: allLibTestDart && hasLibDart && hasTestDart,
    );
  }

  static bool _isDocPath(String path) {
    if (path.startsWith('docs/')) {
      return true;
    }
    final lower = path.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.mdx');
  }

  final bool isEmpty;
  final bool isDocsOnly;
  final bool isLibDartOnly;
  final bool isTestDartOnly;
  final bool isLibTestDartOnly;
}
