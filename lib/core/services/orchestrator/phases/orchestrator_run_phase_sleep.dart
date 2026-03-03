// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseSleep on OrchestratorRunService {
  /// Compute adaptive sleep duration, yield, second stop check, loop back.
  Future<RunLoopTransition> _handleSleepAndLoop(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;

    {
      final haltTransition = _trackedHeartbeat(ctx, lockHandle);
      if (haltTransition != null) return haltTransition;
    }

    if (_stopRequested(projectRoot)) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_stop_requested',
        message: 'Autopilot stop requested',
        data: {
          'step_id': ctx.stepId,
          'step_index': ctx.totalSteps,
          'lock_file': lockHandle.path,
        },
      );
      return const RunLoopTransition.terminate(reason: 'stop_requested');
    }

    if (params.maxSteps != null && ctx.totalSteps >= params.maxSteps!) {
      ctx.stoppedByMaxSteps = true;
      return const RunLoopTransition.terminate(reason: 'max_steps');
    }

    final sleepDuration =
        ctx.forcedSleep ?? _computeAdaptiveSleep(ctx, params);
    if (sleepDuration.inMicroseconds > 0) {
      await _sleep(sleepDuration);
    }
    await Future<void>.delayed(Duration.zero);

    return const RunLoopTransition.next(RunLoopPhase.gateCheck);
  }
}
