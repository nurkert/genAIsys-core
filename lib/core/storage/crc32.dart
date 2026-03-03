// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:typed_data';

/// Lightweight CRC32 (ISO 3309 / ITU-T V.42) implementation.
///
/// Uses the standard polynomial 0xEDB88320 (reflected) and a 256-entry
/// lookup table for fast computation.  This avoids pulling in a heavy
/// external dependency just for state-file integrity checks.
class Crc32 {
  Crc32._();

  static final Uint32List _table = _buildTable();

  /// Compute CRC32 of a UTF-8 encoded [text].
  static int ofString(String text) {
    return ofBytes(utf8.encode(text));
  }

  /// Compute CRC32 of raw [bytes].
  static int ofBytes(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = _table[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Return the CRC32 value as a zero-padded lowercase hex string.
  static String hexOfString(String text) {
    return ofString(text).toRadixString(16).padLeft(8, '0');
  }

  /// Return the CRC32 value as a zero-padded lowercase hex string.
  static String hexOfBytes(List<int> bytes) {
    return ofBytes(bytes).toRadixString(16).padLeft(8, '0');
  }

  static Uint32List _buildTable() {
    const polynomial = 0xEDB88320;
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var crc = i;
      for (var j = 0; j < 8; j++) {
        if (crc & 1 == 1) {
          crc = (crc >>> 1) ^ polynomial;
        } else {
          crc = crc >>> 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }
}
