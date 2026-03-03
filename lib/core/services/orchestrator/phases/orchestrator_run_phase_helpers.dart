// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseHelpers on OrchestratorRunService {
  /// Wraps [lockHandle.heartbeat] with failure tracking and a warning log.
  ///
  /// Increments [ctx.consecutiveLockHeartbeatFailures] on each failed write
  /// and emits `lock_heartbeat_failure_warning` when 3+ failures occur in a row.
  /// Resets the counter on each successful heartbeat.
  ///
  /// When `autopilotLockHeartbeatHaltThreshold > 0` and consecutive failures
  /// reach the threshold, sets [ctx.stoppedBySafetyHalt] = true and returns
  /// a terminate transition; otherwise returns null (no termination needed).
  RunLoopTransition? _trackedHeartbeat(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) {
    bool failed = false;

    void recordFailure(int _) {
      failed = true;
      ctx.consecutiveLockHeartbeatFailures++;
      if (ctx.consecutiveLockHeartbeatFailures >= 3) {
        _appendRunLog(
          ctx.params.projectRoot,
          event: 'lock_heartbeat_failure_warning',
          message:
              'Lock heartbeat write failed ${ctx.consecutiveLockHeartbeatFailures}x consecutively.',
          data: {
            'error_class': 'locking',
            'error_kind': 'heartbeat_failure',
            'count': ctx.consecutiveLockHeartbeatFailures,
            'step_id': ctx.stepId,
          },
        );
      }
    }

    final testHook = heartbeatWriterForTest;
    if (testHook != null) {
      // Test path: use injected writer to simulate heartbeat failures without
      // relying on OS-level file mechanisms (chflags/chmod don't block writes
      // to already-open file descriptors on macOS).
      try {
        testHook();
      } catch (_) {
        recordFailure(1);
      }
    } else {
      lockHandle.heartbeat(onFailure: recordFailure);
    }
    if (!failed) {
      ctx.consecutiveLockHeartbeatFailures = 0;
      return null;
    }
    final haltThreshold =
        ctx.params.config.autopilotLockHeartbeatHaltThreshold;
    if (haltThreshold > 0 &&
        ctx.consecutiveLockHeartbeatFailures >= haltThreshold) {
      _appendRunLog(
        ctx.params.projectRoot,
        event: 'lock_heartbeat_failure_halt',
        message:
            'Autopilot halted: lock heartbeat failed $haltThreshold times consecutively.',
        data: {
          'error_class': 'locking',
          'error_kind': 'heartbeat_failure_halt',
          'count': ctx.consecutiveLockHeartbeatFailures,
          'halt_threshold': haltThreshold,
          'step_id': ctx.stepId,
        },
      );
      ctx.stoppedBySafetyHalt = true;
      return const RunLoopTransition.terminate(
        reason: 'heartbeat_failure_halt',
      );
    }
    return null;
  }

  /// Sync void wrapper around [_trackedHeartbeat] for use as a callback.
  ///
  /// Ignores the [RunLoopTransition] return value — the gate exit path handles
  /// termination after the gate resolves.
  void _trackedHeartbeatRaw(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) {
    _trackedHeartbeat(ctx, lockHandle);
  }

  /// Feature H: Computes adaptive sleep duration based on consecutive failures.
  ///
  /// When [params.config.autopilotAdaptiveSleepEnabled] is true and there are
  /// consecutive failures, the sleep duration is doubled for each failure up to
  /// [params.config.autopilotAdaptiveSleepMaxMultiplier]× base sleep, capped
  /// at [params.idleSleep].
  Duration _computeAdaptiveSleep(
    RunLoopContext ctx,
    ResolvedRunParams params,
  ) {
    if (ctx.stepWasIdle) return params.idleSleep;
    if (!params.config.autopilotAdaptiveSleepEnabled ||
        ctx.consecutiveFailures == 0) {
      return params.stepSleep;
    }
    final maxMult = params.config.autopilotAdaptiveSleepMaxMultiplier;
    final shift = ctx.consecutiveFailures.clamp(0, 30);
    final multiplier = (1 << shift).clamp(1, maxMult);
    final adapted = params.stepSleep * multiplier;
    return adapted > params.idleSleep ? params.idleSleep : adapted;
  }
}
