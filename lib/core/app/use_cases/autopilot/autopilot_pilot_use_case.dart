// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_release_candidate_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotPilotUseCase {
  AutopilotPilotUseCase({AutopilotReleaseCandidateService? service})
    : _service = service ?? AutopilotReleaseCandidateService();

  final AutopilotReleaseCandidateService _service;

  Future<AppResult<AutopilotPilotDto>> run(
    String projectRoot, {
    required Duration duration,
    required int maxCycles,
    String? branch,
    String? prompt,
    bool skipCandidate = false,
    bool autoFixFormatDrift = false,
  }) async {
    try {
      final result = await _service.runPilot(
        projectRoot,
        duration: duration,
        maxCycles: maxCycles,
        branch: branch,
        prompt: prompt,
        skipCandidate: skipCandidate,
        autoFixFormatDrift: autoFixFormatDrift,
      );
      return AppResult.success(
        AutopilotPilotDto(
          passed: result.passed,
          timedOut: result.timedOut,
          commandExitCode: result.commandExitCode,
          branch: result.branch,
          durationSeconds: result.durationSeconds,
          maxCycles: result.maxCycles,
          reportPath: result.reportPath,
          totalSteps: result.totalSteps,
          successfulSteps: result.successfulSteps,
          idleSteps: result.idleSteps,
          failedSteps: result.failedSteps,
          stoppedByMaxSteps: result.stoppedByMaxSteps,
          stoppedWhenIdle: result.stoppedWhenIdle,
          stoppedBySafetyHalt: result.stoppedBySafetyHalt,
          error: result.error,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
