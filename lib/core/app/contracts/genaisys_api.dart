// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../dto/action_dto.dart';
import '../dto/config_dto.dart';
import '../dto/dashboard_dto.dart';
import '../dto/hitl_gate_dto.dart';
import '../dto/review_status_dto.dart';
import '../dto/status_snapshot_dto.dart';
import '../dto/task_dto.dart';
import 'app_result.dart';

abstract class GenaisysApi {
  Future<AppResult<ProjectInitializationDto>> initializeProject(
    String projectRoot, {
    bool overwrite = false,
    String? fromSource,
    bool staticMode = false,
    int? sprintSize,
  });

  Future<AppResult<AppStatusSnapshotDto>> getStatus(String projectRoot);

  Future<AppResult<AppTaskListDto>> listTasks(
    String projectRoot, {
    TaskListQuery query = const TaskListQuery(),
  });

  Future<AppResult<AppTaskDto?>> getNextTask(
    String projectRoot, {
    String? sectionFilter,
  });

  Future<AppResult<AppReviewStatusDto>> getReviewStatus(String projectRoot);

  Future<AppResult<AppDashboardDto>> getDashboard(String projectRoot);

  Future<AppResult<AppConfigDto>> getConfig(String projectRoot);

  Future<AppResult<ConfigUpdateDto>> updateConfig(
    String projectRoot, {
    required AppConfigDto config,
  });

  Future<AppResult<TaskActivationDto>> activateTask(
    String projectRoot, {
    String? id,
    String? title,
  });

  Future<AppResult<TaskDeactivationDto>> deactivateTask(
    String projectRoot, {
    bool keepReview = false,
  });

  Future<AppResult<ReviewDecisionDto>> approveReview(
    String projectRoot, {
    String? note,
  });

  Future<AppResult<ReviewDecisionDto>> rejectReview(
    String projectRoot, {
    String? note,
  });

  Future<AppResult<ReviewClearDto>> clearReview(
    String projectRoot, {
    String? note,
  });

  Future<AppResult<TaskDoneDto>> markTaskDone(
    String projectRoot, {
    bool force = false,
  });

  Future<AppResult<TaskBlockedDto>> blockTask(
    String projectRoot, {
    String? reason,
  });

  Future<AppResult<TaskCreateDto>> createTask(
    String projectRoot, {
    required String title,
    required AppTaskPriority priority,
    required AppTaskCategory category,
    String? section,
  });

  Future<AppResult<TaskPriorityUpdateDto>> updateTaskPriority(
    String projectRoot, {
    String? id,
    String? title,
    required AppTaskPriority priority,
  });

  Future<AppResult<TaskMoveSectionDto>> moveTaskSection(
    String projectRoot, {
    String? id,
    String? title,
    required String section,
  });

  Future<AppResult<TaskDeleteDto>> deleteTask(
    String projectRoot, {
    String? id,
    String? title,
  });

  Future<AppResult<TaskRefinementDto>> refineTask(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  });

  Future<AppResult<CycleTickDto>> cycle(String projectRoot);

  Future<AppResult<TaskCycleExecutionDto>> runTaskCycle(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  });

  Future<AppResult<SpecInitializationDto>> initializePlan(
    String projectRoot, {
    bool overwrite = false,
  });

  Future<AppResult<SpecInitializationDto>> initializeSpec(
    String projectRoot, {
    bool overwrite = false,
  });

  Future<AppResult<SpecInitializationDto>> initializeSubtasks(
    String projectRoot, {
    bool overwrite = false,
  });

  /// Returns the currently pending HITL gate, or a [HitlGateDto] with
  /// `pending: false` when no gate is active.
  Future<AppResult<HitlGateDto>> getHitlGate(String projectRoot);

  /// Writes a decision file to resolve the pending HITL gate.
  ///
  /// [decision] must be `'approve'` or `'reject'`.
  Future<AppResult<void>> submitHitlDecision(
    String projectRoot, {
    required String decision,
    String? note,
  });
}
