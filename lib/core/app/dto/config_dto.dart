// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class AppConfigDto {
  const AppConfigDto({
    required this.gitBaseBranch,
    required this.gitFeaturePrefix,
    required this.gitAutoStash,
    required this.safeWriteEnabled,
    required this.safeWriteRoots,
    required this.shellAllowlist,
    required this.shellAllowlistProfile,
    required this.diffBudgetMaxFiles,
    required this.diffBudgetMaxAdditions,
    required this.diffBudgetMaxDeletions,
    required this.autopilotMinOpenTasks,
    required this.autopilotMaxPlanAdd,
    required this.autopilotStepSleepSeconds,
    required this.autopilotIdleSleepSeconds,
    required this.autopilotMaxSteps,
    required this.autopilotMaxFailures,
    required this.autopilotMaxTaskRetries,
    required this.autopilotSelectionMode,
    required this.autopilotFairnessWindow,
    required this.autopilotPriorityWeightP1,
    required this.autopilotPriorityWeightP2,
    required this.autopilotPriorityWeightP3,
    required this.autopilotReactivateBlocked,
    required this.autopilotReactivateFailed,
    required this.autopilotBlockedCooldownSeconds,
    required this.autopilotFailedCooldownSeconds,
    required this.autopilotLockTtlSeconds,
    required this.autopilotNoProgressThreshold,
    required this.autopilotStuckCooldownSeconds,
    required this.autopilotSelfRestart,
    required this.autopilotScopeMaxFiles,
    required this.autopilotScopeMaxAdditions,
    required this.autopilotScopeMaxDeletions,
    required this.autopilotApproveBudget,
    required this.autopilotManualOverride,
    this.autopilotOvernightUnattendedEnabled = false,
    required this.autopilotSelfTuneEnabled,
    required this.autopilotSelfTuneWindow,
    required this.autopilotSelfTuneMinSamples,
    required this.autopilotSelfTuneSuccessPercent,
  });

  final String gitBaseBranch;
  final String gitFeaturePrefix;
  final bool gitAutoStash;
  final bool safeWriteEnabled;
  final List<String> safeWriteRoots;
  final List<String> shellAllowlist;
  final String shellAllowlistProfile;
  final int diffBudgetMaxFiles;
  final int diffBudgetMaxAdditions;
  final int diffBudgetMaxDeletions;

  final int autopilotMinOpenTasks;
  final int autopilotMaxPlanAdd;
  final int autopilotStepSleepSeconds;
  final int autopilotIdleSleepSeconds;
  final int? autopilotMaxSteps;
  final int autopilotMaxFailures;
  final int autopilotMaxTaskRetries;
  final String autopilotSelectionMode;
  final int autopilotFairnessWindow;
  final int autopilotPriorityWeightP1;
  final int autopilotPriorityWeightP2;
  final int autopilotPriorityWeightP3;
  final bool autopilotReactivateBlocked;
  final bool autopilotReactivateFailed;
  final int autopilotBlockedCooldownSeconds;
  final int autopilotFailedCooldownSeconds;
  final int autopilotLockTtlSeconds;
  final int autopilotNoProgressThreshold;
  final int autopilotStuckCooldownSeconds;
  final bool autopilotSelfRestart;
  final int autopilotScopeMaxFiles;
  final int autopilotScopeMaxAdditions;
  final int autopilotScopeMaxDeletions;
  final int autopilotApproveBudget;
  final bool autopilotManualOverride;
  final bool autopilotOvernightUnattendedEnabled;
  final bool autopilotSelfTuneEnabled;
  final int autopilotSelfTuneWindow;
  final int autopilotSelfTuneMinSamples;
  final int autopilotSelfTuneSuccessPercent;
}

class ConfigUpdateDto {
  const ConfigUpdateDto({required this.updated, required this.config});

  final bool updated;
  final AppConfigDto config;
}
