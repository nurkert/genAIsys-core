// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import '../errors/operation_errors.dart';
import '../config/project_config.dart';
import '../git/git_service.dart';
import '../models/project_state.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import '../policy/diff_budget_policy.dart';
import 'task_management/activate_service.dart';
import 'architecture_planning_service.dart';
import 'git_sync_service.dart';
import 'agents/spec_agent_service.dart';
import 'vision_evaluation_service.dart';
import 'state_repair_service.dart';
import 'step_schema_validation_service.dart';
import 'task_management/subtask_scheduler_service.dart';
import 'task_cycle_service.dart';
import 'vision_backlog_planner_service.dart';

part 'orchestrator_step/orchestrator_step_transitions.dart';

class OrchestratorStepResult {
  OrchestratorStepResult({
    required this.executedCycle,
    required this.activatedTask,
    required this.activeTaskId,
    required this.activeTaskTitle,
    required this.plannedTasksAdded,
    required this.reviewDecision,
    required this.retryCount,
    required this.blockedTask,
    required this.deactivatedTask,
    required this.currentSubtask,
    required this.autoMarkedDone,
    required this.approvedDiffStats,
    this.visionFulfilled,
    this.didArchitecturePlanning = false,
    this.nextEligibleAt,
  });

  final bool executedCycle;
  final bool activatedTask;
  final String? activeTaskId;
  final String? activeTaskTitle;
  final int plannedTasksAdded;
  final String? reviewDecision;
  final int retryCount;
  final bool blockedTask;
  final bool deactivatedTask;
  final String? currentSubtask;
  final bool autoMarkedDone;
  final DiffStats? approvedDiffStats;

  /// Non-null when vision evaluation was performed during this step.
  /// True means the project vision is fully covered; false means gaps remain.
  final bool? visionFulfilled;

  /// True when architecture planning was executed during this step.
  /// Architecture planning is productive initialization work and should not
  /// be classified as "idle" by the run loop.
  final bool didArchitecturePlanning;

  /// When non-null, all tasks are temporarily ineligible (cooling down) and
  /// the run loop should sleep until this time rather than counting the step
  /// toward the no-progress threshold.
  final DateTime? nextEligibleAt;
}

class OrchestratorStepService {
  OrchestratorStepService({
    ActivateService? activateService,
    TaskCycleService? taskCycleService,
    VisionBacklogPlannerService? plannerService,
    StateRepairService? stateRepairService,
    StepSchemaValidationService? schemaValidationService,
    SubtaskSchedulerService? subtaskSchedulerService,
    GitService? gitService,
    GitSyncService? gitSyncService,
    ArchitecturePlanningService? architecturePlanningService,
    VisionEvaluationService? visionEvaluationService,
    SpecAgentService? specAgentService,
  }) : _activateService = activateService ?? ActivateService(),
       _taskCycleService = taskCycleService ?? TaskCycleService(),
       _plannerService = plannerService ?? VisionBacklogPlannerService(),
       _stateRepairService = stateRepairService ?? StateRepairService(),
       _schemaValidationService =
           schemaValidationService ?? StepSchemaValidationService(),
       _subtaskScheduler = subtaskSchedulerService ?? SubtaskSchedulerService(),
       _gitService = gitService ?? GitService(),
       _gitSyncService = gitSyncService ?? GitSyncService(),
       _architecturePlanningService =
           architecturePlanningService ?? ArchitecturePlanningService(),
       _visionEvaluationService =
           visionEvaluationService ?? VisionEvaluationService(),
       _specAgentService = specAgentService ?? SpecAgentService();

  final ActivateService _activateService;
  final TaskCycleService _taskCycleService;
  final VisionBacklogPlannerService _plannerService;
  final StateRepairService _stateRepairService;
  final StepSchemaValidationService _schemaValidationService;
  final SubtaskSchedulerService _subtaskScheduler;
  final GitService _gitService;
  final GitSyncService _gitSyncService;
  final ArchitecturePlanningService _architecturePlanningService;
  final VisionEvaluationService _visionEvaluationService;
  final SpecAgentService _specAgentService;

  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    _GitAutoStashResult? gitAutoStash;
    Object? runError;
    String? stepId;
    ProjectLayout? layout;
    StateStore? stateStore;
    var stepStashedDirtyState = false;
    String? errorKindHint;
    try {
      stepId = _createStepId();
      layout = ProjectLayout(projectRoot);
      _ensureInitialized(layout);
      _schemaValidationService.validateLayout(layout);
      // Commit any residual dirty state from the previous step (run-log
      // entries, deactivated STATE.json, audit files) before state repair
      // and the next task's checkout.
      _persistPostStepCleanup(projectRoot);
      _stateRepairService.repair(projectRoot);
      _enforceRuntimeGitignore(projectRoot);
      final config = ProjectConfig.load(projectRoot);
      _rotateStashes(projectRoot, config: config);
      final resolvedMinOpen = minOpenTasks ?? config.autopilotMinOpenTasks;
      final resolvedMaxPlanAdd = maxPlanAdd ?? config.autopilotMaxPlanAdd;
      final normalizedMinOpen = resolvedMinOpen < 1 ? 1 : resolvedMinOpen;
      final normalizedMaxPlanAdd = resolvedMaxPlanAdd < 1
          ? 1
          : resolvedMaxPlanAdd;
      gitAutoStash = _prepareGitGuard(
        projectRoot,
        config,
        layout: layout,
        stepId: stepId,
      );
      if (!gitAutoStash.restores &&
          gitAutoStash.message.startsWith('genaisys:')) {
        stepStashedDirtyState = true;
      }

      // Inter-loop git sync.
      if (config.gitSyncBetweenLoops) {
        final syncResult = _gitSyncService.syncBeforeLoop(
          projectRoot,
          strategy: config.gitSyncStrategy,
        );
        RunLogStore(layout.runLogPath).append(
          event: 'git_sync_between_loops',
          message: syncResult.synced
              ? 'Git sync completed'
              : 'Git sync skipped or failed',
          data: {
            'step_id': stepId,
            'synced': syncResult.synced,
            'strategy': config.gitSyncStrategy,
            'conflicts': syncResult.conflictsDetected,
            if (syncResult.errorMessage != null)
              'error': syncResult.errorMessage,
          },
        );
        if (syncResult.conflictsDetected) {
          _persistPostStepCleanup(projectRoot);
          return OrchestratorStepResult(
            executedCycle: false,
            activatedTask: false,
            activeTaskId: null,
            activeTaskTitle: null,
            plannedTasksAdded: 0,
            reviewDecision: null,
            retryCount: 0,
            blockedTask: true,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: false,
            approvedDiffStats: null,
          );
        }
      }

      // Architecture planning phase: if no ARCHITECTURE.md exists and a
      // VISION.md is present, run the architecture agent first. The next
      // step can then plan tasks with architecture context available.
      final didArchitecturePlanning = await _maybeRunArchitecturePlanning(
        projectRoot,
        layout: layout,
        stepId: stepId,
      );
      if (didArchitecturePlanning) {
        return OrchestratorStepResult(
          executedCycle: false,
          activatedTask: false,
          activeTaskId: null,
          activeTaskTitle: null,
          plannedTasksAdded: 0,
          reviewDecision: null,
          retryCount: 0,
          blockedTask: false,
          deactivatedTask: false,
          currentSubtask: null,
          autoMarkedDone: false,
          approvedDiffStats: null,
          didArchitecturePlanning: true,
        );
      }

      final planner = await _plannerService.syncBacklogStrategically(
        projectRoot,
        minOpenTasks: normalizedMinOpen,
        maxAdd: normalizedMaxPlanAdd,
      );

      stateStore = StateStore(layout.statePath);
      final activationTransition = await _resolveActivationTransition(
        projectRoot,
        layout: layout,
        stepId: stepId,
        planner: planner,
        stateStore: stateStore,
      );
      if (activationTransition.earlyResult != null) {
        _persistPostStepCleanup(projectRoot);
        return activationTransition.earlyResult!;
      }

      // Guard: subtask queue overflow — prevent runaway queue growth.
      // Check before subtask selection so the full queue length is evaluated.
      {
        final queueState = stateStore.read();
        final queueMax = config.autopilotSubtaskQueueMax;
        if (queueState.subtaskQueue.length > queueMax) {
          _appendRunLog(
            layout,
            event: 'subtask_queue_overflow',
            message:
                'Subtask queue length ${queueState.subtaskQueue.length} exceeds '
                'configured maximum $queueMax — deactivating task',
            data: {
              'step_id': stepId,
              if (activationTransition.activeTaskId?.trim().isNotEmpty == true)
                'task_id': activationTransition.activeTaskId,
              'queue_length': queueState.subtaskQueue.length,
              'queue_max': queueMax,
              'error_class': 'pipeline',
              'error_kind': 'subtask_queue_overflow',
            },
          );
          _activateService.deactivate(projectRoot, keepReview: false);
          _persistPostStepCleanup(projectRoot);
          return OrchestratorStepResult(
            executedCycle: false,
            activatedTask: activationTransition.activatedTask,
            activeTaskId: activationTransition.activeTaskId,
            activeTaskTitle: activationTransition.activeTitle,
            plannedTasksAdded: planner.added,
            reviewDecision: null,
            retryCount: 0,
            blockedTask: true,
            deactivatedTask: true,
            currentSubtask: null,
            autoMarkedDone: false,
            approvedDiffStats: null,
          );
        }
      }

      // Feature 1a: Proactively refine oversized subtasks before coding.
      if (config.pipelineSubtaskRefinementEnabled) {
        try {
          await _specAgentService.maybeRefineSubtasks(
            projectRoot,
            stepId: stepId,
          );
        } catch (_) {
          // Non-fatal: do not block the step if refinement fails.
        }
      }

      // Feature 2: Feasibility check — ensure subtasks cover the AC.
      if (config.pipelineSubtaskFeasibilityEnabled) {
        try {
          await _specAgentService.checkFeasibility(
            projectRoot,
            stepId: stepId,
          );
        } catch (_) {
          // Non-fatal: do not block the step if the check fails.
        }
      }

      // Re-read state after potential queue modifications by 1a/2.
      stateStore = StateStore(layout.statePath);
      final stateAfterRefinement = stateStore.read();

      final subtaskTransition = _resolveSubtaskTransition(
        projectRoot,
        layout: layout,
        stepId: stepId,
        stateStore: stateStore,
        state: stateAfterRefinement,
        activeTitle: activationTransition.activeTitle!,
        activeTaskId: activationTransition.activeTaskId,
        codingPrompt: codingPrompt,
      );

      final normalizedReviewMaxRounds = config.reviewMaxRounds < 1
          ? 1
          : config.reviewMaxRounds;
      final cycleResult = await _taskCycleService.run(
        projectRoot,
        codingPrompt: _composePrompt(
          subtaskTransition.codingPromptToUse,
          activationTransition.activeTitle,
        ),
        testSummary: testSummary,
        overwriteArtifacts: overwriteArtifacts,
        isSubtask: subtaskTransition.isSubtask,
        subtaskDescription: subtaskTransition.isSubtask
            ? subtaskTransition.subtaskDescription
            : null,
        maxReviewRetries: normalizedReviewMaxRounds,
      );

      _handleSubtaskCompletionTransition(
        stateStore,
        isSubtask: subtaskTransition.isSubtask,
        cycleResult: cycleResult,
      );
      _maybeAutoRefineLongRunningSubtask(
        stateStore: stateStore,
        layout: layout,
        stepId: stepId,
        config: config,
        activeTaskId: activationTransition.activeTaskId,
        activeTaskTitle: activationTransition.activeTitle,
        isSubtask: subtaskTransition.isSubtask,
        cycleResult: cycleResult,
      );

      var deactivated = false;
      final shouldDeactivate =
          (!subtaskTransition.isSubtask &&
              cycleResult.reviewDecision?.name == 'approve') ||
          cycleResult.taskBlocked;

      if (shouldDeactivate) {
        _activateService.deactivate(projectRoot, keepReview: true);
        deactivated = true;
      }

      _appendRunLog(
        layout,
        event: 'orchestrator_step',
        message: 'Completed one orchestrator step',
        data: {
          'active_task': activationTransition.activeTitle,
          if (activationTransition.activeTaskId != null &&
              activationTransition.activeTaskId!.isNotEmpty)
            'task_id': activationTransition.activeTaskId,
          'activated_task': activationTransition.activatedTask,
          'planned_added': planner.added,
          'review_decision': cycleResult.reviewDecision?.name ?? '',
          'decision': cycleResult.reviewDecision?.name ?? '',
          'retry_count': cycleResult.retryCount,
          'task_blocked': cycleResult.taskBlocked,
          'deactivated': deactivated,
          'step_id': stepId,
          if (subtaskTransition.isSubtask)
            'subtask_id': subtaskTransition.subtaskDescription,
          if (subtaskTransition.isSubtask)
            'subtask_dependency_aware':
                subtaskTransition.subtaskDependencyAware,
          if (subtaskTransition.isSubtask)
            'subtask_cycle_fallback': subtaskTransition.subtaskCycleFallback,
        },
      );

      return OrchestratorStepResult(
        executedCycle: true,
        activatedTask: activationTransition.activatedTask,
        activeTaskId: activationTransition.activeTaskId,
        activeTaskTitle: activationTransition.activeTitle,
        plannedTasksAdded: planner.added,
        reviewDecision: cycleResult.reviewDecision?.name,
        retryCount: cycleResult.retryCount,
        blockedTask: cycleResult.taskBlocked,
        deactivatedTask: deactivated,
        currentSubtask: subtaskTransition.isSubtask
            ? subtaskTransition.subtaskDescription
            : null,
        autoMarkedDone: cycleResult.autoMarkedDone,
        approvedDiffStats: cycleResult.approvedDiffStats,
      );
    } catch (error, stackTrace) {
      final lower = error.toString().toLowerCase();
      final looksLikeTimeout =
          error is TimeoutException ||
          lower.contains('timeoutexception') ||
          lower.contains(' timed out') ||
          lower.contains('timeout ');
      if (looksLikeTimeout) {
        errorKindHint = 'timeout';
      }
      runError = error;
      throw classifyOperationError(error, stackTrace);
    } finally {
      if (gitAutoStash != null && gitAutoStash.restores) {
        try {
          _gitService.stashPop(projectRoot);
          _appendRunLog(
            ProjectLayout(projectRoot),
            event: 'git_auto_stash_restore',
            message: 'Re-applied auto-stashed changes',
            data: {
              'step_id': gitAutoStash.stepId,
              'stash_message': gitAutoStash.message,
            },
          );
        } catch (error) {
          _appendRunLog(
            ProjectLayout(projectRoot),
            event: 'git_auto_stash_restore_failed',
            message: 'Failed to re-apply auto-stashed changes',
            data: {
              'step_id': gitAutoStash.stepId,
              'stash_message': gitAutoStash.message,
              'error': error.toString(),
            },
          );
          // Recovery: a failed stash pop leaves conflicting changes in the
          // worktree.  Clean up so the next cycle's preflight does not block
          // on git_dirty.  The stash entry is preserved in the stash list
          // for forensic access.
          _recoverFromFailedStashPop(
            projectRoot,
            stepId: gitAutoStash.stepId,
            stashMessage: gitAutoStash.message,
            popError: error.toString(),
          );
          if (runError == null) {
            throw StateError('Failed to re-apply auto-stashed changes: $error');
          }
        }
      }

      // Clean-End invariant (unattended safety): if the step fails mid-cycle
      // (quota/transient/crash), archive the dirty workspace via git stash so
      // the next cycle starts from a clean worktree.
      // NOTE: This must run BEFORE the timeout re-queue below.  If the stash
      // were attempted after the queue mutation and failed, the state would be
      // corrupted (queue mutated but worktree still dirty).
      if (runError != null && layout != null) {
        try {
          final config = ProjectConfig.load(projectRoot);
          if (config.gitAutoStash) {
            var dirty = !_gitService.isClean(projectRoot);
            var attempt = 0;
            while (dirty && attempt < 2) {
              attempt += 1;
              final message =
                  'genaisys:step-error:${stepId ?? 'unknown'}:${DateTime.now().toUtc().microsecondsSinceEpoch}:attempt:$attempt';
              final stashed = _gitService.stashPush(
                projectRoot,
                message: message,
                includeUntracked: true,
              );
              if (stashed) {
                stepStashedDirtyState = true;
                _appendRunLog(
                  layout,
                  event: 'git_step_error_autostash',
                  message: 'Stashed dirty worktree context after step error',
                  data: {
                    'step_id': stepId ?? '',
                    'stash_message': message,
                    'attempt': attempt,
                    'error': runError.toString(),
                    'error_class': 'delivery',
                    'error_kind': 'git_auto_stash',
                  },
                );
              }
              dirty = !_gitService.isClean(projectRoot);
              if (!stashed) {
                break;
              }
            }
            if (dirty) {
              _appendRunLog(
                layout,
                event: 'git_step_error_autostash_incomplete',
                message:
                    'Worktree still dirty after step-error autostash attempts',
                data: {
                  'step_id': stepId ?? '',
                  'attempts': attempt,
                  'error': runError.toString(),
                  'error_class': 'delivery',
                  'error_kind': 'git_auto_stash_incomplete',
                },
              );
            }
          }
        } catch (_) {
          // Best-effort: do not mask the original error; preflight will
          // detect remaining dirty state in the next cycle.
        }
      }

      // If the coding agent timed out mid-subtask, re-queue the current subtask
      // behind the remaining queue to avoid repeatedly burning cycles on the
      // exact same "stuck" item.
      // NOTE: This runs AFTER the error-stash above so that if the stash
      // operation fails, the subtask queue has not yet been mutated.
      if (errorKindHint == 'timeout' && stateStore != null && layout != null) {
        try {
          final state = stateStore.read();
          final current = state.currentSubtask?.trim();
          if (current != null && current.isNotEmpty) {
            final updatedQueue = [...state.subtaskQueue, current];
            stateStore.write(
              state.copyWith(
                subtaskExecution: state.subtaskExecution.copyWith(
                  current: null,
                  queue: updatedQueue,
                ),
                lastUpdated: DateTime.now().toUtc().toIso8601String(),
              ),
            );
            _appendRunLog(
              layout,
              event: 'subtask_requeued_after_timeout',
              message: 'Re-queued current subtask after timeout',
              data: {
                'step_id': stepId ?? '',
                if (state.activeTaskId?.trim().isNotEmpty == true)
                  'task_id': state.activeTaskId!.trim(),
                'subtask_id': current,
                'queue_length_after': updatedQueue.length,
                'error_class': 'pipeline',
                'error_kind': 'timeout',
              },
            );
          }
        } catch (_) {
          // Best-effort: never mask the original timeout error.
        }
      }

      // Unconditional Clean-End invariant (unattended safety).
      // Even when the step succeeds (e.g., review reject followed by
      // normalizeAfterReject), verify the worktree is clean. If not, archive
      // remaining dirty state so the next cycle's preflight does not block.
      // Skip if a stash was already pushed during this step — the worktree
      // state is already archived and re-stashing would be redundant.
      if (layout != null && !stepStashedDirtyState) {
        try {
          final unattended = File(
            ProjectLayout(projectRoot).autopilotLockPath,
          ).existsSync();
          if (unattended && !_gitService.isClean(projectRoot)) {
            final msg =
                'genaisys:clean-end-guard:${stepId ?? "unknown"}:'
                '${DateTime.now().toUtc().microsecondsSinceEpoch}';
            final stashed = _gitService.stashPush(
              projectRoot,
              message: msg,
              includeUntracked: true,
            );
            _appendRunLog(
              layout,
              event: stashed
                  ? 'clean_end_guard_stash'
                  : 'clean_end_guard_dirty',
              message: stashed
                  ? 'Clean-End guard archived residual dirty state'
                  : 'Clean-End guard: worktree still dirty after stash attempt',
              data: {
                'step_id': stepId ?? '',
                'stash_message': msg,
                'had_run_error': runError != null,
                'error_class': 'delivery',
                'error_kind': stashed
                    ? 'clean_end_guard_stash'
                    : 'clean_end_guard_dirty',
              },
            );
          }
        } catch (_) {
          // Best-effort: Clean-End guard must never mask original error.
        }
      }
    }
  }

  /// Trims stash list to the configured maximum.  Best-effort — failures
  /// are logged but never block the step.
  void _rotateStashes(String projectRoot, {required ProjectConfig config}) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) return;
      final maxStashes = config.autopilotMaxStashEntries;
      if (maxStashes <= 0) return;
      _gitService.dropOldestStashes(projectRoot, maxKeep: maxStashes);
    } catch (e) {
      final layout = ProjectLayout(projectRoot);
      RunLogStore(layout.runLogPath).append(
        event: 'stash_rotation_failed',
        message: 'Stash rotation failed (non-fatal)',
        data: {
          'root': projectRoot,
          'error': e.toString(),
          'error_class': 'git',
          'error_kind': 'stash_rotation_failed',
        },
      );
    }
  }

  String _createStepId() {
    final now = DateTime.now().toUtc();
    return 'step-${now.microsecondsSinceEpoch}';
  }

  String _composePrompt(String basePrompt, String? activeTitle) {
    final task = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : '(unknown)';
    return '''
$basePrompt

Constraints:
- Implement exactly one smallest meaningful step.
- Do not mix multiple features.
- Keep internal artifacts and task outputs in English.
- Current active task: $task
'''
        .trim();
  }

  void _maybeAutoRefineLongRunningSubtask({
    required StateStore stateStore,
    required ProjectLayout layout,
    required String stepId,
    required ProjectConfig config,
    required String? activeTaskId,
    required String? activeTaskTitle,
    required bool isSubtask,
    required TaskCycleResult cycleResult,
  }) {
    if (!isSubtask || cycleResult.taskBlocked) {
      return;
    }
    if (cycleResult.reviewDecision?.name == 'approve') {
      return;
    }

    final durationMs =
        cycleResult.pipeline.coding.response.commandEvent?.durationMs;
    if (durationMs == null || durationMs < 1) {
      return;
    }
    final thresholdMs = _longRunSplitThresholdMs(config.agentTimeout);
    if (durationMs < thresholdMs) {
      return;
    }

    final state = stateStore.read();
    final current = state.currentSubtask?.trim();
    if (current == null || current.isEmpty) {
      return;
    }
    final refineKey = _autoRefineKey(
      taskId: activeTaskId,
      taskTitle: activeTaskTitle,
      subtask: current,
    );
    if (refineKey == null) {
      return;
    }
    if ((state.taskRetryCounts[refineKey] ?? 0) > 0) {
      _appendRunLog(
        layout,
        event: 'subtask_auto_refine_skipped',
        message:
            'Skipped long-running subtask refinement because this subtask was already refined once',
        data: {
          'step_id': stepId,
          if (activeTaskId?.trim().isNotEmpty == true) 'task_id': activeTaskId,
          'subtask_id': current,
          'duration_ms': durationMs,
          'threshold_ms': thresholdMs,
          'error_class': 'pipeline',
          'error_kind': 'subtask_auto_refine_skipped',
          'reason': 'already_refined_once',
        },
      );
      return;
    }

    final splitParts = _splitSubtaskForLongRun(current);
    if (splitParts.length < 2) {
      _appendRunLog(
        layout,
        event: 'subtask_auto_refine_skipped',
        message: 'Skipped long-running subtask refinement (no stable split)',
        data: {
          'step_id': stepId,
          if (activeTaskId?.trim().isNotEmpty == true) 'task_id': activeTaskId,
          'subtask_id': current,
          'duration_ms': durationMs,
          'threshold_ms': thresholdMs,
          'error_class': 'pipeline',
          'error_kind': 'subtask_auto_refine_skipped',
          'reason': 'no_split_candidates',
        },
      );
      return;
    }

    final counts = Map<String, int>.from(state.taskRetryCounts);
    counts[refineKey] = 1;
    for (final split in splitParts) {
      final splitKey = _autoRefineKey(
        taskId: activeTaskId,
        taskTitle: activeTaskTitle,
        subtask: split,
      );
      if (splitKey != null) {
        counts[splitKey] = 1;
      }
    }

    final remainingQueue = [...state.subtaskQueue];
    final updatedCurrent = splitParts.first;
    final updatedQueue = [...splitParts.skip(1), ...remainingQueue];

    stateStore.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          current: updatedCurrent,
          queue: updatedQueue,
        ),
        retryScheduling: state.retryScheduling.copyWith(
          retryCounts: Map.unmodifiable(counts),
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    _appendRunLog(
      layout,
      event: 'subtask_auto_refined_long_run',
      message: 'Auto-refined long-running subtask into smaller one-level steps',
      data: {
        'step_id': stepId,
        if (activeTaskId?.trim().isNotEmpty == true) 'task_id': activeTaskId,
        'subtask_id': current,
        'duration_ms': durationMs,
        'threshold_ms': thresholdMs,
        'new_current_subtask': updatedCurrent,
        'generated_subtasks': splitParts,
        'queue_length_after': updatedQueue.length,
        'error_class': 'pipeline',
        'error_kind': 'subtask_auto_refined_long_run',
      },
    );
  }

  int _longRunSplitThresholdMs(Duration agentTimeout) {
    final timeoutMs = agentTimeout.inMilliseconds;
    final derived = (timeoutMs * 2) ~/ 3;
    return math.max(120000, derived);
  }

  List<String> _splitSubtaskForLongRun(String subtask) {
    final normalized = _normalizeSplitText(subtask);
    if (normalized.length < 40) {
      return const [];
    }

    final delimiters = <RegExp>[
      RegExp(r'\s+and then\s+', caseSensitive: false),
      RegExp(r'\s+then\s+', caseSensitive: false),
      RegExp(r'\s+plus\s+', caseSensitive: false),
      RegExp(r'\s+followed by\s+', caseSensitive: false),
      RegExp(r';\s+'),
    ];
    for (final delimiter in delimiters) {
      final rawParts = normalized.split(delimiter);
      final parts = rawParts
          .map(_normalizeSplitText)
          .where((part) => part.length >= 8)
          .toList(growable: false);
      if (parts.length >= 2) {
        return parts.take(3).toList(growable: false);
      }
    }

    if (normalized.length >= 160 && normalized.contains(',')) {
      final clauses = normalized
          .split(RegExp(r',\s+'))
          .map(_normalizeSplitText)
          .where((part) => part.length >= 8)
          .toList(growable: false);
      if (clauses.length >= 3) {
        final first = '${clauses[0]}, ${clauses[1]}';
        return <String>[first, ...clauses.skip(2).take(2)];
      }
    }
    return const [];
  }

  String _normalizeSplitText(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _autoRefineKey({
    required String? taskId,
    required String? taskTitle,
    required String subtask,
  }) {
    final normalizedSubtask = subtask.trim().toLowerCase();
    if (normalizedSubtask.isEmpty) {
      return null;
    }
    final normalizedTaskId = taskId?.trim();
    if (normalizedTaskId != null && normalizedTaskId.isNotEmpty) {
      return 'subtask:auto_refine:id:$normalizedTaskId:$normalizedSubtask';
    }
    final normalizedTaskTitle = taskTitle?.trim().toLowerCase();
    if (normalizedTaskTitle != null && normalizedTaskTitle.isNotEmpty) {
      return 'subtask:auto_refine:title:$normalizedTaskTitle:$normalizedSubtask';
    }
    return 'subtask:auto_refine:$normalizedSubtask';
  }

  _GitAutoStashResult _prepareGitGuard(
    String projectRoot,
    ProjectConfig config, {
    required ProjectLayout layout,
    required String stepId,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return _GitAutoStashResult.none(stepId: stepId);
    }
    if (_gitService.hasMergeInProgress(projectRoot)) {
      throw StateError(
        'Merge in progress. Manual intervention required before autopilot can run.',
      );
    }
    final clean = _gitService.isClean(projectRoot);
    if (clean) {
      return _GitAutoStashResult.none(stepId: stepId);
    }
    if (!config.gitAutoStash) {
      throw StateError(
        'Git repo has uncommitted changes. Clean the repo or enable auto-stash.',
      );
    }
    final state = StateStore(layout.statePath).read();
    final unattendedMode = File(layout.autopilotLockPath).existsSync();
    final reviewRejected =
        state.reviewStatus?.trim().toLowerCase() == 'rejected';
    final hasActiveTask =
        (state.activeTaskId?.trim().isNotEmpty ?? false) ||
        (state.activeTaskTitle?.trim().isNotEmpty ?? false);
    final skipRejectedContextStash = _shouldSkipRejectedContextStash(
      config,
      unattendedMode: unattendedMode,
    );
    if (reviewRejected && hasActiveTask && skipRejectedContextStash) {
      _appendRunLog(
        layout,
        event: 'git_auto_stash_skip_rejected',
        message: 'Skipped auto-stash to preserve rejected worktree context',
        data: {
          'step_id': stepId,
          'reason': 'review_rejected',
          if (state.activeTaskId?.trim().isNotEmpty == true)
            'task_id': state.activeTaskId!.trim(),
        },
      );
      return _GitAutoStashResult.none(stepId: stepId);
    }
    final stashMessage = reviewRejected && hasActiveTask
        ? _buildRejectedContextStashMessage(
            stepId: stepId,
            taskId: state.activeTaskId,
            subtaskId: state.currentSubtask,
          )
        : 'genaisys:auto-stash:$stepId';
    final stashed = _gitService.stashPush(
      projectRoot,
      message: stashMessage,
      includeUntracked: true,
    );
    if (stashed) {
      if (reviewRejected && hasActiveTask) {
        _appendRunLog(
          layout,
          event: 'git_auto_stash_rejected_context',
          message: 'Auto-stashed rejected worktree context before step',
          data: {
            'step_id': stepId,
            'stash_message': stashMessage,
            if (state.activeTaskId?.trim().isNotEmpty == true)
              'task_id': state.activeTaskId!.trim(),
            if (state.currentSubtask?.trim().isNotEmpty == true)
              'subtask_id': state.currentSubtask!.trim(),
            'unattended_mode': unattendedMode,
          },
        );
      }
      _appendRunLog(
        layout,
        event: 'git_auto_stash',
        message: 'Auto-stashed dirty repo before autopilot step',
        data: {'step_id': stepId, 'stash_message': stashMessage},
      );
    }
    return _GitAutoStashResult(
      stepId: stepId,
      restores: stashed && !unattendedMode,
      message: stashMessage,
    );
  }

  bool _shouldSkipRejectedContextStash(
    ProjectConfig config, {
    required bool unattendedMode,
  }) {
    if (unattendedMode) {
      return config.gitAutoStashSkipRejectedUnattended;
    }
    return config.gitAutoStashSkipRejected;
  }

  String _buildRejectedContextStashMessage({
    required String stepId,
    String? taskId,
    String? subtaskId,
  }) {
    final taskToken = taskId?.trim().isNotEmpty == true
        ? taskId!.trim()
        : 'none';
    final subtaskToken = subtaskId?.trim().isNotEmpty == true
        ? _sanitizeToken(subtaskId!)
        : 'none';
    return 'genaisys:rejected-context:$stepId:task:$taskToken:subtask:$subtaskToken';
  }

  String _sanitizeToken(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[.-]+'), '')
        .replaceAll(RegExp(r'[.-]+$'), '');
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized;
  }

  /// Recovers from a failed `git stash pop` by cleaning the worktree.
  ///
  /// A failed pop leaves conflicting changes in the working tree.  Without
  /// cleanup the next preflight would fail with `git_dirty`, causing a
  /// deadlock.  The stash entry itself remains in the stash list for forensic
  /// access (stash pop only removes the entry on success).
  void _recoverFromFailedStashPop(
    String projectRoot, {
    required String stepId,
    required String stashMessage,
    required String popError,
  }) {
    final recoverLayout = ProjectLayout(projectRoot);
    var recoveryMethod = 'none';
    String? forensicRef;
    try {
      // Preserve conflicting worktree state as a forensic stash before cleanup.
      final forensicMessage =
          'genaisys:forensic:${DateTime.now().toUtc().microsecondsSinceEpoch}';
      try {
        final forensicStashed = _gitService.stashPush(
          projectRoot,
          message: forensicMessage,
          includeUntracked: true,
        );
        if (forensicStashed) {
          forensicRef = forensicMessage;
          _appendRunLog(
            recoverLayout,
            event: 'git_forensic_stash_created',
            message:
                'Created forensic stash from failed stash pop worktree state',
            data: {
              'step_id': stepId,
              'stash_message': stashMessage,
              'forensic_ref': forensicMessage,
              'pop_error': popError,
              'error_class': 'delivery',
              'error_kind': 'git_forensic_stash_created',
            },
          );
        }
      } catch (_) {
        // Best-effort: forensic stash is optional; proceed with cleanup.
      }

      // If the worktree is still dirty after the forensic stash (e.g. index
      // conflicts), discard remaining changes.
      if (!_gitService.isClean(projectRoot)) {
        _gitService.discardWorkingChanges(projectRoot);
        recoveryMethod = 'discard_working_changes';
      }

      if (!_gitService.isClean(projectRoot)) {
        // Last resort: hard reset to HEAD.
        _gitService.hardReset(projectRoot);
        recoveryMethod = 'reset_hard';
      }

      final clean = _gitService.isClean(projectRoot);
      _appendRunLog(
        recoverLayout,
        event: 'git_auto_stash_restore_recovery',
        message: clean
            ? 'Recovered worktree after failed stash pop'
            : 'Worktree still dirty after stash pop recovery attempts',
        data: {
          'step_id': stepId,
          'stash_message': stashMessage,
          'pop_error': popError,
          'recovery_method': recoveryMethod,
          'clean_after_recovery': clean,
          'forensic_ref': ?forensicRef,
          'error_class': 'delivery',
          'error_kind': clean
              ? 'git_auto_stash_restore_recovery'
              : 'git_auto_stash_restore_recovery_incomplete',
        },
      );
    } catch (recoveryError) {
      _appendRunLog(
        recoverLayout,
        event: 'git_auto_stash_restore_recovery_failed',
        message: 'Failed to recover worktree after failed stash pop',
        data: {
          'step_id': stepId,
          'stash_message': stashMessage,
          'pop_error': popError,
          'recovery_method': recoveryMethod,
          'forensic_ref': ?forensicRef,
          'recovery_error': recoveryError.toString(),
          'error_class': 'delivery',
          'error_kind': 'git_auto_stash_restore_recovery_failed',
        },
      );
    }
  }

  void _ensureInitialized(ProjectLayout layout) {
    if (!Directory(layout.genaisysDir).existsSync()) {
      throw StateError(
        'No .genaisys directory found at: ${layout.genaisysDir}',
      );
    }
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
  }

  /// Ensures that runtime artifacts inside `.genaisys/` are not tracked by
  /// git.  State repair creates `.genaisys/.gitignore` (via ensureStructure),
  /// but files that were committed *before* the gitignore existed remain in
  /// the index.  This method runs `git rm --cached` for those paths so they
  /// become invisible to git.  After this, heartbeat writes to
  /// `autopilot.lock` and orchestrator updates to `STATE.json` /
  /// `RUN_LOG.jsonl` no longer dirty the worktree and no longer block
  /// branch checkouts.
  ///
  /// This is a one-time migration: on subsequent steps the files are already
  /// untracked and the method becomes a no-op.
  void _enforceRuntimeGitignore(String projectRoot) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) return;
      final layout = ProjectLayout(projectRoot);
      if (!File(layout.gitignorePath).existsSync()) return;

      _gitService.removeFromIndexIfTracked(projectRoot, [
        '.genaisys/RUN_LOG.jsonl',
        '.genaisys/STATE.json',
        '.genaisys/attempts',
        '.genaisys/logs',
        '.genaisys/task_specs',
        '.genaisys/workspaces',
        '.genaisys/locks',
        '.genaisys/audit',
        '.genaisys/evals',
      ]);

      if (!_gitService.hasChanges(projectRoot)) return;
      _gitService.addAll(projectRoot);
      _gitService.commit(
        projectRoot,
        'meta(state): enforce runtime artifact gitignore',
      );
    } catch (_) {
      // Best-effort: runtime gitignore enforcement must not block the step.
    }
  }

  /// Commits any residual dirty state from a previous step to maintain the
  /// clean-end invariant.  After task approval, `deactivate()`, audit trail
  /// recording, and run-log updates dirty the worktree.  This commit ensures
  /// the current step can checkout a new branch cleanly.
  ///
  /// Fully guarded: failures are silently ignored because this is best-effort
  /// cleanup and must never prevent the step from proceeding.  No stash
  /// fallback — existing stash-based cleanup in the step's error handler
  /// already covers failures.
  void _persistPostStepCleanup(String projectRoot) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) return;
      if (!_gitService.hasChanges(projectRoot)) return;
      _gitService.addAll(projectRoot);
      _gitService.commit(projectRoot, 'meta(state): finalize step cleanup');
    } catch (e) {
      // Best-effort commit failed — log the failure for diagnostics so
      // dirty-worktree checkout failures can be traced back to the root cause.
      try {
        final layout = ProjectLayout(projectRoot);
        RunLogStore(layout.runLogPath).append(
          event: 'persist_step_cleanup_failed',
          message: 'Best-effort meta commit failed before branch switch',
          data: {
            'root': projectRoot,
            'error': e.toString(),
            'error_class': 'git',
            'error_kind': 'meta_commit_failed',
          },
        );
      } catch (_) {
        // Last-resort: ignore logging failure.
      }
    }
  }

  void _appendRunLog(
    ProjectLayout layout, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    RunLogStore(layout.runLogPath).append(
      event: event,
      message: message,
      data: {
        ...data,
        'workflow_stage': StateStore(
          layout.statePath,
        ).read().workflowStage.name,
      },
    );
  }
}

class _GitAutoStashResult {
  _GitAutoStashResult({
    required this.stepId,
    required this.restores,
    required this.message,
  });

  factory _GitAutoStashResult.none({required String stepId}) {
    return _GitAutoStashResult(stepId: stepId, restores: false, message: '');
  }

  final String stepId;
  final bool restores;
  final String message;
}
