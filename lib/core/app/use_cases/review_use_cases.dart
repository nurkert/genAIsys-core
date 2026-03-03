// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/action_dto.dart';
import '../dto/review_status_dto.dart';
import 'in_process_genaisys_api.dart';

class ManageReviewUseCase {
  ManageReviewUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppReviewStatusDto>> status(String projectRoot) {
    return _api.getReviewStatus(projectRoot);
  }

  Future<AppResult<ReviewDecisionDto>> approve(
    String projectRoot, {
    String? note,
  }) {
    return _api.approveReview(projectRoot, note: note);
  }

  Future<AppResult<ReviewDecisionDto>> reject(
    String projectRoot, {
    String? note,
  }) {
    return _api.rejectReview(projectRoot, note: note);
  }

  Future<AppResult<ReviewClearDto>> clear(String projectRoot, {String? note}) {
    return _api.clearReview(projectRoot, note: note);
  }
}
