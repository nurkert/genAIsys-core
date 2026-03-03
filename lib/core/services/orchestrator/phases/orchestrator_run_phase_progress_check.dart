// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseProgressCheck on OrchestratorRunService {
  /// No-progress detection, self-restart trigger, cooldown-waiting benign idle.
  Future<RunLoopTransition> _handleProgressCheck(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;

    // Cooldown-waiting idle steps are benign.
    final isCooldownWait =
        ctx.stepWasIdle && ctx.cooldownNextEligibleAt != null;
    if (isCooldownWait) {
      final waitDuration =
          ctx.cooldownNextEligibleAt!.difference(DateTime.now().toUtc());
      if (waitDuration.inMicroseconds > 0) {
        final cappedWait =
            waitDuration > params.idleSleep ? params.idleSleep : waitDuration;
        ctx.forcedSleep = cappedWait;
      }
    }

    if (ctx.stepHadProgress ||
        isCooldownWait ||
        _isBenignIdleStep(
          stepWasIdle: ctx.stepWasIdle,
          consecutiveFailures: ctx.consecutiveFailures,
        )) {
      ctx.consecutiveSelfHealAttempts = 0;
      ctx.noProgressSteps = 0;
    } else {
      ctx.noProgressSteps += 1;
    }

    if (params.noProgressThreshold > 0 &&
        ctx.noProgressSteps >= params.noProgressThreshold) {
      final stepContext = _readStepContext(projectRoot);
      final stuckReason = FailureReasonMapper.normalize(
        errorClass: 'pipeline',
        errorKind: 'stuck',
        event: 'orchestrator_run_stuck',
      );
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_stuck',
        message: 'Autopilot detected no progress',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'no_progress_steps': ctx.noProgressSteps,
          'no_progress_threshold': params.noProgressThreshold,
          'self_restart_enabled': params.selfRestart,
          'self_restart_count': ctx.selfRestartCount,
          'error_class': stuckReason.errorClass,
          'error_kind': stuckReason.errorKind,
          if (stepContext.taskId != null) 'task_id': stepContext.taskId,
          if (stepContext.subtaskId != null)
            'subtask_id': stepContext.subtaskId,
        },
      );
      if (params.selfRestart) {
        if (ctx.selfRestartCount >= params.maxSelfRestarts) {
          // HITL Gate 3: before_halt (max_self_restarts)
          final gate3a = await _runHitlGate(
            ctx, lockHandle,
            event: HitlGateEvent.beforeHalt,
            gateFlag: params.config.hitlGateBeforeHalt,
          );
          if (gate3a != null) return gate3a;
          ctx.stoppedBySafetyHalt = true;
          _appendRunLog(
            projectRoot,
            event: 'orchestrator_run_safety_halt',
            message: 'Autopilot halted: Max self restarts exceeded',
            data: {
              'step_id': ctx.stepId,
              'error_class': 'pipeline',
              'error_kind': 'max_self_restarts',
              'self_restart_count': ctx.selfRestartCount,
              'max_self_restarts': params.maxSelfRestarts,
              if (stepContext.taskId != null) 'task_id': stepContext.taskId,
              if (stepContext.subtaskId != null)
                'subtask_id': stepContext.subtaskId,
            },
          );
          _trackedHeartbeat(ctx, lockHandle);
          return const RunLoopTransition.terminate(
              reason: 'max_self_restarts');
        }
        ctx.selfRestartCount += 1;
        ctx.noProgressSteps = 0;
        ctx.consecutiveFailures = 0;
        _stateRepairService.repair(projectRoot);
        _appendRunLog(
          projectRoot,
          event: 'orchestrator_run_self_restart',
          message: 'Autopilot self restart triggered',
          data: {
            'step_id': ctx.stepId,
            'step_index': ctx.totalSteps,
            'restart_count': ctx.selfRestartCount,
            'max_self_restarts': params.maxSelfRestarts,
            'cooldown_seconds': params.stuckCooldown.inSeconds,
          },
        );
        {
          final haltTransition = _trackedHeartbeat(ctx, lockHandle);
          if (haltTransition != null) return haltTransition;
        }
        if (params.stuckCooldown.inMicroseconds > 0) {
          await _sleep(params.stuckCooldown);
        }
        return const RunLoopTransition.next(
          RunLoopPhase.gateCheck,
          reason: 'self_restart',
        );
      }

      // HITL Gate 3: before_halt (no_progress_threshold)
      final gate3b = await _runHitlGate(
        ctx, lockHandle,
        event: HitlGateEvent.beforeHalt,
        gateFlag: params.config.hitlGateBeforeHalt,
      );
      if (gate3b != null) return gate3b;
      ctx.stoppedBySafetyHalt = true;
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_safety_halt',
        message: 'Autopilot halted: No progress threshold reached',
        data: {
          'step_id': ctx.stepId,
          'no_progress_steps': ctx.noProgressSteps,
          'no_progress_threshold': params.noProgressThreshold,
          'error_class': stuckReason.errorClass,
          'error_kind': stuckReason.errorKind,
          if (stepContext.taskId != null) 'task_id': stepContext.taskId,
          if (stepContext.subtaskId != null)
            'subtask_id': stepContext.subtaskId,
        },
      );
      _trackedHeartbeat(ctx, lockHandle);
      return const RunLoopTransition.terminate(
          reason: 'no_progress_threshold');
    }

    return const RunLoopTransition.next(RunLoopPhase.sleepAndLoop);
  }
}
