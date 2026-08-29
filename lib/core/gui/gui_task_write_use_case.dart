// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/action_dto.dart';
import '../app/dto/task_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// GUI wrapper for task write actions (create/update/move).
class GuiTaskWriteUseCase {
  GuiTaskWriteUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskCreateDto>> create(
    String projectRoot, {
    required String title,
    required AppTaskPriority priority,
    required AppTaskCategory category,
    String? section,
  }) {
    return _api.createTask(
      projectRoot,
      title: title,
      priority: priority,
      category: category,
      section: section,
    );
  }

  Future<AppResult<TaskPriorityUpdateDto>> updatePriority(
    String projectRoot, {
    String? id,
    String? title,
    required AppTaskPriority priority,
  }) {
    return _api.updateTaskPriority(
      projectRoot,
      id: id,
      title: title,
      priority: priority,
    );
  }

  Future<AppResult<TaskMoveSectionDto>> moveSection(
    String projectRoot, {
    String? id,
    String? title,
    required String section,
  }) {
    return _api.moveTaskSection(
      projectRoot,
      id: id,
      title: title,
      section: section,
    );
  }
}
