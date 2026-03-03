// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/orchestrator_step_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotStepUseCase {
  AutopilotStepUseCase({OrchestratorStepService? service})
    : _service = service ?? OrchestratorStepService();

  final OrchestratorStepService _service;

  Future<AppResult<AutopilotStepDto>> run(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
    int? minOpen,
    int? maxPlanAdd,
  }) async {
    try {
      final result = await _service.run(
        projectRoot,
        codingPrompt: prompt,
        testSummary: testSummary,
        overwriteArtifacts: overwrite,
        minOpenTasks: minOpen,
        maxPlanAdd: maxPlanAdd,
      );
      return AppResult.success(
        AutopilotStepDto(
          executedCycle: result.executedCycle,
          activatedTask: result.activatedTask,
          activeTaskTitle: result.activeTaskTitle,
          plannedTasksAdded: result.plannedTasksAdded,
          reviewDecision: result.reviewDecision,
          retryCount: result.retryCount,
          taskBlocked: result.blockedTask,
          deactivatedTask: result.deactivatedTask,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
