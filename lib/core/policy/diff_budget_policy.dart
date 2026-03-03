// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class DiffBudget {
  const DiffBudget({
    required this.maxFiles,
    required this.maxAdditions,
    required this.maxDeletions,
  });

  final int maxFiles;
  final int maxAdditions;
  final int maxDeletions;
}

class DiffStats {
  const DiffStats({
    required this.filesChanged,
    required this.additions,
    required this.deletions,
    this.changedFiles = const [],
  });

  final int filesChanged;
  final int additions;
  final int deletions;

  /// List of changed file paths (relative to project root).
  ///
  /// Populated when available from numstat output. May be empty for
  /// backward-compatible callers that only supply counts.
  final List<String> changedFiles;
}

class DiffBudgetPolicy {
  DiffBudgetPolicy({required this.budget});

  final DiffBudget budget;

  bool allows(DiffStats stats) {
    if (stats.filesChanged > budget.maxFiles) {
      return false;
    }
    if (stats.additions > budget.maxAdditions) {
      return false;
    }
    if (stats.deletions > budget.maxDeletions) {
      return false;
    }
    return true;
  }
}
