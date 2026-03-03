// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhasePreflight on OrchestratorRunService {
  /// Preflight check, escalation, repair, backoff.
  Future<RunLoopTransition> _handlePreflight(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;

    AutopilotPreflightResult preflight;
    try {
      preflight = _preflightService.check(
        projectRoot,
        requirePushReadiness: params.overnightUnattended,
      );
    } catch (preflightError) {
      preflight = AutopilotPreflightResult(
        ok: false,
        reason: 'preflight_crash',
        message: 'Preflight check crashed: $preflightError',
        errorClass: 'preflight',
        errorKind: 'preflight_crash',
      );
      _appendRunLog(
        projectRoot,
        event: 'preflight_crash',
        message: 'Preflight check threw an exception',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'error': preflightError.toString(),
          'error_class': 'preflight',
          'error_kind': 'preflight_crash',
        },
      );
    }
    if (!preflight.ok) {
      ctx.consecutivePreflightFailures += 1;
      ctx.idleSteps += 1;
      final preflightReason = FailureReasonMapper.normalize(
        errorClass: preflight.errorClass,
        errorKind: preflight.errorKind,
        message: preflight.message,
        event: 'preflight_failed',
      );
      final preflightBackoff = _preflightBackoff(
        failures: ctx.consecutivePreflightFailures,
        idleSleep: params.idleSleep,
      );
      _appendRunLog(
        projectRoot,
        event: 'preflight_failed',
        message: 'Autopilot preflight blocked step execution',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'idle': true,
          'blocked': true,
          'reason': preflight.reason,
          'error_class': preflightReason.errorClass,
          'error_kind': preflightReason.errorKind,
          'error': preflight.message,
          'backoff_seconds': preflightBackoff.inSeconds,
        },
      );
      _recordLoopStepPaused(
        projectRoot,
        preflight.message,
        errorClass: preflight.errorClass,
        errorKind: preflight.errorKind,
        event: 'preflight_failed',
      );
      {
        final haltTransition = _trackedHeartbeat(ctx, lockHandle);
        if (haltTransition != null) return haltTransition;
      }

      // Preflight escalation: state repair -> safety halt.
      if (ctx.consecutivePreflightFailures >=
          params.config.autopilotPreflightRepairThreshold) {
        if (ctx.preflightRepairAttempts >=
            params.config.autopilotMaxPreflightRepairAttempts) {
          ctx.stoppedBySafetyHalt = true;
          _appendRunLog(
            projectRoot,
            event: 'orchestrator_run_safety_halt',
            message:
                'Autopilot halted: Max preflight repair attempts exhausted',
            data: {
              'step_id': ctx.stepId,
              'error_class': 'preflight',
              'error_kind': 'max_preflight_failures',
              'consecutive_preflight_failures':
                  ctx.consecutivePreflightFailures,
              'preflight_repair_attempts': ctx.preflightRepairAttempts,
              'last_preflight_error_kind': preflight.errorKind,
            },
          );
          _trackedHeartbeat(ctx, lockHandle);
          return const RunLoopTransition.terminate(
              reason: 'max_preflight_failures');
        }
        ctx.preflightRepairAttempts += 1;
        ctx.consecutivePreflightFailures = 0;
        _stateRepairService.repair(projectRoot);
        _appendRunLog(
          projectRoot,
          event: 'preflight_repair_triggered',
          message:
              'State repair triggered after repeated preflight failures',
          data: {
            'step_id': ctx.stepId,
            'step_index': ctx.totalSteps,
            'preflight_repair_attempt': ctx.preflightRepairAttempts,
            'last_preflight_error_kind': preflight.errorKind,
          },
        );
        {
          final haltTransition = _trackedHeartbeat(ctx, lockHandle);
          if (haltTransition != null) return haltTransition;
        }
      }

      if (params.stopWhenIdle) {
        ctx.stoppedWhenIdle = true;
        return const RunLoopTransition.terminate(reason: 'stop_when_idle');
      }
      if (preflightBackoff.inMicroseconds > 0) {
        ctx.forcedSleep = preflightBackoff;
      }
      return const RunLoopTransition.next(RunLoopPhase.sleepAndLoop,
          reason: 'preflight_failed');
    }
    ctx.consecutivePreflightFailures = 0;
    return const RunLoopTransition.next(RunLoopPhase.stepExecution);
  }
}
