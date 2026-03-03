// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../config/project_config.dart';
import '../project_layout.dart';
import '../storage/atomic_file_write.dart';

/// A single entry in the error pattern registry.
class ErrorPatternEntry {
  ErrorPatternEntry({
    required this.errorKind,
    required this.count,
    required this.lastSeen,
    this.resolutionStrategy,
    this.autoResolvedCount = 0,
  });

  factory ErrorPatternEntry.fromJson(Map<String, dynamic> json) {
    return ErrorPatternEntry(
      errorKind: json['error_kind']?.toString() ?? '',
      count: json['count'] is int ? json['count'] as int : 0,
      lastSeen: json['last_seen']?.toString() ?? '',
      resolutionStrategy: json['resolution_strategy']?.toString(),
      autoResolvedCount: json['auto_resolved_count'] is int
          ? json['auto_resolved_count'] as int
          : 0,
    );
  }

  final String errorKind;
  int count;
  String lastSeen;
  String? resolutionStrategy;
  int autoResolvedCount;

  Map<String, Object?> toJson() => {
    'error_kind': errorKind,
    'count': count,
    'last_seen': lastSeen,
    'resolution_strategy': resolutionStrategy,
    'auto_resolved_count': autoResolvedCount,
  };
}

/// Persistent registry of error patterns observed during autopilot execution.
///
/// Stores patterns in `.genaisys/audit/error_patterns.json` and supports
/// merging new observations, recording resolution strategies, and identifying
/// patterns that need optimization tasks.
class ErrorPatternRegistryService {
  /// Threshold: patterns seen this many times without a resolution strategy
  /// are flagged for optimization task creation.
  static const int unresolvableThreshold = 5;

  /// Loads the current registry from disk.
  List<ErrorPatternEntry> load(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.errorPatternRegistryPath);
    if (!file.existsSync()) {
      return [];
    }
    try {
      final content = file.readAsStringSync().trim();
      if (content.isEmpty) {
        return [];
      }
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ErrorPatternEntry.fromJson)
          .where((e) => e.errorKind.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Maximum number of entries retained in the registry.
  static const int maxEntries = 50;

  /// Entries older than this duration are pruned unless they have a resolution
  /// strategy or a high observation count.
  static const Duration entryTtl = Duration(days: 7);

  /// Persists the registry to disk using atomic write.
  ///
  /// Automatically prunes stale entries and enforces [maxEntries].
  void save(String projectRoot, List<ErrorPatternEntry> entries) {
    final layout = ProjectLayout(projectRoot);
    final parent = File(layout.errorPatternRegistryPath).parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final pruned = _prune(entries);
    final json = jsonEncode(pruned.map((e) => e.toJson()).toList());
    AtomicFileWrite.writeStringSync(layout.errorPatternRegistryPath, json);
  }

  List<ErrorPatternEntry> _prune(List<ErrorPatternEntry> entries) {
    final now = DateTime.now().toUtc();
    // Remove stale entries that are low-value.
    final fresh = entries.where((e) {
      final lastSeen = DateTime.tryParse(e.lastSeen)?.toUtc();
      if (lastSeen == null) return false;
      if (now.difference(lastSeen) <= entryTtl) return true;
      // Keep high-count or resolved entries even if old.
      if (e.count >= unresolvableThreshold) return true;
      if (e.resolutionStrategy != null &&
          e.resolutionStrategy!.trim().isNotEmpty) {
        return true;
      }
      return false;
    }).toList();
    // Enforce max size: keep highest-count entries.
    if (fresh.length > maxEntries) {
      fresh.sort((a, b) => b.count.compareTo(a.count));
      return fresh.sublist(0, maxEntries);
    }
    return fresh;
  }

  /// Merges observed error kind counts into the persistent registry.
  ///
  /// [errorKindCounts] maps `error_kind` strings to their occurrence counts
  /// from the current analysis window.
  void mergeObservations(
    String projectRoot, {
    required Map<String, int> errorKindCounts,
  }) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.pipelineErrorPatternLearningEnabled) return;

    final entries = load(projectRoot);
    final now = DateTime.now().toUtc().toIso8601String();
    final byKind = <String, ErrorPatternEntry>{};
    for (final entry in entries) {
      byKind[entry.errorKind] = entry;
    }

    for (final entry in errorKindCounts.entries) {
      final kind = entry.key;
      final count = entry.value;
      if (kind.isEmpty || count <= 0) continue;

      final existing = byKind[kind];
      if (existing != null) {
        existing.count += count;
        existing.lastSeen = now;
      } else {
        byKind[kind] = ErrorPatternEntry(
          errorKind: kind,
          count: count,
          lastSeen: now,
        );
      }
    }

    save(projectRoot, byKind.values.toList());
  }

  /// Records that an error kind was automatically resolved (e.g., self-heal).
  void recordAutoResolution(String projectRoot, String errorKind) {
    final entries = load(projectRoot);
    for (final entry in entries) {
      if (entry.errorKind == errorKind) {
        entry.autoResolvedCount += 1;
        save(projectRoot, entries);
        return;
      }
    }
  }

  /// Records a resolution strategy for a given error kind.
  void recordResolutionStrategy(
    String projectRoot,
    String errorKind,
    String strategy,
  ) {
    final entries = load(projectRoot);
    for (final entry in entries) {
      if (entry.errorKind == errorKind) {
        entry.resolutionStrategy = strategy;
        save(projectRoot, entries);
        return;
      }
    }
  }

  /// Returns error patterns that have been seen >= [unresolvableThreshold]
  /// times without a resolution strategy.
  List<ErrorPatternEntry> unresolvablePatterns(String projectRoot) {
    return load(projectRoot).where((entry) {
      return entry.count >= unresolvableThreshold &&
          (entry.resolutionStrategy == null ||
              entry.resolutionStrategy!.trim().isEmpty);
    }).toList();
  }

  /// Formats the top error patterns as a markdown section for injection into
  /// coding agent prompts.
  ///
  /// Returns an empty string if no patterns exist. The result is trimmed to
  /// [maxChars] and limited to [maxEntries] patterns, sorted by occurrence
  /// count (highest first).
  String formatForPrompt(
    String projectRoot, {
    int maxEntries = 5,
    int maxChars = 1000,
  }) {
    final entries = load(projectRoot);
    if (entries.isEmpty) return '';

    entries.sort((a, b) => b.count.compareTo(a.count));
    final top = entries.take(maxEntries).toList();

    final buffer = StringBuffer();
    for (final entry in top) {
      final resolution =
          entry.resolutionStrategy != null &&
              entry.resolutionStrategy!.trim().isNotEmpty
          ? 'Resolution: "${entry.resolutionStrategy!.trim()}"'
          : 'No known resolution — avoid this pattern.';
      buffer.writeln(
        '- `${entry.errorKind}`: ${entry.count} occurrences. $resolution',
      );
      if (buffer.length >= maxChars) break;
    }

    final result = buffer.toString().trim();
    if (result.length <= maxChars) return result;
    return result.substring(0, maxChars).trim();
  }

  /// Records a resolution strategy for an error kind ONLY if no strategy
  /// exists yet. This prevents overwriting a previously learned strategy
  /// with a potentially less specific one.
  ///
  /// Returns `true` if a new strategy was stored, `false` if one already
  /// existed or the inputs were invalid.
  bool recordResolutionIfNew(
    String projectRoot,
    String errorKind,
    String strategy,
  ) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.pipelineErrorPatternLearningEnabled) return false;

    final kind = errorKind.trim();
    final strat = strategy.trim();
    if (kind.isEmpty || strat.isEmpty) return false;

    final entries = load(projectRoot);
    for (final entry in entries) {
      if (entry.errorKind == kind) {
        if (entry.resolutionStrategy != null &&
            entry.resolutionStrategy!.trim().isNotEmpty) {
          return false; // Strategy already exists.
        }
        entry.resolutionStrategy = strat;
        save(projectRoot, entries);
        return true;
      }
    }
    // Error kind not yet in registry — nothing to attach a strategy to.
    return false;
  }

  /// Returns known resolution strategies for the given error kind, if any.
  String? knownResolutionFor(String projectRoot, String errorKind) {
    final entries = load(projectRoot);
    for (final entry in entries) {
      if (entry.errorKind == errorKind &&
          entry.resolutionStrategy != null &&
          entry.resolutionStrategy!.trim().isNotEmpty) {
        return entry.resolutionStrategy;
      }
    }
    return null;
  }
}
