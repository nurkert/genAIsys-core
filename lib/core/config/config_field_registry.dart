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
    description:
        'Seconds to wait after a provider exhausts its API quota before retrying.',
  ),
  ConfigFieldDescriptor(
    section: 'providers',
    yamlKey: 'quota_pause_seconds',
    dartFieldName: 'providerQuotaPause',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultProviderQuotaPauseSeconds,
    minValue: 0,
    description:
        'Seconds to pause before falling back to the next provider in the pool after a quota event.',
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
    description: 'Maximum number of files changed per step.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.diff_budget',
    yamlKey: 'max_additions',
    dartFieldName: 'diffBudgetMaxAdditions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultDiffBudgetMaxAdditions,
    minValue: 1,
    description: 'Maximum lines added per step.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.diff_budget',
    yamlKey: 'max_deletions',
    dartFieldName: 'diffBudgetMaxDeletions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultDiffBudgetMaxDeletions,
    minValue: 1,
    description: 'Maximum lines deleted per step.',
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
    description:
        'Shell allowlist profile. Determines which shell commands agents may execute.',
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
    description:
        'Enable Safe-Write policy enforcement. When disabled, agents may write to any path.',
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
    description: 'Enable the quality gate pipeline.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'timeout_seconds',
    dartFieldName: 'qualityGateTimeout',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultQualityGateTimeoutSeconds,
    minValue: 1,
    description:
        'Maximum time in seconds for the full quality gate to complete.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'adaptive_by_diff',
    dartFieldName: 'qualityGateAdaptiveByDiff',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGateAdaptiveByDiff,
    description:
        'Enable adaptive diff mode to adjust checks based on change type.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'skip_tests_for_docs_only',
    dartFieldName: 'qualityGateSkipTestsForDocsOnly',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGateSkipTestsForDocsOnly,
    description: 'Skip test execution for documentation-only changes.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'prefer_dart_test_for_lib_dart_only',
    dartFieldName: 'qualityGatePreferDartTestForLibDartOnly',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultQualityGatePreferDartTestForLibDartOnly,
    description:
        'Use dart test instead of flutter test when changes touch only lib/ Dart files.',
  ),
  ConfigFieldDescriptor(
    section: 'policies.quality_gate',
    yamlKey: 'flake_retry_count',
    dartFieldName: 'qualityGateFlakeRetryCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultQualityGateFlakeRetryCount,
    minValue: 0,
    description: 'Number of automatic retries for flaky test failures.',
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
    description:
        'Default timeout in seconds for agent invocations. Overridden per category by providers.agent_seconds_by_category.',
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
    description: 'The base branch for merges and diff comparison.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'feature_prefix',
    dartFieldName: 'gitFeaturePrefix',
    type: ConfigFieldType.string_,
    defaultValue: 'feat/',
    description: 'Prefix for feature branches created per task.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_delete_remote_merged_branches',
    dartFieldName: 'gitAutoDeleteRemoteMergedBranches',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoDeleteRemoteMergedBranches,
    description: 'Delete remote branches after successful merge.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash',
    dartFieldName: 'gitAutoStash',
    type: ConfigFieldType.bool_,
    defaultValue: false,
    description: 'Automatically stash dirty worktree before operations.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash_skip_rejected',
    dartFieldName: 'gitAutoStashSkipRejected',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoStashSkipRejected,
    description: 'Skip auto-stash when context was rejected by review.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'auto_stash_skip_rejected_unattended',
    dartFieldName: 'gitAutoStashSkipRejectedUnattended',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitAutoStashSkipRejectedUnattended,
    description:
        'Override auto_stash_skip_rejected in unattended mode (stash rejected context instead of skipping).',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'sync_between_loops',
    dartFieldName: 'gitSyncBetweenLoops',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultGitSyncBetweenLoops,
    description: 'Perform git sync between autopilot loop iterations.',
  ),
  ConfigFieldDescriptor(
    section: 'git',
    yamlKey: 'sync_strategy',
    dartFieldName: 'gitSyncStrategy',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultGitSyncStrategy,
    validValues: ['fetch_only', 'pull_ff'],
    description: 'Strategy for inter-loop git synchronization.',
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
    description:
        'Require review approval before task completion. When false, tasks skip the review gate.',
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_commit',
    dartFieldName: 'workflowAutoCommit',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoCommit,
    description: 'Automatically commit agent-produced diffs.',
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_push',
    dartFieldName: 'workflowAutoPush',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoPush,
    description: 'Automatically push committed changes to the remote.',
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'auto_merge',
    dartFieldName: 'workflowAutoMerge',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultWorkflowAutoMerge,
    description:
        'Automatically merge approved feature branches into the base branch.',
  ),
  ConfigFieldDescriptor(
    section: 'workflow',
    yamlKey: 'merge_strategy',
    dartFieldName: 'workflowMergeStrategy',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultWorkflowMergeStrategy,
    validValues: ['merge', 'rebase_before_merge'],
    description:
        'Git merge strategy. rebase_before_merge rebases the feature branch onto base before merging.',
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
    description:
        'Minimum open tasks to maintain in the backlog. Triggers planning when count drops below.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_plan_add',
    dartFieldName: 'autopilotMaxPlanAdd',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxPlanAdd,
    minValue: 1,
    description:
        'Maximum number of tasks a single planning pass may add to the backlog.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'step_sleep_seconds',
    dartFieldName: 'autopilotStepSleep',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotStepSleepSeconds,
    minValue: 0,
    description: 'Seconds to sleep between consecutive steps.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'idle_sleep_seconds',
    dartFieldName: 'autopilotIdleSleep',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotIdleSleepSeconds,
    minValue: 0,
    description: 'Seconds to sleep when no task is ready (idle step).',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_steps',
    dartFieldName: 'autopilotMaxSteps',
    type: ConfigFieldType.int_,
    defaultValue: null,
    nullable: true,
    minValue: 1,
    description:
        'Maximum number of steps before automatic termination. null means unlimited.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_failures',
    dartFieldName: 'autopilotMaxFailures',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxFailures,
    minValue: 1,
    description: 'Maximum total failures before safety halt.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_task_retries',
    dartFieldName: 'autopilotMaxTaskRetries',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxTaskRetries,
    minValue: 1,
    description: 'Maximum retry attempts per task before blocking it.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'selection_mode',
    dartFieldName: 'autopilotSelectionMode',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultAutopilotSelectionMode,
    validValues: [
      'fair',
      'fairness',
      'priority',
      'strict_priority',
      'strict-priority',
    ],
    description:
        'Task selection algorithm. strict_priority always picks the highest-priority task. fair uses priority-weighted round-robin within a fairness window.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'fairness_window',
    dartFieldName: 'autopilotFairnessWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotFairnessWindow,
    minValue: 1,
    description:
        'Number of recent steps considered for fairness rotation in fair selection mode.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p1',
    dartFieldName: 'autopilotPriorityWeightP1',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP1,
    minValue: 1,
    description:
        'Selection weight for P1 tasks. Higher weights win over lower-priority work when the scheduler picks the next task.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p2',
    dartFieldName: 'autopilotPriorityWeightP2',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP2,
    minValue: 1,
    description:
        'Selection weight for P2 tasks, relative to the other priority weights.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'priority_weight_p3',
    dartFieldName: 'autopilotPriorityWeightP3',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPriorityWeightP3,
    minValue: 1,
    description:
        'Selection weight for P3 tasks, relative to the other priority weights.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'reactivate_blocked',
    dartFieldName: 'autopilotReactivateBlocked',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReactivateBlocked,
    description: 'Automatically reactivate blocked tasks after cooldown.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'reactivate_failed',
    dartFieldName: 'autopilotReactivateFailed',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReactivateFailed,
    description: 'Automatically reactivate failed tasks after cooldown.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'blocked_cooldown_seconds',
    dartFieldName: 'autopilotBlockedCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotBlockedCooldownSeconds,
    minValue: 0,
    description:
        'Seconds before a blocked task becomes eligible for reactivation.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'failed_cooldown_seconds',
    dartFieldName: 'autopilotFailedCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotFailedCooldownSeconds,
    minValue: 0,
    description:
        'Seconds before a failed task becomes eligible for reactivation.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'lock_ttl_seconds',
    dartFieldName: 'autopilotLockTtl',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotLockTtlSeconds,
    minValue: 1,
    description: 'Time-to-live for the autopilot lock file.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'no_progress_threshold',
    dartFieldName: 'autopilotNoProgressThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotNoProgressThreshold,
    minValue: 0,
    description:
        'Consecutive no-progress steps before triggering stuck detection.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'stuck_cooldown_seconds',
    dartFieldName: 'autopilotStuckCooldown',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotStuckCooldownSeconds,
    minValue: 0,
    description: 'Seconds to wait after stuck detection before resuming.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_restart',
    dartFieldName: 'autopilotSelfRestart',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfRestart,
    description: 'Enable automatic restart after recoverable failures.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_heal_enabled',
    dartFieldName: 'autopilotSelfHealEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfHealEnabled,
    description:
        'Enable self-heal mechanisms for git state, config drift, and stuck locks.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_heal_max_attempts',
    dartFieldName: 'autopilotSelfHealMaxAttempts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfHealMaxAttempts,
    minValue: 0,
    description: 'Maximum self-heal attempts per incident before escalating.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_files',
    dartFieldName: 'autopilotScopeMaxFiles',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxFiles,
    minValue: 0,
    description:
        'Maximum files an agent may modify in a single step. 0 = unlimited.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_additions',
    dartFieldName: 'autopilotScopeMaxAdditions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxAdditions,
    minValue: 0,
    description: 'Maximum lines added per step. 0 = unlimited.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'scope_max_deletions',
    dartFieldName: 'autopilotScopeMaxDeletions',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotScopeMaxDeletions,
    minValue: 0,
    description: 'Maximum lines deleted per step. 0 = unlimited.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'approve_budget',
    dartFieldName: 'autopilotApproveBudget',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotApproveBudget,
    minValue: 0,
    description: 'Maximum auto-approvals per run. See Approve Budget.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'manual_override',
    dartFieldName: 'autopilotManualOverride',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotManualOverride,
    description:
        'When true, allows manual intervention to override autopilot decisions.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'overnight_unattended_enabled',
    dartFieldName: 'autopilotOvernightUnattendedEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotOvernightUnattendedEnabled,
    description: 'Enable overnight unattended execution mode.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_enabled',
    dartFieldName: 'autopilotSelfTuneEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneEnabled,
    description:
        'Enable self-tune parameter adjustments based on observed performance.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_window',
    dartFieldName: 'autopilotSelfTuneWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneWindow,
    minValue: 1,
    description: 'Number of recent steps analyzed for self-tuning decisions.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_min_samples',
    dartFieldName: 'autopilotSelfTuneMinSamples',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneMinSamples,
    minValue: 1,
    description:
        'Minimum samples required before self-tune adjusts parameters.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'self_tune_success_percent',
    dartFieldName: 'autopilotSelfTuneSuccessPercent',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSelfTuneSuccessPercent,
    minValue: 0,
    maxValue: 100,
    description: 'Target success percentage for self-tune optimization.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_on_ready',
    dartFieldName: 'autopilotReleaseTagOnReady',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagOnReady,
    description:
        'Automatically create a git tag when all tasks reach "done" state.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_push',
    dartFieldName: 'autopilotReleaseTagPush',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagPush,
    description: 'Push release tags to the remote.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'release_tag_prefix',
    dartFieldName: 'autopilotReleaseTagPrefix',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultAutopilotReleaseTagPrefix,
    description: 'Prefix for release tags (e.g., v produces v1.0.0).',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_enabled',
    dartFieldName: 'autopilotPlanningAuditEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditEnabled,
    description: 'Enable periodic planning audits that reassess the backlog.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_cadence_steps',
    dartFieldName: 'autopilotPlanningAuditCadenceSteps',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditCadenceSteps,
    minValue: 1,
    description: 'Steps between planning audit passes.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'planning_audit_max_add',
    dartFieldName: 'autopilotPlanningAuditMaxAdd',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPlanningAuditMaxAdd,
    minValue: 1,
    description: 'Maximum tasks a planning audit may add per pass.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'resource_check_enabled',
    dartFieldName: 'autopilotResourceCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotResourceCheckEnabled,
    description:
        'Check system resource availability (memory, disk) before each step.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_stash_entries',
    dartFieldName: 'autopilotMaxStashEntries',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxStashEntries,
    minValue: 1,
    description: 'Maximum git stash entries retained before cleanup.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_wallclock_hours',
    dartFieldName: 'autopilotMaxWallclockHours',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxWallclockHours,
    minValue: 1,
    description: 'Maximum wall-clock hours before forced termination.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_self_restarts',
    dartFieldName: 'autopilotMaxSelfRestarts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxSelfRestarts,
    minValue: 0,
    description: 'Maximum number of self-restarts per run.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_iterations_safety_limit',
    dartFieldName: 'autopilotMaxIterationsSafetyLimit',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxIterationsSafetyLimit,
    minValue: 1,
    description:
        'Hard ceiling on total loop iterations to prevent runaway execution.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'preflight_timeout_seconds',
    dartFieldName: 'autopilotPreflightTimeout',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultAutopilotPreflightTimeoutSeconds,
    minValue: 1,
    description: 'Timeout for preflight checks.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'subtask_queue_max',
    dartFieldName: 'autopilotSubtaskQueueMax',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSubtaskQueueMax,
    minValue: 1,
    description: 'Maximum number of subtasks queued per task.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'push_failure_threshold',
    dartFieldName: 'autopilotPushFailureThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPushFailureThreshold,
    minValue: 1,
    description: 'Consecutive push failures before halting.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'provider_failure_threshold',
    dartFieldName: 'autopilotProviderFailureThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotProviderFailureThreshold,
    minValue: 1,
    description: 'Consecutive provider failures before disabling the provider.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'review_contract_lock_enabled',
    dartFieldName: 'autopilotReviewContractLockEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotReviewContractLockEnabled,
    description:
        'Lock review contracts to prevent concurrent review modification.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'preflight_repair_threshold',
    dartFieldName: 'autopilotPreflightRepairThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotPreflightRepairThreshold,
    minValue: 1,
    description:
        'Consecutive preflight failures before autopilot attempts an automatic state repair.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_preflight_repair_attempts',
    dartFieldName: 'autopilotMaxPreflightRepairAttempts',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxPreflightRepairAttempts,
    minValue: 0,
    description:
        'Repair attempts allowed before autopilot stops with a safety halt instead of retrying.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'lock_heartbeat_halt_threshold',
    dartFieldName: 'autopilotLockHeartbeatHaltThreshold',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotLockHeartbeatHaltThreshold,
    minValue: 0,
    description:
        'Consecutive lock-heartbeat write failures before autopilot halts. 0 disables the halt.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'sprint_planning_enabled',
    dartFieldName: 'autopilotSprintPlanningEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotSprintPlanningEnabled,
    description:
        'Generate the next sprint automatically when the backlog empties, instead of stopping. Enabled by genaisys init --from.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'max_sprints',
    dartFieldName: 'autopilotMaxSprints',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotMaxSprints,
    minValue: 0,
    description:
        'Maximum number of sprints before the autopilot terminates with max_sprints_reached. 0 means unlimited.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'sprint_size',
    dartFieldName: 'autopilotSprintSize',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotSprintSize,
    minValue: 1,
    maxValue: 50,
    description:
        'Number of tasks generated per new sprint by SprintPlannerService.',
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
    description: 'Enable context injection into agent prompts.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'context_injection_max_tokens',
    dartFieldName: 'pipelineContextInjectionMaxTokens',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineContextInjectionMaxTokens,
    minValue: 1,
    description:
        'Maximum tokens for injected context. Overridden per category by providers.context_injection_max_tokens_by_category.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'error_pattern_injection_enabled',
    dartFieldName: 'pipelineErrorPatternInjectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineErrorPatternInjectionEnabled,
    description:
        'Inject past error patterns into agent prompts to prevent recurring failures.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'impact_analysis_enabled',
    dartFieldName: 'pipelineImpactAnalysisEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineImpactAnalysisEnabled,
    description:
        'Enable change-impact analysis to scope affected areas before coding.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'architecture_gate_enabled',
    dartFieldName: 'pipelineArchitectureGateEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineArchitectureGateEnabled,
    description: 'Enable architecture boundary checks before accepting diffs.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'forensic_recovery_enabled',
    dartFieldName: 'pipelineForensicRecoveryEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineForensicRecoveryEnabled,
    description: 'Enable forensic recovery analysis for stuck states.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'error_pattern_learning_enabled',
    dartFieldName: 'pipelineErrorPatternLearningEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineErrorPatternLearningEnabled,
    description: 'Enable error pattern learning from past failures.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'impact_context_max_files',
    dartFieldName: 'pipelineImpactContextMaxFiles',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineImpactContextMaxFiles,
    minValue: 1,
    description: 'Maximum files included in impact analysis context.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_refinement_enabled',
    dartFieldName: 'pipelineSubtaskRefinementEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskRefinementEnabled,
    description: 'Let the spec agent refine a subtask before coding starts.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_feasibility_enabled',
    dartFieldName: 'pipelineSubtaskFeasibilityEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskFeasibilityEnabled,
    description:
        'Have the spec agent judge whether a subtask is feasible as written before coding starts.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'ac_self_check_enabled',
    dartFieldName: 'pipelineAcSelfCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineAcSelfCheckEnabled,
    description:
        'Make the coding agent check its own work against the acceptance criteria before review.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_commit_enabled',
    dartFieldName: 'pipelineSubtaskCommitEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineSubtaskCommitEnabled,
    description:
        'Commit after each subtask instead of only at the end of the task.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'subtask_forced_narrowing_max_size',
    dartFieldName: 'subtaskForcedNarrowingMaxSize',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultSubtaskForcedNarrowingMaxSize,
    minValue: 1,
    description:
        'Subtask size above which a repeatedly failing task is force-narrowed. 0 disables narrowing.',
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
    description:
        'Instantiate the review agent with fresh context (no carry-over from the coding agent).',
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'strictness',
    dartFieldName: 'reviewStrictness',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReviewStrictness,
    validValues: ['strict', 'standard', 'lenient'],
    description:
        'Review stringency level. strict flags minor issues; lenient focuses on correctness only.',
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'max_rounds',
    dartFieldName: 'reviewMaxRounds',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReviewMaxRounds,
    minValue: 1,
    description:
        'Maximum review-revise rounds before blocking the task. See Review Gate.',
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'require_evidence',
    dartFieldName: 'reviewRequireEvidence',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultReviewRequireEvidence,
    description:
        'Require an evidence bundle (test results, DoD checklist) for approval.',
  ),
  ConfigFieldDescriptor(
    section: 'review',
    yamlKey: 'evidence_min_length',
    dartFieldName: 'reviewEvidenceMinLength',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReviewEvidenceMinLength,
    minValue: 1,
    description: 'Minimum character length for review evidence text.',
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
    description: 'Enable the reflection system.',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_mode',
    dartFieldName: 'reflectionTriggerMode',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReflectionTriggerMode,
    description:
        'Trigger mode for reflection passes: loop_count, task_count, or hours.',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_loop_count',
    dartFieldName: 'reflectionTriggerLoopCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerLoopCount,
    minValue: 1,
    description:
        'Number of loops between reflection passes (when trigger_mode is loop_count).',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_task_count',
    dartFieldName: 'reflectionTriggerTaskCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerTaskCount,
    minValue: 1,
    description:
        'Number of completed tasks between reflection passes (when trigger_mode is task_count).',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'trigger_hours',
    dartFieldName: 'reflectionTriggerHours',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionTriggerHours,
    minValue: 1,
    description:
        'Hours between reflection passes (when trigger_mode is hours).',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'min_samples',
    dartFieldName: 'reflectionMinSamples',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionMinSamples,
    minValue: 1,
    description:
        'Minimum data samples required before generating reflection insights.',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'max_optimization_tasks',
    dartFieldName: 'reflectionMaxOptimizationTasks',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionMaxOptimizationTasks,
    minValue: 0,
    description: 'Maximum optimization tasks reflection may create per pass.',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'optimization_task_priority',
    dartFieldName: 'reflectionOptimizationPriority',
    type: ConfigFieldType.string_,
    defaultValue: ProjectConfig.defaultReflectionOptimizationPriority,
    description:
        'Priority level assigned to reflection-generated optimization tasks.',
  ),
  ConfigFieldDescriptor(
    section: 'reflection',
    yamlKey: 'analysis_window_lines',
    dartFieldName: 'reflectionAnalysisWindowLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultReflectionAnalysisWindowLines,
    minValue: 1,
    description: 'Maximum run-log lines analyzed per reflection pass.',
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
    description:
        'Trigger a reflection pass when the autopilot halts due to failure.',
  ),
  ConfigFieldDescriptor(
    section: 'supervisor',
    yamlKey: 'max_interventions_per_hour',
    dartFieldName: 'supervisorMaxInterventionsPerHour',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultSupervisorMaxInterventionsPerHour,
    minValue: 1,
    description: 'Maximum supervisor interventions (restarts, heals) per hour.',
  ),
  ConfigFieldDescriptor(
    section: 'supervisor',
    yamlKey: 'check_interval_seconds',
    dartFieldName: 'supervisorCheckInterval',
    type: ConfigFieldType.duration,
    defaultValue: ProjectConfig.defaultSupervisorCheckIntervalSeconds,
    minValue: 1,
    description: 'Seconds between supervisor health checks.',
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
    description: 'Enable code health analysis.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'auto_create_tasks',
    dartFieldName: 'codeHealthAutoCreateTasks',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthAutoCreateTasks,
    description: 'Automatically create refactoring tasks for detected issues.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'min_confidence',
    dartFieldName: 'codeHealthMinConfidence',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthMinConfidence,
    minValue: 0.0,
    maxValue: 1.0,
    description: 'Minimum confidence score to report a code health issue.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_refactor_ratio',
    dartFieldName: 'codeHealthMaxRefactorRatio',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxRefactorRatio,
    minValue: 0.0,
    maxValue: 1.0,
    description: 'Maximum ratio of refactoring tasks to total backlog.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_file_lines',
    dartFieldName: 'codeHealthMaxFileLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxFileLines,
    minValue: 1,
    description:
        'Files exceeding this line count trigger a "large file" finding.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_method_lines',
    dartFieldName: 'codeHealthMaxMethodLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxMethodLines,
    minValue: 1,
    description:
        'Methods exceeding this line count trigger a "long method" finding.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_nesting_depth',
    dartFieldName: 'codeHealthMaxNestingDepth',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxNestingDepth,
    minValue: 1,
    description:
        'Maximum nesting depth before triggering a complexity finding.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'max_parameter_count',
    dartFieldName: 'codeHealthMaxParameterCount',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthMaxParameterCount,
    minValue: 1,
    description: 'Maximum method parameters before triggering a finding.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'hotspot_threshold',
    dartFieldName: 'codeHealthHotspotThreshold',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultCodeHealthHotspotThreshold,
    minValue: 0.0,
    maxValue: 1.0,
    description: 'Churn-frequency threshold for marking a file as a hotspot.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'hotspot_window',
    dartFieldName: 'codeHealthHotspotWindow',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthHotspotWindow,
    minValue: 1,
    description: 'Number of recent commits analyzed for hotspot detection.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'patch_cluster_min',
    dartFieldName: 'codeHealthPatchClusterMin',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthPatchClusterMin,
    minValue: 1,
    description: 'Minimum co-changed files to form a patch cluster.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'reflection_enabled',
    dartFieldName: 'codeHealthReflectionEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthReflectionEnabled,
    description: 'Enable LLM-based code health reflection for deeper analysis.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'reflection_cadence',
    dartFieldName: 'codeHealthReflectionCadence',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthReflectionCadence,
    minValue: 0,
    description:
        'Steps between code health reflection passes. 0 = only on demand.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'llm_budget_tokens',
    dartFieldName: 'codeHealthLlmBudgetTokens',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultCodeHealthLlmBudgetTokens,
    minValue: 1,
    description: 'Token budget for LLM-based code health analysis.',
  ),
  ConfigFieldDescriptor(
    section: 'code_health',
    yamlKey: 'block_features',
    dartFieldName: 'codeHealthBlockFeatures',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultCodeHealthBlockFeatures,
    description:
        'Block new feature tasks when code health score is below threshold.',
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
    description: 'Enable periodic vision completion evaluation.',
  ),
  ConfigFieldDescriptor(
    section: 'vision_evaluation',
    yamlKey: 'interval',
    dartFieldName: 'visionEvaluationInterval',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultVisionEvaluationInterval,
    minValue: 1,
    description: 'Steps between vision evaluation passes.',
  ),
  ConfigFieldDescriptor(
    section: 'vision_evaluation',
    yamlKey: 'completion_threshold',
    dartFieldName: 'visionCompletionThreshold',
    type: ConfigFieldType.double_,
    defaultValue: ProjectConfig.defaultVisionCompletionThreshold,
    minValue: 0.0,
    maxValue: 1.0,
    description:
        'Completion fraction at which the project vision is considered achieved.',
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
    description:
        'Back off progressively after consecutive failures instead of retrying at the fixed step interval.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'adaptive_sleep_max_multiplier',
    dartFieldName: 'autopilotAdaptiveSleepMaxMultiplier',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultAutopilotAdaptiveSleepMaxMultiplier,
    minValue: 1,
    description:
        'Upper bound on adaptive back-off, as a multiple of the step sleep. Never exceeds the idle sleep.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'task_dependencies_enabled',
    dartFieldName: 'autopilotTaskDependenciesEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultAutopilotTaskDependenciesEnabled,
    description:
        'Skip tasks whose declared dependencies are not done yet and move on to the next candidate.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'vision_drift_check_enabled',
    dartFieldName: 'visionDriftCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultVisionDriftCheckEnabled,
    description:
        'Reserved for the planned vision-drift check. No pipeline stage reads it yet.',
  ),
  ConfigFieldDescriptor(
    section: 'autopilot',
    yamlKey: 'vision_drift_check_interval',
    dartFieldName: 'visionDriftCheckInterval',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultVisionDriftCheckInterval,
    minValue: 1,
    description:
        'Reserved for the planned vision-drift check. No pipeline stage reads it yet.',
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
    description: 'Master switch. Must be true for any gate to activate.',
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'timeout_minutes',
    dartFieldName: 'hitlTimeoutMinutes',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultHitlTimeoutMinutes,
    minValue: 0,
    description:
        'Minutes to wait before auto-approving. 0 = wait indefinitely.',
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_after_task_done',
    dartFieldName: 'hitlGateAfterTaskDone',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateAfterTaskDone,
    description: 'Pause after every auto-marked-done task completion.',
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_before_sprint',
    dartFieldName: 'hitlGateBeforeSprint',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateBeforeSprint,
    description:
        'Pause before each new sprint is generated by SprintPlannerService.',
  ),
  ConfigFieldDescriptor(
    section: 'hitl',
    yamlKey: 'gate_before_halt',
    dartFieldName: 'hitlGateBeforeHalt',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultHitlGateBeforeHalt,
    description:
        'Pause before the autopilot performs a safety halt. Human can approve to halt normally or reject to terminate with hitl_rejected.',
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
    description:
        'Require a behaviour change to come with a test change before it can pass the gate.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'lessons_learned_enabled',
    dartFieldName: 'pipelineLessonsLearnedEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineLessonsLearnedEnabled,
    description: 'Feed previously recorded lessons into agent prompts.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'lessons_learned_max_lines',
    dartFieldName: 'pipelineLessonsLearnedMaxLines',
    type: ConfigFieldType.int_,
    defaultValue: ProjectConfig.defaultPipelineLessonsLearnedMaxLines,
    description:
        'Entries kept in the lessons-learned file; older entries are rotated out.',
  ),
  ConfigFieldDescriptor(
    section: 'pipeline',
    yamlKey: 'final_ac_check_enabled',
    dartFieldName: 'pipelineFinalAcCheckEnabled',
    type: ConfigFieldType.bool_,
    defaultValue: ProjectConfig.defaultPipelineFinalAcCheckEnabled,
    description:
        'Verify the acceptance criteria one final time before a task is marked done.',
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
    description:
        'Show the review agent only what changed since its previous round, instead of the full diff.',
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
