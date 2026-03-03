// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../models/health_snapshot.dart';
import '../../models/run_log_event.dart';
import '../../models/task.dart';
import '../../project_layout.dart';
import '../../config/project_config.dart';
import '../../services/task_management/activate_service.dart';
import '../../services/cycle_service.dart';
import '../../services/config_service.dart';
import '../../services/task_management/done_service.dart';
import '../../services/init_service.dart';
import '../../services/review_service.dart';
import '../../services/spec_service.dart';
import '../../services/observability/status_service.dart';
import '../../services/observability/run_telemetry_service.dart';
import '../../services/task_cycle_service.dart';
import '../../services/task_management/task_refinement_service.dart';
import '../../services/task_management/task_service.dart';
import '../../services/task_management/task_write_service.dart';
import '../../storage/state_store.dart';
import '../../storage/run_log_store.dart';
import '../contracts/app_error.dart';
import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../../models/hitl_gate.dart';
import '../../services/hitl_gate_service.dart';
import '../dto/action_dto.dart';
import '../dto/config_dto.dart';
import '../dto/dashboard_dto.dart';
import '../dto/hitl_gate_dto.dart';
import '../dto/review_status_dto.dart';
import '../dto/status_snapshot_dto.dart';
import '../dto/telemetry_dto.dart';
import '../dto/task_dto.dart';
import '../shared/app_error_mapper.dart';

part 'in_process_genaisys_api_spec_review_helpers.dart';
part 'in_process_genaisys_api_mapping_helpers.dart';

class InProcessGenaisysApi implements GenaisysApi {
  InProcessGenaisysApi({
    InitService? initService,
    StatusService? statusService,
    TaskService? taskService,
    ReviewService? reviewService,
    ActivateService? activateService,
    ConfigService? configService,
    DoneService? doneService,
    CycleService? cycleService,
    TaskCycleService? taskCycleService,
    SpecService? specService,
    TaskWriteService? taskWriteService,
    TaskRefinementService? taskRefinementService,
  }) : _initService = initService ?? InitService(),
       _statusService = statusService ?? StatusService(),
       _taskService = taskService ?? TaskService(),
       _reviewService = reviewService ?? ReviewService(),
       _activateService = activateService ?? ActivateService(),
       _configService = configService ?? ConfigService(),
       _doneService = doneService ?? DoneService(),
       _cycleService = cycleService ?? CycleService(),
       _taskCycleService = taskCycleService ?? TaskCycleService(),
       _specService = specService ?? SpecService(),
       _taskWriteService = taskWriteService ?? TaskWriteService(),
       _taskRefinementService =
           taskRefinementService ?? TaskRefinementService();

  final InitService _initService;
  final StatusService _statusService;
  final TaskService _taskService;
  final ReviewService _reviewService;
  final ActivateService _activateService;
  final ConfigService _configService;
  final DoneService _doneService;
  final CycleService _cycleService;
  final TaskCycleService _taskCycleService;
  final SpecService _specService;
  final TaskWriteService _taskWriteService;
  final TaskRefinementService _taskRefinementService;

  @override
  Future<AppResult<ProjectInitializationDto>> initializeProject(
    String projectRoot, {
    bool overwrite = false,
    String? fromSource,
    bool staticMode = false,
    int? sprintSize,
  }) async {
    try {
      final InitResult result;
      if (fromSource != null) {
        result = await _initService.initializeFromSource(
          projectRoot,
          overwrite: overwrite,
          fromSource: fromSource,
          staticMode: staticMode,
          sprintSize: sprintSize,
        );
      } else {
        result = _initService.initialize(projectRoot, overwrite: overwrite);
      }
      return AppResult.success(
        ProjectInitializationDto(
          initialized: true,
          genaisysDir: result.genaisysDir,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<AppStatusSnapshotDto>> getStatus(String projectRoot) async {
    try {
      final snapshot = _statusService.getStatus(projectRoot);
      final dto = AppStatusSnapshotDto(
        projectRoot: snapshot.projectRoot,
        tasksTotal: snapshot.tasksTotal,
        tasksOpen: snapshot.tasksOpen,
        tasksDone: snapshot.tasksDone,
        tasksBlocked: snapshot.tasksBlocked,
        activeTaskTitle: _normalizeNullable(snapshot.activeTaskTitle),
        activeTaskId: _normalizeNullable(snapshot.activeTaskId),
        reviewStatus: _normalizeNullable(snapshot.reviewStatus),
        reviewUpdatedAt: _normalizeNullable(snapshot.reviewUpdatedAt),
        cycleCount: snapshot.cycleCount,
        lastUpdated: _normalizeNullable(snapshot.lastUpdated),
        lastError: _normalizeNullable(snapshot.lastError),
        lastErrorClass: _normalizeNullable(snapshot.lastErrorClass),
        lastErrorKind: _normalizeNullable(snapshot.lastErrorKind),
        workflowStage: snapshot.workflowStage.name,
        health: _toHealthDto(snapshot.health),
        telemetry: _toTelemetryDto(snapshot.telemetry),
      );
      _safeAppendLog(
        projectRoot,
        event: 'status',
        message: 'Reported project status',
        data: {
          'root': projectRoot,
          'tasks_total': dto.tasksTotal,
          'tasks_blocked': dto.tasksBlocked,
          'active_task': dto.activeTaskTitle ?? '',
          'workflow_stage': dto.workflowStage,
        },
      );
      return AppResult.success(dto);
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<AppTaskListDto>> listTasks(
    String projectRoot, {
    TaskListQuery query = const TaskListQuery(),
  }) async {
    try {
      final result = _taskService.listTasks(
        projectRoot,
        TaskListRequest(
          openOnly: query.openOnly,
          doneOnly: query.doneOnly,
          blockedOnly: query.blockedOnly,
          activeOnly: query.activeOnly,
          sectionFilter: query.sectionFilter,
          sortByPriority: query.sortByPriority,
        ),
      );
      final dto = AppTaskListDto(
        total: result.total,
        tasks: result.visible.map(_toTaskDto).toList(growable: false),
      );
      _safeAppendLog(
        projectRoot,
        event: 'tasks_list',
        message: 'Listed tasks',
        data: {
          'root': projectRoot,
          'tasks_total': dto.total,
          'open_only': query.openOnly,
          'done_only': query.doneOnly,
          'blocked_only': query.blockedOnly,
          'active_only': query.activeOnly,
          'sort_priority': query.sortByPriority,
          'section': query.sectionFilter ?? '',
          'filter_mode': _filterMode(query),
        },
      );
      return AppResult.success(dto);
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<AppTaskDto?>> getNextTask(
    String projectRoot, {
    String? sectionFilter,
  }) async {
    try {
      final task = _taskService.nextTask(
        projectRoot,
        sectionFilter: sectionFilter,
      );
      final dto = task == null ? null : _toTaskDto(task);
      _safeAppendLog(
        projectRoot,
        event: 'next_task',
        message: dto == null ? 'No open tasks found' : 'Selected next task',
        data: {
          'root': projectRoot,
          'task': dto?.title ?? '',
          'section': sectionFilter ?? '',
        },
      );
      return AppResult.success(dto);
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<AppReviewStatusDto>> getReviewStatus(
    String projectRoot,
  ) async {
    try {
      final snapshot = _reviewService.status(projectRoot);
      return AppResult.success(
        AppReviewStatusDto(
          status: snapshot.status,
          updatedAt: snapshot.updatedAt,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<AppDashboardDto>> getDashboard(String projectRoot) async {
    final statusResult = await getStatus(projectRoot);
    if (!statusResult.ok || statusResult.data == null) {
      return AppResult.failure(
        statusResult.error ??
            AppError.unknown('Failed to load dashboard status.'),
      );
    }

    final reviewResult = await getReviewStatus(projectRoot);
    if (!reviewResult.ok || reviewResult.data == null) {
      return AppResult.failure(
        reviewResult.error ??
            AppError.unknown('Failed to load dashboard review status.'),
      );
    }

    return AppResult.success(
      AppDashboardDto(status: statusResult.data!, review: reviewResult.data!),
    );
  }

  @override
  Future<AppResult<AppConfigDto>> getConfig(String projectRoot) async {
    try {
      final config = _configService.load(projectRoot);
      return AppResult.success(_toConfigDto(config));
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<ConfigUpdateDto>> updateConfig(
    String projectRoot, {
    required AppConfigDto config,
  }) async {
    try {
      final normalized = _normalizeConfig(config);
      _validateConfig(normalized);
      final update = ConfigUpdate(
        gitBaseBranch: normalized.gitBaseBranch,
        gitFeaturePrefix: normalized.gitFeaturePrefix,
        gitAutoStash: normalized.gitAutoStash,
        safeWriteEnabled: normalized.safeWriteEnabled,
        safeWriteRoots: normalized.safeWriteRoots,
        shellAllowlist: normalized.shellAllowlist,
        shellAllowlistProfile: normalized.shellAllowlistProfile,
        diffBudgetMaxFiles: normalized.diffBudgetMaxFiles,
        diffBudgetMaxAdditions: normalized.diffBudgetMaxAdditions,
        diffBudgetMaxDeletions: normalized.diffBudgetMaxDeletions,
        autopilotMinOpenTasks: normalized.autopilotMinOpenTasks,
        autopilotMaxPlanAdd: normalized.autopilotMaxPlanAdd,
        autopilotStepSleepSeconds: normalized.autopilotStepSleepSeconds,
        autopilotIdleSleepSeconds: normalized.autopilotIdleSleepSeconds,
        autopilotMaxSteps: normalized.autopilotMaxSteps,
        autopilotMaxFailures: normalized.autopilotMaxFailures,
        autopilotMaxTaskRetries: normalized.autopilotMaxTaskRetries,
        autopilotSelectionMode: normalized.autopilotSelectionMode,
        autopilotFairnessWindow: normalized.autopilotFairnessWindow,
        autopilotPriorityWeightP1: normalized.autopilotPriorityWeightP1,
        autopilotPriorityWeightP2: normalized.autopilotPriorityWeightP2,
        autopilotPriorityWeightP3: normalized.autopilotPriorityWeightP3,
        autopilotReactivateBlocked: normalized.autopilotReactivateBlocked,
        autopilotReactivateFailed: normalized.autopilotReactivateFailed,
        autopilotBlockedCooldownSeconds:
            normalized.autopilotBlockedCooldownSeconds,
        autopilotFailedCooldownSeconds:
            normalized.autopilotFailedCooldownSeconds,
        autopilotLockTtlSeconds: normalized.autopilotLockTtlSeconds,
        autopilotNoProgressThreshold: normalized.autopilotNoProgressThreshold,
        autopilotStuckCooldownSeconds: normalized.autopilotStuckCooldownSeconds,
        autopilotSelfRestart: normalized.autopilotSelfRestart,
        autopilotScopeMaxFiles: normalized.autopilotScopeMaxFiles,
        autopilotScopeMaxAdditions: normalized.autopilotScopeMaxAdditions,
        autopilotScopeMaxDeletions: normalized.autopilotScopeMaxDeletions,
        autopilotApproveBudget: normalized.autopilotApproveBudget,
        autopilotManualOverride: normalized.autopilotManualOverride,
        autopilotOvernightUnattendedEnabled:
            normalized.autopilotOvernightUnattendedEnabled,
        autopilotSelfTuneEnabled: normalized.autopilotSelfTuneEnabled,
        autopilotSelfTuneWindow: normalized.autopilotSelfTuneWindow,
        autopilotSelfTuneMinSamples: normalized.autopilotSelfTuneMinSamples,
        autopilotSelfTuneSuccessPercent:
            normalized.autopilotSelfTuneSuccessPercent,
      );
      final updated = _configService.update(projectRoot, update: update);
      final dto = _toConfigDto(updated);
      return AppResult.success(ConfigUpdateDto(updated: true, config: dto));
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskActivationDto>> activateTask(
    String projectRoot, {
    String? id,
    String? title,
  }) async {
    try {
      final result = _activateService.activate(
        projectRoot,
        requestedId: id,
        requestedTitle: title,
      );
      return AppResult.success(
        TaskActivationDto(
          activated: result.hasTask,
          task: result.task == null ? null : _toTaskDto(result.task!),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskDeactivationDto>> deactivateTask(
    String projectRoot, {
    bool keepReview = false,
  }) async {
    try {
      _activateService.deactivate(projectRoot, keepReview: keepReview);
      final state = StateStore(ProjectLayout(projectRoot).statePath).read();
      return AppResult.success(
        TaskDeactivationDto(
          deactivated: true,
          keepReview: keepReview,
          activeTaskTitle: _normalizeNullable(state.activeTaskTitle),
          activeTaskId: _normalizeNullable(state.activeTaskId),
          reviewStatus: _normalizeNullable(state.reviewStatus),
          reviewUpdatedAt: _normalizeNullable(state.reviewUpdatedAt),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<ReviewDecisionDto>> approveReview(
    String projectRoot, {
    String? note,
  }) async {
    return _recordReviewDecision(
      projectRoot,
      decision: 'approve',
      label: 'approved',
      note: note,
    );
  }

  @override
  Future<AppResult<ReviewDecisionDto>> rejectReview(
    String projectRoot, {
    String? note,
  }) async {
    return _recordReviewDecision(
      projectRoot,
      decision: 'reject',
      label: 'rejected',
      note: note,
    );
  }

  @override
  Future<AppResult<ReviewClearDto>> clearReview(
    String projectRoot, {
    String? note,
  }) async {
    try {
      _reviewService.clear(projectRoot, note: note);
      final status = _reviewService.status(projectRoot);
      return AppResult.success(
        ReviewClearDto(
          reviewCleared: true,
          reviewStatus: status.status,
          reviewUpdatedAt: status.updatedAt,
          note: _normalizeNullable(note),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskDoneDto>> markTaskDone(
    String projectRoot, {
    bool force = false,
  }) async {
    try {
      final title = await _doneService.markDone(projectRoot, force: force);
      return AppResult.success(TaskDoneDto(done: true, taskTitle: title));
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskBlockedDto>> blockTask(
    String projectRoot, {
    String? reason,
  }) async {
    try {
      final title = _doneService.blockActive(projectRoot, reason: reason);
      return AppResult.success(
        TaskBlockedDto(
          blocked: true,
          taskTitle: title,
          reason: _normalizeNullable(reason),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskCreateDto>> createTask(
    String projectRoot, {
    required String title,
    required AppTaskPriority priority,
    required AppTaskCategory category,
    String? section,
  }) async {
    try {
      final result = _taskWriteService.createTask(
        projectRoot,
        title: title,
        priority: _mapPriority(priority),
        category: _mapCategory(category),
        section: section,
      );
      return AppResult.success(
        TaskCreateDto(created: true, task: _toTaskDto(result.task)),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskPriorityUpdateDto>> updateTaskPriority(
    String projectRoot, {
    String? id,
    String? title,
    required AppTaskPriority priority,
  }) async {
    if ((id == null || id.trim().isEmpty) &&
        (title == null || title.trim().isEmpty)) {
      return AppResult.failure(
        AppError.invalidInput('Task id or title is required.'),
      );
    }
    try {
      final result = _taskWriteService.updatePriority(
        projectRoot,
        id: id,
        title: title,
        priority: _mapPriority(priority),
      );
      return AppResult.success(
        TaskPriorityUpdateDto(updated: true, task: _toTaskDto(result.task)),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskMoveSectionDto>> moveTaskSection(
    String projectRoot, {
    String? id,
    String? title,
    required String section,
  }) async {
    if ((id == null || id.trim().isEmpty) &&
        (title == null || title.trim().isEmpty)) {
      return AppResult.failure(
        AppError.invalidInput('Task id or title is required.'),
      );
    }
    if (section.trim().isEmpty) {
      return AppResult.failure(
        AppError.invalidInput('Section must not be empty.'),
      );
    }
    try {
      final result = _taskWriteService.moveSection(
        projectRoot,
        id: id,
        title: title,
        section: section,
      );
      return AppResult.success(
        TaskMoveSectionDto(
          moved: result.fromSection != result.task.section,
          task: _toTaskDto(result.task),
          fromSection: result.fromSection,
          toSection: result.task.section,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskDeleteDto>> deleteTask(
    String projectRoot, {
    String? id,
    String? title,
  }) async {
    if ((id == null || id.trim().isEmpty) &&
        (title == null || title.trim().isEmpty)) {
      return AppResult.failure(
        AppError.invalidInput('Task id or title is required.'),
      );
    }
    try {
      final result = _taskWriteService.deleteTask(
        projectRoot,
        id: id,
        title: title,
      );
      return AppResult.success(
        TaskDeleteDto(
          deleted: true,
          taskTitle: result.task.title,
          taskId: result.task.id,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskRefinementDto>> refineTask(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  }) async {
    try {
      final result = await _taskRefinementService.refine(
        projectRoot,
        title: title,
        overwrite: overwrite,
      );
      return AppResult.success(
        TaskRefinementDto(
          refined: result.artifacts.isNotEmpty,
          title: result.title,
          usedFallback: result.usedFallback,
          artifacts: result.artifacts
              .map(
                (artifact) => TaskRefinementArtifactDto(
                  kind: artifact.kind.name,
                  path: artifact.path,
                  wrote: artifact.wrote,
                  usedFallback: artifact.usedFallback,
                ),
              )
              .toList(growable: false),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<CycleTickDto>> cycle(String projectRoot) async {
    try {
      final result = _cycleService.tick(projectRoot);
      return AppResult.success(
        CycleTickDto(cycleUpdated: true, cycleCount: result.cycleCount),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<TaskCycleExecutionDto>> runTaskCycle(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) async {
    if (prompt.trim().isEmpty) {
      return AppResult.failure(
        AppError.invalidInput('Prompt must not be empty.'),
      );
    }

    try {
      final config = ProjectConfig.load(projectRoot);
      final maxRounds = config.reviewMaxRounds < 1 ? 1 : config.reviewMaxRounds;
      final result = await _taskCycleService.run(
        projectRoot,
        codingPrompt: prompt,
        testSummary: testSummary,
        overwriteArtifacts: overwrite,
        maxReviewRetries: maxRounds,
      );
      return AppResult.success(
        TaskCycleExecutionDto(
          taskCycleCompleted: true,
          reviewRecorded: result.reviewRecorded,
          reviewDecision: result.pipeline.review?.decision.name,
          codingOk: result.pipeline.coding.response.ok,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializePlan(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    return _initializeSpec(
      projectRoot,
      kind: SpecKind.plan,
      overwrite: overwrite,
    );
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializeSpec(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    return _initializeSpec(
      projectRoot,
      kind: SpecKind.spec,
      overwrite: overwrite,
    );
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializeSubtasks(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    return _initializeSpec(
      projectRoot,
      kind: SpecKind.subtasks,
      overwrite: overwrite,
    );
  }

  @override
  Future<AppResult<HitlGateDto>> getHitlGate(String projectRoot) async {
    try {
      const service = HitlGateService();
      final gate = service.pendingGate(projectRoot);
      if (gate == null) {
        return AppResult.success(const HitlGateDto(pending: false));
      }
      return AppResult.success(
        HitlGateDto(
          pending: true,
          event: gate.event.serialized,
          taskId: gate.taskId,
          taskTitle: gate.taskTitle,
          sprintNumber: gate.sprintNumber,
          expiresAt: gate.expiresAt?.toIso8601String(),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }

  @override
  Future<AppResult<void>> submitHitlDecision(
    String projectRoot, {
    required String decision,
    String? note,
  }) async {
    try {
      const service = HitlGateService();
      final type = decision == 'reject'
          ? HitlDecisionType.reject
          : HitlDecisionType.approve;
      service.submitDecision(projectRoot, decision: type, note: note);
      return AppResult.success(null);
    } catch (error, stackTrace) {
      return AppResult.failure(_mapError(error, stackTrace));
    }
  }
}
