// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/observability/health_check_service.dart';
import '../../../services/orchestrator_run_service.dart';
import '../../../services/observability/run_telemetry_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotStatusUseCase {
  AutopilotStatusUseCase({
    OrchestratorRunService? service,
    HealthCheckService? healthService,
    RunTelemetryService? telemetryService,
  }) : _service = service ?? OrchestratorRunService(),
       _healthService = healthService ?? HealthCheckService(),
       _telemetryService = telemetryService ?? RunTelemetryService();

  final OrchestratorRunService _service;
  final HealthCheckService _healthService;
  final RunTelemetryService _telemetryService;

  Future<AppResult<AutopilotStatusDto>> load(String projectRoot) async {
    try {
      final status = _service.getStatus(projectRoot);
      final health = _healthService.check(projectRoot);
      final telemetry = _telemetryService.load(projectRoot, recentLimit: 24);
      final stall = deriveStallInfo(status, health, telemetry);
      return AppResult.success(
        AutopilotStatusDto(
          autopilotRunning: status.isRunning,
          pid: status.pid,
          startedAt: status.startedAt,
          lastLoopAt: status.lastLoopAt,
          consecutiveFailures: status.consecutiveFailures,
          lastError: status.lastError,
          lastErrorClass: status.lastErrorClass,
          lastErrorKind: status.lastErrorKind,
          subtaskQueue: status.subtaskQueue,
          currentSubtask: status.currentSubtask,
          lastStepSummary: status.lastStepSummary == null
              ? null
              : AutopilotStepSummaryDto(
                  stepId: status.lastStepSummary!.stepId,
                  taskId: status.lastStepSummary!.taskId,
                  subtaskId: status.lastStepSummary!.subtaskId,
                  decision: status.lastStepSummary!.decision,
                  event: status.lastStepSummary!.event,
                  timestamp: status.lastStepSummary!.timestamp,
                ),
          health: toHealthDto(health),
          telemetry: toTelemetryDto(telemetry),
          healthSummary: toHealthSummaryDto(telemetry.healthSummary),
          stallReason: stall.reason,
          stallDetail: stall.detail,
          hitlGatePending: status.hitlGatePending,
          hitlGateEvent: status.hitlGateEvent,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
