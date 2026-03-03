// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/orchestrator_run_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotRunUseCase {
  AutopilotRunUseCase({OrchestratorRunService? service})
    : _service = service ?? OrchestratorRunService();

  final OrchestratorRunService _service;

  Future<AppResult<AutopilotRunDto>> run(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
    int? minOpen,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle = false,
    int? maxFailures,
    int? maxTaskRetries,
    bool overrideSafety = false,
  }) async {
    try {
      final result = await _service.run(
        projectRoot,
        codingPrompt: prompt,
        testSummary: testSummary,
        overwriteArtifacts: overwrite,
        minOpenTasks: minOpen,
        maxPlanAdd: maxPlanAdd,
        stepSleep: stepSleep,
        idleSleep: idleSleep,
        maxSteps: maxSteps,
        stopWhenIdle: stopWhenIdle,
        maxConsecutiveFailures: maxFailures,
        maxTaskRetries: maxTaskRetries,
        overrideSafety: overrideSafety,
      );
      return AppResult.success(
        AutopilotRunDto(
          totalSteps: result.totalSteps,
          successfulSteps: result.successfulSteps,
          idleSteps: result.idleSteps,
          failedSteps: result.failedSteps,
          stoppedByMaxSteps: result.stoppedByMaxSteps,
          stoppedWhenIdle: result.stoppedWhenIdle,
          stoppedBySafetyHalt: result.stoppedBySafetyHalt,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
