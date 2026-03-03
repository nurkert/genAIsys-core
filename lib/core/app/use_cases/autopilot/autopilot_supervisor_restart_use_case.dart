// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_supervisor_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotSupervisorRestartUseCase {
  AutopilotSupervisorRestartUseCase({AutopilotSupervisorService? service})
    : _service = service ?? AutopilotSupervisorService();

  final AutopilotSupervisorService _service;

  Future<AppResult<AutopilotSupervisorStartDto>> run(
    String projectRoot, {
    String profile = 'overnight',
    String? prompt,
    String startReason = 'manual_restart',
    int maxRestarts = AutopilotSupervisorService.defaultMaxRestarts,
    int restartBackoffBaseSeconds =
        AutopilotSupervisorService.defaultRestartBackoffBaseSeconds,
    int restartBackoffMaxSeconds =
        AutopilotSupervisorService.defaultRestartBackoffMaxSeconds,
    int lowSignalLimit = AutopilotSupervisorService.defaultLowSignalLimit,
    int throughputWindowMinutes =
        AutopilotSupervisorService.defaultThroughputWindowMinutes,
    int throughputMaxSteps =
        AutopilotSupervisorService.defaultThroughputMaxSteps,
    int throughputMaxRejects =
        AutopilotSupervisorService.defaultThroughputMaxRejects,
    int throughputMaxHighRetries =
        AutopilotSupervisorService.defaultThroughputMaxHighRetries,
  }) async {
    try {
      final result = await _service.restart(
        projectRoot,
        profile: profile,
        prompt: prompt,
        startReason: startReason,
        maxRestarts: maxRestarts,
        restartBackoffBaseSeconds: restartBackoffBaseSeconds,
        restartBackoffMaxSeconds: restartBackoffMaxSeconds,
        lowSignalLimit: lowSignalLimit,
        throughputWindowMinutes: throughputWindowMinutes,
        throughputMaxSteps: throughputMaxSteps,
        throughputMaxRejects: throughputMaxRejects,
        throughputMaxHighRetries: throughputMaxHighRetries,
      );
      return AppResult.success(
        AutopilotSupervisorStartDto(
          started: result.started,
          sessionId: result.sessionId,
          profile: result.profile,
          pid: result.pid,
          resumeAction: result.resumeAction,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
