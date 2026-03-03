// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../git/git_service.dart';
import 'agents/review_agent_service.dart';
import '../services/review_bundle_service.dart';
import '../services/review_service.dart';

class ReviewCycleResult {
  ReviewCycleResult({
    required this.hasChanges,
    required this.reviewed,
    required this.decision,
  });

  final bool hasChanges;
  final bool reviewed;
  final ReviewDecision? decision;
}

class ReviewCycleService {
  ReviewCycleService({
    GitService? gitService,
    ReviewBundleService? reviewBundleService,
    ReviewAgentService? reviewAgentService,
    ReviewService? reviewService,
  }) : _gitService = gitService ?? GitService(),
       _reviewBundleService = reviewBundleService ?? ReviewBundleService(),
       _reviewAgentService = reviewAgentService ?? ReviewAgentService(),
       _reviewService = reviewService ?? ReviewService();

  final GitService _gitService;
  final ReviewBundleService _reviewBundleService;
  final ReviewAgentService _reviewAgentService;
  final ReviewService _reviewService;

  Future<ReviewCycleResult> run(
    String projectRoot, {
    String? testSummary,
  }) async {
    final hasChanges = _gitService.hasChanges(projectRoot);
    if (!hasChanges) {
      return ReviewCycleResult(
        hasChanges: false,
        reviewed: false,
        decision: null,
      );
    }

    final bundle = _reviewBundleService.build(
      projectRoot,
      testSummary: testSummary,
    );
    final result = await _reviewAgentService.reviewBundle(
      projectRoot,
      bundle: bundle,
    );

    _reviewService.recordDecision(
      projectRoot,
      decision: result.decision == ReviewDecision.approve
          ? 'approve'
          : 'reject',
      note: _extractNote(result.response.stdout),
      testSummary: testSummary,
    );

    return ReviewCycleResult(
      hasChanges: true,
      reviewed: true,
      decision: result.decision,
    );
  }

  String? _extractNote(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lines = trimmed.split('\n');
    if (lines.length == 1) {
      return lines.first.trim();
    }
    final remainder = lines.skip(1).join('\n').trim();
    return remainder.isEmpty ? null : remainder;
  }
}
