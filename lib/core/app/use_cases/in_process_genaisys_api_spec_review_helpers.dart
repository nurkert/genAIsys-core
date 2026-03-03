// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'in_process_genaisys_api.dart';

extension _InProcessGenaisysApiSpecReviewHelpers on InProcessGenaisysApi {
  Future<AppResult<SpecInitializationDto>> _initializeSpec(
    String projectRoot, {
    required SpecKind kind,
    required bool overwrite,
  }) async {
    try {
      final result = _specService.initSpec(
        projectRoot,
        kind: kind,
        overwrite: overwrite,
      );
      return AppResult.success(
        SpecInitializationDto(created: result.created, path: result.path),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  Future<AppResult<ReviewDecisionDto>> _recordReviewDecision(
    String projectRoot, {
    required String decision,
    required String label,
    String? note,
  }) async {
    try {
      final taskTitle = _reviewService.recordDecision(
        projectRoot,
        decision: decision,
        note: note,
      );
      return AppResult.success(
        ReviewDecisionDto(
          reviewRecorded: true,
          decision: label,
          taskTitle: taskTitle,
          note: _normalizeNullable(note),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }
}
