// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

class CliJsonDecoder {
  const CliJsonDecoder();

  Map<String, dynamic>? decodeFirstJsonLine(String output) {
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final decoded = decodeJsonLine(trimmed);
      if (decoded != null) {
        return decoded;
      }
    }
    return null;
  }

  Map<String, dynamic>? decodeJsonLine(String line) {
    try {
      final parsed = jsonDecode(line);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      if (parsed is Map) {
        return parsed.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
