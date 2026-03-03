// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all review-related fields from [ProjectConfig].
class ReviewConfig {
  const ReviewConfig({
    required this.requireReview,
    required this.freshContext,
    required this.strictness,
    required this.maxRounds,
    required this.requireEvidence,
    required this.evidenceMinLength,
  });

  factory ReviewConfig.fromProjectConfig(ProjectConfig c) => ReviewConfig(
    requireReview: c.workflowRequireReview,
    freshContext: c.reviewFreshContext,
    strictness: c.reviewStrictness,
    maxRounds: c.reviewMaxRounds,
    requireEvidence: c.reviewRequireEvidence,
    evidenceMinLength: c.reviewEvidenceMinLength,
  );

  final bool requireReview;
  final bool freshContext;
  final String strictness;
  final int maxRounds;
  final bool requireEvidence;
  final int evidenceMinLength;
}
