// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/action_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// GUI wrapper for review write actions.
class GuiReviewActionsUseCase {
  GuiReviewActionsUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

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
