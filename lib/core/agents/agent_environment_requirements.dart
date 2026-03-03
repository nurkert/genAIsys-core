// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class AgentEnvironmentRequirements {
  /// Single source of truth for required environment variables by provider.
  /// Each inner list is an "any-of" group; all groups must be satisfied.
  static const Map<String, List<List<String>>> byProvider = {
    // Codex CLI is intentionally credential-agnostic at Genaisys level.
    // Authentication is delegated to the installed CLI/session state.
    'codex': [],
    // Gemini CLI can authenticate via stored session (`gemini auth`) or via
    // API key. The env var requirement is optional: when the list is empty the
    // startup validation treats the provider as always-available (session auth).
    'gemini': <List<String>>[],
    // Claude Code can authenticate via stored session (`claude login`) or via
    // API key. The env var requirement is optional: when the list is empty the
    // startup validation treats the provider as always-available (session auth).
    'claude-code': <List<String>>[],
    // Vibe CLI can authenticate via stored session or via MISTRAL_API_KEY.
    'vibe': <List<String>>[],
    // Amp CLI can authenticate via stored session (`amp login`) or via
    // AMP_API_KEY. The env var requirement is optional (session auth).
    'amp': <List<String>>[],
    // Native HTTP runner: API key is optional (Ollama runs without auth).
    // Users can set GENAISYS_NATIVE_API_KEY for providers that require it.
    'native': <List<String>>[],
  };

  static List<String> flattenedForProvider(String provider) {
    final key = provider.trim().toLowerCase();
    if (key.isEmpty) {
      return const [];
    }
    final groups = byProvider[key];
    if (groups == null) {
      return const [];
    }
    final unique = <String>[];
    for (final group in groups) {
      for (final variable in group) {
        if (!unique.contains(variable)) {
          unique.add(variable);
        }
      }
    }
    return unique;
  }
}
