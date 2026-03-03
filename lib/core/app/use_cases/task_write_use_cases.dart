// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/action_dto.dart';
import '../dto/task_dto.dart';
import 'in_process_genaisys_api.dart';

class CreateTaskUseCase {
  CreateTaskUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskCreateDto>> run(
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
}

class UpdateTaskPriorityUseCase {
  UpdateTaskPriorityUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskPriorityUpdateDto>> run(
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
}

class MoveTaskSectionUseCase {
  MoveTaskSectionUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskMoveSectionDto>> run(
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

class TaskRefinementUseCase {
  TaskRefinementUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskRefinementDto>> run(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  }) {
    return _api.refineTask(projectRoot, title: title, overwrite: overwrite);
  }
}
