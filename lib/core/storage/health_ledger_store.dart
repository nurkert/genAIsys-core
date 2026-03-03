// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../models/code_health_models.dart';

/// Append-only JSONL store for delivery health snapshots.
///
/// Follows the same pattern as [RunLogStore] — one JSON object per line,
/// stored at `.genaisys/health_ledger.jsonl`.
class HealthLedgerStore {
  HealthLedgerStore(this.ledgerPath);

  final String ledgerPath;

  /// Append a delivery health entry to the ledger.
  void append(DeliveryHealthEntry entry) {
    final file = File(ledgerPath);
    final line = '${jsonEncode(entry.toJson())}\n';
    try {
      file.writeAsStringSync(line, mode: FileMode.append);
    } catch (e) {
      // Best-effort: ledger writes should never block the main pipeline.
      try {
        stderr.writeln('[HealthLedgerStore] Failed to append entry: $e');
      } catch (_) {
        // Ultimate fallback: ignore.
      }
    }
  }

  /// Read the most recent entries from the ledger.
  ///
  /// Returns up to [maxEntries] entries, most recent last.
  /// Silently skips malformed lines.
  List<DeliveryHealthEntry> readRecent({int maxEntries = 50}) {
    final file = File(ledgerPath);
    if (!file.existsSync()) {
      return const [];
    }
    try {
      final lines = file
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final startIndex =
          lines.length > maxEntries ? lines.length - maxEntries : 0;
      final recent = lines.sublist(startIndex);
      final entries = <DeliveryHealthEntry>[];
      for (final line in recent) {
        try {
          final json = jsonDecode(line);
          if (json is Map<String, Object?>) {
            entries.add(DeliveryHealthEntry.fromJson(json));
          }
        } catch (_) {
          // Skip malformed lines.
        }
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// Compute how frequently each file was touched in the last [windowSize]
  /// deliveries.
  ///
  /// Returns a map of file path → touch count.
  Map<String, int> fileTouchFrequency({int windowSize = 20}) {
    final entries = readRecent(maxEntries: windowSize);
    final frequency = <String, int>{};
    for (final entry in entries) {
      for (final file in entry.files) {
        frequency[file.filePath] = (frequency[file.filePath] ?? 0) + 1;
      }
    }
    return frequency;
  }
}
