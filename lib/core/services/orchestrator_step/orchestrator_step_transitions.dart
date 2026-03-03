// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_step_service.dart';

class _ActivationTransition {
  const _ActivationTransition({
    required this.state,
    required this.activeTitle,
    required this.activeTaskId,
    required this.activatedTask,
    this.earlyResult,
  });

  final ProjectState state;
  final String? activeTitle;
  final String? activeTaskId;
  final bool activatedTask;

  /// Non-null when an early-return result ends the step before task execution.
  final OrchestratorStepResult? earlyResult;
}

class _SubtaskTransition {
  const _SubtaskTransition({
    required this.codingPromptToUse,
    required this.isSubtask,
    required this.subtaskDescription,
    required this.subtaskDependencyAware,
    required this.subtaskCycleFallback,
  });

  final String codingPromptToUse;
  final bool isSubtask;
  final String subtaskDescription;
  final bool subtaskDependencyAware;
  final bool subtaskCycleFallback;
}

extension _OrchestratorStepTransitions on OrchestratorStepService {
  Future<_ActivationTransition> _resolveActivationTransition(
    String projectRoot, {
    required ProjectLayout layout,
    required String stepId,
    required PlannerSyncResult planner,
    required StateStore stateStore,
  }) async {
    var state = stateStore.read();
    var activeTitle = state.activeTaskTitle?.trim();
    var activeTaskId = state.activeTaskId?.trim();
    var activatedTask = false;

    if ((activeTitle == null || activeTitle.isEmpty) &&
        planner.openBefore == 0 &&
        planner.added > 0) {
      _appendRunLog(
        layout,
        event: 'orchestrator_step_planned',
        message: 'Planned new backlog tasks (no active task yet)',
        data: {'planned_added': planner.added, 'step_id': stepId},
      );
      return _ActivationTransition(
        state: state,
        activeTitle: activeTitle,
        activeTaskId: activeTaskId,
        activatedTask: activatedTask,
        earlyResult: OrchestratorStepResult(
          executedCycle: false,
          activatedTask: false,
          activeTaskId: activeTaskId,
          activeTaskTitle: null,
          plannedTasksAdded: planner.added,
          reviewDecision: null,
          retryCount: 0,
          blockedTask: false,
          deactivatedTask: false,
          currentSubtask: null,
          autoMarkedDone: false,
          approvedDiffStats: null,
        ),
      );
    }

    if (activeTitle == null || activeTitle.isEmpty) {
      // Commit any residual dirty state (run-log entries, planner updates)
      // before activation triggers a git checkout. Without this, dirty
      // .genaisys/ files from pre-activation operations block the branch
      // switch, especially when git.auto_stash is disabled.
      _persistPostStepCleanup(projectRoot);
      final activation = _activateService.activate(projectRoot);
      if (!activation.hasTask) {
        // Vision evaluation: when the backlog is empty and no tasks can be
        // activated, evaluate whether the project vision is fulfilled. If gaps
        // remain, the suggested next steps are fed back into the planner so the
        // autopilot can continue working.
        final visionResult = await _maybeRunVisionEvaluation(
          projectRoot,
          layout: layout,
          stepId: stepId,
        );
        if (visionResult != null && !visionResult.visionFulfilled) {
          // Vision has gaps — new tasks may have been planned. Return early so
          // the next step can pick up the newly created tasks.
          return _ActivationTransition(
            state: state,
            activeTitle: activeTitle,
            activeTaskId: activeTaskId,
            activatedTask: activatedTask,
            earlyResult: OrchestratorStepResult(
              executedCycle: false,
              activatedTask: false,
              activeTaskId: activeTaskId,
              activeTaskTitle: null,
              plannedTasksAdded: planner.added,
              reviewDecision: null,
              retryCount: 0,
              blockedTask: false,
              deactivatedTask: false,
              currentSubtask: null,
              autoMarkedDone: false,
              approvedDiffStats: null,
              visionFulfilled: false,
            ),
          );
        }

        // Check if all tasks are temporarily cooling down — if so, report
        // the earliest eligible time so the run loop can sleep rather than
        // counting this as a no-progress step.
        DateTime? nextEligibleAt;
        final cooldowns = state.taskCooldownUntil;
        if (cooldowns.isNotEmpty) {
          DateTime? earliest;
          final now = DateTime.now().toUtc();
          for (final entry in cooldowns.entries) {
            final expiresAt = DateTime.tryParse(entry.value);
            if (expiresAt == null) continue;
            if (expiresAt.isBefore(now)) continue;
            if (earliest == null || expiresAt.isBefore(earliest)) {
              earliest = expiresAt;
            }
          }
          nextEligibleAt = earliest;
        }
        _appendRunLog(
          layout,
          event: 'orchestrator_step_idle',
          message: 'No active task and no open task to activate',
          data: {
            'planned_added': planner.added,
            'step_id': stepId,
            if (activeTaskId != null && activeTaskId.isNotEmpty)
              'task_id': activeTaskId,
            if (visionResult != null)
              'vision_fulfilled': visionResult.visionFulfilled,
            if (nextEligibleAt != null)
              'next_eligible_at': nextEligibleAt.toIso8601String(),
          },
        );
        return _ActivationTransition(
          state: state,
          activeTitle: activeTitle,
          activeTaskId: activeTaskId,
          activatedTask: activatedTask,
          earlyResult: OrchestratorStepResult(
            executedCycle: false,
            activatedTask: false,
            activeTaskId: activeTaskId,
            activeTaskTitle: null,
            plannedTasksAdded: planner.added,
            reviewDecision: null,
            retryCount: 0,
            blockedTask: false,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: false,
            approvedDiffStats: null,
            visionFulfilled: visionResult?.visionFulfilled,
            nextEligibleAt: nextEligibleAt,
          ),
        );
      }
      activatedTask = true;
      activeTitle = activation.task!.title;
      state = stateStore.read();
      activeTaskId = state.activeTaskId?.trim();
    }

    return _ActivationTransition(
      state: state,
      activeTitle: activeTitle,
      activeTaskId: activeTaskId,
      activatedTask: activatedTask,
    );
  }

  _SubtaskTransition _resolveSubtaskTransition(
    String projectRoot, {
    required ProjectLayout layout,
    required String stepId,
    required StateStore stateStore,
    required ProjectState state,
    required String activeTitle,
    required String? activeTaskId,
    required String codingPrompt,
  }) {
    var codingPromptToUse = codingPrompt;
    var isSubtask = false;
    var subtaskDescription = '';
    var subtaskDependencyAware = false;
    var subtaskCycleFallback = false;

    var effectiveState = state;
    final current = effectiveState.currentSubtask?.trim();
    if (current != null &&
        current.isNotEmpty &&
        effectiveState.subtaskQueue.isNotEmpty &&
        _subtaskScheduler.isVerificationSubtask(current)) {
      // If a verification-only gate is sticky as "currentSubtask" while
      // implementation subtasks remain queued, demote it deterministically.
      // This prevents repeated unattended timeouts/no-diff cycles.
      final updatedQueue = [...effectiveState.subtaskQueue, current];
      stateStore.write(
        effectiveState.copyWith(
          subtaskExecution: effectiveState.subtaskExecution.copyWith(
            current: null,
            queue: updatedQueue,
          ),
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      _appendRunLog(
        layout,
        event: 'subtask_scheduler_demote_verification',
        message: 'Demoted verification-only current subtask behind queued work',
        data: {
          'step_id': stepId,
          'task': activeTitle,
          if (activeTaskId != null && activeTaskId.isNotEmpty)
            'task_id': activeTaskId,
          'demoted_subtask': current,
          'queue_length_after': updatedQueue.length,
        },
      );
      effectiveState = stateStore.read();
    }

    if (effectiveState.currentSubtask != null) {
      isSubtask = true;
      subtaskDescription = effectiveState.currentSubtask!;
      codingPromptToUse = 'Implement subtask: $subtaskDescription';
    } else if (effectiveState.subtaskQueue.isNotEmpty) {
      isSubtask = true;
      final selection = _subtaskScheduler.selectNext(
        projectRoot,
        activeTaskTitle: activeTitle,
        activeTaskId: activeTaskId,
        queue: effectiveState.subtaskQueue,
      );
      final next = selection.selectedSubtask;
      final rest = selection.remainingQueue;
      subtaskDependencyAware = selection.dependencyAware;
      subtaskCycleFallback = selection.cycleFallback;
      stateStore.write(
        effectiveState.copyWith(
          subtaskExecution: effectiveState.subtaskExecution.copyWith(
            current: next,
            queue: rest,
          ),
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      subtaskDescription = next;
      codingPromptToUse = 'Implement subtask: $subtaskDescription';
      _appendRunLog(
        layout,
        event: 'subtask_scheduler_selection',
        message: 'Selected next subtask using dependency-aware scheduler',
        data: {
          'step_id': stepId,
          'task': activeTitle,
          if (activeTaskId != null && activeTaskId.isNotEmpty)
            'task_id': activeTaskId,
          'subtask_id': subtaskDescription,
          'dependency_aware': subtaskDependencyAware,
          'cycle_fallback': subtaskCycleFallback,
          'scheduler_total_order': selection.tieBreakerFields,
          'scheduler_selected': selection.selectedCandidate.toJson(),
          'scheduler_candidates': selection.candidates
              .map((candidate) => candidate.toJson())
              .toList(growable: false),
          'remaining_queue': rest.length,
        },
      );
    }

    return _SubtaskTransition(
      codingPromptToUse: codingPromptToUse,
      isSubtask: isSubtask,
      subtaskDescription: subtaskDescription,
      subtaskDependencyAware: subtaskDependencyAware,
      subtaskCycleFallback: subtaskCycleFallback,
    );
  }

  void _handleSubtaskCompletionTransition(
    StateStore stateStore, {
    required bool isSubtask,
    required TaskCycleResult cycleResult,
  }) {
    if (!isSubtask || cycleResult.reviewDecision?.name != 'approve') {
      return;
    }
    final state = stateStore.read();
    stateStore.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          current: null,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Runs architecture planning if ARCHITECTURE.md does not exist and
  /// VISION.md is present. Returns true if architecture was planned
  /// (caller should return early to let the next step pick up tasks).
  Future<bool> _maybeRunArchitecturePlanning(
    String projectRoot, {
    required ProjectLayout layout,
    required String stepId,
  }) async {
    final archFile = File(layout.architecturePath);
    if (archFile.existsSync() && archFile.readAsStringSync().trim().isNotEmpty) {
      return false;
    }
    final visionFile = File(layout.visionPath);
    if (!visionFile.existsSync()) {
      return false;
    }

    _appendRunLog(
      layout,
      event: 'architecture_planning_started',
      message: 'Starting architecture planning phase',
      data: {'step_id': stepId},
    );

    final result = await _architecturePlanningService.planArchitecture(
      projectRoot,
    );
    if (result == null) {
      return false;
    }

    archFile.writeAsStringSync(result.architectureContent);
    _persistPostStepCleanup(projectRoot);

    _appendRunLog(
      layout,
      event: 'architecture_planning_completed',
      message: 'Architecture planning completed — ARCHITECTURE.md written',
      data: {
        'step_id': stepId,
        'modules_count': result.suggestedModules.length,
        'constraints_count': result.suggestedConstraints.length,
        'used_fallback': result.usedFallback,
      },
    );

    return true;
  }

  /// Evaluates whether the project vision is fulfilled. If gaps remain,
  /// creates new tasks from the suggested next steps. Returns the evaluation
  /// result, or null if evaluation was skipped (disabled or no VISION.md).
  Future<VisionEvaluationResult?> _maybeRunVisionEvaluation(
    String projectRoot, {
    required ProjectLayout layout,
    required String stepId,
  }) async {
    final config = ProjectConfig.load(projectRoot);
    if (!config.visionEvaluationEnabled) {
      return null;
    }

    _appendRunLog(
      layout,
      event: 'vision_evaluation_started',
      message: 'Starting vision evaluation',
      data: {'step_id': stepId},
    );

    final result = await _visionEvaluationService.evaluate(projectRoot);
    if (result == null) {
      return null;
    }

    _appendRunLog(
      layout,
      event: result.visionFulfilled
          ? 'vision_complete'
          : 'vision_gap_detected',
      message: result.visionFulfilled
          ? 'Vision evaluation: project is feature-complete'
          : 'Vision evaluation: gaps remain — requesting new tasks',
      data: {
        'step_id': stepId,
        'vision_fulfilled': result.visionFulfilled,
        'completion_estimate': result.completionEstimate,
        'covered_goals': result.coveredGoals.length,
        'uncovered_goals': result.uncoveredGoals.length,
        'suggested_next_steps': result.suggestedNextSteps.length,
        'used_fallback': result.usedFallback,
        'threshold': config.visionCompletionThreshold,
      },
    );

    // If vision has gaps, feed suggested next steps back into the planner.
    if (!result.visionFulfilled && result.suggestedNextSteps.isNotEmpty) {
      final planner = await _plannerService.syncBacklogStrategically(
        projectRoot,
        minOpenTasks: result.suggestedNextSteps.length,
        maxAdd: result.suggestedNextSteps.length,
      );
      _appendRunLog(
        layout,
        event: 'vision_gap_tasks_planned',
        message: 'Planned tasks from vision evaluation gaps',
        data: {
          'step_id': stepId,
          'planned_added': planner.added,
        },
      );
    }

    _persistPostStepCleanup(projectRoot);
    return result;
  }
}
