// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/orchestrator_run_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotStopUseCase {
  AutopilotStopUseCase({OrchestratorRunService? service})
    : _service = service ?? OrchestratorRunService();

  final OrchestratorRunService _service;

  Future<AppResult<AutopilotStopDto>> run(String projectRoot) async {
    try {
      await _service.stop(projectRoot);
      return AppResult.success(const AutopilotStopDto(autopilotStopped: true));
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
