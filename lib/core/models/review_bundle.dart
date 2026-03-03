// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class ReviewBundle {
  const ReviewBundle({
    required this.diffSummary,
    required this.diffPatch,
    required this.testSummary,
    required this.taskTitle,
    required this.spec,
    this.subtaskDescription,
  });

  final String diffSummary;
  final String diffPatch;
  final String? testSummary;
  final String? taskTitle;
  final String? spec;

  /// When non-null, the review is for a subtask delivery (not the full task).
  /// The review agent should evaluate only this subtask's scope, not the
  /// full task acceptance criteria.
  final String? subtaskDescription;
}
