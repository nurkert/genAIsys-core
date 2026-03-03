// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'agent_runner.dart';
import 'agent_runner_mixin.dart';

/// Provider adapter for the Mistral Vibe CLI (`vibe`).
///
/// Runs with `--auto-approve` for unattended automation, piping the composed
/// prompt via stdin. Supports both hard timeout and idle timeout (fail-closed
/// when no output is produced within the idle window). Auth works via stored
/// session or via `MISTRAL_API_KEY` environment variable.
class VibeRunner with AgentRunnerMixin {
  VibeRunner({
    this.executable = 'vibe',
    this.args = const ['--prompt', '-', '--output', 'text', '--auto-approve'],
  });

  @override
  final String executable;
  @override
  final List<String> args;
  static const String _configOverridesEnvKey =
      'GENAISYS_VIBE_CLI_CONFIG_OVERRIDES';

  @override
  Future<AgentResponse> runProcess(
    String exec,
    List<String> execArgs,
    AgentRequest request, {
    required bool runInShell,
  }) {
    final effectiveArgs = _applyConfigOverrides(execArgs, request.environment);
    return runWithIdleMonitoring(
      exec,
      effectiveArgs,
      request,
      runInShell: runInShell,
    );
  }

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

    // Vibe CLI accepts flags like --model, --max-turns, etc.
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

    // Prepend overrides before the existing args so they don't split
    // `--prompt -` (where `-` is the stdin value for `--prompt`).
    final prefix = <String>[];
    for (final entry in filtered) {
      if (entry.contains('=')) {
        prefix.add(entry);
      } else {
        prefix.addAll(entry.split(RegExp(r'\s+')));
      }
    }
    return [...prefix, ...execArgs];
  }
}
