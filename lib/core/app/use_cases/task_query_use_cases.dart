// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/task_dto.dart';
import 'in_process_genaisys_api.dart';

class ListTasksUseCase {
  ListTasksUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppTaskListDto>> run(
    String projectRoot, {
    TaskListQuery query = const TaskListQuery(),
  }) {
    return _api.listTasks(projectRoot, query: query);
  }
}

class GetNextTaskUseCase {
  GetNextTaskUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppTaskDto?>> run(
    String projectRoot, {
    String? sectionFilter,
  }) {
    return _api.getNextTask(projectRoot, sectionFilter: sectionFilter);
  }
}
