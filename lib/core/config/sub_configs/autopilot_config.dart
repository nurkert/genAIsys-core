// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all autopilot-related fields from [ProjectConfig].
///
/// This is a lazy-computed view — no data is duplicated; each field
/// delegates to the underlying [ProjectConfig] instance.
class AutopilotConfig {
  const AutopilotConfig({
    required this.minOpenTasks,
    required this.maxPlanAdd,
    required this.stepSleep,
    required this.idleSleep,
    required this.maxSteps,
    required this.maxFailures,
    required this.maxTaskRetries,
    required this.selectionMode,
    required this.fairnessWindow,
    required this.priorityWeightP1,
    required this.priorityWeightP2,
    required this.priorityWeightP3,
    required this.reactivateBlocked,
    required this.reactivateFailed,
    required this.blockedCooldown,
    required this.failedCooldown,
    required this.lockTtl,
    required this.noProgressThreshold,
    required this.stuckCooldown,
    required this.selfRestart,
    required this.selfHealEnabled,
    required this.selfHealMaxAttempts,
    required this.scopeMaxFiles,
    required this.scopeMaxAdditions,
    required this.scopeMaxDeletions,
    required this.approveBudget,
    required this.manualOverride,
    required this.overnightUnattendedEnabled,
    required this.selfTuneEnabled,
    required this.selfTuneWindow,
    required this.selfTuneMinSamples,
    required this.selfTuneSuccessPercent,
    required this.releaseTagOnReady,
    required this.releaseTagPush,
    required this.releaseTagPrefix,
    required this.planningAuditEnabled,
    required this.planningAuditCadenceSteps,
    required this.planningAuditMaxAdd,
    required this.resourceCheckEnabled,
    required this.maxStashEntries,
    required this.maxWallclockHours,
    required this.maxSelfRestarts,
    required this.maxIterationsSafetyLimit,
    required this.preflightTimeout,
    required this.subtaskQueueMax,
    required this.pushFailureThreshold,
    required this.providerFailureThreshold,
    required this.reviewContractLockEnabled,
    required this.preflightRepairThreshold,
    required this.maxPreflightRepairAttempts,
    required this.lockHeartbeatHaltThreshold,
    required this.adaptiveSleepEnabled,
    required this.adaptiveSleepMaxMultiplier,
    required this.taskDependenciesEnabled,
    required this.sprintPlanningEnabled,
    required this.maxSprints,
    required this.sprintSize,
  });

  factory AutopilotConfig.fromProjectConfig(ProjectConfig c) => AutopilotConfig(
    minOpenTasks: c.autopilotMinOpenTasks,
    maxPlanAdd: c.autopilotMaxPlanAdd,
    stepSleep: c.autopilotStepSleep,
    idleSleep: c.autopilotIdleSleep,
    maxSteps: c.autopilotMaxSteps,
    maxFailures: c.autopilotMaxFailures,
    maxTaskRetries: c.autopilotMaxTaskRetries,
    selectionMode: c.autopilotSelectionMode,
    fairnessWindow: c.autopilotFairnessWindow,
    priorityWeightP1: c.autopilotPriorityWeightP1,
    priorityWeightP2: c.autopilotPriorityWeightP2,
    priorityWeightP3: c.autopilotPriorityWeightP3,
    reactivateBlocked: c.autopilotReactivateBlocked,
    reactivateFailed: c.autopilotReactivateFailed,
    blockedCooldown: c.autopilotBlockedCooldown,
    failedCooldown: c.autopilotFailedCooldown,
    lockTtl: c.autopilotLockTtl,
    noProgressThreshold: c.autopilotNoProgressThreshold,
    stuckCooldown: c.autopilotStuckCooldown,
    selfRestart: c.autopilotSelfRestart,
    selfHealEnabled: c.autopilotSelfHealEnabled,
    selfHealMaxAttempts: c.autopilotSelfHealMaxAttempts,
    scopeMaxFiles: c.autopilotScopeMaxFiles,
    scopeMaxAdditions: c.autopilotScopeMaxAdditions,
    scopeMaxDeletions: c.autopilotScopeMaxDeletions,
    approveBudget: c.autopilotApproveBudget,
    manualOverride: c.autopilotManualOverride,
    overnightUnattendedEnabled: c.autopilotOvernightUnattendedEnabled,
    selfTuneEnabled: c.autopilotSelfTuneEnabled,
    selfTuneWindow: c.autopilotSelfTuneWindow,
    selfTuneMinSamples: c.autopilotSelfTuneMinSamples,
    selfTuneSuccessPercent: c.autopilotSelfTuneSuccessPercent,
    releaseTagOnReady: c.autopilotReleaseTagOnReady,
    releaseTagPush: c.autopilotReleaseTagPush,
    releaseTagPrefix: c.autopilotReleaseTagPrefix,
    planningAuditEnabled: c.autopilotPlanningAuditEnabled,
    planningAuditCadenceSteps: c.autopilotPlanningAuditCadenceSteps,
    planningAuditMaxAdd: c.autopilotPlanningAuditMaxAdd,
    resourceCheckEnabled: c.autopilotResourceCheckEnabled,
    maxStashEntries: c.autopilotMaxStashEntries,
    maxWallclockHours: c.autopilotMaxWallclockHours,
    maxSelfRestarts: c.autopilotMaxSelfRestarts,
    maxIterationsSafetyLimit: c.autopilotMaxIterationsSafetyLimit,
    preflightTimeout: c.autopilotPreflightTimeout,
    subtaskQueueMax: c.autopilotSubtaskQueueMax,
    pushFailureThreshold: c.autopilotPushFailureThreshold,
    providerFailureThreshold: c.autopilotProviderFailureThreshold,
    reviewContractLockEnabled: c.autopilotReviewContractLockEnabled,
    preflightRepairThreshold: c.autopilotPreflightRepairThreshold,
    maxPreflightRepairAttempts: c.autopilotMaxPreflightRepairAttempts,
    lockHeartbeatHaltThreshold: c.autopilotLockHeartbeatHaltThreshold,
    adaptiveSleepEnabled: c.autopilotAdaptiveSleepEnabled,
    adaptiveSleepMaxMultiplier: c.autopilotAdaptiveSleepMaxMultiplier,
    taskDependenciesEnabled: c.autopilotTaskDependenciesEnabled,
    sprintPlanningEnabled: c.autopilotSprintPlanningEnabled,
    maxSprints: c.autopilotMaxSprints,
    sprintSize: c.autopilotSprintSize,
  );

  final int minOpenTasks;
  final int maxPlanAdd;
  final Duration stepSleep;
  final Duration idleSleep;
  final int? maxSteps;
  final int maxFailures;
  final int maxTaskRetries;
  final String selectionMode;
  final int fairnessWindow;
  final int priorityWeightP1;
  final int priorityWeightP2;
  final int priorityWeightP3;
  final bool reactivateBlocked;
  final bool reactivateFailed;
  final Duration blockedCooldown;
  final Duration failedCooldown;
  final Duration lockTtl;
  final int noProgressThreshold;
  final Duration stuckCooldown;
  final bool selfRestart;
  final bool selfHealEnabled;
  final int selfHealMaxAttempts;
  final int scopeMaxFiles;
  final int scopeMaxAdditions;
  final int scopeMaxDeletions;
  final int approveBudget;
  final bool manualOverride;
  final bool overnightUnattendedEnabled;
  final bool selfTuneEnabled;
  final int selfTuneWindow;
  final int selfTuneMinSamples;
  final int selfTuneSuccessPercent;
  final bool releaseTagOnReady;
  final bool releaseTagPush;
  final String releaseTagPrefix;
  final bool planningAuditEnabled;
  final int planningAuditCadenceSteps;
  final int planningAuditMaxAdd;
  final bool resourceCheckEnabled;
  final int maxStashEntries;
  final int maxWallclockHours;
  final int maxSelfRestarts;
  final int maxIterationsSafetyLimit;
  final Duration preflightTimeout;
  final int subtaskQueueMax;
  final int pushFailureThreshold;
  final int providerFailureThreshold;
  final bool reviewContractLockEnabled;
  final int preflightRepairThreshold;
  final int maxPreflightRepairAttempts;
  final int lockHeartbeatHaltThreshold;
  final bool adaptiveSleepEnabled;
  final int adaptiveSleepMaxMultiplier;
  final bool taskDependenciesEnabled;
  final bool sprintPlanningEnabled;
  final int maxSprints;
  final int sprintSize;
}
