// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import '../policy/safe_write_policy.dart';
import '../policy/shell_allowlist_policy.dart';
import 'agent_runner.dart';
import 'native_http_runner.dart';
import 'native_tool_definitions.dart';
import 'native_tool_executor.dart';

/// Agent runner that implements a multi-turn tool-calling loop over an
/// OpenAI-compatible HTTP endpoint.
///
/// Each turn: send messages → if the LLM returns tool_calls, execute them and
/// append results → repeat. When the LLM returns content without tool_calls
/// (or the turn cap is reached), the loop ends.
class NativeAgentLoopRunner implements AgentRunner {
  NativeAgentLoopRunner({
    required this.httpRunner,
    required this.maxTurns,
    required this.safeWriteEnabled,
    required this.safeWriteRoots,
    required this.shellAllowlist,
  });

  final NativeHttpRunner httpRunner;
  final int maxTurns;
  final bool safeWriteEnabled;
  final List<String> safeWriteRoots;
  final List<String> shellAllowlist;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final startedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    final projectRoot = request.workingDirectory ?? '.';

    // Build policy instances.
    final safeWritePolicy = SafeWritePolicy(
      projectRoot: projectRoot,
      allowedRoots: safeWriteRoots,
      enabled: safeWriteEnabled,
    );
    final shellAllowlistPolicy = ShellAllowlistPolicy(
      allowedPrefixes: shellAllowlist,
    );
    final executor = NativeToolExecutor(
      projectRoot: projectRoot,
      safeWritePolicy: safeWritePolicy,
      shellAllowlistPolicy: shellAllowlistPolicy,
    );

    // Resolve API key from environment.
    final effectiveApiKey = _resolveApiKey(request.environment);

    // Build initial messages.
    final messages = <Map<String, Object?>>[
      if (request.systemPrompt != null &&
          request.systemPrompt!.trim().isNotEmpty)
        {'role': 'system', 'content': request.systemPrompt!},
      {'role': 'user', 'content': request.prompt},
    ];
    final tools = NativeToolDefinitions.all();
    final toolLog = StringBuffer();
    String? lastContent;

    // Calculate total timeout budget.
    final totalTimeout = request.timeout;
    final deadline = totalTimeout != null
        ? startedAt.add(totalTimeout)
        : null;

    for (var turn = 0; turn < maxTurns; turn++) {
      // Check remaining time budget.
      Duration? turnTimeout;
      if (deadline != null) {
        final remaining = deadline.difference(DateTime.now().toUtc());
        if (remaining.isNegative || remaining == Duration.zero) {
          stopwatch.stop();
          return AgentResponse(
            exitCode: 124,
            stdout: toolLog.toString(),
            stderr: 'Timed out after ${totalTimeout!.inSeconds}s '
                '(turn $turn).',
            commandEvent: _buildCommandEvent(
              request: request,
              startedAt: startedAt,
              durationMs: stopwatch.elapsedMilliseconds,
              timedOut: true,
            ),
          );
        }
        turnTimeout = remaining;
      }

      final result = await httpRunner.chatWithTools(
        messages: messages,
        tools: tools,
        apiKeyOverride: effectiveApiKey,
        timeout: turnTimeout,
      );

      // HTTP error → propagate immediately.
      if (!result.ok) {
        stopwatch.stop();
        return AgentResponse(
          exitCode: result.exitCode,
          stdout: toolLog.toString(),
          stderr: result.stderr,
          commandEvent: _buildCommandEvent(
            request: request,
            startedAt: startedAt,
            durationMs: stopwatch.elapsedMilliseconds,
            timedOut: result.exitCode == 124,
          ),
        );
      }

      // Remember content if present (even alongside tool calls).
      if (result.content != null && result.content!.isNotEmpty) {
        lastContent = result.content;
      }

      // No tool calls → done.
      if (!result.hasToolCalls) {
        break;
      }

      // Token limit reached → done.
      if (result.finishReason == 'length') {
        break;
      }

      // Append assistant message (with tool_calls) to history.
      if (result.assistantMessage != null) {
        messages.add(result.assistantMessage!);
      }

      // Execute each tool call and append results.
      for (final toolCall in result.toolCalls) {
        final toolResult = await executor.execute(toolCall);
        messages.add(toolResult.toToolMessage());

        // Audit log.
        final status = toolResult.isError ? 'ERROR' : 'OK';
        toolLog.writeln(
          '[tool:${toolCall.functionName}] $status '
          '(id=${toolCall.id})',
        );
      }
    }

    stopwatch.stop();
    final stdout = StringBuffer();
    if (toolLog.isNotEmpty) {
      stdout.writeln(toolLog.toString().trimRight());
      stdout.writeln('---');
    }
    if (lastContent != null) {
      stdout.write(lastContent);
    }

    return AgentResponse(
      exitCode: 0,
      stdout: stdout.toString(),
      stderr: '',
      commandEvent: _buildCommandEvent(
        request: request,
        startedAt: startedAt,
        durationMs: stopwatch.elapsedMilliseconds,
        timedOut: false,
      ),
    );
  }

  String _resolveApiKey(Map<String, String>? environment) {
    if (httpRunner.apiKey.isNotEmpty) return httpRunner.apiKey;
    return environment?['GENAISYS_NATIVE_API_KEY'] ?? '';
  }

  AgentCommandEvent _buildCommandEvent({
    required AgentRequest request,
    required DateTime startedAt,
    required int durationMs,
    required bool timedOut,
  }) {
    return AgentCommandEvent(
      executable: NativeHttpRunner.syntheticExecutable,
      arguments: ['POST', '${httpRunner.apiBase}/chat/completions'],
      runInShell: false,
      startedAt: startedAt.toIso8601String(),
      durationMs: durationMs < 0 ? 0 : durationMs,
      timedOut: timedOut,
      workingDirectory: request.workingDirectory,
    );
  }
}
