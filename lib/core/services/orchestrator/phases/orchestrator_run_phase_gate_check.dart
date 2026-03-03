// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseGateCheck on OrchestratorRunService {
  /// Gate check: iteration limit, wallclock, maxSteps, stop signal,
  /// config hot-reload, stash GC.
  RunLoopTransition _handleGateCheck(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) {
    final params = ctx.params;
    final projectRoot = params.projectRoot;

    // Iteration safety limit guard.
    if (params.maxIterationsSafetyLimit > 0 &&
        ctx.totalSteps >= params.maxIterationsSafetyLimit) {
      ctx.stoppedBySafetyHalt = true;
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_safety_halt',
        message: 'Autopilot halted: Max iteration safety limit exceeded',
        data: {
          'error_class': 'pipeline',
          'error_kind': 'max_iterations_safety_limit',
          'total_steps': ctx.totalSteps,
          'max_iterations_safety_limit': params.maxIterationsSafetyLimit,
        },
      );
      return const RunLoopTransition.terminate(
          reason: 'max_iterations_safety_limit');
    }

    // Wallclock timeout guard.
    if (params.maxWallclockHours > 0 &&
        DateTime.now().toUtc().isAfter(
              ctx.runStart.add(Duration(hours: params.maxWallclockHours)),
            )) {
      ctx.stoppedBySafetyHalt = true;
      _appendRunLog(
        projectRoot,
        event: 'wallclock_timeout',
        message: 'Autopilot halted: Wallclock timeout exceeded',
        data: {
          'error_class': 'pipeline',
          'error_kind': 'wallclock_timeout',
          'max_wallclock_hours': params.maxWallclockHours,
          'run_start': ctx.runStart.toIso8601String(),
          'total_steps': ctx.totalSteps,
        },
      );
      return const RunLoopTransition.terminate(reason: 'wallclock_timeout');
    }

    if (params.maxSteps != null && ctx.totalSteps >= params.maxSteps!) {
      ctx.stoppedByMaxSteps = true;
      return const RunLoopTransition.terminate(reason: 'max_steps');
    }
    if (_stopRequested(projectRoot)) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_stop_requested',
        message: 'Autopilot stop requested',
        data: {
          'step_index': ctx.totalSteps,
          'lock_file': lockHandle.path,
        },
      );
      return const RunLoopTransition.terminate(reason: 'stop_requested');
    }

    ctx.totalSteps += 1;
    ctx.resetIterationState();

    // Config hot-reload every 10 steps.
    ctx.configReloadCounter += 1;
    if (ctx.configReloadCounter % 10 == 0) {
      try {
        final reloadedConfig = _loadConfig(projectRoot);
        // Propagate all runtime params so mid-run config changes take effect
        // without restarting the autopilot.
        ctx.params = ctx.params.copyWith(
          config: reloadedConfig,
          maxFailures: reloadedConfig.autopilotMaxFailures,
          maxTaskRetries: reloadedConfig.autopilotMaxTaskRetries,
          stepSleep: reloadedConfig.autopilotStepSleep,
          idleSleep: reloadedConfig.autopilotIdleSleep,
          selfHealEnabled: reloadedConfig.autopilotSelfHealEnabled,
          selfHealMaxAttempts: reloadedConfig.autopilotSelfHealMaxAttempts,
          noProgressThreshold: reloadedConfig.autopilotNoProgressThreshold,
          minOpen: reloadedConfig.autopilotMinOpenTasks,
          maxPlanAdd: reloadedConfig.autopilotMaxPlanAdd,
          approveBudget: reloadedConfig.autopilotApproveBudget,
          scopeMaxFiles: reloadedConfig.autopilotScopeMaxFiles,
          scopeMaxAdditions: reloadedConfig.autopilotScopeMaxAdditions,
          scopeMaxDeletions: reloadedConfig.autopilotScopeMaxDeletions,
        );
        _appendRunLog(
          projectRoot,
          event: 'config_hot_reload',
          message: 'Config hot-reloaded at step ${ctx.totalSteps}',
          data: {
            'step_index': ctx.totalSteps,
            'reload_count': ctx.configReloadCounter ~/ 10,
            'max_task_retries': reloadedConfig.autopilotMaxTaskRetries,
            'max_failures': reloadedConfig.autopilotMaxFailures,
          },
        );
        // Feature I: Stash GC — drop oldest stashes above configured limit.
        if (_gitService.isGitRepo(projectRoot)) {
          try {
            _gitService.dropOldestStashes(
              projectRoot,
              maxKeep: reloadedConfig.autopilotMaxStashEntries,
            );
          } catch (_) {
            // Non-critical: silent.
          }
        }
      } catch (e) {
        _appendRunLog(
          projectRoot,
          event: 'config_hot_reload_failed',
          message: 'Config hot-reload failed at step ${ctx.totalSteps}',
          data: {
            'step_index': ctx.totalSteps,
            'error': e.toString(),
            'error_class': 'state',
            'error_kind': 'config_reload',
          },
        );
        // Safe fallback: keep existing params unchanged.
      }
    }
    ctx.stepId = _buildRunStepId(ctx.runId, ctx.totalSteps);

    return const RunLoopTransition.next(RunLoopPhase.preflight);
  }
}
