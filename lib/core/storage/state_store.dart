// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../models/project_state.dart';
import 'atomic_file_write.dart';
import 'crc32.dart';

/// Callback invoked when state corruption is detected during [StateStore.read].
///
/// Receives the file path, the expected checksum (from file), and the
/// computed checksum.  Callers can use this to emit structured run-log events.
typedef CorruptionCallback =
    void Function({
      required String path,
      required String expected,
      required String computed,
    });

class StateStore {
  StateStore(this.statePath, {CorruptionCallback? onCorruption})
    : _onCorruption = onCorruption;

  final String statePath;
  final CorruptionCallback? _onCorruption;

  /// Key used to embed the CRC32 checksum in the serialized JSON.
  static const String checksumKey = '_checksum';

  ProjectState read() {
    final file = File(statePath);
    if (!file.existsSync()) {
      return ProjectState.initial();
    }
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return ProjectState.initial();
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(content);
      if (raw is! Map) {
        _onCorruption?.call(
          path: statePath,
          expected: 'object',
          computed: '${raw.runtimeType}',
        );
        return ProjectState.initial();
      }
      decoded = Map<String, dynamic>.from(raw);
    } on FormatException {
      _onCorruption?.call(
        path: statePath,
        expected: 'valid_json',
        computed: 'parse_error',
      );
      return ProjectState.initial();
    }

    // Verify checksum if present.
    final storedChecksum = decoded.remove(checksumKey);
    if (storedChecksum is String && storedChecksum.isNotEmpty) {
      final payloadForHash = const JsonEncoder.withIndent(
        '  ',
      ).convert(decoded);
      final computed = Crc32.hexOfString(payloadForHash);
      if (computed != storedChecksum) {
        _onCorruption?.call(
          path: statePath,
          expected: storedChecksum,
          computed: computed,
        );
        return ProjectState.initial();
      }
    }

    return ProjectState.fromJson(decoded);
  }

  void write(ProjectState state) {
    final stateJson = state.toJson();
    // Remove any pre-existing checksum key to avoid double-embedding.
    stateJson.remove(checksumKey);
    final payload = const JsonEncoder.withIndent('  ').convert(stateJson);
    final checksum = Crc32.hexOfString(payload);

    // Re-encode with the checksum appended at the end.
    stateJson[checksumKey] = checksum;
    final fullPayload = const JsonEncoder.withIndent('  ').convert(stateJson);
    AtomicFileWrite.writeStringSync(statePath, fullPayload);
  }
}
