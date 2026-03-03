// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseStepOutcome on OrchestratorRunService {
  /// Evaluate step result: idle detection, self-heal, failure counting,
  /// budget checks, release tag, code health, reflection.
  Future<RunLoopTransition> _handleStepOutcome(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    final stepResult = ctx.lastStepResult!;
    final stepStopwatch = Stopwatch(); // Already stopped by caller context.

    ctx.stepWasIdle = !stepResult.executedCycle &&
        stepResult.plannedTasksAdded == 0 &&
        !stepResult.didArchitecturePlanning &&
        stepResult.visionFulfilled == null;
    ctx.stepHadProgress = _didProgress(stepResult);
    ctx.cooldownNextEligibleAt = stepResult.nextEligibleAt;
    if (ctx.stepWasIdle) {
      ctx.idleSteps += 1;
    }
    final stepIssueKind = _stepIssueKind(stepResult);

    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_step',
      message: ctx.stepWasIdle
          ? 'Autopilot run step completed (idle)'
          : 'Autopilot run step completed',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'executed_cycle': stepResult.executedCycle,
        'planned_tasks_added': stepResult.plannedTasksAdded,
        'review_decision': stepResult.reviewDecision ?? '',
        'decision': stepResult.reviewDecision ?? '',
        'retry_count': stepResult.retryCount,
        'task_blocked': stepResult.blockedTask,
        'progress_failure': stepIssueKind != null,
        'error_kind': stepIssueKind,
        'idle': ctx.stepWasIdle,
        'step_duration_ms': stepStopwatch.elapsedMilliseconds,
        if (stepResult.activeTaskId != null &&
            stepResult.activeTaskId!.isNotEmpty)
          'task_id': stepResult.activeTaskId,
        if (stepResult.currentSubtask != null &&
            stepResult.currentSubtask!.isNotEmpty)
          'subtask_id': stepResult.currentSubtask,
      },
    );

    if (stepResult.autoMarkedDone) {
      ctx.approvalCount += 1;

      // HITL Gate 1: after_task_done
      final gate1 = await _runHitlGate(
        ctx, lockHandle,
        event: HitlGateEvent.afterTaskDone,
        gateFlag: params.config.hitlGateAfterTaskDone,
        taskId: stepResult.activeTaskId,
        taskTitle: stepResult.activeTaskTitle,
      );
      if (gate1 != null) return gate1;

      await _releaseTagService.maybeCreateReleaseTag(
        projectRoot,
        config: params.config,
        stepResult: stepResult,
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
      );
    }
    final approvedDiff = stepResult.approvedDiffStats;
    if (approvedDiff != null) {
      ctx.scopeFiles += approvedDiff.filesChanged;
      ctx.scopeAdditions += approvedDiff.additions;
      ctx.scopeDeletions += approvedDiff.deletions;
    }

    // Code health evaluation on delivery.
    if (stepResult.autoMarkedDone && params.config.codeHealthEnabled) {
      try {
        final touchedFiles = stepResult.approvedDiffStats?.changedFiles ?? [];
        await _codeHealthService.evaluateDelivery(
          projectRoot,
          touchedFiles: touchedFiles,
          taskId: stepResult.activeTaskId,
          taskTitle: stepResult.activeTaskTitle,
          config: params.config,
        );
      } catch (e) {
        _appendRunLog(
          projectRoot,
          event: 'code_health_evaluation_failed',
          message: 'Code health evaluation failed: $e',
          data: {'step_id': ctx.stepId, 'error_class': 'code_health'},
        );
        // Quality gate was bypassed — do not count as positive progress.
        ctx.stepHadProgress = false;
      }
    }

    // Productivity reflection check.
    if (params.config.reflectionEnabled) {
      final trigger = ReflectionTrigger(
        mode: params.config.reflectionTriggerMode,
        threshold: _reflectionThreshold(params.config),
      );
      if (_reflectionService.shouldTrigger(
        projectRoot,
        completedLoops: ctx.totalSteps,
        completedTasks: ctx.approvalCount,
        elapsed: DateTime.now().toUtc().difference(ctx.runStart),
        trigger: trigger,
      )) {
        try {
          final reflectionResult = _reflectionService.reflect(
            projectRoot,
            maxOptimizationTasks:
                params.config.reflectionMaxOptimizationTasks,
            optimizationPriority:
                params.config.reflectionOptimizationPriority,
          );
          _updateReflectionState(projectRoot, reflectionResult);
        } catch (e) {
          _appendRunLog(
            projectRoot,
            event: 'reflection_failed',
            message: 'Productivity reflection failed: $e',
            data: {
              'step_id': ctx.stepId,
              'step_index': ctx.totalSteps,
            },
          );
        }
      }
    }

    // Self-heal for step issue.
    if (stepIssueKind != null &&
        (params.maxSteps == null || ctx.totalSteps < params.maxSteps!) &&
        _selfHealService.canAttemptSelfHeal(
          enabled: params.selfHealEnabled,
          attemptsUsed: ctx.consecutiveSelfHealAttempts,
          maxAttempts: params.selfHealMaxAttempts,
          errorKind: stepIssueKind,
          unattendedMode: params.overnightUnattended,
        )) {
      ctx.consecutiveSelfHealAttempts += 1;
      ctx.totalSelfHealAttempts += 1;
      final recovered = await _selfHealService.attemptSelfHealFallback(
        projectRoot,
        codingPrompt: params.codingPrompt,
        testSummary: params.testSummary,
        overwriteArtifacts: params.overwriteArtifacts,
        minOpenTasks: params.minOpen,
        maxPlanAdd: params.maxPlanAdd,
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
        errorKind: stepIssueKind,
        errorMessage: _stepIssueMessage(stepResult),
        attempt: ctx.totalSelfHealAttempts,
        maxAttempts: params.selfHealMaxAttempts,
        maxTaskRetries: params.maxTaskRetries,
      );
      if (recovered) {
        ctx.consecutiveSelfHealAttempts = 0;
        ctx.consecutiveFailures = 0;
        ctx.successfulSteps += 1;
        _recordLoopStepSuccess(projectRoot);
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.next(
          RunLoopPhase.gateCheck,
          reason: 'self_heal_recovered',
        );
      }
    }

    if (stepIssueKind != null) {
      ctx.failedSteps += 1;
      ctx.consecutiveFailures += 1;
      ctx.stepHadProgress = false;
      final stepIssueMessage = _stepIssueMessage(stepResult);
      final progressFailureReason = FailureReasonMapper.normalize(
        errorKind: stepIssueKind,
        message: stepIssueMessage,
        event: 'orchestrator_run_progress_failure',
      );
      final cooldown = _progressFailureCooldown(
        failedCooldown: params.failedCooldown,
        fallbackSleep: params.stepSleep,
      );
      if (cooldown.inMicroseconds > 0) {
        ctx.forcedSleep = cooldown;
      }
      final releasedForCooldown = _releaseFailedActiveTaskForCooldown(
        projectRoot,
        stepResult: stepResult,
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
        stepIssueKind: stepIssueKind,
        unattendedMode: params.overnightUnattended,
        reactivateFailed: params.config.autopilotReactivateFailed,
      );
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_progress_failure',
        message: 'Autopilot step ended without progress',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'error_class': progressFailureReason.errorClass,
          'error_kind': progressFailureReason.errorKind,
          'error': stepIssueMessage,
          'consecutive_failures': ctx.consecutiveFailures,
          'failed_cooldown_seconds': params.failedCooldown.inSeconds,
          'cooldown_seconds': cooldown.inSeconds,
          'reactivate_failed': params.config.autopilotReactivateFailed,
          'released_failed_task': releasedForCooldown,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
          if (stepResult.currentSubtask != null &&
              stepResult.currentSubtask!.isNotEmpty)
            'subtask_id': stepResult.currentSubtask,
        },
      );
      _recordLoopStepFailure(
        projectRoot,
        stepIssueMessage,
        errorKind: stepIssueKind,
        event: 'orchestrator_run_progress_failure',
      );

      if (ctx.consecutiveFailures >= params.maxFailures) {
        ctx.stoppedBySafetyHalt = true;
        _appendRunLog(
          projectRoot,
          event: 'orchestrator_run_safety_halt',
          message: 'Autopilot halted: Max consecutive failures exceeded',
          data: {
            'step_id': ctx.stepId,
            'max_consecutive_failures': params.maxFailures,
            'consecutive_failures': ctx.consecutiveFailures,
            'last_error': stepIssueMessage,
            'error_class': progressFailureReason.errorClass,
            'error_kind': progressFailureReason.errorKind,
            if (stepResult.activeTaskId != null &&
                stepResult.activeTaskId!.isNotEmpty)
              'task_id': stepResult.activeTaskId,
            if (stepResult.currentSubtask != null &&
                stepResult.currentSubtask!.isNotEmpty)
              'subtask_id': stepResult.currentSubtask,
          },
        );
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.terminate(
            reason: 'max_consecutive_failures');
      }
    } else {
      ctx.successfulSteps += 1;
      ctx.consecutiveFailures = 0;
      _recordLoopStepSuccess(projectRoot);
    }

    // Safety budget checks.
    if (!params.overrideSafety) {
      if (_approveBudgetExceeded(ctx.approvalCount, params.approveBudget)) {
        ctx.stoppedBySafetyHalt = true;
        _appendRunLog(
          projectRoot,
          event: 'orchestrator_run_safety_halt',
          message: 'Autopilot halted: Approve budget exceeded',
          data: {
            'error_class': 'pipeline',
            'step_id': ctx.stepId,
            'approve_budget': params.approveBudget,
            'approve_count': ctx.approvalCount,
            'error_kind': 'approve_budget',
            if (stepResult.activeTaskId != null &&
                stepResult.activeTaskId!.isNotEmpty)
              'task_id': stepResult.activeTaskId,
            if (stepResult.currentSubtask != null &&
                stepResult.currentSubtask!.isNotEmpty)
              'subtask_id': stepResult.currentSubtask,
          },
        );
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.terminate(reason: 'approve_budget');
      }

      if (_scopeBudgetExceeded(
        filesChanged: ctx.scopeFiles,
        additions: ctx.scopeAdditions,
        deletions: ctx.scopeDeletions,
        maxFiles: params.scopeMaxFiles,
        maxAdditions: params.scopeMaxAdditions,
        maxDeletions: params.scopeMaxDeletions,
      )) {
        ctx.stoppedBySafetyHalt = true;
        _appendRunLog(
          projectRoot,
          event: 'orchestrator_run_safety_halt',
          message: 'Autopilot halted: Scope budget exceeded',
          data: {
            'error_class': 'pipeline',
            'step_id': ctx.stepId,
            'scope_max_files': params.scopeMaxFiles,
            'scope_max_additions': params.scopeMaxAdditions,
            'scope_max_deletions': params.scopeMaxDeletions,
            'scope_files': ctx.scopeFiles,
            'scope_additions': ctx.scopeAdditions,
            'scope_deletions': ctx.scopeDeletions,
            'error_kind': 'scope_budget',
            if (stepResult.activeTaskId != null &&
                stepResult.activeTaskId!.isNotEmpty)
              'task_id': stepResult.activeTaskId,
            if (stepResult.currentSubtask != null &&
                stepResult.currentSubtask!.isNotEmpty)
              'subtask_id': stepResult.currentSubtask,
          },
        );
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.terminate(reason: 'scope_budget');
      }
    }

    if (stepResult.retryCount >= params.maxTaskRetries &&
        !stepResult.blockedTask &&
        !stepResult.deactivatedTask) {
      ctx.stoppedBySafetyHalt = true;
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_safety_halt',
        message: 'Autopilot halted: Max task retries exceeded',
        data: {
          'error_class': 'pipeline',
          'error_kind': 'max_task_retries',
          'step_id': ctx.stepId,
          'max_task_retries': params.maxTaskRetries,
          'retry_count': stepResult.retryCount,
          'task_title': stepResult.activeTaskTitle,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
          if (stepResult.currentSubtask != null &&
              stepResult.currentSubtask!.isNotEmpty)
            'subtask_id': stepResult.currentSubtask,
        },
      );
      _trackedHeartbeat(ctx, lockHandle);
      return const RunLoopTransition.terminate(reason: 'max_task_retries');
    }

    if (ctx.stepWasIdle &&
        params.config.autopilotSprintPlanningEnabled) {
      // HITL Gate 2: before_sprint
      final gate2 = await _runHitlGate(
        ctx, lockHandle,
        event: HitlGateEvent.beforeSprint,
        gateFlag: params.config.hitlGateBeforeSprint,
      );
      if (gate2 != null) return gate2;

      final sprintResult = await _sprintPlannerService.maybeStartNextSprint(
        projectRoot,
        config: params.config,
        stepId: ctx.stepId,
      );
      if (sprintResult.sprintStarted) {
        // New tasks were added — no longer idle.
        ctx.stepWasIdle = false;
      } else if (sprintResult.visionFulfilled) {
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.terminate(reason: 'vision_fulfilled');
      } else if (sprintResult.maxSprintsReached) {
        _trackedHeartbeat(ctx, lockHandle);
        return const RunLoopTransition.terminate(reason: 'max_sprints_reached');
      }
    }

    if (params.stopWhenIdle && ctx.stepWasIdle) {
      ctx.stoppedWhenIdle = true;
      _trackedHeartbeat(ctx, lockHandle);
      return const RunLoopTransition.terminate(reason: 'stop_when_idle');
    }

    return const RunLoopTransition.next(RunLoopPhase.progressCheck);
  }
}
