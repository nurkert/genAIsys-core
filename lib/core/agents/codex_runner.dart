// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'agent_runner.dart';
import 'agent_runner_mixin.dart';

class CodexRunner with AgentRunnerMixin {
  CodexRunner({
    this.executable = 'codex',
    this.args = const ['exec', '--color', 'never', '-'],
  });

  @override
  final String executable;
  @override
  final List<String> args;
  static const String _configOverridesEnvKey =
      'GENAISYS_CODEX_CLI_CONFIG_OVERRIDES';

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

    // Only allow `key=value` style entries to avoid argument smuggling.
    final filtered = <String>[];
    final seen = <String>{};
    final pattern = RegExp(r'^[a-zA-Z0-9_.-]+\s*=.+$');
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

    // Insert right after `exec` and before the stdin `-` prompt marker (if any).
    final out = <String>[execArgs.first];
    for (final entry in filtered) {
      out.addAll(['-c', entry]);
    }
    if (execArgs.length == 1) {
      return out;
    }

    final rest = execArgs.sublist(1);
    if (rest.isNotEmpty && rest.last == '-') {
      out.addAll(rest.sublist(0, rest.length - 1));
      out.add('-');
      return out;
    }
    out.addAll(rest);
    return out;
  }
}
