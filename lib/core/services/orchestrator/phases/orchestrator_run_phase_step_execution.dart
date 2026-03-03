// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../../orchestrator_run_service.dart';

extension _OrchestratorRunPhaseStepExecution on OrchestratorRunService {
  /// Execute the actual step via `_stepService.run()`.
  ///
  /// On success, stores the result in `ctx.lastStepResult` and returns
  /// `next(stepOutcome)`. On error, stores the error in `ctx.lastStepError`
  /// and returns `next(errorRecovery)`.
  Future<RunLoopTransition> _handleStepExecution(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle,
  ) async {
    final params = ctx.params;
    final projectRoot = params.projectRoot;

    _seedPlanningAuditCadence(
      projectRoot,
      stepIndex: ctx.totalSteps,
      config: params.config,
      stepId: ctx.stepId,
    );

    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_step_start',
      message: 'Autopilot run step started',
      data: {
        'step_id': ctx.stepId,
        'step_index': ctx.totalSteps,
        'lock_file': lockHandle.path,
      },
    );

    try {
      final stepResult = await _runWithHeartbeat(
        lockHandle,
        () => _stepService.run(
          projectRoot,
          codingPrompt: params.codingPrompt,
          testSummary: params.testSummary,
          overwriteArtifacts: params.overwriteArtifacts,
          minOpenTasks: params.minOpen,
          maxPlanAdd: params.maxPlanAdd,
          maxTaskRetries: params.maxTaskRetries,
        ),
        lockTtl: params.config.autopilotLockTtl,
      );
      ctx.lastStepResult = stepResult;
      return const RunLoopTransition.next(RunLoopPhase.stepOutcome);
    } on QuotaPauseError catch (e) {
      ctx.lastStepError = e;
      return const RunLoopTransition.next(RunLoopPhase.errorRecovery);
    } on TransientError catch (e) {
      ctx.lastStepError = e;
      return const RunLoopTransition.next(RunLoopPhase.errorRecovery);
    } on PermanentError catch (e) {
      ctx.lastStepError = e;
      return const RunLoopTransition.next(RunLoopPhase.errorRecovery);
    } on PolicyViolationError catch (e) {
      ctx.lastStepError = e;
      return const RunLoopTransition.next(RunLoopPhase.errorRecovery);
    } on StateError catch (e) {
      ctx.lastStepError = e;
      return const RunLoopTransition.next(RunLoopPhase.errorRecovery);
    } on Error catch (fatalError, stackTrace) {
      // VM-level errors (OOM, StackOverflow) must not be masked — rethrow for
      // a clean crash that supervision/systemd can detect and restart.
      if (fatalError is OutOfMemoryError || fatalError is StackOverflowError) {
        try {
          stderr.writeln('[FATAL] Unrecoverable VM error: $fatalError');
        } catch (_) {}
        rethrow;
      }
      // Other Error subclasses (AssertionError etc.) → reclassify as recoverable.
      ctx.lastStepError =
          StateError('Unexpected error: $fatalError\n$stackTrace');
      return const RunLoopTransition.next(
        RunLoopPhase.errorRecovery,
        reason: 'unexpected_exception',
      );
    } catch (error, stackTrace) {
      // Unknown exception type — reclassify to prevent unhandled crash.
      ctx.lastStepError =
          StateError('Unexpected error: $error\n$stackTrace');
      return const RunLoopTransition.next(
        RunLoopPhase.errorRecovery,
        reason: 'unexpected_exception',
      );
    }
  }
}
