// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'agent_runner.dart';
import 'agent_runner_mixin.dart';

/// Provider adapter for the Claude Code CLI (`claude`).
///
/// Runs in print mode (`-p`) with text output. When a system prompt is
/// provided, it is passed via the `--system-prompt` CLI flag so that stdin
/// carries only the user prompt. Supports both hard timeout and idle timeout
/// (fail-closed when no output is produced within the idle window). Auth works
/// via stored session (`claude login`) or via `ANTHROPIC_API_KEY` environment
/// variable.
class ClaudeCodeRunner with AgentRunnerMixin {
  ClaudeCodeRunner({
    this.executable = 'claude',
    this.args = const ['-p', '--output-format', 'text'],
  });

  @override
  final String executable;
  @override
  final List<String> args;
  static const String _configOverridesEnvKey =
      'GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES';

  @override
  Future<AgentResponse> runProcess(
    String exec,
    List<String> execArgs,
    AgentRequest request, {
    required bool runInShell,
  }) {
    var effectiveArgs = _applyConfigOverrides(execArgs, request.environment);
    if (request.systemPrompt != null &&
        request.systemPrompt!.trim().isNotEmpty) {
      effectiveArgs = [
        ...effectiveArgs,
        '--system-prompt',
        request.systemPrompt!,
      ];
    }
    return runWithIdleMonitoring(
      exec,
      effectiveArgs,
      request,
      runInShell: runInShell,
    );
  }

  /// When `--system-prompt` flag is used, stdin carries only the user prompt.
  @override
  String buildInput(AgentRequest request) => request.prompt;

  List<String> _applyConfigOverrides(
    List<String> execArgs,
    Map<String, String>? environment,
  ) {
    if (execArgs.isEmpty) {
      return execArgs;
    }
    final raw = environment?[_configOverridesEnvKey];
    if (raw == null || raw.trim().isEmpty) {
      return execArgs;
    }

    final overrides = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        overrides.add(trimmed);
      }
    }
    if (overrides.isEmpty) {
      return execArgs;
    }

    // Claude Code CLI accepts flags like --model, --max-turns, etc.
    // Only allow `--flag value` or `--flag=value` style entries.
    final filtered = <String>[];
    final seen = <String>{};
    final pattern = RegExp(r'^--[a-zA-Z0-9_-]+(=.+|\s+\S+)?$');
    for (final entry in overrides) {
      if (!pattern.hasMatch(entry)) {
        continue;
      }
      if (seen.add(entry)) {
        filtered.add(entry);
      }
    }
    if (filtered.isEmpty) {
      return execArgs;
    }

    // Insert overrides before the positional arguments but after core flags.
    final out = <String>[...execArgs];
    for (final entry in filtered) {
      if (entry.contains('=')) {
        out.add(entry);
      } else {
        // Split `--flag value` into two args.
        final parts = entry.split(RegExp(r'\s+'));
        out.addAll(parts);
      }
    }
    return out;
  }
}
