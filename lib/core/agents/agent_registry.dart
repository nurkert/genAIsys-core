// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'amp_runner.dart';
import 'agent_runner.dart';
import 'claude_code_runner.dart';
import 'codex_runner.dart';
import 'gemini_runner.dart';
import 'vibe_runner.dart';

class AgentRegistry {
  AgentRegistry({
    AgentRunner? codex,
    AgentRunner? gemini,
    AgentRunner? claudeCode,
    AgentRunner? vibe,
    AgentRunner? amp,
    Map<String, AgentRunner>? custom,
  }) : _runners = _buildRunners(
         codex: codex,
         gemini: gemini,
         claudeCode: claudeCode,
         vibe: vibe,
         amp: amp,
         custom: custom,
       );

  final Map<String, AgentRunner> _runners;

  AgentRunner? resolve(String provider) {
    final key = _normalizeKey(provider);
    if (key.isEmpty) {
      return null;
    }
    return _runners[key];
  }

  AgentRunner resolveOrDefault(String? provider) {
    final key = _normalizeKey(provider);
    final runner = key.isEmpty ? null : _runners[key];
    return runner ?? _defaultRunner();
  }

  AgentRunner _defaultRunner() {
    final codex = _runners['codex'];
    if (codex != null) {
      return codex;
    }
    if (_runners.isNotEmpty) {
      return _runners.values.first;
    }
    throw StateError('No agent runners registered.');
  }

  static Map<String, AgentRunner> _buildRunners({
    AgentRunner? codex,
    AgentRunner? gemini,
    AgentRunner? claudeCode,
    AgentRunner? vibe,
    AgentRunner? amp,
    Map<String, AgentRunner>? custom,
  }) {
    final hasExplicit =
        codex != null ||
        gemini != null ||
        claudeCode != null ||
        vibe != null ||
        amp != null ||
        custom != null;
    if (!hasExplicit) {
      // Production default — all runners available.
      return {
        'codex': CodexRunner(),
        'gemini': GeminiRunner(),
        'claude-code': ClaudeCodeRunner(),
        'vibe': VibeRunner(),
        'amp': AmpRunner(),
      };
    }
    return {
      'codex': ?codex,
      'gemini': ?gemini,
      'claude-code': ?claudeCode,
      'vibe': ?vibe,
      'amp': ?amp,
      if (custom != null) ..._normalizeKeys(custom),
    };
  }
}

Map<String, AgentRunner> _normalizeKeys(Map<String, AgentRunner> input) {
  final output = <String, AgentRunner>{};
  for (final entry in input.entries) {
    final key = _normalizeKey(entry.key);
    if (key.isEmpty) {
      continue;
    }
    output[key] = entry.value;
  }
  return output;
}

String _normalizeKey(String? value) {
  return value?.trim().toLowerCase() ?? '';
}
