// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'project_config.dart';

ProjectConfig _parseProjectConfigLines(List<String> lines) {
  final s = ConfigParserState();
  final v = ConfigValuesMap();
  String? presetName;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      continue;
    }
    final indent = parse_utils.indentCount(rawLine);
    final trimmed = line.trim();

    // --- Section / subsection headers (lines ending with `:`) ---
    if (trimmed.endsWith(':') && !trimmed.contains(': ')) {
      final key = trimmed.substring(0, trimmed.length - 1);
      if (indent == 0) {
        s.currentSection = key;
        s.currentCategoryMapKey = null;
        if (s.currentSection != 'providers') {
          s.currentProvidersListKey = null;
          s.currentNativeSubsection = null;
        }
        if (s.currentSection != 'policies') {
          s.currentPoliciesSection = null;
          s.currentPoliciesListKey = null;
        }
        if (s.currentSection != 'agents') {
          s.currentAgentsSection = null;
        }
      } else if (s.currentSection == 'providers' && indent == 2) {
        providers_parser.parseProvidersSubsection(s, key);
      } else if (s.currentSection == 'policies') {
        policies_parser.parsePoliciesSubsection(s, key, indent);
      } else if (s.currentSection == 'agents' && indent == 2) {
        agents_parser.parseAgentsSubsection(s, key);
      } else if (s.currentSection == 'pipeline' && indent == 2) {
        if (key == 'context_injection_max_tokens_by_category') {
          s.currentCategoryMapKey = 'context_injection_max_tokens_by_category';
        } else {
          s.currentCategoryMapKey = null;
        }
      }
      continue;
    }

    // --- List items (`- foo`) ---
    if (trimmed.startsWith('- ')) {
      if (s.currentSection == 'providers' &&
          providers_parser.parseProvidersListItem(s, trimmed)) {
        continue;
      }
      if (s.currentSection == 'policies' &&
          policies_parser.parsePoliciesListItem(s, trimmed)) {
        continue;
      }
    }

    // --- Category map entries (key: value inside a named map) ---
    if (s.currentCategoryMapKey != null && indent >= 4) {
      final mapKv = parse_utils.parseKeyValue(trimmed);
      if (mapKv != null) {
        final mapKey = mapKv.key.trim().toLowerCase();
        if (mapKey.isNotEmpty) {
          switch (s.currentCategoryMapKey) {
            case 'reasoning_effort_by_category':
              final effort = mapKv.value.trim().toLowerCase();
              if (effort == 'low' || effort == 'medium' || effort == 'high') {
                s.reasoningEffortByCategory[mapKey] = effort;
              }
              break;
            case 'agent_seconds_by_category':
              final seconds = int.tryParse(mapKv.value.trim());
              if (seconds != null && seconds > 0) {
                s.agentTimeoutByCategory[mapKey] = seconds;
              }
              break;
            case 'context_injection_max_tokens_by_category':
              final tokens = int.tryParse(mapKv.value.trim());
              if (tokens != null && tokens > 0) {
                s.contextInjectionMaxTokensByCategory[mapKey] = tokens;
              }
              break;
          }
        }
        continue;
      }
    }

    // --- Key-value pairs ---
    final kv = parse_utils.parseKeyValue(trimmed);
    if (kv == null) {
      continue;
    }

    // Root-level key: preset.
    if (kv.key == 'preset' && s.currentSection == null) {
      presetName = kv.value.trim().toLowerCase();
      continue;
    }

    // A key-value at indent 2 inside `policies:` is at the policies level,
    // not inside any subsection — reset subsection state so the registry
    // section resolves to 'policies' rather than 'policies.<sub>'.
    if (s.currentSection == 'policies' && indent == 2) {
      s.currentPoliciesSection = null;
      s.currentPoliciesListKey = null;
      s.currentCategoryMapKey = null;
    }

    // Determine the registry section for the current parser position.
    final registrySection = _resolveRegistrySection(s);
    if (registrySection != null) {
      // Try registry-driven parsing first. If the key is in the registry,
      // parseRegistryKeyValue handles it and we skip the old parser.
      final qualified = '$registrySection.${kv.key}';
      if (registryFieldByQualifiedKey(qualified) != null) {
        parseRegistryKeyValue(v, registrySection, kv.key, kv.value);
        continue;
      }
    }

    // Fall through to specialised parsers for non-registry keys.
    if (s.currentSection == 'project') {
      project_parser.parseProjectKeyValue(s, kv);
    } else if (s.currentSection == 'providers') {
      providers_parser.parseProvidersKeyValue(s, kv, indent);
    } else if (s.currentSection == 'agents' &&
        s.currentAgentsSection != null &&
        s.currentAgentsSection!.isNotEmpty) {
      agents_parser.parseAgentsKeyValue(s, kv);
    } else if (s.currentSection == 'policies') {
      policies_parser.parsePoliciesKeyValue(s, kv);
    }
  }

  // --- Apply preset (layer between defaults and explicit YAML) ---
  if (presetName != null && configPresets.containsKey(presetName)) {
    v.applyPreset(configPresets[presetName]!);
  }

  // --- Post-processing and resolution ---
  return _buildProjectConfig(s, v);
}

/// Map the current parser position to the registry section path.
String? _resolveRegistrySection(ConfigParserState s) {
  final section = s.currentSection;
  if (section == null) return null;

  switch (section) {
    case 'git':
    case 'workflow':
    case 'autopilot':
    case 'pipeline':
    case 'review':
    case 'reflection':
    case 'supervisor':
    case 'vision_evaluation':
    case 'providers':
      return section;
    case 'policies':
      final sub = s.currentPoliciesSection;
      if (sub != null && sub.isNotEmpty) return 'policies.$sub';
      return 'policies';
    default:
      return null;
  }
}

/// Convenience: look up a registry field by its Dart name (must exist).
ConfigFieldDescriptor _field(String dartFieldName) {
  final f = registryFieldByDartName(dartFieldName);
  assert(f != null, 'Registry field not found: $dartFieldName');
  return f!;
}

ProjectConfig _buildProjectConfig(ConfigParserState s, ConfigValuesMap v) {
  // --- Non-registry post-processing (agents, providers, allowlists) ---
  final agentProfiles = <String, AgentProfile>{};
  final agentKeys = <String>{...s.agentEnabled.keys, ...s.agentPromptPaths.keys};
  for (final key in agentKeys) {
    agentProfiles[key] = AgentProfile(
      enabled: s.agentEnabled[key] ?? true,
      systemPromptPath: s.agentPromptPaths[key],
    );
  }

  // shellAllowlistProfile is a registry field stored in v, but needs custom
  // fallback logic: default to 'custom' when a custom allowlist is provided.
  final explicitProfile =
      v.wasExplicitlySet('policies.shell_allowlist_profile')
          ? v.getString(_field('shellAllowlistProfile'))
          : null;
  final resolvedProfile = ProjectConfig.normalizeShellAllowlistProfile(
    explicitProfile,
    fallback: s.shellAllowlist.isNotEmpty
        ? 'custom'
        : ProjectConfig.defaultShellAllowlistProfile,
  );
  final resolvedAllowlist = ProjectConfig.resolveShellAllowlist(
    profile: resolvedProfile,
    customAllowlist: s.shellAllowlist,
  );
  final resolvedSafeWriteRoots = ProjectConfig.normalizeSafeWriteRoots(
    s.safeWriteRoots.isEmpty
        ? ProjectConfig.defaultSafeWriteRoots
        : s.safeWriteRoots,
  );
  final resolvedQualityGateCommands =
      ProjectConfig.normalizeQualityGateCommands(
        s.qualityGateCommands.isEmpty
            ? ProjectConfig.defaultQualityGateCommands
            : s.qualityGateCommands,
      );
  final resolvedProviderPool = providers_parser.resolveProviderPoolEntries(
    configured: s.providerPoolRaw,
    primary: s.primary,
    fallback: s.fallback,
  );
  final resolvedCodexCliConfigOverrides =
      ProjectConfig.normalizeCliConfigOverrides(s.codexCliConfigOverrides);
  final resolvedClaudeCodeCliConfigOverrides =
      ProjectConfig.normalizeCliConfigOverrides(s.claudeCodeCliConfigOverrides);
  final resolvedGeminiCliConfigOverrides =
      ProjectConfig.normalizeCliConfigOverrides(s.geminiCliConfigOverrides);
  final resolvedVibeCliConfigOverrides =
      ProjectConfig.normalizeCliConfigOverrides(s.vibeCliConfigOverrides);
  final resolvedAmpCliConfigOverrides =
      ProjectConfig.normalizeCliConfigOverrides(s.ampCliConfigOverrides);

  final resolvedNativeConfig =
      (s.nativeModel != null || s.nativeApiBase != null)
          ? NativeProviderConfig(
              apiBase: s.nativeApiBase ?? NativeProviderConfig.defaultApiBase,
              model: s.nativeModel ?? '',
              apiKey: s.nativeApiKey ?? '',
              temperature:
                  s.nativeTemperature ?? NativeProviderConfig.defaultTemperature,
              maxTokens:
                  s.nativeMaxTokens ?? NativeProviderConfig.defaultMaxTokens,
              maxTurns:
                  s.nativeMaxTurns ?? NativeProviderConfig.defaultMaxTurns,
            )
          : null;

  // --- Build ProjectConfig using registry values (v) + non-registry state (s) ---
  return ProjectConfig(
    // Non-registry fields (project, providers complex, agents, lists, maps).
    projectType: s.projectType,
    providersPrimary: s.primary,
    providersFallback: s.fallback,
    providerPool: resolvedProviderPool,
    providersNative: resolvedNativeConfig,
    codexCliConfigOverrides: resolvedCodexCliConfigOverrides,
    claudeCodeCliConfigOverrides: resolvedClaudeCodeCliConfigOverrides,
    geminiCliConfigOverrides: resolvedGeminiCliConfigOverrides,
    vibeCliConfigOverrides: resolvedVibeCliConfigOverrides,
    ampCliConfigOverrides: resolvedAmpCliConfigOverrides,
    reasoningEffortByCategory: Map.unmodifiable({
      ...ProjectConfig.defaultReasoningEffortByCategory,
      ...s.reasoningEffortByCategory,
    }),
    agentTimeoutByCategory: Map.unmodifiable({
      ...ProjectConfig.defaultAgentTimeoutByCategory,
      ...s.agentTimeoutByCategory,
    }),
    shellAllowlist: resolvedAllowlist,
    shellAllowlistProfile: resolvedProfile,
    safeWriteRoots: resolvedSafeWriteRoots,
    qualityGateCommands: resolvedQualityGateCommands,
    contextInjectionMaxTokensByCategory: Map.unmodifiable({
      ...ProjectConfig.defaultContextInjectionMaxTokensByCategory,
      ...s.contextInjectionMaxTokensByCategory,
    }),
    agentProfiles: Map.unmodifiable(agentProfiles),

    // Registry-driven fields: providers.
    providerQuotaCooldown: v.getDuration(_field('providerQuotaCooldown')),
    providerQuotaPause: v.getDuration(_field('providerQuotaPause')),

    // Registry-driven fields: policies.
    diffBudgetMaxFiles: v.getInt(_field('diffBudgetMaxFiles')),
    diffBudgetMaxAdditions: v.getInt(_field('diffBudgetMaxAdditions')),
    diffBudgetMaxDeletions: v.getInt(_field('diffBudgetMaxDeletions')),
    safeWriteEnabled: v.getBool(_field('safeWriteEnabled')),
    qualityGateEnabled: v.getBool(_field('qualityGateEnabled')),
    qualityGateTimeout: v.getDuration(_field('qualityGateTimeout')),
    qualityGateAdaptiveByDiff: v.getBool(_field('qualityGateAdaptiveByDiff')),
    qualityGateSkipTestsForDocsOnly:
        v.getBool(_field('qualityGateSkipTestsForDocsOnly')),
    qualityGatePreferDartTestForLibDartOnly:
        v.getBool(_field('qualityGatePreferDartTestForLibDartOnly')),
    qualityGateFlakeRetryCount: v.getInt(_field('qualityGateFlakeRetryCount')),
    agentTimeout: v.getDuration(_field('agentTimeout')),

    // Registry-driven fields: git.
    gitBaseBranch: v.getString(_field('gitBaseBranch')),
    gitFeaturePrefix: v.getString(_field('gitFeaturePrefix')),
    gitAutoDeleteRemoteMergedBranches:
        v.getBool(_field('gitAutoDeleteRemoteMergedBranches')),
    gitAutoStash: v.getBool(_field('gitAutoStash')),
    gitAutoStashSkipRejected: v.getBool(_field('gitAutoStashSkipRejected')),
    gitAutoStashSkipRejectedUnattended:
        v.getBool(_field('gitAutoStashSkipRejectedUnattended')),
    gitSyncBetweenLoops: v.getBool(_field('gitSyncBetweenLoops')),
    gitSyncStrategy: v.getString(_field('gitSyncStrategy')),

    // Registry-driven fields: workflow.
    workflowRequireReview: v.getBool(_field('workflowRequireReview')),
    workflowAutoCommit: v.getBool(_field('workflowAutoCommit')),
    workflowAutoPush: v.getBool(_field('workflowAutoPush')),
    workflowAutoMerge: v.getBool(_field('workflowAutoMerge')),
    workflowMergeStrategy: v.getString(_field('workflowMergeStrategy')),

    // Registry-driven fields: autopilot.
    autopilotMinOpenTasks: v.getInt(_field('autopilotMinOpenTasks')),
    autopilotMaxPlanAdd: v.getInt(_field('autopilotMaxPlanAdd')),
    autopilotStepSleep: v.getDuration(_field('autopilotStepSleep')),
    autopilotIdleSleep: v.getDuration(_field('autopilotIdleSleep')),
    autopilotMaxSteps: v.getIntOrNull(_field('autopilotMaxSteps')),
    autopilotMaxFailures: v.getInt(_field('autopilotMaxFailures')),
    autopilotMaxTaskRetries: v.getInt(_field('autopilotMaxTaskRetries')),
    autopilotSelectionMode: v.getString(_field('autopilotSelectionMode')),
    autopilotFairnessWindow: v.getInt(_field('autopilotFairnessWindow')),
    autopilotPriorityWeightP1: v.getInt(_field('autopilotPriorityWeightP1')),
    autopilotPriorityWeightP2: v.getInt(_field('autopilotPriorityWeightP2')),
    autopilotPriorityWeightP3: v.getInt(_field('autopilotPriorityWeightP3')),
    autopilotReactivateBlocked: v.getBool(_field('autopilotReactivateBlocked')),
    autopilotReactivateFailed: v.getBool(_field('autopilotReactivateFailed')),
    autopilotBlockedCooldown:
        v.getDuration(_field('autopilotBlockedCooldown')),
    autopilotFailedCooldown:
        v.getDuration(_field('autopilotFailedCooldown')),
    autopilotLockTtl: v.getDuration(_field('autopilotLockTtl')),
    autopilotNoProgressThreshold:
        v.getInt(_field('autopilotNoProgressThreshold')),
    autopilotStuckCooldown: v.getDuration(_field('autopilotStuckCooldown')),
    autopilotSelfRestart: v.getBool(_field('autopilotSelfRestart')),
    autopilotSelfHealEnabled: v.getBool(_field('autopilotSelfHealEnabled')),
    autopilotSelfHealMaxAttempts:
        v.getInt(_field('autopilotSelfHealMaxAttempts')),
    autopilotScopeMaxFiles: v.getInt(_field('autopilotScopeMaxFiles')),
    autopilotScopeMaxAdditions: v.getInt(_field('autopilotScopeMaxAdditions')),
    autopilotScopeMaxDeletions: v.getInt(_field('autopilotScopeMaxDeletions')),
    autopilotApproveBudget: v.getInt(_field('autopilotApproveBudget')),
    autopilotManualOverride: v.getBool(_field('autopilotManualOverride')),
    autopilotOvernightUnattendedEnabled:
        v.getBool(_field('autopilotOvernightUnattendedEnabled')),
    autopilotSelfTuneEnabled: v.getBool(_field('autopilotSelfTuneEnabled')),
    autopilotSelfTuneWindow: v.getInt(_field('autopilotSelfTuneWindow')),
    autopilotSelfTuneMinSamples:
        v.getInt(_field('autopilotSelfTuneMinSamples')),
    autopilotSelfTuneSuccessPercent:
        v.getInt(_field('autopilotSelfTuneSuccessPercent')),
    autopilotReleaseTagOnReady: v.getBool(_field('autopilotReleaseTagOnReady')),
    autopilotReleaseTagPush: v.getBool(_field('autopilotReleaseTagPush')),
    autopilotReleaseTagPrefix: v.getString(_field('autopilotReleaseTagPrefix')),
    autopilotPlanningAuditEnabled:
        v.getBool(_field('autopilotPlanningAuditEnabled')),
    autopilotPlanningAuditCadenceSteps:
        v.getInt(_field('autopilotPlanningAuditCadenceSteps')),
    autopilotPlanningAuditMaxAdd:
        v.getInt(_field('autopilotPlanningAuditMaxAdd')),
    autopilotResourceCheckEnabled:
        v.getBool(_field('autopilotResourceCheckEnabled')),
    autopilotMaxStashEntries: v.getInt(_field('autopilotMaxStashEntries')),
    autopilotMaxWallclockHours: v.getInt(_field('autopilotMaxWallclockHours')),
    autopilotMaxSelfRestarts: v.getInt(_field('autopilotMaxSelfRestarts')),
    autopilotMaxIterationsSafetyLimit:
        v.getInt(_field('autopilotMaxIterationsSafetyLimit')),
    autopilotPreflightTimeout:
        v.getDuration(_field('autopilotPreflightTimeout')),
    autopilotSubtaskQueueMax: v.getInt(_field('autopilotSubtaskQueueMax')),
    autopilotPushFailureThreshold:
        v.getInt(_field('autopilotPushFailureThreshold')),
    autopilotProviderFailureThreshold:
        v.getInt(_field('autopilotProviderFailureThreshold')),
    autopilotReviewContractLockEnabled:
        v.getBool(_field('autopilotReviewContractLockEnabled')),
    autopilotPreflightRepairThreshold:
        v.getInt(_field('autopilotPreflightRepairThreshold')),
    autopilotMaxPreflightRepairAttempts:
        v.getInt(_field('autopilotMaxPreflightRepairAttempts')),
    autopilotLockHeartbeatHaltThreshold:
        v.getInt(_field('autopilotLockHeartbeatHaltThreshold')),
    autopilotSprintPlanningEnabled:
        v.getBool(_field('autopilotSprintPlanningEnabled')),
    autopilotMaxSprints: v.getInt(_field('autopilotMaxSprints')),
    autopilotSprintSize: v.getInt(_field('autopilotSprintSize')),
    hitlEnabled: v.getBool(_field('hitlEnabled')),
    hitlTimeoutMinutes: v.getInt(_field('hitlTimeoutMinutes')),
    hitlGateAfterTaskDone: v.getBool(_field('hitlGateAfterTaskDone')),
    hitlGateBeforeSprint: v.getBool(_field('hitlGateBeforeSprint')),
    hitlGateBeforeHalt: v.getBool(_field('hitlGateBeforeHalt')),

    // Registry-driven fields: pipeline.
    pipelineContextInjectionEnabled:
        v.getBool(_field('pipelineContextInjectionEnabled')),
    pipelineContextInjectionMaxTokens:
        v.getInt(_field('pipelineContextInjectionMaxTokens')),
    pipelineErrorPatternInjectionEnabled:
        v.getBool(_field('pipelineErrorPatternInjectionEnabled')),
    pipelineImpactAnalysisEnabled:
        v.getBool(_field('pipelineImpactAnalysisEnabled')),
    pipelineArchitectureGateEnabled:
        v.getBool(_field('pipelineArchitectureGateEnabled')),
    pipelineForensicRecoveryEnabled:
        v.getBool(_field('pipelineForensicRecoveryEnabled')),
    pipelineErrorPatternLearningEnabled:
        v.getBool(_field('pipelineErrorPatternLearningEnabled')),
    pipelineImpactContextMaxFiles:
        v.getInt(_field('pipelineImpactContextMaxFiles')),
    pipelineSubtaskRefinementEnabled:
        v.getBool(_field('pipelineSubtaskRefinementEnabled')),
    pipelineSubtaskFeasibilityEnabled:
        v.getBool(_field('pipelineSubtaskFeasibilityEnabled')),
    pipelineAcSelfCheckEnabled:
        v.getBool(_field('pipelineAcSelfCheckEnabled')),
    pipelineSubtaskCommitEnabled:
        v.getBool(_field('pipelineSubtaskCommitEnabled')),
    subtaskForcedNarrowingMaxSize:
        v.getInt(_field('subtaskForcedNarrowingMaxSize')),
    pipelineLessonsLearnedMaxLines:
        v.getInt(_field('pipelineLessonsLearnedMaxLines')),

    // Registry-driven fields: review.
    reviewFreshContext: v.getBool(_field('reviewFreshContext')),
    reviewStrictness: v.getString(_field('reviewStrictness')),
    reviewMaxRounds: v.getInt(_field('reviewMaxRounds')),
    reviewRequireEvidence: v.getBool(_field('reviewRequireEvidence')),
    reviewEvidenceMinLength: v.getInt(_field('reviewEvidenceMinLength')),

    // Registry-driven fields: reflection.
    reflectionEnabled: v.getBool(_field('reflectionEnabled')),
    reflectionTriggerMode: v.getString(_field('reflectionTriggerMode')),
    reflectionTriggerLoopCount: v.getInt(_field('reflectionTriggerLoopCount')),
    reflectionTriggerTaskCount: v.getInt(_field('reflectionTriggerTaskCount')),
    reflectionTriggerHours: v.getInt(_field('reflectionTriggerHours')),
    reflectionMinSamples: v.getInt(_field('reflectionMinSamples')),
    reflectionMaxOptimizationTasks:
        v.getInt(_field('reflectionMaxOptimizationTasks')),
    reflectionOptimizationPriority:
        v.getString(_field('reflectionOptimizationPriority')),
    reflectionAnalysisWindowLines:
        v.getInt(_field('reflectionAnalysisWindowLines')),

    // Registry-driven fields: supervisor.
    supervisorReflectionOnHalt:
        v.getBool(_field('supervisorReflectionOnHalt')),
    supervisorMaxInterventionsPerHour:
        v.getInt(_field('supervisorMaxInterventionsPerHour')),
    supervisorCheckInterval:
        v.getDuration(_field('supervisorCheckInterval')),

    // Registry-driven fields: vision_evaluation.
    visionEvaluationEnabled: v.getBool(_field('visionEvaluationEnabled')),
    visionEvaluationInterval: v.getInt(_field('visionEvaluationInterval')),
    visionCompletionThreshold:
        v.getDouble(_field('visionCompletionThreshold')),
  );
}

String _normalizeAgentKey(String value) {
  return value.trim().toLowerCase();
}

List<String> _normalizeAllowlist(List<String> allowlist) {
  return policies_parser.normalizeAllowlist(allowlist);
}
