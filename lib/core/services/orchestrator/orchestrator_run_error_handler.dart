// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_run_service.dart';

extension _OrchestratorRunErrorHandler on OrchestratorRunService {
  /// Attempts a self-heal fallback for the given error kind and message.
  ///
  /// Returns `true` if recovery succeeded and the caller should transition to
  /// [RunLoopPhase.gateCheck]. Returns `false` if self-heal was not attempted
  /// or did not recover, so the caller should continue with its normal
  /// failure path.
  Future<bool> _trySelfHeal(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle, {
    required String errorKind,
    required String errorMessage,
  }) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    if (params.maxSteps != null && ctx.totalSteps >= params.maxSteps!) {
      return false;
    }
    if (!_selfHealService.canAttemptSelfHeal(
      enabled: params.selfHealEnabled,
      attemptsUsed: ctx.consecutiveSelfHealAttempts,
      maxAttempts: params.selfHealMaxAttempts,
      errorKind: errorKind,
      unattendedMode: params.overnightUnattended,
    )) {
      return false;
    }
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
      errorKind: errorKind,
      errorMessage: errorMessage,
      attempt: ctx.totalSelfHealAttempts,
      maxAttempts: params.selfHealMaxAttempts,
      maxTaskRetries: params.maxTaskRetries,
    );
    if (recovered) {
      ctx.consecutiveSelfHealAttempts = 0;
      ctx.consecutiveFailures = 0;
      _recordLoopStepSuccess(projectRoot);
      lockHandle.heartbeat();
    }
    return recovered;
  }

  /// Unified error handler for all 5 error types caught during step execution.
  ///
  /// Returns a [RunLoopTransition] indicating whether the loop should continue
  /// to progressCheck/sleepAndLoop or terminate.
  Future<RunLoopTransition> _handleStepError(
    RunLoopContext ctx,
    Object error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.stepWasIdle = true;
    ctx.stepHadProgress = false;

    if (error is QuotaPauseError) {
      return _handleQuotaPauseError(ctx, error, lockHandle);
    } else if (error is TransientError) {
      return _handleTransientError(ctx, error, lockHandle);
    } else if (error is PermanentError) {
      return _handlePermanentError(ctx, error, lockHandle);
    } else if (error is PolicyViolationError) {
      return _handlePolicyViolationError(ctx, error, lockHandle);
    } else if (error is StateError) {
      return _handleStateError(ctx, error, lockHandle);
    }
    // Unknown error type — treat as state error for safety.
    ctx.failedSteps += 1;
    ctx.consecutiveFailures += 1;
    _recordLoopStepFailure(
      projectRoot,
      error.toString(),
      errorClass: 'state',
      errorKind: 'unknown',
      event: 'orchestrator_run_error',
    );
    if (ctx.consecutiveFailures >= params.maxFailures) {
      ctx.stoppedBySafetyHalt = true;
      return const RunLoopTransition.terminate(reason: 'unknown_error_halt');
    }
    return const RunLoopTransition.next(RunLoopPhase.progressCheck);
  }

  Future<RunLoopTransition> _handleQuotaPauseError(
    RunLoopContext ctx,
    QuotaPauseError error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.idleSteps += 1;
    final stepContext = _readStepContext(projectRoot);
    var pauseFor = error.pauseFor;
    if (pauseFor.isNegative || pauseFor == Duration.zero) {
      pauseFor = params.idleSleep;
    }
    if (pauseFor.isNegative) {
      pauseFor = Duration.zero;
    }
    final desiredPause = pauseFor;
    if (pauseFor.inMicroseconds > 0) {
      ctx.forcedSleep = pauseFor;
    }
    final quotaReason = FailureReasonMapper.normalize(
      errorClass: 'provider',
      errorKind: 'provider_quota',
      message: error.message,
      event: 'orchestrator_run_provider_pause',
    );
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_provider_pause',
      message: 'Autopilot paused due to provider quota exhaustion',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'error': error.message,
        'error_class': quotaReason.errorClass,
        'error_kind': quotaReason.errorKind,
        'desired_pause_seconds': desiredPause.inSeconds,
        'pause_seconds': pauseFor.inSeconds,
        'resume_at': error.resumeAt?.toUtc().toIso8601String(),
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    _recordLoopStepPaused(
      projectRoot,
      error.message,
      errorClass: 'provider',
      errorKind: 'provider_quota',
      event: 'orchestrator_run_provider_pause',
    );
    // QuotaPauseError is known-temporary — do NOT halt for stop-when-idle.
    return const RunLoopTransition.next(RunLoopPhase.progressCheck);
  }

  Future<RunLoopTransition> _handleTransientError(
    RunLoopContext ctx,
    TransientError error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.failedSteps += 1;
    ctx.consecutiveFailures += 1;
    final errorKind = _classifyErrorKind(error.message);
    final transientReason = FailureReasonMapper.normalize(
      errorClass: 'pipeline',
      errorKind: errorKind,
      message: error.message,
      event: 'orchestrator_run_transient_error',
    );
    final backoff = _errorBackoff(
      failures: ctx.consecutiveFailures,
      baseSleep: params.stepSleep,
      errorKind: transientReason.errorKind,
      idleSleep: params.idleSleep,
    );
    if (backoff.inMicroseconds > 0) {
      ctx.forcedSleep = backoff;
    }
    final stepContext = _readStepContext(projectRoot);
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_transient_error',
      message: 'Autopilot run step failed (transient)',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'error': error.message,
        'error_class': transientReason.errorClass,
        'error_kind': transientReason.errorKind,
        'consecutive_failures': ctx.consecutiveFailures,
        'backoff_seconds': backoff.inSeconds,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    _recordLoopStepFailure(
      projectRoot,
      error.message,
      errorClass: transientReason.errorClass,
      errorKind: transientReason.errorKind,
      event: 'orchestrator_run_transient_error',
    );

    // Unattended timeout → treat as progress failure.
    final unattendedTimeoutFailure =
        params.overnightUnattended && transientReason.errorKind == 'timeout';
    if (unattendedTimeoutFailure) {
      final timeoutCooldown = _progressFailureCooldown(
        failedCooldown: params.failedCooldown,
        fallbackSleep: params.stepSleep,
      );
      if (timeoutCooldown.inMicroseconds > 0) {
        ctx.forcedSleep = timeoutCooldown;
      }
      final releasedForCooldown = _releaseFailedActiveTaskForCooldown(
        projectRoot,
        stepResult: OrchestratorStepResult(
          executedCycle: true,
          activatedTask: false,
          activeTaskId: stepContext.taskId,
          activeTaskTitle: null,
          plannedTasksAdded: 0,
          reviewDecision: null,
          retryCount: params.maxTaskRetries,
          blockedTask: false,
          deactivatedTask: false,
          currentSubtask: stepContext.subtaskId,
          autoMarkedDone: false,
          approvedDiffStats: null,
        ),
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
        stepIssueKind: transientReason.errorKind,
        unattendedMode: params.overnightUnattended,
        reactivateFailed: params.config.autopilotReactivateFailed,
      );
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_progress_failure',
        message:
            'Autopilot timeout counted as progress failure in unattended mode',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'error_class': transientReason.errorClass,
          'error_kind': transientReason.errorKind,
          'error': error.message,
          'consecutive_failures': ctx.consecutiveFailures,
          'failed_cooldown_seconds': params.failedCooldown.inSeconds,
          'cooldown_seconds': timeoutCooldown.inSeconds,
          'reactivate_failed': params.config.autopilotReactivateFailed,
          'released_failed_task': releasedForCooldown,
          if (stepContext.taskId != null) 'task_id': stepContext.taskId,
          if (stepContext.subtaskId != null)
            'subtask_id': stepContext.subtaskId,
        },
      );
    }

    // Self-heal attempt.
    if (await _trySelfHeal(
      ctx,
      lockHandle,
      errorKind: transientReason.errorKind,
      errorMessage: error.message,
    )) {
      return const RunLoopTransition.next(
        RunLoopPhase.gateCheck,
        reason: 'self_heal_recovered',
      );
    }

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
          'last_error': error.message,
          'error_class': transientReason.errorClass,
          'error_kind': transientReason.errorKind,
          if (stepContext.taskId != null) 'task_id': stepContext.taskId,
          if (stepContext.subtaskId != null)
            'subtask_id': stepContext.subtaskId,
        },
      );
      lockHandle.heartbeat();
      return const RunLoopTransition.terminate(
          reason: 'max_consecutive_failures');
    }
    return const RunLoopTransition.next(RunLoopPhase.progressCheck);
  }

  Future<RunLoopTransition> _handlePermanentError(
    RunLoopContext ctx,
    PermanentError error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.failedSteps += 1;
    ctx.consecutiveFailures += 1;
    final errorKind = _classifyErrorKind(error.message);
    final permanentReason = FailureReasonMapper.normalize(
      errorClass: 'pipeline',
      errorKind: errorKind,
      message: error.message,
      event: 'orchestrator_run_permanent_error',
    );
    final stepContext = _readStepContext(projectRoot);
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_permanent_error',
      message: 'Autopilot run step failed (permanent)',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'error': error.message,
        'error_class': permanentReason.errorClass,
        'error_kind': permanentReason.errorKind,
        'consecutive_failures': ctx.consecutiveFailures,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    _recordLoopStepFailure(
      projectRoot,
      error.message,
      errorClass: permanentReason.errorClass,
      errorKind: permanentReason.errorKind,
      event: 'orchestrator_run_permanent_error',
    );

    // Self-heal attempt.
    if (await _trySelfHeal(
      ctx,
      lockHandle,
      errorKind: permanentReason.errorKind,
      errorMessage: error.message,
    )) {
      return const RunLoopTransition.next(
        RunLoopPhase.gateCheck,
        reason: 'self_heal_recovered',
      );
    }

    // In unattended mode, block the failing task instead of halting.
    if (params.overnightUnattended) {
      final taskBlocked = _tryBlockAndReleaseActiveTask(
        projectRoot,
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
        errorKind: permanentReason.errorKind,
        errorMessage: error.message,
      );
      if (taskBlocked) {
        lockHandle.heartbeat();
        return const RunLoopTransition.next(
          RunLoopPhase.gateCheck,
          reason: 'task_blocked_continue',
        );
      }
    }

    ctx.stoppedBySafetyHalt = true;
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_safety_halt',
      message: 'Autopilot halted: Permanent failure',
      data: {
        'step_id': ctx.stepId,
        'last_error': error.message,
        'error_class': permanentReason.errorClass,
        'error_kind': permanentReason.errorKind,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    lockHandle.heartbeat();
    return const RunLoopTransition.terminate(reason: 'permanent_failure');
  }

  Future<RunLoopTransition> _handlePolicyViolationError(
    RunLoopContext ctx,
    PolicyViolationError error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.failedSteps += 1;
    ctx.consecutiveFailures += 1;
    final errorKind = _classifyErrorKind(error.message);
    final policyReason = FailureReasonMapper.normalize(
      errorClass: 'policy',
      errorKind: errorKind,
      message: error.message,
      event: 'orchestrator_run_policy_violation',
    );
    final stepContext = _readStepContext(projectRoot);
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_policy_violation',
      message: 'Autopilot run step failed (policy violation)',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'error': error.message,
        'error_class': policyReason.errorClass,
        'error_kind': policyReason.errorKind,
        'consecutive_failures': ctx.consecutiveFailures,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    _recordLoopStepFailure(
      projectRoot,
      error.message,
      errorClass: policyReason.errorClass,
      errorKind: policyReason.errorKind,
      event: 'orchestrator_run_policy_violation',
    );

    // Self-heal attempt (parity with TransientError / PermanentError handlers).
    if (await _trySelfHeal(
      ctx,
      lockHandle,
      errorKind: policyReason.errorKind,
      errorMessage: error.message,
    )) {
      return const RunLoopTransition.next(
        RunLoopPhase.gateCheck,
        reason: 'self_heal_recovered_policy_violation',
      );
    }

    // In unattended mode, block the failing task instead of halting.
    if (params.overnightUnattended) {
      final taskBlocked = _tryBlockAndReleaseActiveTask(
        projectRoot,
        stepId: ctx.stepId,
        stepIndex: ctx.totalSteps,
        errorKind: policyReason.errorKind,
        errorMessage: error.message,
      );
      if (taskBlocked) {
        lockHandle.heartbeat();
        return const RunLoopTransition.next(
          RunLoopPhase.gateCheck,
          reason: 'task_blocked_continue',
        );
      }
    }

    ctx.stoppedBySafetyHalt = true;
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_safety_halt',
      message: 'Autopilot halted: Policy violation',
      data: {
        'step_id': ctx.stepId,
        'last_error': error.message,
        'error_class': policyReason.errorClass,
        'error_kind': policyReason.errorKind,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    lockHandle.heartbeat();
    return const RunLoopTransition.terminate(reason: 'policy_violation');
  }

  Future<RunLoopTransition> _handleStateError(
    RunLoopContext ctx,
    StateError error,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;
    ctx.failedSteps += 1;
    ctx.consecutiveFailures += 1;
    final errorKind = _classifyErrorKind(error.message);
    final stateReason = FailureReasonMapper.normalize(
      errorClass: 'state',
      errorKind: errorKind,
      message: error.message,
      event: 'orchestrator_run_error',
    );
    final backoff = _errorBackoff(
      failures: ctx.consecutiveFailures,
      baseSleep: params.idleSleep,
      errorKind: stateReason.errorKind,
      idleSleep: params.idleSleep,
    );
    if (backoff.inMicroseconds > 0) {
      ctx.forcedSleep = backoff;
    }
    final stepContext = _readStepContext(projectRoot);
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_error',
      message: 'Autopilot run step failed',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'error': error.message,
        'error_class': stateReason.errorClass,
        'error_kind': stateReason.errorKind,
        'consecutive_failures': ctx.consecutiveFailures,
        'backoff_seconds': backoff.inSeconds,
        if (stepContext.taskId != null) 'task_id': stepContext.taskId,
        if (stepContext.subtaskId != null) 'subtask_id': stepContext.subtaskId,
      },
    );
    _recordLoopStepFailure(
      projectRoot,
      error.message,
      errorClass: stateReason.errorClass,
      errorKind: stateReason.errorKind,
      event: 'orchestrator_run_error',
    );

    // Self-heal attempt.
    if (await _trySelfHeal(
      ctx,
      lockHandle,
      errorKind: stateReason.errorKind,
      errorMessage: error.message,
    )) {
      return const RunLoopTransition.next(
        RunLoopPhase.gateCheck,
        reason: 'self_heal_recovered',
      );
    }

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
          'last_error': error.message,
          'error_class': stateReason.errorClass,
          'error_kind': stateReason.errorKind,
          if (stepContext.taskId != null) 'task_id': stepContext.taskId,
          if (stepContext.subtaskId != null)
            'subtask_id': stepContext.subtaskId,
        },
      );
      lockHandle.heartbeat();
      return const RunLoopTransition.terminate(
          reason: 'max_consecutive_failures');
    }
    return const RunLoopTransition.next(RunLoopPhase.progressCheck);
  }
}
