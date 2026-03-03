// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent_error_hints.dart';
import 'agent_runner.dart';
import 'executable_resolver.dart';

/// Shared process-management utilities for [AgentRunner] implementations.
///
/// Concrete runners mix this in and override [executable], [args], and the
/// abstract [runProcess] hook which defines provider-specific stream handling.
mixin AgentRunnerMixin implements AgentRunner {
  String get executable;
  List<String> get args;

  static const int timeoutExitCode = 124;
  static const String idleTimeoutEnvKey =
      'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS';

  // ---------------------------------------------------------------------------
  // run() template
  // ---------------------------------------------------------------------------

  /// Resolves the executable and delegates to [runProcess].
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final resolved = resolveExecutable(
      executable,
      environment: request.environment,
      extraSearchPaths: defaultSearchPaths(),
    );
    final execToUse = resolved ?? executable;
    final runInShell = resolved == null;
    return runProcess(execToUse, args, request, runInShell: runInShell);
  }

  /// Provider-specific process orchestration.
  ///
  /// Override this in the concrete runner to control how stdout/stderr are
  /// consumed (e.g. simple `utf8.decodeStream` vs. subscription-based idle
  /// monitoring).  The shared helpers in this mixin handle everything else.
  Future<AgentResponse> runProcess(
    String exec,
    List<String> execArgs,
    AgentRequest request, {
    required bool runInShell,
  });

  // ---------------------------------------------------------------------------
  // Environment sanitization
  // ---------------------------------------------------------------------------

  /// Keys that must never leak into child agent processes.
  ///
  /// Both Claude Code and Amp set `CLAUDECODE=1` to detect nested sessions;
  /// Gemini CLI sets `GEMINI_CLI` similarly. Removing these prevents child
  /// agents from thinking they are already inside a parent session.
  static const List<String> _blockedEnvKeys = [
    'CLAUDECODE', // Claude Code + Amp (Amp sets CLAUDECODE=1)
    'GEMINI_CLI', // Gemini CLI subprocess marker
  ];

  /// Returns a sanitized copy of [environment] with blocked keys removed.
  ///
  /// When [environment] is `null` (inherit parent), creates a copy of the
  /// current process environment, strips blocked keys, and returns it.
  /// When [environment] is provided, strips blocked keys and returns a copy.
  static Map<String, String> sanitizeEnvironment(
    Map<String, String>? environment,
  ) {
    final base = environment ?? Map<String, String>.from(Platform.environment);
    final sanitized = Map<String, String>.from(base);
    for (final key in _blockedEnvKeys) {
      sanitized.remove(key);
    }
    return sanitized;
  }

  // ---------------------------------------------------------------------------
  // Input composition
  // ---------------------------------------------------------------------------

  String buildInput(AgentRequest request) {
    if (request.systemPrompt == null || request.systemPrompt!.trim().isEmpty) {
      return request.prompt;
    }
    return 'System: ${request.systemPrompt}\n\n${request.prompt}';
  }

  // ---------------------------------------------------------------------------
  // Process start / stdin helpers
  // ---------------------------------------------------------------------------

  /// Writes the composed input to [process.stdin] and closes it, ignoring
  /// broken-pipe errors that occur when the process exits early.
  Future<void> writeAndCloseStdin(Process process, AgentRequest request) async {
    try {
      process.stdin.write(buildInput(request));
    } on IOException catch (_) {
      // Ignore broken pipe if the process exits before consuming stdin.
    }
    try {
      await process.stdin.close();
    } on IOException catch (_) {
      // Ignore close errors from early process exit.
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  int mapProcessExceptionToExitCode(String detail) {
    final lower = detail.toLowerCase();
    if (lower.contains('permission denied') ||
        lower.contains('operation not permitted')) {
      return 126;
    }
    return 127;
  }

  String composeProcessError(String detail, String hint) {
    final buffer = StringBuffer();
    buffer.writeln(detail.trim());
    if (hint.trim().isNotEmpty) {
      buffer.writeln(hint.trim());
    }
    return buffer.toString().trim();
  }

  /// Builds an error [AgentResponse] from a [ProcessException].
  AgentResponse buildProcessExceptionResponse({
    required String exec,
    required List<String> execArgs,
    required bool runInShell,
    required AgentRequest request,
    required DateTime startedAt,
    required Stopwatch stopwatch,
    required ProcessException error,
  }) {
    final detail = error.toString();
    final code = mapProcessExceptionToExitCode(detail);
    final hint = AgentErrorHints.hintForExitCode(
      code,
      executable: exec,
      detail: detail,
      path: request.environment?['PATH'],
    );
    final message = composeProcessError(detail, hint);
    stopwatch.stop();
    return AgentResponse(
      exitCode: code,
      stdout: '',
      stderr: message,
      commandEvent: buildCommandEvent(
        executable: exec,
        arguments: execArgs,
        runInShell: runInShell,
        request: request,
        startedAt: startedAt,
        durationMs: stopwatch.elapsedMilliseconds,
        timedOut: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Process termination
  // ---------------------------------------------------------------------------

  void terminateProcess(Process process) {
    try {
      process.kill();
      if (!Platform.isWindows) {
        // Kill the entire process group so child processes are also cleaned up.
        try {
          Process.killPid(-process.pid, ProcessSignal.sigterm);
        } catch (_) {
          // Best-effort: process group kill may fail if PID is already dead.
        }
        process.kill(ProcessSignal.sigkill);
        try {
          Process.killPid(-process.pid, ProcessSignal.sigkill);
        } catch (_) {
          // Best-effort: force-kill may fail if process already exited.
        }
      }
    } catch (_) {
      // Best-effort: the process may have already exited.
    }
  }

  // ---------------------------------------------------------------------------
  // Stream finalization
  // ---------------------------------------------------------------------------

  Future<String> finalizeStream(
    StreamSubscription<String>? sub,
    Completer<void> done,
    StringBuffer buffer,
  ) async {
    try {
      await sub?.cancel();
    } catch (_) {
      // Best-effort: subscription may already be cancelled or broken.
    }
    try {
      await done.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Best-effort: stream did not complete within drain window.
    } catch (_) {
      // Best-effort: stream completion may fail with I/O or state errors.
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Timeout messages
  // ---------------------------------------------------------------------------

  String appendTimeoutMessage(String stderr, Duration timeout) {
    final message = 'Timed out after ${timeout.inSeconds}s.';
    if (stderr.trim().isEmpty) {
      return message;
    }
    return '$stderr\n$message';
  }

  String appendIdleTimeoutMessage(String stderr, AgentIdleTimeout idle) {
    final seconds = idle.duration?.inSeconds ?? 0;
    final message = seconds > 0
        ? 'No agent output for ${seconds}s (idle timeout).'
        : 'No agent output (idle timeout).';
    if (stderr.trim().isEmpty) {
      return message;
    }
    return '$stderr\n$message';
  }

  // ---------------------------------------------------------------------------
  // Idle-timeout parsing
  // ---------------------------------------------------------------------------

  Duration? parseIdleTimeout(Map<String, String>? environment) {
    final raw = environment?[idleTimeoutEnvKey]?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final seconds = int.tryParse(raw);
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  // ---------------------------------------------------------------------------
  // Command event construction
  // ---------------------------------------------------------------------------

  AgentCommandEvent buildCommandEvent({
    required String executable,
    required List<String> arguments,
    required bool runInShell,
    required AgentRequest request,
    required DateTime startedAt,
    required int durationMs,
    required bool timedOut,
  }) {
    return AgentCommandEvent(
      executable: executable,
      arguments: List<String>.unmodifiable(arguments),
      runInShell: runInShell,
      startedAt: startedAt.toIso8601String(),
      durationMs: durationMs < 0 ? 0 : durationMs,
      timedOut: timedOut,
      workingDirectory: request.workingDirectory,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared process lifecycle with idle monitoring
  // ---------------------------------------------------------------------------

  /// Runs a child process with subscription-based idle monitoring.
  ///
  /// Shared by [CodexRunner] and [ClaudeCodeRunner] which both need to detect
  /// idle agents (no output for a configurable window). The caller is
  /// responsible for applying any provider-specific config overrides to
  /// [execArgs] before calling this method.
  Future<AgentResponse> runWithIdleMonitoring(
    String exec,
    List<String> execArgs,
    AgentRequest request, {
    required bool runInShell,
  }) async {
    final startedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    final idleTimeout = parseIdleTimeout(request.environment);
    Process process;
    try {
      process = await Process.start(
        exec,
        execArgs,
        workingDirectory: request.workingDirectory,
        environment: AgentRunnerMixin.sanitizeEnvironment(request.environment),
        includeParentEnvironment: false,
        runInShell: runInShell,
      );
    } on ProcessException catch (error) {
      return buildProcessExceptionResponse(
        exec: exec,
        execArgs: execArgs,
        runInShell: runInShell,
        request: request,
        startedAt: startedAt,
        stopwatch: stopwatch,
        error: error,
      );
    }

    await writeAndCloseStdin(process, request);

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    Timer? idleTimer;
    final idleTriggered = Completer<void>();

    void resetIdleTimer() {
      if (idleTimeout == null || idleTimeout.inMilliseconds <= 0) {
        return;
      }
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () {
        if (!idleTriggered.isCompleted) {
          idleTriggered.complete();
        }
      });
    }

    // Start idle timer immediately: if the provider never emits any output,
    // we still fail-closed instead of hanging silently.
    resetIdleTimer();
    try {
      stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              stdoutBuffer.write(chunk);
              resetIdleTimer();
            },
            onError: (_) {},
            onDone: () {
              if (!stdoutDone.isCompleted) {
                stdoutDone.complete();
              }
            },
            cancelOnError: false,
          );

      stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              stderrBuffer.write(chunk);
              resetIdleTimer();
            },
            onError: (_) {},
            onDone: () {
              if (!stderrDone.isCompleted) {
                stderrDone.complete();
              }
            },
            cancelOnError: false,
          );

      final timeout = request.timeout;
      int exitCode;
      if (timeout != null && timeout.inMilliseconds > 0) {
        try {
          exitCode = await Future.any<int>([
            process.exitCode,
            idleTriggered.future.then<int>((_) {
              throw AgentIdleTimeout(idleTimeout);
            }),
          ]).timeout(timeout);
        } on TimeoutException {
          terminateProcess(process);
          final stdout = await finalizeStream(
            stdoutSub,
            stdoutDone,
            stdoutBuffer,
          );
          final stderr = await finalizeStream(
            stderrSub,
            stderrDone,
            stderrBuffer,
          );
          stopwatch.stop();
          return AgentResponse(
            exitCode: AgentRunnerMixin.timeoutExitCode,
            stdout: stdout,
            stderr: appendTimeoutMessage(stderr, timeout),
            commandEvent: buildCommandEvent(
              executable: exec,
              arguments: execArgs,
              runInShell: runInShell,
              request: request,
              startedAt: startedAt,
              durationMs: stopwatch.elapsedMilliseconds,
              timedOut: true,
            ),
          );
        } on AgentIdleTimeout catch (idle) {
          terminateProcess(process);
          final stdout = await finalizeStream(
            stdoutSub,
            stdoutDone,
            stdoutBuffer,
          );
          final stderr = await finalizeStream(
            stderrSub,
            stderrDone,
            stderrBuffer,
          );
          stopwatch.stop();
          return AgentResponse(
            exitCode: AgentRunnerMixin.timeoutExitCode,
            stdout: stdout,
            stderr: appendIdleTimeoutMessage(stderr, idle),
            commandEvent: buildCommandEvent(
              executable: exec,
              arguments: execArgs,
              runInShell: runInShell,
              request: request,
              startedAt: startedAt,
              durationMs: stopwatch.elapsedMilliseconds,
              timedOut: true,
            ),
          );
        }
      } else {
        exitCode = await Future.any<int>([
          process.exitCode,
          idleTriggered.future.then<int>((_) {
            throw AgentIdleTimeout(idleTimeout);
          }),
        ]);
      }
      final stdout = await finalizeStream(stdoutSub, stdoutDone, stdoutBuffer);
      final stderr = await finalizeStream(stderrSub, stderrDone, stderrBuffer);
      stopwatch.stop();

      return AgentResponse(
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
        commandEvent: buildCommandEvent(
          executable: exec,
          arguments: execArgs,
          runInShell: runInShell,
          request: request,
          startedAt: startedAt,
          durationMs: stopwatch.elapsedMilliseconds,
          timedOut: false,
        ),
      );
    } finally {
      idleTimer?.cancel();
    }
  }
}

/// Thrown internally to signal an idle-timeout condition.
class AgentIdleTimeout implements Exception {
  AgentIdleTimeout(this.duration);

  final Duration? duration;
}
