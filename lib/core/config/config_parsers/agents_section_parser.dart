// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'config_parse_utils.dart';
import 'config_parser_state.dart';

/// Handles subsection headers under `agents:` (indent 2).
void parseAgentsSubsection(ConfigParserState s, String key) {
  s.currentAgentsSection = key.trim().toLowerCase();
}

/// Parses key-value pairs under an `agents:` subsection.
void parseAgentsKeyValue(ConfigParserState s, ConfigKeyValue kv) {
  final agent = s.currentAgentsSection;
  if (agent == null || agent.isEmpty) {
    return;
  }
  if (kv.key == 'enabled') {
    s.agentEnabled[agent] = kv.value.toLowerCase() == 'true';
  } else if (kv.key == 'system_prompt') {
    s.agentPromptPaths[agent] = kv.value;
  }
}
