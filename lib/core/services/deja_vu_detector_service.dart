// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:math' as math;

import '../models/code_health_models.dart';
import '../storage/health_ledger_store.dart';

/// Layer 2: Behavioral pattern analysis over recent delivery history.
///
/// Detects file hotspots, patch clusters (same file in consecutive deliveries),
/// and growing complexity trends. Pure Dart, no LLM.
class DejaVuDetectorService {
  DejaVuDetectorService({required HealthLedgerStore ledgerStore})
      : _ledgerStore = ledgerStore;

  final HealthLedgerStore _ledgerStore;

  /// Detect deja-vu patterns in recent delivery history.
  List<CodeHealthSignal> detect(
    String projectRoot, {
    int windowSize = 20,
    double hotspotThreshold = 0.3,
    int patchClusterMin = 3,
  }) {
    final entries = _ledgerStore.readRecent(maxEntries: windowSize);
    if (entries.isEmpty) return const [];

    final signals = <CodeHealthSignal>[];

    signals.addAll(_detectHotspots(entries, hotspotThreshold));
    signals.addAll(_detectPatchClusters(entries, patchClusterMin));
    signals.addAll(_detectGrowingComplexity(entries));

    return signals;
  }

  /// Files with touch rate > threshold across the window.
  ///
  /// Requires at least 3 entries for meaningful frequency analysis.
  List<CodeHealthSignal> _detectHotspots(
    List<DeliveryHealthEntry> entries,
    double threshold,
  ) {
    final entryCount = entries.length;
    if (entryCount < 3) return const [];

    final touchCount = <String, int>{};
    for (final entry in entries) {
      for (final file in entry.files) {
        touchCount[file.filePath] = (touchCount[file.filePath] ?? 0) + 1;
      }
    }

    final signals = <CodeHealthSignal>[];
    for (final entry in touchCount.entries) {
      final rate = entry.value / entryCount;
      if (rate > threshold) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.dejaVu,
          confidence: math.min(1.0, rate),
          finding: '${entry.key} touched in ${entry.value}/$entryCount '
              'recent deliveries (${(rate * 100).toStringAsFixed(0)}% rate)',
          affectedFiles: [entry.key],
          suggestedAction:
              'Investigate why this file keeps changing — may need decomposition',
        ));
      }
    }
    return signals;
  }

  /// Same file in N or more consecutive deliveries.
  List<CodeHealthSignal> _detectPatchClusters(
    List<DeliveryHealthEntry> entries,
    int minConsecutive,
  ) {
    if (entries.length < minConsecutive) return const [];

    // Build per-file presence arrays (ordered by delivery).
    final allFiles = <String>{};
    for (final entry in entries) {
      for (final file in entry.files) {
        allFiles.add(file.filePath);
      }
    }

    final signals = <CodeHealthSignal>[];
    for (final filePath in allFiles) {
      var maxConsecutive = 0;
      var currentRun = 0;
      for (final entry in entries) {
        final present = entry.files.any((f) => f.filePath == filePath);
        if (present) {
          currentRun++;
          if (currentRun > maxConsecutive) maxConsecutive = currentRun;
        } else {
          currentRun = 0;
        }
      }
      if (maxConsecutive >= minConsecutive) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.dejaVu,
          confidence: math.min(1.0, maxConsecutive / 5),
          finding: '$filePath modified in $maxConsecutive consecutive '
              'deliveries (patch cluster)',
          affectedFiles: [filePath],
          suggestedAction:
              'Repeated patches suggest symptom-level fixes — investigate root cause',
        ));
      }
    }
    return signals;
  }

  /// File's complexity metrics increased in 3+ of the last 5 snapshots.
  List<CodeHealthSignal> _detectGrowingComplexity(
    List<DeliveryHealthEntry> entries,
  ) {
    if (entries.length < 3) return const [];

    // Build per-file metric history.
    final history = <String, List<FileHealthSnapshot>>{};
    for (final entry in entries) {
      for (final file in entry.files) {
        history.putIfAbsent(file.filePath, () => []).add(file);
      }
    }

    final signals = <CodeHealthSignal>[];
    for (final entry in history.entries) {
      final snapshots = entry.value;
      if (snapshots.length < 3) continue;

      // Take the last 5 snapshots.
      final recent = snapshots.length > 5
          ? snapshots.sublist(snapshots.length - 5)
          : snapshots;

      var growthCount = 0;
      for (var i = 1; i < recent.length; i++) {
        if (recent[i].lineCount > recent[i - 1].lineCount ||
            recent[i].maxMethodLines > recent[i - 1].maxMethodLines) {
          growthCount++;
        }
      }

      if (growthCount >= 3) {
        signals.add(CodeHealthSignal(
          layer: HealthSignalLayer.dejaVu,
          confidence: growthCount / 5,
          finding: '${entry.key} complexity is growing — increased in '
              '$growthCount of last ${recent.length} snapshots',
          affectedFiles: [entry.key],
          suggestedAction:
              'Proactive refactoring needed before complexity becomes entrenched',
        ));
      }
    }
    return signals;
  }
}
