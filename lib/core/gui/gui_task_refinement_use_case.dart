// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/action_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// GUI wrapper for task refinement (plan/spec/subtasks draft generation).
class GuiTaskRefinementUseCase {
  GuiTaskRefinementUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskRefinementDto>> refine(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  }) {
    return _api.refineTask(projectRoot, title: title, overwrite: overwrite);
  }
}
