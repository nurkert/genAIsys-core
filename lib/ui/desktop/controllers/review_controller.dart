// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../../core/app/app.dart';

/// Manages review status and approve/reject/clear operations.
///
/// Extracted from [ProjectWorkspaceController] to isolate review
/// state changes so they don't trigger rebuilds in unrelated views.
class ReviewController {
  ReviewController({
    required String projectRootPath,
    required GenaisysApi api,
  }) : _projectRootPath = projectRootPath,
       _api = api;

  final String _projectRootPath;
  final GenaisysApi _api;

  AppReviewStatusDto? _reviewStatus;

  AppReviewStatusDto? get reviewStatus => _reviewStatus;

  /// Fetches review status. Returns error message or null.
  Future<String?> refresh() async {
    final AppResult<AppReviewStatusDto> result = await _api.getReviewStatus(
      _projectRootPath,
    );
    if (result.ok && result.data != null) {
      _reviewStatus = result.data;
      return null;
    }
    return result.error?.message ?? 'Failed to load review status.';
  }

  /// Sets the review status from an external source (e.g. dashboard).
  void updateFromDashboard(AppReviewStatusDto? status) {
    _reviewStatus = status;
  }

  Future<AppResult<ReviewDecisionDto>> approve({String? note}) {
    return _api.approveReview(_projectRootPath, note: note);
  }

  Future<AppResult<ReviewDecisionDto>> reject({String? note}) {
    return _api.rejectReview(_projectRootPath, note: note);
  }

  Future<AppResult<ReviewClearDto>> clear({String? note}) {
    return _api.clearReview(_projectRootPath, note: note);
  }

  void dispose() {
    // No notifiers to dispose; review is read through the coordinator.
  }
}
