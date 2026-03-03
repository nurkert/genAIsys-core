// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_smoke_check_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotSmokeUseCase {
  AutopilotSmokeUseCase({AutopilotSmokeCheckService? service})
    : _service = service ?? AutopilotSmokeCheckService();

  final AutopilotSmokeCheckService _service;

  Future<AppResult<AutopilotSmokeDto>> run({bool keepProject = true}) async {
    try {
      final result = await _service.run(keepProject: keepProject);
      return AppResult.success(
        AutopilotSmokeDto(
          ok: result.ok,
          projectRoot: result.projectRoot,
          taskTitle: result.taskTitle,
          reviewDecision: result.reviewDecision,
          taskDone: result.taskDone,
          commitCount: result.commitCount,
          failures: result.failures,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
