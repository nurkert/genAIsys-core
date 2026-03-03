// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/policy_simulation_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotSimulationUseCase {
  AutopilotSimulationUseCase({PolicySimulationService? service})
    : _service = service ?? PolicySimulationService();

  final PolicySimulationService _service;

  Future<AppResult<AutopilotSimulationDto>> run(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
    int? minOpen,
    int? maxPlanAdd,
    bool keepWorkspace = false,
  }) async {
    try {
      final result = await _service.run(
        projectRoot,
        codingPrompt: prompt,
        testSummary: testSummary,
        overwriteArtifacts: overwrite,
        minOpenTasks: minOpen,
        maxPlanAdd: maxPlanAdd,
        keepWorkspace: keepWorkspace,
      );
      final stats = result.diffStats;
      return AppResult.success(
        AutopilotSimulationDto(
          projectRoot: result.projectRoot,
          workspaceRoot: result.workspaceRoot,
          hasTask: result.hasTask,
          activatedTask: result.activatedTask,
          plannedTasksAdded: result.plannedTasksAdded,
          taskTitle: result.taskTitle,
          taskId: result.taskId,
          subtask: result.subtask,
          reviewDecision: result.reviewDecision,
          diffSummary: result.diffSummary,
          diffPatch: result.diffPatch,
          filesChanged: stats?.filesChanged ?? 0,
          additions: stats?.additions ?? 0,
          deletions: stats?.deletions ?? 0,
          policyViolation: result.policyViolation,
          policyMessage: result.policyMessage,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
