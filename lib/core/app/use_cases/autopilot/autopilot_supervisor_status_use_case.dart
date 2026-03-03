// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_supervisor_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotSupervisorStatusUseCase {
  AutopilotSupervisorStatusUseCase({AutopilotSupervisorService? service})
    : _service = service ?? AutopilotSupervisorService();

  final AutopilotSupervisorService _service;

  Future<AppResult<AutopilotSupervisorStatusDto>> load(
    String projectRoot,
  ) async {
    try {
      final status = _service.getStatus(projectRoot);
      return AppResult.success(
        AutopilotSupervisorStatusDto(
          running: status.running,
          workerPid: status.workerPid,
          sessionId: status.sessionId,
          profile: status.profile,
          startReason: status.startReason,
          restartCount: status.restartCount,
          cooldownUntil: status.cooldownUntil,
          lastHaltReason: status.lastHaltReason,
          lastResumeAction: status.lastResumeAction,
          lastExitCode: status.lastExitCode,
          lowSignalStreak: status.lowSignalStreak,
          throughputWindowStartedAt: status.throughputWindowStartedAt,
          throughputSteps: status.throughputSteps,
          throughputRejects: status.throughputRejects,
          throughputHighRetries: status.throughputHighRetries,
          startedAt: status.startedAt,
          autopilotRunning: status.autopilotRunning,
          autopilotPid: status.autopilotPid,
          autopilotLastLoopAt: status.autopilotLastLoopAt,
          autopilotConsecutiveFailures: status.autopilotConsecutiveFailures,
          autopilotLastError: status.autopilotLastError,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
