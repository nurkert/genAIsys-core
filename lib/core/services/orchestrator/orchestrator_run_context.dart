// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_run_service.dart';

/// Sequential phases of each autopilot run-loop iteration.
///
/// The run loop dispatches to a handler for the current phase; each handler
/// returns a [RunLoopTransition] that names the next phase (or terminates).
enum RunLoopPhase {
  /// Iteration limit, wallclock timeout, maxSteps, stop signal.
  gateCheck,

  /// Preflight check, escalation, repair, backoff.
  preflight,

  /// Execute the actual step via `_stepService.run()`.
  stepExecution,

  /// Evaluate step result: self-heal, failure counting, budget checks.
  stepOutcome,

  /// Unified error handler for all caught error types.
  errorRecovery,

  /// No-progress detection, self-restart.
  progressCheck,

  /// Compute sleep duration, yield, second stop check.
  sleepAndLoop,
}

/// Handler return type: tells the run loop what to do next.
class RunLoopTransition {
  const RunLoopTransition.next(RunLoopPhase phase, {this.reason})
      : nextPhase = phase;

  const RunLoopTransition.terminate({this.reason}) : nextPhase = null;

  /// The next phase to execute, or `null` for termination.
  final RunLoopPhase? nextPhase;

  /// Optional human-readable reason (for logging/debugging).
  final String? reason;

  bool get isTerminal => nextPhase == null;
}

/// Immutable normalized configuration resolved once at run start.
class ResolvedRunParams {
  ResolvedRunParams({
    required this.projectRoot,
    required this.codingPrompt,
    required this.testSummary,
    required this.overwriteArtifacts,
    required this.stopWhenIdle,
    required this.minOpen,
    required this.maxPlanAdd,
    required this.stepSleep,
    required this.idleSleep,
    required this.maxSteps,
    required this.maxFailures,
    required this.maxTaskRetries,
    required this.noProgressThreshold,
    required this.stuckCooldown,
    required this.selfRestart,
    required this.selfHealEnabled,
    required this.selfHealMaxAttempts,
    required this.scopeMaxFiles,
    required this.scopeMaxAdditions,
    required this.scopeMaxDeletions,
    required this.approveBudget,
    required this.overrideSafety,
    required this.overnightUnattended,
    required this.failedCooldown,
    required this.maxWallclockHours,
    required this.maxSelfRestarts,
    required this.maxIterationsSafetyLimit,
    required this.config,
  });

  final String projectRoot;
  final String codingPrompt;
  final String? testSummary;
  final bool overwriteArtifacts;
  final bool stopWhenIdle;

  final int minOpen;
  final int maxPlanAdd;
  final Duration stepSleep;
  final Duration idleSleep;
  final int? maxSteps;
  final int maxFailures;
  final int maxTaskRetries;
  final int noProgressThreshold;
  final Duration stuckCooldown;
  final bool selfRestart;
  final bool selfHealEnabled;
  final int selfHealMaxAttempts;
  final int scopeMaxFiles;
  final int scopeMaxAdditions;
  final int scopeMaxDeletions;
  final int approveBudget;
  final bool overrideSafety;
  final bool overnightUnattended;
  final Duration failedCooldown;
  final int maxWallclockHours;
  final int maxSelfRestarts;
  final int maxIterationsSafetyLimit;

  /// The initial config snapshot (used for reflection settings, lock TTL, etc.).
  final ProjectConfig config;

  /// Returns a copy with updated fields. Only the supplied non-null arguments
  /// replace their counterparts; all others are carried over unchanged.
  ResolvedRunParams copyWith({
    int? maxFailures,
    int? maxTaskRetries,
    Duration? stepSleep,
    Duration? idleSleep,
    bool? selfHealEnabled,
    int? selfHealMaxAttempts,
    int? noProgressThreshold,
    int? minOpen,
    int? maxPlanAdd,
    int? approveBudget,
    int? scopeMaxFiles,
    int? scopeMaxAdditions,
    int? scopeMaxDeletions,
    ProjectConfig? config,
  }) {
    return ResolvedRunParams(
      projectRoot: projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary,
      overwriteArtifacts: overwriteArtifacts,
      stopWhenIdle: stopWhenIdle,
      minOpen: minOpen ?? this.minOpen,
      maxPlanAdd: maxPlanAdd ?? this.maxPlanAdd,
      stepSleep: stepSleep ?? this.stepSleep,
      idleSleep: idleSleep ?? this.idleSleep,
      maxSteps: maxSteps,
      maxFailures: maxFailures ?? this.maxFailures,
      maxTaskRetries: maxTaskRetries ?? this.maxTaskRetries,
      noProgressThreshold: noProgressThreshold ?? this.noProgressThreshold,
      stuckCooldown: stuckCooldown,
      selfRestart: selfRestart,
      selfHealEnabled: selfHealEnabled ?? this.selfHealEnabled,
      selfHealMaxAttempts: selfHealMaxAttempts ?? this.selfHealMaxAttempts,
      scopeMaxFiles: scopeMaxFiles ?? this.scopeMaxFiles,
      scopeMaxAdditions: scopeMaxAdditions ?? this.scopeMaxAdditions,
      scopeMaxDeletions: scopeMaxDeletions ?? this.scopeMaxDeletions,
      approveBudget: approveBudget ?? this.approveBudget,
      overrideSafety: overrideSafety,
      overnightUnattended: overnightUnattended,
      failedCooldown: failedCooldown,
      maxWallclockHours: maxWallclockHours,
      maxSelfRestarts: maxSelfRestarts,
      maxIterationsSafetyLimit: maxIterationsSafetyLimit,
      config: config ?? this.config,
    );
  }
}

/// Mutable state carrier for a single autopilot run.
///
/// All 18+ counters that were previously local variables in `run()` live here.
class RunLoopContext {
  RunLoopContext({
    required this.params,
    required this.runStart,
    required this.runId,
  });

  ResolvedRunParams params; // mutable: updated on config hot-reload
  final DateTime runStart;
  final String runId;

  // ── Counters ──────────────────────────────────────────────────────────

  int totalSteps = 0;
  int successfulSteps = 0;
  int idleSteps = 0;
  int failedSteps = 0;
  int consecutiveFailures = 0;
  int noProgressSteps = 0;
  int selfRestartCount = 0;
  int consecutiveSelfHealAttempts = 0;
  int totalSelfHealAttempts = 0;
  int consecutivePreflightFailures = 0;
  int preflightRepairAttempts = 0;
  int approvalCount = 0;
  int scopeFiles = 0;
  int scopeAdditions = 0;
  int scopeDeletions = 0;
  int configReloadCounter = 0;
  int consecutiveLockHeartbeatFailures = 0;

  // ── Termination flags ─────────────────────────────────────────────────

  bool stoppedByMaxSteps = false;
  bool stoppedWhenIdle = false;
  bool stoppedBySafetyHalt = false;

  // ── HITL state ────────────────────────────────────────────────────────

  /// True while the orchestrator is blocked waiting for a HITL decision.
  bool hitlGatePending = false;

  // ── Per-iteration ephemeral state ─────────────────────────────────────

  late String stepId;
  bool stepWasIdle = false;
  bool stepHadProgress = false;
  Duration? forcedSleep;
  DateTime? cooldownNextEligibleAt;
  OrchestratorStepResult? lastStepResult;
  Object? lastStepError;

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Resets per-iteration ephemeral state at the start of each loop iteration.
  void resetIterationState() {
    stepWasIdle = false;
    stepHadProgress = false;
    forcedSleep = null;
    cooldownNextEligibleAt = null;
    lastStepResult = null;
    lastStepError = null;
  }

  /// Builds the [OrchestratorRunResult] from the current counter state.
  OrchestratorRunResult toResult() {
    return OrchestratorRunResult(
      totalSteps: totalSteps,
      successfulSteps: successfulSteps,
      idleSteps: idleSteps,
      failedSteps: failedSteps,
      stoppedByMaxSteps: stoppedByMaxSteps,
      stoppedWhenIdle: stoppedWhenIdle,
      stoppedBySafetyHalt: stoppedBySafetyHalt,
    );
  }
}
