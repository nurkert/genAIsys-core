// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/task_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// Thin use-case wrapper for next-task selection in GUI flows.
class GuiNextTaskUseCase {
  GuiNextTaskUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppTaskDto?>> load(
    String projectRoot, {
    String? sectionFilter,
  }) {
    return _api.getNextTask(projectRoot, sectionFilter: sectionFilter);
  }
}
