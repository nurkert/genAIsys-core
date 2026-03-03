// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_supervisor_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotSupervisorStopUseCase {
  AutopilotSupervisorStopUseCase({AutopilotSupervisorService? service})
    : _service = service ?? AutopilotSupervisorService();

  final AutopilotSupervisorService _service;

  Future<AppResult<AutopilotSupervisorStopDto>> run(
    String projectRoot, {
    String reason = 'manual_stop',
  }) async {
    try {
      final result = await _service.stop(projectRoot, reason: reason);
      return AppResult.success(
        AutopilotSupervisorStopDto(
          stopped: result.stopped,
          wasRunning: result.wasRunning,
          reason: result.reason,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
