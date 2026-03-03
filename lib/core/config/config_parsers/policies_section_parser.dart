// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';
import 'config_parse_utils.dart';
import 'config_parser_state.dart';

/// Handles subsection headers under `policies:` (indent 2+).
void parsePoliciesSubsection(ConfigParserState s, String key, int indent) {
  if (indent == 2) {
    s.currentPoliciesSection = key;
    s.currentPoliciesListKey = null;
    s.currentCategoryMapKey = null;
  } else if (s.currentPoliciesSection == 'safe_write' && indent >= 4) {
    s.currentPoliciesListKey = key == 'roots' ? 'roots' : null;
  } else if (s.currentPoliciesSection == 'quality_gate' && indent >= 4) {
    s.currentPoliciesListKey = key == 'commands' ? 'commands' : null;
  } else if (s.currentPoliciesSection == 'timeouts' && indent >= 4) {
    if (key == 'agent_seconds_by_category') {
      s.currentCategoryMapKey = 'agent_seconds_by_category';
    } else {
      s.currentCategoryMapKey = null;
    }
  }
}

/// Handles list items (`- ...`) under `policies:`.
/// Returns `true` if the item was consumed.
bool parsePoliciesListItem(ConfigParserState s, String trimmed) {
  if (s.currentPoliciesSection == 'safe_write' &&
      s.currentPoliciesListKey == 'roots') {
    s.safeWriteRoots.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentPoliciesSection == 'quality_gate' &&
      s.currentPoliciesListKey == 'commands') {
    s.qualityGateCommands.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  if (s.currentPoliciesSection == 'shell_allowlist') {
    s.shellAllowlist.add(stripQuotes(trimmed.substring(2).trim()));
    return true;
  }
  return false;
}

/// Handles key-value pairs under `policies:` for non-registry keys.
///
/// Registry-driven scalar keys (enabled, timeout_seconds, etc.) are handled
/// by [parseRegistryKeyValue] before this function is reached.
void parsePoliciesKeyValue(ConfigParserState s, ConfigKeyValue kv) {
  if (s.currentPoliciesSection == 'safe_write') {
    if (kv.key == 'roots') {
      s.currentPoliciesListKey = 'roots';
      s.safeWriteRoots.addAll(parseInlineList(kv.value));
    }
  } else if (s.currentPoliciesSection == 'quality_gate') {
    if (kv.key == 'commands') {
      s.currentPoliciesListKey = 'commands';
      s.qualityGateCommands.addAll(parseInlineList(kv.value));
    }
  }
}

/// Normalizes the allowlist, ensuring minimal required entries.
List<String> normalizeAllowlist(List<String> allowlist) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final entry in allowlist) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (seen.add(trimmed)) {
      normalized.add(trimmed);
    }
  }
  for (final required in ProjectConfig.minimalShellAllowlist) {
    if (seen.add(required)) {
      normalized.add(required);
    }
  }
  return normalized;
}
