// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'config_field_descriptor.dart';
import 'project_config.dart';

/// Single source of truth for all scalar config fields.
///
/// Each entry fully describes a config key: section, YAML key, Dart field name,
/// type, default value, and validation constraints. Parsing, schema validation,
/// and default resolution are all driven from this list.
///
/// **To add a new config key**: add one [ConfigFieldDescriptor] here, then add
/// the matching `final` field + constructor param on [ProjectConfig].
const List<ConfigFieldDescriptor> configFieldRegistry = [
  // ─────────────────────────────────────────────────────────────────────────
  // providers (scalar keys only — pool, CLI overrides, native, and category
  // maps remain in specialised parsers)
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'providers',
    yamlKey: 'quota_cooldown_seconds',
    dartFieldName: 'providerQuotaCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultProviderQuotaCooldownSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'providers',
    yamlKey: 'quota_pause_seconds',
    dartFieldName: 'providerQuotaPause',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultProviderQuotaPauseSeconds,
    minValue: 0,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // policies.diff_budget
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'policies.diff_budget',
    yamlKey: 'max_files',
    dartFieldName: 'diffBudgetMaxFiles',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultDiffBudgetMaxFiles,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'policies.diff_budget',
    yamlKey: 'max_additions',
    dartFieldName: 'diffBudgetMaxAdditions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultDiffBudgetMaxAdditions,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'policies.diff_budget',
    yamlKey: 'max_deletions',
    dartFieldName: 'diffBudgetMaxDeletions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultDiffBudgetMaxDeletions,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // policies (top-level under policies:)
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'policies',
    yamlKey: 'shell_allowlist_profile',
    dartFieldName: 'shellAllowlistProfile',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultShellAllowlistProfile,
    validValues: ['minimal', 'standard', 'extended', 'custom'],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // policies.safe_write
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'policies.safe_write',
    yamlKey: 'enabled',
    dartFieldName: 'safeWriteEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: true,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // policies.quality_gate
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'enabled',
    dartFieldName: 'qualityGateEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGateEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'timeout_seconds',
    dartFieldName: 'qualityGateTimeout',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultQualityGateTimeoutSeconds,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'adaptive_by_diff',
    dartFieldName: 'qualityGateAdaptiveByDiff',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGateAdaptiveByDiff,
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'skip_tests_for_docs_only',
    dartFieldName: 'qualityGateSkipTestsForDocsOnly',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGateSkipTestsForDocsOnly,
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'prefer_dart_test_for_lib_dart_only',
    dartFieldName: 'qualityGatePreferDartTestForLibDartOnly',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGatePreferDartTestForLibDartOnly,
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'flake_retry_count',
    dartFieldName: 'qualityGateFlakeRetryCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultQualityGateFlakeRetryCount,
    minValue: 0,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // policies.timeouts
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'policies.timeouts',
    yamlKey: 'agent_seconds',
    dartFieldName: 'agentTimeout',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAgentTimeoutSeconds,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // git
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'base_branch',
    dartFieldName: 'gitBaseBranch',
    type: ConfigFieldType.string_,
    defaultValue: 'main',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'feature_prefix',
    dartFieldName: 'gitFeaturePrefix',
    type: ConfigFieldType.string_,
    defaultValue: 'feat/',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_delete_remote_merged_branches',
    dartFieldName: 'gitAutoDeleteRemoteMergedBranches',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoDeleteRemoteMergedBranches,
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash',
    dartFieldName: 'gitAutoStash',
    type: ConfigFieldType.bool_,
    defaultValue: false,
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash_skip_rejected',
    dartFieldName: 'gitAutoStashSkipRejected',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoStashSkipRejected,
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash_skip_rejected_unattended',
    dartFieldName: 'gitAutoStashSkipRejectedUnattended',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoStashSkipRejectedUnattended,
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'sync_between_loops',
    dartFieldName: 'gitSyncBetweenLoops',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitSyncBetweenLoops,
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'sync_strategy',
    dartFieldName: 'gitSyncStrategy',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultGitSyncStrategy,
    validValues: ['fetch_only', 'pull_ff'],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // workflow
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'require_review',
    dartFieldName: 'workflowRequireReview',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowRequireReview,
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_commit',
    dartFieldName: 'workflowAutoCommit',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoCommit,
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_push',
    dartFieldName: 'workflowAutoPush',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoPush,
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_merge',
    dartFieldName: 'workflowAutoMerge',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoMerge,
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'merge_strategy',
    dartFieldName: 'workflowMergeStrategy',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultWorkflowMergeStrategy,
    validValues: ['merge', 'rebase_before_merge'],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // autopilot
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'min_open',
    dartFieldName: 'autopilotMinOpenTasks',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMinOpenTasks,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_plan_add',
    dartFieldName: 'autopilotMaxPlanAdd',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxPlanAdd,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'step_sleep_seconds',
    dartFieldName: 'autopilotStepSleep',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotStepSleepSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'idle_sleep_seconds',
    dartFieldName: 'autopilotIdleSleep',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotIdleSleepSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_steps',
    dartFieldName: 'autopilotMaxSteps',
    type: ConfigFieldType.int_,
    defaultValue: null,
    nullable: true,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_failures',
    dartFieldName: 'autopilotMaxFailures',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxFailures,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_task_retries',
    dartFieldName: 'autopilotMaxTaskRetries',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxTaskRetries,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'selection_mode',
    dartFieldName: 'autopilotSelectionMode',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultAutopilotSelectionMode,
    validValues: ['fair', 'fairness', 'priority', 'strict_priority', 'strict-priority'],
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'fairness_window',
    dartFieldName: 'autopilotFairnessWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotFairnessWindow,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p1',
    dartFieldName: 'autopilotPriorityWeightP1',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP1,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p2',
    dartFieldName: 'autopilotPriorityWeightP2',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP2,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p3',
    dartFieldName: 'autopilotPriorityWeightP3',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP3,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'reactivate_blocked',
    dartFieldName: 'autopilotReactivateBlocked',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReactivateBlocked,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'reactivate_failed',
    dartFieldName: 'autopilotReactivateFailed',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReactivateFailed,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'blocked_cooldown_seconds',
    dartFieldName: 'autopilotBlockedCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotBlockedCooldownSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'failed_cooldown_seconds',
    dartFieldName: 'autopilotFailedCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotFailedCooldownSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'lock_ttl_seconds',
    dartFieldName: 'autopilotLockTtl',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotLockTtlSeconds,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'no_progress_threshold',
    dartFieldName: 'autopilotNoProgressThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotNoProgressThreshold,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'stuck_cooldown_seconds',
    dartFieldName: 'autopilotStuckCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotStuckCooldownSeconds,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_restart',
    dartFieldName: 'autopilotSelfRestart',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfRestart,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_heal_enabled',
    dartFieldName: 'autopilotSelfHealEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfHealEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_heal_max_attempts',
    dartFieldName: 'autopilotSelfHealMaxAttempts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfHealMaxAttempts,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_files',
    dartFieldName: 'autopilotScopeMaxFiles',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxFiles,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_additions',
    dartFieldName: 'autopilotScopeMaxAdditions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxAdditions,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_deletions',
    dartFieldName: 'autopilotScopeMaxDeletions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxDeletions,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'approve_budget',
    dartFieldName: 'autopilotApproveBudget',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotApproveBudget,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'manual_override',
    dartFieldName: 'autopilotManualOverride',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotManualOverride,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'overnight_unattended_enabled',
    dartFieldName: 'autopilotOvernightUnattendedEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotOvernightUnattendedEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_enabled',
    dartFieldName: 'autopilotSelfTuneEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_window',
    dartFieldName: 'autopilotSelfTuneWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneWindow,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_min_samples',
    dartFieldName: 'autopilotSelfTuneMinSamples',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneMinSamples,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_success_percent',
    dartFieldName: 'autopilotSelfTuneSuccessPercent',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneSuccessPercent,
    minValue: 0,
    maxValue: 100,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_on_ready',
    dartFieldName: 'autopilotReleaseTagOnReady',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagOnReady,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_push',
    dartFieldName: 'autopilotReleaseTagPush',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagPush,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_prefix',
    dartFieldName: 'autopilotReleaseTagPrefix',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagPrefix,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_enabled',
    dartFieldName: 'autopilotPlanningAuditEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_cadence_steps',
    dartFieldName: 'autopilotPlanningAuditCadenceSteps',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditCadenceSteps,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_max_add',
    dartFieldName: 'autopilotPlanningAuditMaxAdd',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditMaxAdd,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'resource_check_enabled',
    dartFieldName: 'autopilotResourceCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotResourceCheckEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_stash_entries',
    dartFieldName: 'autopilotMaxStashEntries',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxStashEntries,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_wallclock_hours',
    dartFieldName: 'autopilotMaxWallclockHours',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxWallclockHours,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_self_restarts',
    dartFieldName: 'autopilotMaxSelfRestarts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxSelfRestarts,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_iterations_safety_limit',
    dartFieldName: 'autopilotMaxIterationsSafetyLimit',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxIterationsSafetyLimit,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'preflight_timeout_seconds',
    dartFieldName: 'autopilotPreflightTimeout',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotPreflightTimeoutSeconds,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'subtask_queue_max',
    dartFieldName: 'autopilotSubtaskQueueMax',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSubtaskQueueMax,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'push_failure_threshold',
    dartFieldName: 'autopilotPushFailureThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPushFailureThreshold,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'provider_failure_threshold',
    dartFieldName: 'autopilotProviderFailureThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotProviderFailureThreshold,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'review_contract_lock_enabled',
    dartFieldName: 'autopilotReviewContractLockEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReviewContractLockEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'preflight_repair_threshold',
    dartFieldName: 'autopilotPreflightRepairThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPreflightRepairThreshold,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_preflight_repair_attempts',
    dartFieldName: 'autopilotMaxPreflightRepairAttempts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxPreflightRepairAttempts,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'lock_heartbeat_halt_threshold',
    dartFieldName: 'autopilotLockHeartbeatHaltThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotLockHeartbeatHaltThreshold,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'sprint_planning_enabled',
    dartFieldName: 'autopilotSprintPlanningEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSprintPlanningEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_sprints',
    dartFieldName: 'autopilotMaxSprints',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxSprints,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'sprint_size',
    dartFieldName: 'autopilotSprintSize',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSprintSize,
    minValue: 1,
    maxValue: 50,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // pipeline
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'context_injection_enabled',
    dartFieldName: 'pipelineContextInjectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineContextInjectionEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'context_injection_max_tokens',
    dartFieldName: 'pipelineContextInjectionMaxTokens',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineContextInjectionMaxTokens,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'error_pattern_injection_enabled',
    dartFieldName: 'pipelineErrorPatternInjectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineErrorPatternInjectionEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'impact_analysis_enabled',
    dartFieldName: 'pipelineImpactAnalysisEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineImpactAnalysisEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'architecture_gate_enabled',
    dartFieldName: 'pipelineArchitectureGateEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineArchitectureGateEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'forensic_recovery_enabled',
    dartFieldName: 'pipelineForensicRecoveryEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineForensicRecoveryEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'error_pattern_learning_enabled',
    dartFieldName: 'pipelineErrorPatternLearningEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineErrorPatternLearningEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'impact_context_max_files',
    dartFieldName: 'pipelineImpactContextMaxFiles',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineImpactContextMaxFiles,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_refinement_enabled',
    dartFieldName: 'pipelineSubtaskRefinementEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskRefinementEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_feasibility_enabled',
    dartFieldName: 'pipelineSubtaskFeasibilityEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskFeasibilityEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'ac_self_check_enabled',
    dartFieldName: 'pipelineAcSelfCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineAcSelfCheckEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_commit_enabled',
    dartFieldName: 'pipelineSubtaskCommitEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskCommitEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_forced_narrowing_max_size',
    dartFieldName: 'subtaskForcedNarrowingMaxSize',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultSubtaskForcedNarrowingMaxSize,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // review
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'fresh_context',
    dartFieldName: 'reviewFreshContext',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultReviewFreshContext,
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'strictness',
    dartFieldName: 'reviewStrictness',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReviewStrictness,
    validValues: ['strict', 'standard', 'lenient'],
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'max_rounds',
    dartFieldName: 'reviewMaxRounds',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReviewMaxRounds,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'require_evidence',
    dartFieldName: 'reviewRequireEvidence',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultReviewRequireEvidence,
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'evidence_min_length',
    dartFieldName: 'reviewEvidenceMinLength',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReviewEvidenceMinLength,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // reflection
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'enabled',
    dartFieldName: 'reflectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultReflectionEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_mode',
    dartFieldName: 'reflectionTriggerMode',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReflectionTriggerMode,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_loop_count',
    dartFieldName: 'reflectionTriggerLoopCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerLoopCount,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_task_count',
    dartFieldName: 'reflectionTriggerTaskCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerTaskCount,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_hours',
    dartFieldName: 'reflectionTriggerHours',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerHours,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'min_samples',
    dartFieldName: 'reflectionMinSamples',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionMinSamples,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'max_optimization_tasks',
    dartFieldName: 'reflectionMaxOptimizationTasks',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionMaxOptimizationTasks,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'optimization_task_priority',
    dartFieldName: 'reflectionOptimizationPriority',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReflectionOptimizationPriority,
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'analysis_window_lines',
    dartFieldName: 'reflectionAnalysisWindowLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionAnalysisWindowLines,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // supervisor
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'supervisor',
    yamlKey: 'reflection_on_halt',
    dartFieldName: 'supervisorReflectionOnHalt',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultSupervisorReflectionOnHalt,
  ),
  ConfigFieldDescriptor(
    section: 'supervisor',
    yamlKey: 'max_interventions_per_hour',
    dartFieldName: 'supervisorMaxInterventionsPerHour',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultSupervisorMaxInterventionsPerHour,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'supervisor',
    yamlKey: 'check_interval_seconds',
    dartFieldName: 'supervisorCheckInterval',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultSupervisorCheckIntervalSeconds,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // code_health
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'enabled',
    dartFieldName: 'codeHealthEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'auto_create_tasks',
    dartFieldName: 'codeHealthAutoCreateTasks',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthAutoCreateTasks,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'min_confidence',
    dartFieldName: 'codeHealthMinConfidence',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthMinConfidence,
    minValue: 0.0,
    maxValue: 1.0,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_refactor_ratio',
    dartFieldName: 'codeHealthMaxRefactorRatio',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxRefactorRatio,
    minValue: 0.0,
    maxValue: 1.0,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_file_lines',
    dartFieldName: 'codeHealthMaxFileLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxFileLines,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_method_lines',
    dartFieldName: 'codeHealthMaxMethodLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxMethodLines,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_nesting_depth',
    dartFieldName: 'codeHealthMaxNestingDepth',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxNestingDepth,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_parameter_count',
    dartFieldName: 'codeHealthMaxParameterCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxParameterCount,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'hotspot_threshold',
    dartFieldName: 'codeHealthHotspotThreshold',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthHotspotThreshold,
    minValue: 0.0,
    maxValue: 1.0,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'hotspot_window',
    dartFieldName: 'codeHealthHotspotWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthHotspotWindow,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'patch_cluster_min',
    dartFieldName: 'codeHealthPatchClusterMin',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthPatchClusterMin,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'reflection_enabled',
    dartFieldName: 'codeHealthReflectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthReflectionEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'reflection_cadence',
    dartFieldName: 'codeHealthReflectionCadence',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthReflectionCadence,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'llm_budget_tokens',
    dartFieldName: 'codeHealthLlmBudgetTokens',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthLlmBudgetTokens,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'block_features',
    dartFieldName: 'codeHealthBlockFeatures',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthBlockFeatures,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // vision_evaluation
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'vision_evaluation',
    yamlKey: 'enabled',
    dartFieldName: 'visionEvaluationEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultVisionEvaluationEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'vision_evaluation',
    yamlKey: 'interval',
    dartFieldName: 'visionEvaluationInterval',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultVisionEvaluationInterval,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'vision_evaluation',
    yamlKey: 'completion_threshold',
    dartFieldName: 'visionCompletionThreshold',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultVisionCompletionThreshold,
    minValue: 0.0,
    maxValue: 1.0,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // autopilot (Wave 2 additions)
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'adaptive_sleep_enabled',
    dartFieldName: 'autopilotAdaptiveSleepEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotAdaptiveSleepEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'adaptive_sleep_max_multiplier',
    dartFieldName: 'autopilotAdaptiveSleepMaxMultiplier',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotAdaptiveSleepMaxMultiplier,
    minValue: 1,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'task_dependencies_enabled',
    dartFieldName: 'autopilotTaskDependenciesEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotTaskDependenciesEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'vision_drift_check_enabled',
    dartFieldName: 'visionDriftCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultVisionDriftCheckEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'vision_drift_check_interval',
    dartFieldName: 'visionDriftCheckInterval',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultVisionDriftCheckInterval,
    minValue: 1,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // hitl
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'enabled',
    dartFieldName: 'hitlEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'timeout_minutes',
    dartFieldName: 'hitlTimeoutMinutes',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultHitlTimeoutMinutes,
    minValue: 0,
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_after_task_done',
    dartFieldName: 'hitlGateAfterTaskDone',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateAfterTaskDone,
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_before_sprint',
    dartFieldName: 'hitlGateBeforeSprint',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateBeforeSprint,
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_before_halt',
    dartFieldName: 'hitlGateBeforeHalt',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateBeforeHalt,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // pipeline (Wave 2 additions)
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'test_delta_gate_enabled',
    dartFieldName: 'pipelineTestDeltaGateEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineTestDeltaGateEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'lessons_learned_enabled',
    dartFieldName: 'pipelineLessonsLearnedEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineLessonsLearnedEnabled,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'lessons_learned_max_lines',
    dartFieldName: 'pipelineLessonsLearnedMaxLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineLessonsLearnedMaxLines,
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'final_ac_check_enabled',
    dartFieldName: 'pipelineFinalAcCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineFinalAcCheckEnabled,
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // review (Wave 2 additions)
  // ─────────────────────────────────────────────────────────────────────────
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'diff_delta_enabled',
    dartFieldName: 'reviewDiffDeltaEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultReviewDiffDeltaEnabled,
  ),
];

// ───────────────────────────────────────────────────────────────────────────
// Lookup helpers
// ───────────────────────────────────────────────────────────────────────────

/// Index: dartFieldName → descriptor.  Built lazily on first access.
final Map<String, ConfigFieldDescriptor> _byDartField = {
  for (final f in configFieldRegistry) f.dartFieldName: f,
};

/// Index: qualifiedKey → descriptor.  Built lazily on first access.
final Map<String, ConfigFieldDescriptor> _byQualifiedKey = {
  for (final f in configFieldRegistry) f.qualifiedKey: f,
};

/// Lookup by Dart field name (e.g. `'autopilotMaxTaskRetries'`).
ConfigFieldDescriptor? registryFieldByDartName(String dartFieldName) =>
    _byDartField[dartFieldName];

/// Lookup by qualified YAML key (e.g. `'autopilot.max_task_retries'`).
ConfigFieldDescriptor? registryFieldByQualifiedKey(String qualifiedKey) =>
    _byQualifiedKey[qualifiedKey];

/// All fields belonging to a given section (e.g. `'autopilot'`).
Iterable<ConfigFieldDescriptor> registryFieldsForSection(String section) =>
    configFieldRegistry.where((f) => f.section == section);

/// All distinct section names in the registry.
Set<String> get registrySections =>
    configFieldRegistry.map((f) => f.section).toSet();
