// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';
import 'config_parse_utils.dart';
import 'config_parser_state.dart';

/// Handles subsection headers under `providers:` (indent 2).
void parseProvidersSubsection(ConfigParserState s, String key) {
  s.currentCategoryMapKey = null;
  if (key == 'reasoning_effort_by_category') {
    s.currentCategoryMapKey = 'reasoning_effort_by_category';
    s.currentProvidersListKey = null;
    s.currentNativeSubsection = null;
  } else if (key == 'native') {
    s.currentNativeSubsection = 'native';
    s.currentProvidersListKey = null;
  } else {
    s.currentNativeSubsection = null;
    s.currentProvidersListKey = key == 'pool'
        ? 'pool'
        : key == 'codex_cli_config_overrides'
        ? 'codex_cli_config_overrides'
        : key == 'claude_code_cli_config_overrides'
        ? 'claude_code_cli_config_overrides'
        : key == 'gemini_cli_config_overrides'
        ? 'gemini_cli_config_overrides'
        : key == 'vibe_cli_config_overrides'
        ? 'vibe_cli_config_overrides'
        : key == 'amp_cli_config_overrides'
        ? 'amp_cli_config_overrides'
        : null;
  }
}

/// Handles list items (`- ...`) under `providers:`.
/// Returns `true` if the item was consumed.
bool parseProvidersListItem(ConfigParserState s, String trimmed) {
  if (s.currentProvidersListKey == 'pool') {
    s.providerPoolRaw.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentProvidersListKey == 'codex_cli_config_overrides') {
    s.codexCliConfigOverrides.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentProvidersListKey == 'claude_code_cli_config_overrides') {
    s.claudeCodeCliConfigOverrides.add(
      stripQuotes(trimmed.substring(2).trim()),
    );
    return true;
  }
  if (s.currentProvidersListKey == 'gemini_cli_config_overrides') {
    s.geminiCliConfigOverrides.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentProvidersListKey == 'vibe_cli_config_overrides') {
    s.vibeCliConfigOverrides.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentProvidersListKey == 'amp_cli_config_overrides') {
    s.ampCliConfigOverrides.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  return false;
}

/// Handles key-value pairs under `providers:`.
void parseProvidersKeyValue(ConfigParserState s, ConfigKeyValue kv, int indent) {
  if (s.currentNativeSubsection == 'native' && indent >= 4) {
    _parseNativeKeyValue(s, kv);
    return;
  }
  if (kv.key == 'primary') {
    s.primary = kv.value;
  } else if (kv.key == 'fallback') {
    s.fallback = kv.value;
  } else if (kv.key == 'pool') {
    s.currentProvidersListKey = 'pool';
    s.providerPoolRaw.addAll(parseInlineList(kv.value));
  } else if (kv.key == 'codex_cli_config_overrides') {
    s.currentProvidersListKey = 'codex_cli_config_overrides';
    s.codexCliConfigOverrides.addAll(parseInlineList(kv.value));
  } else if (kv.key == 'claude_code_cli_config_overrides') {
    s.currentProvidersListKey = 'claude_code_cli_config_overrides';
    s.claudeCodeCliConfigOverrides.addAll(parseInlineList(kv.value));
  } else if (kv.key == 'gemini_cli_config_overrides') {
    s.currentProvidersListKey = 'gemini_cli_config_overrides';
    s.geminiCliConfigOverrides.addAll(parseInlineList(kv.value));
  } else if (kv.key == 'vibe_cli_config_overrides') {
    s.currentProvidersListKey = 'vibe_cli_config_overrides';
    s.vibeCliConfigOverrides.addAll(parseInlineList(kv.value));
  } else if (kv.key == 'amp_cli_config_overrides') {
    s.currentProvidersListKey = 'amp_cli_config_overrides';
    s.ampCliConfigOverrides.addAll(parseInlineList(kv.value));
  }
}

void _parseNativeKeyValue(ConfigParserState s, ConfigKeyValue kv) {
  if (kv.key == 'api_base') {
    final v = stripQuotes(kv.value.trim());
    if (v.isNotEmpty) s.nativeApiBase = v;
  } else if (kv.key == 'model') {
    final v = stripQuotes(kv.value.trim());
    if (v.isNotEmpty) s.nativeModel = v;
  } else if (kv.key == 'api_key') {
    s.nativeApiKey = stripQuotes(kv.value);
  } else if (kv.key == 'temperature') {
    s.nativeTemperature = double.tryParse(kv.value.trim());
  } else if (kv.key == 'max_tokens') {
    final v = int.tryParse(kv.value.trim());
    if (v != null && v > 0) s.nativeMaxTokens = v;
  } else if (kv.key == 'max_turns') {
    final v = int.tryParse(kv.value.trim());
    if (v != null && v > 0) s.nativeMaxTurns = v;
  }
}

/// Resolves the final provider pool from raw entries, primary, and fallback.
///
/// When an explicit pool is configured, the [primary] provider (if set and
/// present in the pool) is promoted to the front so it is attempted first.
/// This ensures `providers.primary` always determines the first-tried
/// provider, regardless of the order entries appear in the pool list.
List<ProviderPoolEntry> resolveProviderPoolEntries({
  required List<String> configured,
  required String? primary,
  required String? fallback,
}) {
  final source = configured.isNotEmpty
      ? configured
      : <String>[
          if (normalizeProviderKey(primary) != null) primary!,
          if (normalizeProviderKey(fallback) != null) fallback!,
        ];
  final entries = <ProviderPoolEntry>[];
  final seen = <String>{};
  for (final raw in source) {
    final entry = _parseProviderPoolEntry(raw);
    if (entry == null) {
      continue;
    }
    if (seen.add(entry.key)) {
      entries.add(entry);
    }
  }

  // When an explicit primary is set and exists in the pool, promote it to
  // the front so the pool order respects the user's primary preference.
  final normalizedPrimary = normalizeProviderKey(primary);
  if (normalizedPrimary != null && entries.length > 1) {
    final primaryIndex = entries.indexWhere(
      (e) => e.provider == normalizedPrimary,
    );
    if (primaryIndex > 0) {
      final promoted = entries.removeAt(primaryIndex);
      entries.insert(0, promoted);
    }
  }

  return List<ProviderPoolEntry>.unmodifiable(entries);
}

ProviderPoolEntry? _parseProviderPoolEntry(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final marker = trimmed.indexOf('@');
  String providerRaw;
  String accountRaw;
  if (marker < 0) {
    providerRaw = trimmed;
    accountRaw = ProviderPoolEntry.defaultAccount;
  } else {
    providerRaw = trimmed.substring(0, marker).trim();
    accountRaw = trimmed.substring(marker + 1).trim();
  }
  final provider = normalizeProviderKey(providerRaw);
  if (provider == null) {
    return null;
  }
  final account = _normalizeProviderAccount(accountRaw);
  return ProviderPoolEntry(provider: provider, account: account);
}

String _normalizeProviderAccount(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return ProviderPoolEntry.defaultAccount;
  }
  return trimmed;
}

String? normalizeProviderKey(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
