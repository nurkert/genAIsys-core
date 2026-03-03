// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Whether the review should be a full (fresh) review or a verification
/// review that only checks whether previous rejection items were addressed.
enum ReviewMode {
  /// Normal full review — all quality gates apply, reviewer has full discretion.
  fullReview,

  /// Verification review — scope locked to the previous rejection notes
  /// (the "contract"). New non-critical observations are captured as advisory
  /// notes that do not block approval.
  verificationReview,
}

/// Decision output from [ReviewEscalationService.computeReviewMode].
class ReviewEscalationDecision {
  const ReviewEscalationDecision({
    required this.mode,
    required this.contractNotes,
  });

  /// The review mode to use for this round.
  final ReviewMode mode;

  /// Previous rejection notes that form the review contract.
  /// Empty for [ReviewMode.fullReview].
  final List<String> contractNotes;
}

/// Pure-logic service that decides whether a review round should be a full
/// review or a contract-locked verification review.
///
/// The "Review Contract Lock" prevents moving goalposts across review rounds:
/// - Round 0: full review with all quality gates.
/// - Round 1+: verification review — the reviewer only checks whether the
///   previous rejection items were resolved. New non-critical findings are
///   captured as ADVISORY notes and tracked as follow-up QA tasks.
class ReviewEscalationService {
  /// Computes the review mode for the current retry round.
  ///
  /// Returns [ReviewMode.verificationReview] when all conditions are met:
  /// - [contractLockEnabled] is `true`
  /// - [retryCount] >= 1
  /// - [previousRejectNotes] is non-empty
  ///
  /// Otherwise returns [ReviewMode.fullReview].
  ReviewEscalationDecision computeReviewMode({
    required int retryCount,
    required bool contractLockEnabled,
    required List<String> previousRejectNotes,
  }) {
    if (!contractLockEnabled ||
        retryCount < 1 ||
        previousRejectNotes.isEmpty) {
      return const ReviewEscalationDecision(
        mode: ReviewMode.fullReview,
        contractNotes: [],
      );
    }
    return ReviewEscalationDecision(
      mode: ReviewMode.verificationReview,
      contractNotes: List.unmodifiable(previousRejectNotes),
    );
  }

  /// Builds a `[P3] [QA]` follow-up task line for advisory notes discovered
  /// during verification reviews.
  ///
  /// Returns `null` if [advisoryNotes] is empty.
  String? buildFollowUpTaskLine(
    String originalTaskTitle,
    List<String> advisoryNotes,
  ) {
    if (advisoryNotes.isEmpty) return null;
    final summary = advisoryNotes.length == 1
        ? advisoryNotes.first
        : '${advisoryNotes.length} advisory findings';
    return '- [ ] [P3] [QA] Address review findings from: '
        '$originalTaskTitle | AC: $summary';
  }
}
