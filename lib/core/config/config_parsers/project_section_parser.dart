// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'config_parse_utils.dart';
import 'config_parser_state.dart';

/// Parses key-value pairs under the `project:` section.
void parseProjectKeyValue(ConfigParserState s, ConfigKeyValue kv) {
  if (kv.key == 'type') {
    final raw = kv.value.trim().toLowerCase();
    if (raw.isNotEmpty) {
      s.projectType = raw;
    }
  }
}
