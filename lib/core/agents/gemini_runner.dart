// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'agent_runner.dart';
import 'agent_runner_mixin.dart';

class GeminiRunner with AgentRunnerMixin {
  GeminiRunner({
    this.executable = 'gemini',
    this.args = const [
      '--approval-mode',
      'yolo',
      '--prompt',
      '-',
      '--output-format',
      'text',
    ],
  });

  @override
  final String executable;
  @override
  final List<String> args;
  static const String _configOverridesEnvKey =
      'GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES';

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

    // Gemini CLI accepts flags like -y, --model, --sandbox, etc.
    // Only allow `-flag` or `--flag` style entries (with optional =value).
    final filtered = <String>[];
    final seen = <String>{};
    final pattern = RegExp(r'^--?[a-zA-Z0-9_-]+(=.+|\s+\S+)?$');
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
