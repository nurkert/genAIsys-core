// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'agent_service.dart';

extension _AgentServiceEnvironment on AgentService {
  AgentResponse? _preflight(
    AgentRunner runner, {
    required Map<String, String>? environment,
    required AgentRequest request,
  }) {
    if (runner is CodexRunner) {
      return _checkExecutable(
        runner.executable,
        args: runner.args,
        environment: environment,
        request: request,
      );
    }
    if (runner is GeminiRunner) {
      return _checkExecutable(
        runner.executable,
        args: runner.args,
        environment: environment,
        request: request,
      );
    }
    if (runner is ClaudeCodeRunner) {
      return _checkExecutable(
        runner.executable,
        args: runner.args,
        environment: environment,
        request: request,
      );
    }
    if (runner is VibeRunner) {
      return _checkExecutable(
        runner.executable,
        args: runner.args,
        environment: environment,
        request: request,
      );
    }
    if (runner is AmpRunner) {
      return _checkExecutable(
        runner.executable,
        args: runner.args,
        environment: environment,
        request: request,
      );
    }
    // Fallback for wrapped or unknown runners that still have executable/args
    try {
      final dynamic r = runner;
      final String exe = r.executable;
      final List<String> args = List<String>.from(r.args);
      return _checkExecutable(
        exe,
        args: args,
        environment: environment,
        request: request,
      );
    } catch (_) {}

    return null;
  }

  AgentResponse? _checkExecutable(
    String executable, {
    required List<String> args,
    required Map<String, String>? environment,
    required AgentRequest request,
  }) {
    final resolved = resolveExecutable(
      executable,
      environment: environment,
      extraSearchPaths: defaultSearchPaths(),
    );
    if (resolved != null) {
      return null;
    }
    final message = AgentErrorHints.missingExecutableMessage(
      executable,
      path: environment?['PATH'],
    );
    return AgentResponse(
      exitCode: 127,
      stdout: '',
      stderr: message,
      commandEvent: AgentCommandEvent(
        executable: executable,
        arguments: List<String>.unmodifiable(args),
        runInShell: false,
        startedAt: DateTime.now().toUtc().toIso8601String(),
        durationMs: 0,
        timedOut: false,
        workingDirectory: request.workingDirectory,
        phase: 'preflight',
      ),
    );
  }

  AgentRequest _normalizeEnvironment(
    AgentRequest request, {
    Duration? timeout,
    required bool unattendedMode,
  }) {
    final env = <String, String>{...Platform.environment};
    if (request.environment != null) {
      env.addAll(request.environment!);
    }
    env['PATH'] = _augmentPath(env['PATH']);

    // Prevent unattended runs from hanging indefinitely in provider calls that
    // produce no output (e.g., auth prompts, stuck network I/O). This is
    // intentionally fail-closed: we'll retry/rotate providers rather than stall.
    if (unattendedMode) {
      env.putIfAbsent('GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS', () {
        final effective = timeout ?? request.timeout;
        final cap = effective != null && effective.inSeconds > 0
            ? effective.inSeconds
            : 0;
        // Default to 5 minutes, but never exceed the overall agent timeout.
        final desired = 300;
        if (cap <= 0) return desired.toString();
        return (desired > cap ? cap : desired).toString();
      });
    }
    return AgentRequest(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      workingDirectory: request.workingDirectory,
      environment: env,
      timeout: timeout ?? request.timeout,
    );
  }

  AgentRequest _applyCandidateEnvironment(
    AgentRequest request,
    SelectedAgentRunner candidate,
  ) {
    if (candidate.environment.isEmpty) {
      return request;
    }
    final merged = <String, String>{...?request.environment};
    merged.addAll(candidate.environment);
    return AgentRequest(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      workingDirectory: request.workingDirectory,
      environment: merged,
      timeout: request.timeout,
    );
  }

  String _augmentPath(String? current) {
    final separator = Platform.isWindows ? ';' : ':';
    final paths = <String>[];

    // Check for test override
    final testEnv = Zone.current[#genaisys_test_env];
    final effectiveCurrent = (testEnv is Map && testEnv.containsKey('PATH'))
        ? testEnv['PATH'] as String?
        : current;

    if (effectiveCurrent != null && effectiveCurrent.trim().isNotEmpty) {
      paths.addAll(
        effectiveCurrent
            .split(separator)
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty),
      );
    }
    for (final extra in _defaultPathHints()) {
      if (!paths.contains(extra)) {
        paths.add(extra);
      }
    }
    return paths.join(separator);
  }

  List<String> _defaultPathHints() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final userBinPaths = <String>[];
    if (home != null) {
      if (Platform.isLinux || Platform.isMacOS) {
        userBinPaths.add(
          _joinPath(home, '.npm-global${Platform.pathSeparator}bin'),
        );
        userBinPaths.add(_joinPath(home, '.local${Platform.pathSeparator}bin'));
        userBinPaths.add(_joinPath(home, 'bin'));
      }
    }

    if (Platform.isMacOS) {
      return [
        ...userBinPaths,
        '/opt/homebrew/bin',
        '/usr/local/bin',
        '/usr/bin',
        '/bin',
      ];
    }
    if (Platform.isLinux) {
      return [...userBinPaths, '/usr/local/bin', '/usr/bin', '/bin'];
    }
    if (Platform.isWindows) {
      return const [r'C:\Windows\System32', r'C:\Windows'];
    }
    return const [];
  }

  String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }

  void _recordCommandAudit(
    String projectRoot, {
    required ProjectConfig config,
    required String provider,
    required AgentRequest request,
    required AgentResponse response,
    required String attempt,
    required bool usedFallback,
  }) {
    final command = _requireCommandEvent(
      projectRoot,
      response: response,
      provider: provider,
      attempt: attempt,
    );
    _enforceCommandPolicy(
      projectRoot,
      config: config,
      command: command,
      provider: provider,
      attempt: attempt,
    );
    _commandAuditService.record(
      projectRoot,
      runner: provider,
      attempt: attempt,
      usedFallback: usedFallback,
      request: request,
      response: response,
      command: command,
    );
  }

  AgentCommandEvent _requireCommandEvent(
    String projectRoot, {
    required AgentResponse response,
    required String provider,
    required String attempt,
  }) {
    final command = response.commandEvent;
    if (command != null) {
      return command;
    }
    _throwPolicyViolation(
      projectRoot,
      reason: 'agent_command event missing from runner response',
      provider: provider,
      attempt: attempt,
      errorKind: 'missing_event',
    );
  }

  void _enforceCommandPolicy(
    String projectRoot, {
    required ProjectConfig config,
    required AgentCommandEvent command,
    required String provider,
    required String attempt,
  }) {
    if (command.executable.trim().isEmpty) {
      _throwPolicyViolation(
        projectRoot,
        reason: 'agent_command.executable is empty',
        provider: provider,
        attempt: attempt,
        errorKind: 'invalid_event',
      );
    }
    if (DateTime.tryParse(command.startedAt) == null) {
      _throwPolicyViolation(
        projectRoot,
        reason: 'agent_command.started_at is invalid',
        provider: provider,
        attempt: attempt,
        errorKind: 'invalid_event',
      );
    }
    if (command.durationMs < 0) {
      _throwPolicyViolation(
        projectRoot,
        reason: 'agent_command.duration_ms is negative',
        provider: provider,
        attempt: attempt,
        errorKind: 'invalid_event',
      );
    }
    if (command.phase != 'run' && command.phase != 'preflight') {
      _throwPolicyViolation(
        projectRoot,
        reason: 'agent_command.phase "${command.phase}" is not allowed',
        provider: provider,
        attempt: attempt,
        errorKind: 'invalid_event',
      );
    }
    _enforceShellAllowlist(
      projectRoot,
      config: config,
      command: command,
      provider: provider,
      attempt: attempt,
    );
  }

  void _enforceShellAllowlist(
    String projectRoot, {
    required ProjectConfig config,
    required AgentCommandEvent command,
    required String provider,
    required String attempt,
  }) {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: config.shellAllowlist,
      enabled: true,
    );
    final executable = command.executable.trim();
    final baseExecutable = _basename(executable);
    final args = command.arguments
        .map((item) => item.trim())
        .toList(growable: false);
    final baseCommand = args.isEmpty
        ? baseExecutable
        : '$baseExecutable ${args.join(' ')}';
    final candidates = <String>{
      command.commandLine.trim(),
      executable,
      baseExecutable,
      baseCommand.trim(),
    }.where((entry) => entry.isNotEmpty).toList(growable: false);

    for (final candidate in candidates) {
      if (policy.allows(candidate)) {
        return;
      }
    }

    _throwPolicyViolation(
      projectRoot,
      reason:
          'shell_allowlist blocked agent command "${baseCommand.trim().isEmpty ? command.commandLine : baseCommand}"',
      provider: provider,
      attempt: attempt,
      errorKind: 'shell_allowlist',
    );
  }

  String _basename(String value) {
    final normalized = value.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      return '';
    }
    final parts = normalized.split('/');
    return parts.isEmpty ? normalized : parts.last.trim();
  }

  Never _throwPolicyViolation(
    String projectRoot, {
    required String reason,
    required String provider,
    required String attempt,
    required String errorKind,
  }) {
    final message = 'Policy violation: $reason (fail-closed).';
    _blockProviderForUnattended(
      projectRoot,
      provider: provider,
      reason: reason,
      attempt: attempt,
      errorKind: errorKind,
    );
    _appendPolicyViolation(
      projectRoot,
      provider: provider,
      attempt: attempt,
      reason: reason,
      errorKind: errorKind,
    );
    throw StateError(message);
  }
}
