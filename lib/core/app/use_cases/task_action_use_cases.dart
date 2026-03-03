// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/action_dto.dart';
import 'in_process_genaisys_api.dart';

class ManageTaskUseCase {
  ManageTaskUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskActivationDto>> activate(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    return _api.activateTask(projectRoot, id: id, title: title);
  }

  Future<AppResult<TaskDeactivationDto>> deactivate(
    String projectRoot, {
    bool keepReview = false,
  }) {
    return _api.deactivateTask(projectRoot, keepReview: keepReview);
  }

  Future<AppResult<TaskDoneDto>> markDone(
    String projectRoot, {
    bool force = false,
  }) {
    return _api.markTaskDone(projectRoot, force: force);
  }

  Future<AppResult<TaskBlockedDto>> block(
    String projectRoot, {
    String? reason,
  }) {
    return _api.blockTask(projectRoot, reason: reason);
  }

  Future<AppResult<CycleTickDto>> cycle(String projectRoot) {
    return _api.cycle(projectRoot);
  }

  Future<AppResult<TaskCycleExecutionDto>> runCycle(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    return _api.runTaskCycle(
      projectRoot,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
    );
  }
}
