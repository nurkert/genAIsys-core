// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/operation_errors.dart';
import '../errors/failure_reason_mapper.dart';
import '../git/git_service.dart';
import '../models/project_state.dart';
import '../config/project_config.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import 'task_management/activate_service.dart';
import 'autopilot/autopilot_preflight_service.dart';
import 'autopilot/autopilot_release_tag_service.dart';
import 'autopilot/autopilot_self_heal_service.dart';
import 'build_test_runner_service.dart';
import 'observability/code_health_service.dart';
import '../models/hitl_gate.dart';
import 'hitl_gate_service.dart';
import 'sprint_planner_service.dart';
import 'state_repair_service.dart';
import 'orchestrator_step_service.dart';
import 'pid_liveness_service.dart';
import 'planning_audit_cadence_service.dart';
import 'productivity_reflection_service.dart';

part 'orchestrator/orchestrator_run_context.dart';
part 'orchestrator/orchestrator_run_state_handlers.dart';
part 'orchestrator/phases/orchestrator_run_phase_helpers.dart';
part 'orchestrator/phases/orchestrator_run_phase_gate_check.dart';
part 'orchestrator/phases/orchestrator_run_phase_preflight.dart';
part 'orchestrator/phases/orchestrator_run_phase_step_execution.dart';
part 'orchestrator/phases/orchestrator_run_phase_step_outcome.dart';
part 'orchestrator/phases/orchestrator_run_phase_progress_check.dart';
part 'orchestrator/phases/orchestrator_run_phase_sleep.dart';
part 'orchestrator/orchestrator_run_error_handler.dart';
part 'orchestrator/orchestrator_run_locking.dart';
part 'orchestrator/orchestrator_run_telemetry.dart';
part 'orchestrator/orchestrator_run_loop_support.dart';

typedef RunSleep = Future<void> Function(Duration duration);

class OrchestratorRunResult {
  OrchestratorRunResult({
    required this.totalSteps,
    required this.successfulSteps,
    required this.idleSteps,
    required this.failedSteps,
    required this.stoppedByMaxSteps,
    required this.stoppedWhenIdle,
    required this.stoppedBySafetyHalt,
  });

  final int totalSteps;
  final int successfulSteps;
  final int idleSteps;
  final int failedSteps;
  final bool stoppedByMaxSteps;
  final bool stoppedWhenIdle;
  final bool stoppedBySafetyHalt;
}

class AutopilotStepSummary {
  AutopilotStepSummary({
    required this.stepId,
    this.taskId,
    this.subtaskId,
    this.decision,
    this.event,
    this.timestamp,
  });

  final String stepId;
  final String? taskId;
  final String? subtaskId;
  final String? decision;
  final String? event;
  final String? timestamp;
}

class AutopilotStatus {
  AutopilotStatus({
    required this.isRunning,
    required this.pid,
    required this.startedAt,
    required this.lastLoopAt,
    required this.consecutiveFailures,
    required this.lastError,
    this.lastErrorClass,
    this.lastErrorKind,
    required this.subtaskQueue,
    required this.currentSubtask,
    required this.lastStepSummary,
    this.hitlGatePending = false,
    this.hitlGateEvent,
  });

  final bool isRunning;
  final int? pid;
  final String? startedAt;
  final String? lastLoopAt;
  final int consecutiveFailures;
  final String? lastError;
  final String? lastErrorClass;
  final String? lastErrorKind;
  final List<String> subtaskQueue;
  final String? currentSubtask;
  final AutopilotStepSummary? lastStepSummary;
  final bool hitlGatePending;
  final String? hitlGateEvent;
}

class OrchestratorRunService {
  OrchestratorRunService({
    OrchestratorStepService? stepService,
    RunSleep? sleep,
    StateRepairService? stateRepairService,
    PlanningAuditCadenceService? planningAuditCadenceService,
    BuildTestRunnerService? buildTestRunnerService,
    AutopilotPreflightService? autopilotPreflightService,
    GitService? gitService,
    ProductivityReflectionService? reflectionService,
    PidLivenessService? pidLivenessService,
    AutopilotReleaseTagService? releaseTagService,
    AutopilotSelfHealService? selfHealService,
    CodeHealthService? codeHealthService,
    SprintPlannerService? sprintPlannerService,
    HitlGateService? hitlGateService,
    // Injected for testing: overrides the started_at used for TOCTOU detection.
    DateTime? thisProcessStartedAt,
  }) : _stepService = stepService ?? OrchestratorStepService(),
       _customSleep = sleep,
       _stateRepairService = stateRepairService ?? StateRepairService(),
       _planningAuditCadenceService =
           planningAuditCadenceService ?? PlanningAuditCadenceService(),
       _preflightService =
           autopilotPreflightService ?? AutopilotPreflightService(),
       _gitService = gitService ?? GitService(),
       _reflectionService =
           reflectionService ?? ProductivityReflectionService(),
       _pidLivenessService = pidLivenessService ?? PidLivenessService(),
       _releaseTagService = releaseTagService ??
           AutopilotReleaseTagService(
             gitService: gitService,
             buildTestRunnerService: buildTestRunnerService,
           ),
       _selfHealService = selfHealService ??
           AutopilotSelfHealService(stepService: stepService),
       _codeHealthService = codeHealthService ?? CodeHealthService(),
       _sprintPlannerService = sprintPlannerService ?? SprintPlannerService(),
       _hitlGateService = hitlGateService ?? const HitlGateService(),
       _thisProcessStartedAt = thisProcessStartedAt;

  final OrchestratorStepService _stepService;
  final RunSleep? _customSleep;
  final StateRepairService _stateRepairService;
  final PlanningAuditCadenceService _planningAuditCadenceService;
  final AutopilotPreflightService _preflightService;
  final GitService _gitService;
  final ProductivityReflectionService _reflectionService;
  final PidLivenessService _pidLivenessService;
  final AutopilotReleaseTagService _releaseTagService;
  final AutopilotSelfHealService _selfHealService;
  final CodeHealthService _codeHealthService;
  final SprintPlannerService _sprintPlannerService;
  final HitlGateService _hitlGateService;

  /// The started_at timestamp written into our lock file when we acquire it.
  /// Set in [_acquireRunLock]. Used by [_recoverStaleLock] for TOCTOU
  /// protection: if a live PID's lock has a different started_at, the PID
  /// must have been recycled by the OS and the lock can be safely recovered.
  DateTime? _thisProcessStartedAt;

  /// For testing only: when set, [_trackedHeartbeat] calls this instead of the
  /// real lock heartbeat write. Throw to simulate a heartbeat write failure.
  /// Does NOT affect lock acquisition writes or timer-based heartbeats.
  /// Do not use in production code.
  void Function()? heartbeatWriterForTest;

  /// Completer for the current sleep, allowing early wake-up on stop.
  Completer<void>? _sleepCompleter;

  /// Cancellable sleep: uses a Completer + Timer so that [requestStop] can
  /// complete the completer early and the sleep exits immediately.
  Future<void> _sleep(Duration duration) async {
    final customSleep = _customSleep;
    if (customSleep != null) {
      return customSleep(duration);
    }
    final completer = Completer<void>();
    _sleepCompleter = completer;
    final timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      await completer.future;
    } finally {
      timer.cancel();
      _sleepCompleter = null;
    }
  }

  /// Request stop: writes the stop signal and wakes the sleep immediately.
  void requestStop(String projectRoot) {
    _writeStopSignal(projectRoot);
    final completer = _sleepCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  AutopilotStatus getStatus(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final lockFile = File(layout.autopilotLockPath);
    int? pid;
    String? startedAt;

    if (lockFile.existsSync()) {
      final ttl = _resolveLockTtl(projectRoot);
      _recoverStaleLock(projectRoot, lockFile, ttl, context: 'status_check');
    }

    if (lockFile.existsSync()) {
      final meta = _readLockMetadata(lockFile);
      pid = _parsePid(meta.pid);
      startedAt = meta.startedAt?.toIso8601String();
    }

    final store = StateStore(layout.statePath);
    ProjectState state;
    try {
      state = store.read();
    } catch (_) {
      state = ProjectState.initial();
    }

    final isRunning = lockFile.existsSync();
    final lastStepSummary = _readLastStepSummary(projectRoot);
    final hitlGate = _hitlGateService.pendingGate(projectRoot);

    return AutopilotStatus(
      isRunning: isRunning,
      pid: pid,
      startedAt: startedAt,
      lastLoopAt: state.lastLoopAt,
      consecutiveFailures: state.consecutiveFailures,
      lastError: state.lastError,
      lastErrorClass: state.lastErrorClass,
      lastErrorKind: state.lastErrorKind,
      subtaskQueue: state.subtaskQueue,
      currentSubtask: state.currentSubtask,
      lastStepSummary: lastStepSummary,
      hitlGatePending: hitlGate != null,
      hitlGateEvent: hitlGate?.event.serialized,
    );
  }

  Future<void> stop(String projectRoot) async {
    final status = getStatus(projectRoot);
    _writeStopSignal(projectRoot);
    if (!status.isRunning) {
      _markRunStopped(projectRoot);
      _clearStopSignal(projectRoot);
      return;
    }

    final selfPid = pidOrNull();
    final isSelf =
        status.pid != null && selfPid != null && status.pid == selfPid;
    final targetPid = (!isSelf && status.pid != null && status.pid! > 0)
        ? status.pid
        : null;

    // Fail-closed: if we cannot identify a target pid, do NOT delete the lock
    // or clear the stop signal. Otherwise we can orphan a live run loop that
    // will keep executing without an observable lock/stop handle.
    if (!isSelf && targetPid == null) {
      return;
    }

    if (!isSelf && targetPid != null) {
      // Best-effort termination. This is required because the run loop might be
      // blocked in an agent/provider call and cannot observe the stop signal.
      try {
        Process.killPid(targetPid, ProcessSignal.sigterm);
      } catch (_) {
        // Process might be already gone or signal unsupported.
      }

      // If SIGTERM didn't stop it quickly, escalate to SIGKILL (fail-closed).
      await _sleep(const Duration(milliseconds: 200));
      if (_pidLivenessService.isProcessAlive(targetPid)) {
        try {
          Process.killPid(targetPid, ProcessSignal.sigkill);
        } catch (_) {
          // Ignore: platform might not support SIGKILL.
        }
        await _sleep(const Duration(milliseconds: 200));
      }
    }

    if (!isSelf) {
      // Only force cleanup if the target pid is gone. Otherwise we risk
      // orphaning a live run without a lock handle or status visibility.
      if (targetPid != null && _pidLivenessService.isProcessAlive(targetPid)) {
        throw StateError(
          'Unable to stop autopilot: process $targetPid did not terminate.',
        );
      }

      _markRunStopped(projectRoot);
      try {
        final lockFile = File(ProjectLayout(projectRoot).autopilotLockPath);
        if (lockFile.existsSync()) {
          lockFile.deleteSync();
        }
      } catch (_) {}
      _clearStopSignal(projectRoot);
    }
  }

  Future<OrchestratorRunResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle = false,
    int? maxConsecutiveFailures,
    int? maxTaskRetries,
    bool unattendedMode = false,
    bool overrideSafety = false,
  }) async {
    final config = _loadConfig(projectRoot);
    _stateRepairService.repair(projectRoot);
    final resolvedMaxSteps = maxSteps ?? config.autopilotMaxSteps;
    if (resolvedMaxSteps != null && resolvedMaxSteps < 1) {
      throw ArgumentError.value(resolvedMaxSteps, 'maxSteps', 'must be >= 1');
    }
    final resolvedMinOpen = minOpenTasks ?? config.autopilotMinOpenTasks;
    final resolvedMaxPlanAdd = maxPlanAdd ?? config.autopilotMaxPlanAdd;
    final resolvedStepSleep = stepSleep ?? config.autopilotStepSleep;
    final resolvedIdleSleep = idleSleep ?? config.autopilotIdleSleep;
    final resolvedMaxFailures =
        maxConsecutiveFailures ?? config.autopilotMaxFailures;
    final resolvedMaxTaskRetries =
        maxTaskRetries ?? config.autopilotMaxTaskRetries;
    final resolvedSelfHealMaxAttempts = config.autopilotSelfHealMaxAttempts;
    final resolvedOverrideSafety =
        overrideSafety || config.autopilotManualOverride;
    final overnightUnattendedRequested =
        unattendedMode || (resolvedMaxSteps == null && !stopWhenIdle);

    if (overnightUnattendedRequested &&
        !config.autopilotOvernightUnattendedEnabled) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_unattended_blocked',
        message: 'Overnight unattended run is not released',
        data: {
          'error_class': 'policy',
          'error_kind': 'unattended_not_released',
          'config_key': 'autopilot.overnight_unattended_enabled',
        },
      );
      throw PermanentError(
        'Overnight unattended run is not released. '
        'Enable autopilot.overnight_unattended_enabled in .genaisys/config.yml.',
      );
    }

    final params = ResolvedRunParams(
      projectRoot: projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary,
      overwriteArtifacts: overwriteArtifacts,
      stopWhenIdle: stopWhenIdle,
      minOpen: resolvedMinOpen < 1 ? 1 : resolvedMinOpen,
      maxPlanAdd: resolvedMaxPlanAdd < 1 ? 1 : resolvedMaxPlanAdd,
      stepSleep:
          resolvedStepSleep.isNegative ? Duration.zero : resolvedStepSleep,
      idleSleep:
          resolvedIdleSleep.isNegative ? Duration.zero : resolvedIdleSleep,
      maxSteps: resolvedMaxSteps,
      maxFailures: resolvedMaxFailures < 1 ? 1 : resolvedMaxFailures,
      maxTaskRetries:
          resolvedMaxTaskRetries < 1 ? 1 : resolvedMaxTaskRetries,
      noProgressThreshold: config.autopilotNoProgressThreshold < 0
          ? 0
          : config.autopilotNoProgressThreshold,
      stuckCooldown: config.autopilotStuckCooldown.isNegative
          ? Duration.zero
          : config.autopilotStuckCooldown,
      selfRestart: config.autopilotSelfRestart,
      selfHealEnabled: config.autopilotSelfHealEnabled,
      selfHealMaxAttempts:
          resolvedSelfHealMaxAttempts < 0 ? 0 : resolvedSelfHealMaxAttempts,
      scopeMaxFiles: config.autopilotScopeMaxFiles,
      scopeMaxAdditions: config.autopilotScopeMaxAdditions,
      scopeMaxDeletions: config.autopilotScopeMaxDeletions,
      approveBudget: config.autopilotApproveBudget,
      overrideSafety: resolvedOverrideSafety,
      overnightUnattended: overnightUnattendedRequested,
      failedCooldown: config.autopilotFailedCooldown.isNegative
          ? Duration.zero
          : config.autopilotFailedCooldown,
      maxWallclockHours: config.autopilotMaxWallclockHours,
      maxSelfRestarts: config.autopilotMaxSelfRestarts,
      maxIterationsSafetyLimit: config.autopilotMaxIterationsSafetyLimit,
      config: config,
    );

    final lockHandle = _acquireRunLock(projectRoot);
    final runId = lockHandle.startedAt;
    _markRunStarted(projectRoot);

    final ctx = RunLoopContext(
      params: params,
      runStart: DateTime.now().toUtc(),
      runId: runId,
    );

    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_start',
      message: 'Autopilot run started',
      data: {
        'lock_file': lockHandle.path,
        'step_sleep_seconds': params.stepSleep.inSeconds,
        'idle_sleep_seconds': params.idleSleep.inSeconds,
        'max_steps': params.maxSteps,
        'stop_when_idle': params.stopWhenIdle,
        'max_consecutive_failures': params.maxFailures,
        'max_task_retries': params.maxTaskRetries,
        'no_progress_threshold': params.noProgressThreshold,
        'stuck_cooldown_seconds': params.stuckCooldown.inSeconds,
        'self_restart': params.selfRestart,
        'self_heal_enabled': params.selfHealEnabled,
        'self_heal_max_attempts': params.selfHealMaxAttempts,
        'scope_max_files': params.scopeMaxFiles,
        'scope_max_additions': params.scopeMaxAdditions,
        'scope_max_deletions': params.scopeMaxDeletions,
        'approve_budget': params.approveBudget,
        'manual_override': params.overrideSafety,
        'max_wallclock_hours': params.maxWallclockHours,
        'max_self_restarts': params.maxSelfRestarts,
        'max_iterations_safety_limit': params.maxIterationsSafetyLimit,
      },
    );

    try {
      var phase = RunLoopPhase.gateCheck;
      while (true) {
        final RunLoopTransition transition;
        switch (phase) {
          case RunLoopPhase.gateCheck:
            transition = _handleGateCheck(ctx, lockHandle);
          case RunLoopPhase.preflight:
            transition = await _handlePreflight(ctx, lockHandle);
          case RunLoopPhase.stepExecution:
            transition = await _handleStepExecution(ctx, lockHandle);
          case RunLoopPhase.stepOutcome:
            transition = await _handleStepOutcome(ctx, lockHandle);
          case RunLoopPhase.errorRecovery:
            transition =
                await _handleStepError(ctx, ctx.lastStepError!, lockHandle);
          case RunLoopPhase.progressCheck:
            transition = await _handleProgressCheck(ctx, lockHandle);
          case RunLoopPhase.sleepAndLoop:
            transition = await _handleSleepAndLoop(ctx, lockHandle);
        }
        if (transition.isTerminal) break;
        phase = transition.nextPhase!;
      }

      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_end',
        message: 'Autopilot run stopped',
        data: {
          'total_steps': ctx.totalSteps,
          'successful_steps': ctx.successfulSteps,
          'idle_steps': ctx.idleSteps,
          'failed_steps': ctx.failedSteps,
          'stopped_by_max_steps': ctx.stoppedByMaxSteps,
          'stopped_when_idle': ctx.stoppedWhenIdle,
          'stopped_by_safety_halt': ctx.stoppedBySafetyHalt,
          'self_heal_attempts': ctx.totalSelfHealAttempts,
        },
      );
    } finally {
      _markRunStopped(projectRoot);
      _clearStopSignal(projectRoot);
      _checkoutBaseBranchOnExit(projectRoot);
      lockHandle.release();
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_unlock',
        message: 'Autopilot run lock released',
        data: {'lock_file': lockHandle.path},
      );
    }

    return ctx.toResult();
  }

  /// Best-effort checkout of the base branch after autopilot completion or
  /// safety halt.  Only runs when the worktree is clean and we are in a git
  /// repo.  Failures are logged but never thrown.
  void _checkoutBaseBranchOnExit(String projectRoot) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) return;
      if (!_gitService.isClean(projectRoot)) {
        _appendRunLog(
          projectRoot,
          event: 'exit_checkout_skipped',
          message: 'Skipped base branch checkout on exit: worktree dirty',
          data: {'root': projectRoot},
        );
        return;
      }
      final config = _loadConfig(projectRoot);
      final baseBranch = config.gitBaseBranch;
      if (baseBranch.trim().isEmpty) return;
      final current = _gitService.currentBranch(projectRoot);
      if (current == baseBranch) return;
      if (!_gitService.branchExists(projectRoot, baseBranch)) return;
      _gitService.checkout(projectRoot, baseBranch);
      _appendRunLog(
        projectRoot,
        event: 'exit_checkout_base',
        message: 'Checked out base branch on autopilot exit',
        data: {
          'root': projectRoot,
          'base_branch': baseBranch,
          'previous_branch': current,
        },
      );
    } catch (e) {
      _appendRunLog(
        projectRoot,
        event: 'exit_checkout_failed',
        message: 'Failed to checkout base branch on exit',
        data: {
          'root': projectRoot,
          'error': e.toString(),
          'error_class': 'git',
          'error_kind': 'exit_checkout_failed',
        },
      );
    }
  }

  int? pidOrNull() {
    try {
      return pid;
    } catch (_) {
      return null;
    }
  }
}
