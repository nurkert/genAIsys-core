// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../project_layout.dart';
import 'config_field_descriptor.dart';
import 'config_field_registry.dart';
import 'config_parsers/agents_section_parser.dart' as agents_parser;
import 'config_parsers/config_parse_utils.dart' as parse_utils;
import 'config_parsers/config_parser_state.dart';
import 'config_parsers/policies_section_parser.dart' as policies_parser;
import 'config_parsers/project_section_parser.dart' as project_parser;
import 'config_parsers/providers_section_parser.dart' as providers_parser;
import 'config_presets.dart';
import 'config_values_map.dart';
import 'sub_configs/autopilot_config.dart';
import 'sub_configs/code_health_config.dart';
import 'sub_configs/git_config.dart';
import 'sub_configs/hitl_config.dart';
import 'sub_configs/pipeline_config.dart';
import 'sub_configs/policies_config.dart';
import 'sub_configs/providers_config.dart';
import 'sub_configs/reflection_config.dart';
import 'sub_configs/review_config.dart';

part 'project_config_parser.dart';
part 'project_config_models.dart';

class ProjectConfig {
  ProjectConfig({
    this.projectType,
    this.providersPrimary,
    this.providersFallback,
    this.providerPool = const [],
    this.providersNative,
    this.codexCliConfigOverrides = const [],
    this.claudeCodeCliConfigOverrides = const [],
    this.geminiCliConfigOverrides = const [],
    this.vibeCliConfigOverrides = const [],
    this.ampCliConfigOverrides = const [],
    this.reasoningEffortByCategory = defaultReasoningEffortByCategory,
    this.agentTimeoutByCategory = defaultAgentTimeoutByCategory,
    this.providerQuotaCooldown = const Duration(
      seconds: defaultProviderQuotaCooldownSeconds,
    ),
    this.providerQuotaPause = const Duration(
      seconds: defaultProviderQuotaPauseSeconds,
    ),
    this.diffBudgetMaxFiles = defaultDiffBudgetMaxFiles,
    this.diffBudgetMaxAdditions = defaultDiffBudgetMaxAdditions,
    this.diffBudgetMaxDeletions = defaultDiffBudgetMaxDeletions,
    this.shellAllowlist = const [],
    this.shellAllowlistProfile = defaultShellAllowlistProfile,
    this.safeWriteEnabled = true,
    this.safeWriteRoots = defaultSafeWriteRoots,
    this.qualityGateEnabled = defaultQualityGateEnabled,
    this.qualityGateCommands = defaultQualityGateCommands,
    this.qualityGateTimeout = const Duration(
      seconds: defaultQualityGateTimeoutSeconds,
    ),
    this.qualityGateAdaptiveByDiff = defaultQualityGateAdaptiveByDiff,
    this.qualityGateSkipTestsForDocsOnly =
        defaultQualityGateSkipTestsForDocsOnly,
    this.qualityGatePreferDartTestForLibDartOnly =
        defaultQualityGatePreferDartTestForLibDartOnly,
    this.qualityGateFlakeRetryCount = defaultQualityGateFlakeRetryCount,
    this.agentTimeout = const Duration(seconds: defaultAgentTimeoutSeconds),
    this.gitBaseBranch = 'main',
    this.gitFeaturePrefix = 'feat/',
    this.workflowRequireReview = defaultWorkflowRequireReview,
    this.workflowAutoCommit = defaultWorkflowAutoCommit,
    this.workflowAutoPush = defaultWorkflowAutoPush,
    this.workflowAutoMerge = defaultWorkflowAutoMerge,
    this.workflowMergeStrategy = defaultWorkflowMergeStrategy,
    this.gitAutoDeleteRemoteMergedBranches =
        defaultGitAutoDeleteRemoteMergedBranches,
    this.gitAutoStash = false,
    this.gitAutoStashSkipRejected = defaultGitAutoStashSkipRejected,
    this.gitAutoStashSkipRejectedUnattended =
        defaultGitAutoStashSkipRejectedUnattended,
    this.autopilotMinOpenTasks = defaultAutopilotMinOpenTasks,
    this.autopilotMaxPlanAdd = defaultAutopilotMaxPlanAdd,
    this.autopilotStepSleep = const Duration(
      seconds: defaultAutopilotStepSleepSeconds,
    ),
    this.autopilotIdleSleep = const Duration(
      seconds: defaultAutopilotIdleSleepSeconds,
    ),
    this.autopilotMaxSteps,
    this.autopilotMaxFailures = defaultAutopilotMaxFailures,
    this.autopilotMaxTaskRetries = defaultAutopilotMaxTaskRetries,
    this.autopilotSelectionMode = defaultAutopilotSelectionMode,
    this.autopilotFairnessWindow = defaultAutopilotFairnessWindow,
    this.autopilotPriorityWeightP1 = defaultAutopilotPriorityWeightP1,
    this.autopilotPriorityWeightP2 = defaultAutopilotPriorityWeightP2,
    this.autopilotPriorityWeightP3 = defaultAutopilotPriorityWeightP3,
    this.autopilotReactivateBlocked = defaultAutopilotReactivateBlocked,
    this.autopilotReactivateFailed = defaultAutopilotReactivateFailed,
    this.autopilotBlockedCooldown = const Duration(
      seconds: defaultAutopilotBlockedCooldownSeconds,
    ),
    this.autopilotFailedCooldown = const Duration(
      seconds: defaultAutopilotFailedCooldownSeconds,
    ),
    this.autopilotLockTtl = const Duration(
      seconds: defaultAutopilotLockTtlSeconds,
    ),
    this.autopilotNoProgressThreshold = defaultAutopilotNoProgressThreshold,
    this.autopilotStuckCooldown = const Duration(
      seconds: defaultAutopilotStuckCooldownSeconds,
    ),
    this.autopilotSelfRestart = defaultAutopilotSelfRestart,
    this.autopilotSelfHealEnabled = defaultAutopilotSelfHealEnabled,
    this.autopilotSelfHealMaxAttempts = defaultAutopilotSelfHealMaxAttempts,
    this.autopilotScopeMaxFiles = defaultAutopilotScopeMaxFiles,
    this.autopilotScopeMaxAdditions = defaultAutopilotScopeMaxAdditions,
    this.autopilotScopeMaxDeletions = defaultAutopilotScopeMaxDeletions,
    this.autopilotApproveBudget = defaultAutopilotApproveBudget,
    this.autopilotManualOverride = defaultAutopilotManualOverride,
    this.autopilotOvernightUnattendedEnabled =
        defaultAutopilotOvernightUnattendedEnabled,
    this.autopilotSelfTuneEnabled = defaultAutopilotSelfTuneEnabled,
    this.autopilotSelfTuneWindow = defaultAutopilotSelfTuneWindow,
    this.autopilotSelfTuneMinSamples = defaultAutopilotSelfTuneMinSamples,
    this.autopilotSelfTuneSuccessPercent =
        defaultAutopilotSelfTuneSuccessPercent,
    this.autopilotReleaseTagOnReady = defaultAutopilotReleaseTagOnReady,
    this.autopilotReleaseTagPush = defaultAutopilotReleaseTagPush,
    this.autopilotReleaseTagPrefix = defaultAutopilotReleaseTagPrefix,
    this.autopilotPlanningAuditEnabled = defaultAutopilotPlanningAuditEnabled,
    this.autopilotPlanningAuditCadenceSteps =
        defaultAutopilotPlanningAuditCadenceSteps,
    this.autopilotPlanningAuditMaxAdd = defaultAutopilotPlanningAuditMaxAdd,
    this.autopilotResourceCheckEnabled = defaultAutopilotResourceCheckEnabled,
    this.autopilotMaxStashEntries = defaultAutopilotMaxStashEntries,
    this.autopilotMaxWallclockHours = defaultAutopilotMaxWallclockHours,
    this.autopilotMaxSelfRestarts = defaultAutopilotMaxSelfRestarts,
    this.autopilotMaxIterationsSafetyLimit =
        defaultAutopilotMaxIterationsSafetyLimit,
    this.autopilotPreflightTimeout = const Duration(
      seconds: defaultAutopilotPreflightTimeoutSeconds,
    ),
    this.autopilotSubtaskQueueMax = defaultAutopilotSubtaskQueueMax,
    this.autopilotPushFailureThreshold = defaultAutopilotPushFailureThreshold,
    this.autopilotProviderFailureThreshold =
        defaultAutopilotProviderFailureThreshold,
    this.autopilotReviewContractLockEnabled =
        defaultAutopilotReviewContractLockEnabled,
    this.autopilotPreflightRepairThreshold =
        defaultAutopilotPreflightRepairThreshold,
    this.autopilotMaxPreflightRepairAttempts =
        defaultAutopilotMaxPreflightRepairAttempts,
    this.autopilotLockHeartbeatHaltThreshold =
        defaultAutopilotLockHeartbeatHaltThreshold,
    this.autopilotSprintPlanningEnabled = defaultAutopilotSprintPlanningEnabled,
    this.autopilotMaxSprints = defaultAutopilotMaxSprints,
    this.autopilotSprintSize = defaultAutopilotSprintSize,
    this.hitlEnabled = defaultHitlEnabled,
    this.hitlTimeoutMinutes = defaultHitlTimeoutMinutes,
    this.hitlGateAfterTaskDone = defaultHitlGateAfterTaskDone,
    this.hitlGateBeforeSprint = defaultHitlGateBeforeSprint,
    this.hitlGateBeforeHalt = defaultHitlGateBeforeHalt,
    this.reviewEvidenceMinLength = defaultReviewEvidenceMinLength,
    this.agentProfiles = const {},
    // Pipeline config.
    this.pipelineContextInjectionEnabled =
        defaultPipelineContextInjectionEnabled,
    this.pipelineContextInjectionMaxTokens =
        defaultPipelineContextInjectionMaxTokens,
    this.contextInjectionMaxTokensByCategory =
        defaultContextInjectionMaxTokensByCategory,
    this.pipelineErrorPatternInjectionEnabled =
        defaultPipelineErrorPatternInjectionEnabled,
    this.pipelineImpactAnalysisEnabled = defaultPipelineImpactAnalysisEnabled,
    this.pipelineArchitectureGateEnabled =
        defaultPipelineArchitectureGateEnabled,
    this.pipelineForensicRecoveryEnabled =
        defaultPipelineForensicRecoveryEnabled,
    this.pipelineErrorPatternLearningEnabled =
        defaultPipelineErrorPatternLearningEnabled,
    this.pipelineImpactContextMaxFiles = defaultPipelineImpactContextMaxFiles,
    this.pipelineSubtaskRefinementEnabled =
        defaultPipelineSubtaskRefinementEnabled,
    this.pipelineSubtaskFeasibilityEnabled =
        defaultPipelineSubtaskFeasibilityEnabled,
    this.pipelineAcSelfCheckEnabled = defaultPipelineAcSelfCheckEnabled,
    this.pipelineSubtaskCommitEnabled = defaultPipelineSubtaskCommitEnabled,
    this.subtaskForcedNarrowingMaxSize = defaultSubtaskForcedNarrowingMaxSize,
    this.pipelineTestDeltaGateEnabled = defaultPipelineTestDeltaGateEnabled,
    this.pipelineTestDeltaGateCategories =
        defaultPipelineTestDeltaGateCategories,
    this.pipelineLessonsLearnedEnabled = defaultPipelineLessonsLearnedEnabled,
    this.pipelineLessonsLearnedMaxLines = defaultPipelineLessonsLearnedMaxLines,
    this.reviewDiffDeltaEnabled = defaultReviewDiffDeltaEnabled,
    this.pipelineFinalAcCheckEnabled = defaultPipelineFinalAcCheckEnabled,
    // Git sync config.
    this.gitSyncBetweenLoops = defaultGitSyncBetweenLoops,
    this.gitSyncStrategy = defaultGitSyncStrategy,
    // Review config.
    this.reviewFreshContext = defaultReviewFreshContext,
    this.reviewStrictness = defaultReviewStrictness,
    this.reviewMaxRounds = defaultReviewMaxRounds,
    this.reviewRequireEvidence = defaultReviewRequireEvidence,
    this.visionDriftCheckEnabled = defaultVisionDriftCheckEnabled,
    this.visionDriftCheckInterval = defaultVisionDriftCheckInterval,
    this.autopilotAdaptiveSleepEnabled = defaultAutopilotAdaptiveSleepEnabled,
    this.autopilotAdaptiveSleepMaxMultiplier =
        defaultAutopilotAdaptiveSleepMaxMultiplier,
    this.autopilotTaskDependenciesEnabled =
        defaultAutopilotTaskDependenciesEnabled,
    // Reflection config.
    this.reflectionEnabled = defaultReflectionEnabled,
    this.reflectionTriggerMode = defaultReflectionTriggerMode,
    this.reflectionTriggerLoopCount = defaultReflectionTriggerLoopCount,
    this.reflectionTriggerTaskCount = defaultReflectionTriggerTaskCount,
    this.reflectionTriggerHours = defaultReflectionTriggerHours,
    this.reflectionMinSamples = defaultReflectionMinSamples,
    this.reflectionMaxOptimizationTasks = defaultReflectionMaxOptimizationTasks,
    this.reflectionOptimizationPriority = defaultReflectionOptimizationPriority,
    this.reflectionAnalysisWindowLines = defaultReflectionAnalysisWindowLines,
    // Supervisor config.
    this.supervisorReflectionOnHalt = defaultSupervisorReflectionOnHalt,
    this.supervisorMaxInterventionsPerHour =
        defaultSupervisorMaxInterventionsPerHour,
    this.supervisorCheckInterval = const Duration(
      seconds: defaultSupervisorCheckIntervalSeconds,
    ),
    // Vision evaluation config.
    this.visionEvaluationEnabled = defaultVisionEvaluationEnabled,
    this.visionEvaluationInterval = defaultVisionEvaluationInterval,
    this.visionCompletionThreshold = defaultVisionCompletionThreshold,
    // Code health config.
    this.codeHealthEnabled = defaultCodeHealthEnabled,
    this.codeHealthAutoCreateTasks = defaultCodeHealthAutoCreateTasks,
    this.codeHealthMinConfidence = defaultCodeHealthMinConfidence,
    this.codeHealthMaxRefactorRatio = defaultCodeHealthMaxRefactorRatio,
    this.codeHealthMaxFileLines = defaultCodeHealthMaxFileLines,
    this.codeHealthMaxMethodLines = defaultCodeHealthMaxMethodLines,
    this.codeHealthMaxNestingDepth = defaultCodeHealthMaxNestingDepth,
    this.codeHealthMaxParameterCount = defaultCodeHealthMaxParameterCount,
    this.codeHealthHotspotThreshold = defaultCodeHealthHotspotThreshold,
    this.codeHealthHotspotWindow = defaultCodeHealthHotspotWindow,
    this.codeHealthPatchClusterMin = defaultCodeHealthPatchClusterMin,
    this.codeHealthReflectionEnabled = defaultCodeHealthReflectionEnabled,
    this.codeHealthReflectionCadence = defaultCodeHealthReflectionCadence,
    this.codeHealthLlmBudgetTokens = defaultCodeHealthLlmBudgetTokens,
    this.codeHealthBlockFeatures = defaultCodeHealthBlockFeatures,
  });

  static const int defaultDiffBudgetMaxFiles = 20;
  static const int defaultDiffBudgetMaxAdditions = 2000;
  static const int defaultDiffBudgetMaxDeletions = 1500;
  static const bool defaultQualityGateEnabled = true;
  static const int defaultQualityGateTimeoutSeconds = 900;
  static const bool defaultQualityGateAdaptiveByDiff = true;
  static const bool defaultQualityGateSkipTestsForDocsOnly = true;
  static const bool defaultQualityGatePreferDartTestForLibDartOnly = true;
  static const int defaultQualityGateFlakeRetryCount = 1;
  static const int defaultAgentTimeoutSeconds = 900;
  static const int defaultProviderQuotaCooldownSeconds = 900;
  static const int defaultProviderQuotaPauseSeconds = 300;
  static const String defaultShellAllowlistProfile = 'standard';
  static const int defaultAutopilotMinOpenTasks = 8;
  static const int defaultAutopilotMaxPlanAdd = 4;
  static const int defaultAutopilotStepSleepSeconds = 2;
  static const int defaultAutopilotIdleSleepSeconds = 30;
  static const int defaultAutopilotMaxFailures = 5;
  static const int defaultAutopilotMaxTaskRetries = 3;
  static const String defaultAutopilotSelectionMode = 'strict_priority';
  static const int defaultAutopilotFairnessWindow = 12;
  static const int defaultAutopilotPriorityWeightP1 = 3;
  static const int defaultAutopilotPriorityWeightP2 = 2;
  static const int defaultAutopilotPriorityWeightP3 = 1;
  static const bool defaultAutopilotReactivateBlocked = false;
  static const bool defaultAutopilotReactivateFailed = true;
  static const int defaultAutopilotBlockedCooldownSeconds = 0;
  static const int defaultAutopilotFailedCooldownSeconds = 0;
  static const int defaultAutopilotLockTtlSeconds = 600;
  static const int defaultAutopilotNoProgressThreshold = 6;
  static const int defaultAutopilotStuckCooldownSeconds = 60;
  static const bool defaultAutopilotSelfRestart = true;
  static const bool defaultAutopilotSelfHealEnabled = true;
  static const int defaultAutopilotSelfHealMaxAttempts = 3;
  static const int defaultAutopilotScopeMaxFiles = 60;
  static const int defaultAutopilotScopeMaxAdditions = 6000;
  static const int defaultAutopilotScopeMaxDeletions = 4500;
  static const int defaultAutopilotApproveBudget = 3;
  static const bool defaultAutopilotManualOverride = false;
  static const bool defaultAutopilotOvernightUnattendedEnabled = false;
  static const bool defaultAutopilotSelfTuneEnabled = true;
  static const int defaultAutopilotSelfTuneWindow = 12;
  static const int defaultAutopilotSelfTuneMinSamples = 4;
  static const int defaultAutopilotSelfTuneSuccessPercent = 70;
  static const bool defaultAutopilotReleaseTagOnReady = true;
  static const bool defaultAutopilotReleaseTagPush = true;
  static const String defaultAutopilotReleaseTagPrefix = 'v';
  static const bool defaultAutopilotPlanningAuditEnabled = true;
  static const int defaultAutopilotPlanningAuditCadenceSteps = 12;
  static const int defaultAutopilotPlanningAuditMaxAdd = 4;
  static const bool defaultAutopilotResourceCheckEnabled = true;
  static const int defaultAutopilotMaxStashEntries = 20;
  static const int defaultAutopilotMaxWallclockHours = 24;
  static const int defaultAutopilotMaxSelfRestarts = 5;
  static const int defaultAutopilotMaxIterationsSafetyLimit = 2000;
  static const int defaultAutopilotPreflightTimeoutSeconds = 30;
  static const int defaultAutopilotSubtaskQueueMax = 100;
  static const int defaultAutopilotPushFailureThreshold = 5;
  static const int defaultAutopilotProviderFailureThreshold = 3;
  static const bool defaultAutopilotReviewContractLockEnabled = true;
  static const int defaultAutopilotPreflightRepairThreshold = 5;
  static const int defaultAutopilotMaxPreflightRepairAttempts = 3;
  static const int defaultAutopilotLockHeartbeatHaltThreshold = 0;
  static const bool defaultAutopilotSprintPlanningEnabled = false;
  static const int defaultAutopilotMaxSprints = 0;
  static const int defaultAutopilotSprintSize = 8;
  // HITL defaults.
  static const bool defaultHitlEnabled = false;
  static const int defaultHitlTimeoutMinutes = 60;
  static const bool defaultHitlGateAfterTaskDone = false;
  static const bool defaultHitlGateBeforeSprint = false;
  static const bool defaultHitlGateBeforeHalt = false;
  static const int defaultReviewEvidenceMinLength = 50;
  // Workflow defaults.
  static const bool defaultWorkflowRequireReview = true;
  static const bool defaultWorkflowAutoCommit = true;
  static const bool defaultWorkflowAutoPush = true;
  static const bool defaultWorkflowAutoMerge = true;
  static const String defaultWorkflowMergeStrategy = 'merge';
  static const bool defaultGitAutoStashSkipRejected = true;
  static const bool defaultGitAutoStashSkipRejectedUnattended = false;
  static const bool defaultGitAutoDeleteRemoteMergedBranches = false;
  // Provider category defaults.
  static const Map<String, String> defaultReasoningEffortByCategory = {
    'docs': 'low',
    'refactor': 'high',
    'security': 'high',
    'core': 'medium',
    'default': 'medium',
  };
  static const Map<String, int> defaultAgentTimeoutByCategory = {
    'docs': 180,
    'refactor': 480,
    'security': 480,
    'core': 360,
    'default': 360,
  };
  // Pipeline defaults.
  static const bool defaultPipelineContextInjectionEnabled = true;
  static const int defaultPipelineContextInjectionMaxTokens = 8000;
  static const Map<String, int> defaultContextInjectionMaxTokensByCategory = {
    'docs': 2000,
    'refactor': 12000,
    'core': 8000,
    'default': 8000,
  };
  static const bool defaultPipelineErrorPatternInjectionEnabled = true;
  static const bool defaultPipelineImpactAnalysisEnabled = true;
  static const bool defaultPipelineArchitectureGateEnabled = true;
  static const bool defaultPipelineForensicRecoveryEnabled = true;
  static const bool defaultPipelineErrorPatternLearningEnabled = true;
  static const int defaultPipelineImpactContextMaxFiles = 10;
  static const bool defaultPipelineSubtaskRefinementEnabled = true;
  static const bool defaultPipelineSubtaskFeasibilityEnabled = true;
  static const bool defaultPipelineAcSelfCheckEnabled = true;
  static const bool defaultPipelineSubtaskCommitEnabled = true;
  static const int defaultSubtaskForcedNarrowingMaxSize = 3;
  static const bool defaultPipelineTestDeltaGateEnabled = false;
  static const List<String> defaultPipelineTestDeltaGateCategories = [
    'core',
    'security',
    'qa',
    'agent',
  ];
  static const bool defaultPipelineLessonsLearnedEnabled = true;
  static const int defaultPipelineLessonsLearnedMaxLines = 100;
  static const bool defaultReviewDiffDeltaEnabled = true;
  static const bool defaultPipelineFinalAcCheckEnabled = false;
  static const bool defaultVisionDriftCheckEnabled = true;
  static const int defaultVisionDriftCheckInterval = 5;
  static const bool defaultAutopilotAdaptiveSleepEnabled = true;
  static const int defaultAutopilotAdaptiveSleepMaxMultiplier = 4;
  static const bool defaultAutopilotTaskDependenciesEnabled = true;
  // Git sync defaults.
  static const bool defaultGitSyncBetweenLoops = false;
  static const String defaultGitSyncStrategy = 'fetch_only';
  // Review defaults.
  static const bool defaultReviewFreshContext = true;
  static const String defaultReviewStrictness = 'standard';
  static const int defaultReviewMaxRounds = 3;
  static const bool defaultReviewRequireEvidence = true;
  // Reflection defaults.
  static const bool defaultReflectionEnabled = true;
  static const String defaultReflectionTriggerMode = 'loop_count';
  static const int defaultReflectionTriggerLoopCount = 10;
  static const int defaultReflectionTriggerTaskCount = 5;
  static const int defaultReflectionTriggerHours = 4;
  static const int defaultReflectionMinSamples = 5;
  static const int defaultReflectionMaxOptimizationTasks = 3;
  static const String defaultReflectionOptimizationPriority = 'P2';
  static const int defaultReflectionAnalysisWindowLines = 2000;
  // Supervisor defaults.
  static const bool defaultSupervisorReflectionOnHalt = true;
  static const int defaultSupervisorMaxInterventionsPerHour = 5;
  static const int defaultSupervisorCheckIntervalSeconds = 30;
  // Vision evaluation defaults.
  // Code health defaults.
  static const bool defaultCodeHealthEnabled = true;
  static const bool defaultCodeHealthAutoCreateTasks = true;
  static const double defaultCodeHealthMinConfidence = 0.6;
  static const double defaultCodeHealthMaxRefactorRatio = 0.3;
  static const int defaultCodeHealthMaxFileLines = 500;
  static const int defaultCodeHealthMaxMethodLines = 80;
  static const int defaultCodeHealthMaxNestingDepth = 5;
  static const int defaultCodeHealthMaxParameterCount = 6;
  static const double defaultCodeHealthHotspotThreshold = 0.3;
  static const int defaultCodeHealthHotspotWindow = 20;
  static const int defaultCodeHealthPatchClusterMin = 3;
  static const bool defaultCodeHealthReflectionEnabled = true;
  static const int defaultCodeHealthReflectionCadence = 0;
  static const int defaultCodeHealthLlmBudgetTokens = 4000;
  static const bool defaultCodeHealthBlockFeatures = false;
  static const bool defaultVisionEvaluationEnabled = true;
  static const int defaultVisionEvaluationInterval = 10;
  static const double defaultVisionCompletionThreshold = 0.9;
  static const List<String> minimalShellAllowlist = [
    'rg',
    'ls',
    'cat',
    'codex',
    'gemini',
    'claude',
    'vibe',
    'amp',
    'native',
    'git status',
    'git diff',
  ];
  static const List<String> standardShellAllowlist = [
    'rg',
    'ls',
    'cat',
    'codex',
    'gemini',
    'claude',
    'vibe',
    'amp',
    'native',
    'git status',
    'git diff',
    'git log',
    'git show',
    'git branch',
    'git rev-parse',
    'flutter test',
    'flutter pub',
    'dart test',
    'dart format',
    'dart analyze',
    'dart pub',
    'dart run',
  ];
  static const List<String> extendedShellAllowlist = [
    'rg',
    'ls',
    'cat',
    'codex',
    'gemini',
    'claude',
    'vibe',
    'amp',
    'native',
    'git status',
    'git diff',
    'git log',
    'git show',
    'git branch',
    'git rev-parse',
    'git checkout',
    'git switch',
    'git add',
    'git commit',
    'git stash',
    'git fetch',
    'git pull',
    'git push',
    'flutter test',
    'flutter pub',
    'dart test',
    'dart format',
    'dart analyze',
    'dart pub',
    'dart run',
    'dart fix',
  ];
  static const List<String> defaultSafeWriteRoots = [
    'lib',
    'test',
    'assets',
    'web',
    'android',
    'ios',
    'linux',
    'macos',
    'windows',
    'bin',
    'tool',
    'scripts',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'pubspec.yaml',
    'pubspec.lock',
    'analysis_options.yaml',
    '.gitignore',
    '.dart_tool',
    'CHANGELOG.md',
  ];
  static const List<String> defaultQualityGateCommands = [
    'dart format --output=none --set-exit-if-changed .',
    'dart analyze',
    'dart test',
  ];

  final String? projectType;
  final String? providersPrimary;
  final String? providersFallback;
  final List<ProviderPoolEntry> providerPool;
  final NativeProviderConfig? providersNative;
  final List<String> codexCliConfigOverrides;
  final List<String> claudeCodeCliConfigOverrides;
  final List<String> geminiCliConfigOverrides;
  final List<String> vibeCliConfigOverrides;
  final List<String> ampCliConfigOverrides;
  final Map<String, String> reasoningEffortByCategory;
  final Map<String, int> agentTimeoutByCategory;
  final Duration providerQuotaCooldown;
  final Duration providerQuotaPause;
  final int diffBudgetMaxFiles;
  final int diffBudgetMaxAdditions;
  final int diffBudgetMaxDeletions;
  final List<String> shellAllowlist;
  final String shellAllowlistProfile;
  final bool safeWriteEnabled;
  final List<String> safeWriteRoots;
  final bool qualityGateEnabled;
  final List<String> qualityGateCommands;
  final Duration qualityGateTimeout;
  final bool qualityGateAdaptiveByDiff;
  final bool qualityGateSkipTestsForDocsOnly;
  final bool qualityGatePreferDartTestForLibDartOnly;
  final int qualityGateFlakeRetryCount;
  final Duration agentTimeout;
  final String gitBaseBranch;
  final String gitFeaturePrefix;
  final bool workflowRequireReview;
  final bool workflowAutoCommit;
  final bool workflowAutoPush;
  final bool workflowAutoMerge;
  final String workflowMergeStrategy;
  final bool gitAutoDeleteRemoteMergedBranches;
  final bool gitAutoStash;
  final bool gitAutoStashSkipRejected;
  final bool gitAutoStashSkipRejectedUnattended;
  final int autopilotMinOpenTasks;
  final int autopilotMaxPlanAdd;
  final Duration autopilotStepSleep;
  final Duration autopilotIdleSleep;
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
  final Duration autopilotBlockedCooldown;
  final Duration autopilotFailedCooldown;
  final Duration autopilotLockTtl;
  final int autopilotNoProgressThreshold;
  final Duration autopilotStuckCooldown;
  final bool autopilotSelfRestart;
  final bool autopilotSelfHealEnabled;
  final int autopilotSelfHealMaxAttempts;
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
  final bool autopilotReleaseTagOnReady;
  final bool autopilotReleaseTagPush;
  final String autopilotReleaseTagPrefix;
  final bool autopilotPlanningAuditEnabled;
  final int autopilotPlanningAuditCadenceSteps;
  final int autopilotPlanningAuditMaxAdd;
  final bool autopilotResourceCheckEnabled;
  final int autopilotMaxStashEntries;
  final int autopilotMaxWallclockHours;
  final int autopilotMaxSelfRestarts;
  final int autopilotMaxIterationsSafetyLimit;
  final Duration autopilotPreflightTimeout;
  final int autopilotSubtaskQueueMax;
  final int autopilotPushFailureThreshold;
  final int autopilotProviderFailureThreshold;
  final bool autopilotReviewContractLockEnabled;
  final int autopilotPreflightRepairThreshold;
  final int autopilotMaxPreflightRepairAttempts;
  final int autopilotLockHeartbeatHaltThreshold;
  final bool autopilotSprintPlanningEnabled;
  final int autopilotMaxSprints;
  final int autopilotSprintSize;
  // HITL fields.
  final bool hitlEnabled;
  final int hitlTimeoutMinutes;
  final bool hitlGateAfterTaskDone;
  final bool hitlGateBeforeSprint;
  final bool hitlGateBeforeHalt;
  final int reviewEvidenceMinLength;
  final Map<String, AgentProfile> agentProfiles;
  // Pipeline fields.
  final bool pipelineContextInjectionEnabled;
  final int pipelineContextInjectionMaxTokens;
  final Map<String, int> contextInjectionMaxTokensByCategory;
  final bool pipelineErrorPatternInjectionEnabled;
  final bool pipelineImpactAnalysisEnabled;
  final bool pipelineArchitectureGateEnabled;
  final bool pipelineForensicRecoveryEnabled;
  final bool pipelineErrorPatternLearningEnabled;
  final int pipelineImpactContextMaxFiles;
  final bool pipelineSubtaskRefinementEnabled;
  final bool pipelineSubtaskFeasibilityEnabled;
  final bool pipelineAcSelfCheckEnabled;
  final bool pipelineSubtaskCommitEnabled;
  final int subtaskForcedNarrowingMaxSize;
  final bool pipelineTestDeltaGateEnabled;
  final List<String> pipelineTestDeltaGateCategories;
  final bool pipelineLessonsLearnedEnabled;
  final int pipelineLessonsLearnedMaxLines;
  final bool reviewDiffDeltaEnabled;
  final bool pipelineFinalAcCheckEnabled;
  // Git sync fields.
  final bool gitSyncBetweenLoops;
  final String gitSyncStrategy;
  // Review fields.
  final bool reviewFreshContext;
  final String reviewStrictness;
  final int reviewMaxRounds;
  final bool reviewRequireEvidence;
  // Reflection fields.
  final bool reflectionEnabled;
  final String reflectionTriggerMode;
  final int reflectionTriggerLoopCount;
  final int reflectionTriggerTaskCount;
  final int reflectionTriggerHours;
  final int reflectionMinSamples;
  final int reflectionMaxOptimizationTasks;
  final String reflectionOptimizationPriority;
  final int reflectionAnalysisWindowLines;
  // Supervisor fields.
  final bool supervisorReflectionOnHalt;
  final int supervisorMaxInterventionsPerHour;
  final Duration supervisorCheckInterval;
  final bool visionDriftCheckEnabled;
  final int visionDriftCheckInterval;
  final bool autopilotAdaptiveSleepEnabled;
  final int autopilotAdaptiveSleepMaxMultiplier;
  final bool autopilotTaskDependenciesEnabled;
  // Vision evaluation fields.
  final bool visionEvaluationEnabled;
  final int visionEvaluationInterval;
  final double visionCompletionThreshold;
  // Code health fields.
  final bool codeHealthEnabled;
  final bool codeHealthAutoCreateTasks;
  final double codeHealthMinConfidence;
  final double codeHealthMaxRefactorRatio;
  final int codeHealthMaxFileLines;
  final int codeHealthMaxMethodLines;
  final int codeHealthMaxNestingDepth;
  final int codeHealthMaxParameterCount;
  final double codeHealthHotspotThreshold;
  final int codeHealthHotspotWindow;
  final int codeHealthPatchClusterMin;
  final bool codeHealthReflectionEnabled;
  final int codeHealthReflectionCadence;
  final int codeHealthLlmBudgetTokens;
  final bool codeHealthBlockFeatures;

  // ── Sub-config views (lazy, computed once on first access) ──────────────
  //
  // Existing flat fields are UNCHANGED. These getters are additive views
  // that group related fields for callers that prefer structured access.
  // New code may write `config.autopilot.maxFailures` instead of
  // `config.autopilotMaxFailures`.

  late final AutopilotConfig autopilot =
      AutopilotConfig.fromProjectConfig(this);
  late final HitlConfig hitl = HitlConfig.fromProjectConfig(this);
  late final PipelineConfig pipeline = PipelineConfig.fromProjectConfig(this);
  late final GitConfig git = GitConfig.fromProjectConfig(this);
  late final PoliciesConfig policies = PoliciesConfig.fromProjectConfig(this);
  late final ReviewConfig review = ReviewConfig.fromProjectConfig(this);
  late final ProvidersConfig providers =
      ProvidersConfig.fromProjectConfig(this);
  late final CodeHealthConfig codeHealth =
      CodeHealthConfig.fromProjectConfig(this);
  late final ReflectionConfig reflection =
      ReflectionConfig.fromProjectConfig(this);

  AgentProfile? agentProfile(String key) {
    final normalized = _normalizeAgentKey(key);
    if (normalized.isEmpty) {
      return null;
    }
    return agentProfiles[normalized];
  }

  /// Resolve the reasoning effort level for a task category key.
  ///
  /// Falls back to the `default` entry, then `medium`.
  String reasoningEffortForCategory(String categoryKey) {
    final key = categoryKey.trim().toLowerCase();
    return reasoningEffortByCategory[key] ??
        reasoningEffortByCategory['default'] ??
        'medium';
  }

  /// Resolve the agent timeout for a task category key.
  ///
  /// Falls back to the `default` entry, then [agentTimeout].
  Duration agentTimeoutForCategory(String categoryKey) {
    final key = categoryKey.trim().toLowerCase();
    final seconds =
        agentTimeoutByCategory[key] ??
        agentTimeoutByCategory['default'] ??
        agentTimeout.inSeconds;
    return Duration(seconds: seconds);
  }

  /// Resolve the context injection token budget for a task category key.
  ///
  /// Falls back to the `default` entry, then [pipelineContextInjectionMaxTokens].
  int contextInjectionMaxTokensForCategory(String categoryKey) {
    final key = categoryKey.trim().toLowerCase();
    return contextInjectionMaxTokensByCategory[key] ??
        contextInjectionMaxTokensByCategory['default'] ??
        pipelineContextInjectionMaxTokens;
  }

  static ProjectConfig empty() {
    final profile = defaultShellAllowlistProfile;
    final allowlist = resolveShellAllowlist(
      profile: profile,
      customAllowlist: const [],
    );
    return ProjectConfig(
      shellAllowlist: allowlist,
      shellAllowlistProfile: profile,
      safeWriteRoots: defaultSafeWriteRoots,
    );
  }

  static ProjectConfig load(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    return loadFromFile(layout.configPath);
  }

  static ProjectConfig loadFromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return ProjectConfig.empty();
    }
    final lines = file.readAsLinesSync();
    return _parseLines(lines);
  }

  static String normalizeShellAllowlistProfile(
    String? value, {
    String? fallback,
  }) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback ?? defaultShellAllowlistProfile;
    }
    switch (trimmed) {
      case 'minimal':
      case 'standard':
      case 'extended':
      case 'custom':
        return trimmed;
    }
    return fallback ?? defaultShellAllowlistProfile;
  }

  static List<String> resolveShellAllowlist({
    required String profile,
    required List<String> customAllowlist,
  }) {
    final normalizedProfile = normalizeShellAllowlistProfile(profile);
    List<String> base;
    switch (normalizedProfile) {
      case 'minimal':
        base = minimalShellAllowlist;
        break;
      case 'extended':
        base = extendedShellAllowlist;
        break;
      case 'standard':
        base = standardShellAllowlist;
        break;
      case 'custom':
      default:
        base = customAllowlist;
        break;
    }
    return _normalizeAllowlist(base);
  }

  static List<String> normalizeSafeWriteRoots(List<String> roots) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final entry in roots) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  static List<String> normalizeQualityGateCommands(List<String> commands) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final entry in commands) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  static List<String> normalizeCliConfigOverrides(List<String> overrides) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final entry in overrides) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  /// @deprecated Use [normalizeCliConfigOverrides] instead.
  static List<String> normalizeCodexCliConfigOverrides(List<String> o) =>
      normalizeCliConfigOverrides(o);

  /// @deprecated Use [normalizeCliConfigOverrides] instead.
  static List<String> normalizeClaudeCodeCliConfigOverrides(List<String> o) =>
      normalizeCliConfigOverrides(o);

  /// @deprecated Use [normalizeCliConfigOverrides] instead.
  static List<String> normalizeGeminiCliConfigOverrides(List<String> o) =>
      normalizeCliConfigOverrides(o);

  static ProjectConfig _parseLines(List<String> lines) {
    return _parseProjectConfigLines(lines);
  }
}
