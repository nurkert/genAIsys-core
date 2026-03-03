import 'package:test/test.dart';
import 'package:genaisys/core/config/config_field_descriptor.dart';
import 'package:genaisys/core/config/config_field_registry.dart';
import 'package:genaisys/core/config/project_config.dart';

void main() {
  // -----------------------------------------------------------------------
  // Known field names on ProjectConfig, maintained manually.
  // If a new field is added to ProjectConfig, add it here (or to
  // _nonRegistryFields if it uses complex parsing).
  // -----------------------------------------------------------------------

  /// Fields on [ProjectConfig] that are NOT in the registry because they
  /// use complex parsing (lists, maps, provider pool, agent profiles, etc.).
  const nonRegistryFields = <String>{
    // project
    'projectType',
    // providers (complex)
    'providersPrimary',
    'providersFallback',
    'providerPool',
    'providersNative',
    'codexCliConfigOverrides',
    'claudeCodeCliConfigOverrides',
    'geminiCliConfigOverrides',
    'vibeCliConfigOverrides',
    'ampCliConfigOverrides',
    'reasoningEffortByCategory',
    'agentTimeoutByCategory',
    // policies (list-based)
    'shellAllowlist',
    'safeWriteRoots',
    'qualityGateCommands',
    // pipeline (category map / list)
    'contextInjectionMaxTokensByCategory',
    'pipelineTestDeltaGateCategories',
    // agents
    'agentProfiles',
  };

  test('no duplicate dartFieldNames in registry', () {
    final seen = <String>{};
    for (final field in configFieldRegistry) {
      expect(
        seen.add(field.dartFieldName),
        isTrue,
        reason: 'duplicate dartFieldName: ${field.dartFieldName}',
      );
    }
  });

  test('no duplicate qualifiedKeys in registry', () {
    final seen = <String>{};
    for (final field in configFieldRegistry) {
      expect(
        seen.add(field.qualifiedKey),
        isTrue,
        reason: 'duplicate qualifiedKey: ${field.qualifiedKey}',
      );
    }
  });

  test('every registry dartFieldName corresponds to a ProjectConfig field', () {
    // We verify by constructing a default ProjectConfig and reading the
    // field via a manual map. This is the reflection-free approach.
    final config = ProjectConfig.empty();
    final fieldValues = _projectConfigFieldMap(config);

    for (final field in configFieldRegistry) {
      expect(
        fieldValues.containsKey(field.dartFieldName),
        isTrue,
        reason:
            'registry entry "${field.dartFieldName}" not found in '
            'ProjectConfig field map — is the name correct?',
      );
    }
  });

  test('every registry entry default matches the ProjectConfig default', () {
    final config = ProjectConfig.empty();
    final fieldValues = _projectConfigFieldMap(config);

    for (final field in configFieldRegistry) {
      if (!fieldValues.containsKey(field.dartFieldName)) continue;

      final configValue = fieldValues[field.dartFieldName];
      final registryDefault = field.defaultValue;

      if (field.type == ConfigFieldType.duration) {
        // Duration fields: registry stores raw seconds, ProjectConfig has
        // Duration. Compare the seconds value.
        final duration = configValue as Duration;
        expect(
          duration.inSeconds,
          registryDefault,
          reason:
              '${field.dartFieldName}: registry default $registryDefault '
              '!= config Duration(seconds: ${duration.inSeconds})',
        );
      } else if (field.nullable && registryDefault == null) {
        expect(
          configValue,
          isNull,
          reason: '${field.dartFieldName}: expected null default',
        );
      } else {
        expect(
          configValue,
          registryDefault,
          reason:
              '${field.dartFieldName}: registry default $registryDefault '
              '!= config default $configValue',
        );
      }
    }
  });

  test('registry + nonRegistryFields cover all ProjectConfig fields', () {
    final config = ProjectConfig.empty();
    final allFields = _projectConfigFieldMap(config).keys.toSet();
    final registeredFields =
        configFieldRegistry.map((f) => f.dartFieldName).toSet();
    final covered = {...registeredFields, ...nonRegistryFields};

    final uncovered = allFields.difference(covered);
    expect(
      uncovered,
      isEmpty,
      reason:
          'ProjectConfig fields not covered by registry or nonRegistryFields: '
          '$uncovered — add to registry or nonRegistryFields set',
    );
  });

  test('lookup helpers return correct results', () {
    final byDart = registryFieldByDartName('autopilotMaxTaskRetries');
    expect(byDart, isNotNull);
    expect(byDart!.yamlKey, 'max_task_retries');
    expect(byDart.section, 'autopilot');

    final byKey = registryFieldByQualifiedKey('autopilot.max_task_retries');
    expect(byKey, isNotNull);
    expect(byKey!.dartFieldName, 'autopilotMaxTaskRetries');

    expect(registryFieldByDartName('nonExistent'), isNull);
    expect(registryFieldByQualifiedKey('fake.key'), isNull);
  });

  test('registryFieldsForSection returns correct fields', () {
    final reviewFields = registryFieldsForSection('review').toList();
    expect(reviewFields.length, 6);
    final names = reviewFields.map((f) => f.yamlKey).toSet();
    expect(
      names,
      containsAll([
        'fresh_context',
        'strictness',
        'max_rounds',
        'require_evidence',
        'evidence_min_length',
        'diff_delta_enabled',
      ]),
    );
  });

  test('registrySections contains all expected sections', () {
    final sections = registrySections;
    expect(
      sections,
      containsAll([
        'providers',
        'policies',
        'policies.diff_budget',
        'policies.safe_write',
        'policies.quality_gate',
        'policies.timeouts',
        'git',
        'workflow',
        'autopilot',
        'pipeline',
        'review',
        'reflection',
        'supervisor',
        'vision_evaluation',
        'code_health',
        'hitl',
      ]),
    );
  });

  test('bool fields have bool defaultValue', () {
    for (final field in configFieldRegistry) {
      if (field.type == ConfigFieldType.bool_) {
        expect(
          field.defaultValue is bool,
          isTrue,
          reason: '${field.dartFieldName}: bool field must have bool default',
        );
      }
    }
  });

  test('int fields have int defaultValue or null when nullable', () {
    for (final field in configFieldRegistry) {
      if (field.type == ConfigFieldType.int_) {
        if (field.nullable) {
          expect(
            field.defaultValue == null || field.defaultValue is int,
            isTrue,
            reason:
                '${field.dartFieldName}: nullable int field must have int or null default',
          );
        } else {
          expect(
            field.defaultValue is int,
            isTrue,
            reason: '${field.dartFieldName}: int field must have int default',
          );
        }
      }
    }
  });

  test('duration fields have int defaultValue (seconds)', () {
    for (final field in configFieldRegistry) {
      if (field.type == ConfigFieldType.duration) {
        expect(
          field.defaultValue is int,
          isTrue,
          reason:
              '${field.dartFieldName}: duration field must have int (seconds) default',
        );
      }
    }
  });

  test('string fields have String defaultValue', () {
    for (final field in configFieldRegistry) {
      if (field.type == ConfigFieldType.string_) {
        expect(
          field.defaultValue is String,
          isTrue,
          reason:
              '${field.dartFieldName}: string field must have String default',
        );
      }
    }
  });

  test('double fields have double defaultValue', () {
    for (final field in configFieldRegistry) {
      if (field.type == ConfigFieldType.double_) {
        expect(
          field.defaultValue is double,
          isTrue,
          reason:
              '${field.dartFieldName}: double field must have double default',
        );
      }
    }
  });

  // -----------------------------------------------------------------------
  // Sub-config view getter tests (additive — Phase 2 refactor)
  // Verify that the lazy sub-config views on ProjectConfig are accessible
  // and that sampled field values match the corresponding flat fields.
  // -----------------------------------------------------------------------

  group('Sub-config view getters', () {
    late ProjectConfig config;
    setUp(() => config = ProjectConfig.empty());

    test('all 9 sub-config getters return non-null objects', () {
      expect(config.autopilot, isNotNull);
      expect(config.pipeline, isNotNull);
      expect(config.git, isNotNull);
      expect(config.policies, isNotNull);
      expect(config.review, isNotNull);
      expect(config.providers, isNotNull);
      expect(config.codeHealth, isNotNull);
      expect(config.reflection, isNotNull);
      expect(config.hitl, isNotNull);
    });

    test('autopilot sub-config field values match flat fields', () {
      expect(config.autopilot.maxFailures, config.autopilotMaxFailures);
      expect(config.autopilot.stepSleep, config.autopilotStepSleep);
      expect(config.autopilot.idleSleep, config.autopilotIdleSleep);
      expect(config.autopilot.maxTaskRetries, config.autopilotMaxTaskRetries);
      expect(config.autopilot.noProgressThreshold,
          config.autopilotNoProgressThreshold);
      expect(config.autopilot.lockHeartbeatHaltThreshold,
          config.autopilotLockHeartbeatHaltThreshold);
    });

    test('pipeline sub-config field values match flat fields', () {
      expect(config.pipeline.contextInjectionEnabled,
          config.pipelineContextInjectionEnabled);
      expect(config.pipeline.lessonsLearnedEnabled,
          config.pipelineLessonsLearnedEnabled);
      expect(config.pipeline.testDeltaGateEnabled,
          config.pipelineTestDeltaGateEnabled);
    });

    test('git sub-config field values match flat fields', () {
      expect(config.git.baseBranch, config.gitBaseBranch);
      expect(config.git.featurePrefix, config.gitFeaturePrefix);
      expect(config.git.autoStash, config.gitAutoStash);
      expect(config.git.syncStrategy, config.gitSyncStrategy);
    });

    test('policies sub-config field values match flat fields', () {
      expect(config.policies.qualityGateEnabled, config.qualityGateEnabled);
      expect(config.policies.safeWriteEnabled, config.safeWriteEnabled);
      expect(config.policies.diffBudgetMaxFiles, config.diffBudgetMaxFiles);
    });

    test('review sub-config field values match flat fields', () {
      expect(config.review.requireReview, config.workflowRequireReview);
      expect(config.review.strictness, config.reviewStrictness);
      expect(config.review.maxRounds, config.reviewMaxRounds);
      expect(config.review.evidenceMinLength, config.reviewEvidenceMinLength);
    });

    test('codeHealth sub-config field values match flat fields', () {
      expect(config.codeHealth.enabled, config.codeHealthEnabled);
      expect(config.codeHealth.maxFileLines, config.codeHealthMaxFileLines);
      expect(config.codeHealth.llmBudgetTokens, config.codeHealthLlmBudgetTokens);
    });

    test('reflection sub-config field values match flat fields', () {
      expect(config.reflection.enabled, config.reflectionEnabled);
      expect(config.reflection.triggerMode, config.reflectionTriggerMode);
      expect(config.reflection.supervisorReflectionOnHalt,
          config.supervisorReflectionOnHalt);
      expect(config.reflection.visionDriftCheckEnabled,
          config.visionDriftCheckEnabled);
    });

    test('hitl sub-config field values match flat fields', () {
      expect(config.hitl.enabled, config.hitlEnabled);
      expect(config.hitl.timeoutMinutes, config.hitlTimeoutMinutes);
      expect(config.hitl.gateAfterTaskDone, config.hitlGateAfterTaskDone);
      expect(config.hitl.gateBeforeSprint, config.hitlGateBeforeSprint);
      expect(config.hitl.gateBeforeHalt, config.hitlGateBeforeHalt);
    });

    test('sub-config getters are lazy and return same instance on repeated access', () {
      final a = config.autopilot;
      final b = config.autopilot;
      expect(identical(a, b), isTrue, reason: 'late final getter must return same instance');
    });
  });
}

/// Reflection-free field map of [ProjectConfig]. When a new field is added
/// to [ProjectConfig], add a corresponding entry here.
Map<String, Object?> _projectConfigFieldMap(ProjectConfig c) => {
  // project
  'projectType': c.projectType,
  // providers
  'providersPrimary': c.providersPrimary,
  'providersFallback': c.providersFallback,
  'providerPool': c.providerPool,
  'providersNative': c.providersNative,
  'codexCliConfigOverrides': c.codexCliConfigOverrides,
  'claudeCodeCliConfigOverrides': c.claudeCodeCliConfigOverrides,
  'geminiCliConfigOverrides': c.geminiCliConfigOverrides,
  'vibeCliConfigOverrides': c.vibeCliConfigOverrides,
  'ampCliConfigOverrides': c.ampCliConfigOverrides,
  'reasoningEffortByCategory': c.reasoningEffortByCategory,
  'agentTimeoutByCategory': c.agentTimeoutByCategory,
  'providerQuotaCooldown': c.providerQuotaCooldown,
  'providerQuotaPause': c.providerQuotaPause,
  // policies
  'diffBudgetMaxFiles': c.diffBudgetMaxFiles,
  'diffBudgetMaxAdditions': c.diffBudgetMaxAdditions,
  'diffBudgetMaxDeletions': c.diffBudgetMaxDeletions,
  'shellAllowlist': c.shellAllowlist,
  'shellAllowlistProfile': c.shellAllowlistProfile,
  'safeWriteEnabled': c.safeWriteEnabled,
  'safeWriteRoots': c.safeWriteRoots,
  'qualityGateEnabled': c.qualityGateEnabled,
  'qualityGateCommands': c.qualityGateCommands,
  'qualityGateTimeout': c.qualityGateTimeout,
  'qualityGateAdaptiveByDiff': c.qualityGateAdaptiveByDiff,
  'qualityGateSkipTestsForDocsOnly': c.qualityGateSkipTestsForDocsOnly,
  'qualityGatePreferDartTestForLibDartOnly':
      c.qualityGatePreferDartTestForLibDartOnly,
  'qualityGateFlakeRetryCount': c.qualityGateFlakeRetryCount,
  'agentTimeout': c.agentTimeout,
  // git
  'gitBaseBranch': c.gitBaseBranch,
  'gitFeaturePrefix': c.gitFeaturePrefix,
  'gitAutoDeleteRemoteMergedBranches': c.gitAutoDeleteRemoteMergedBranches,
  'gitAutoStash': c.gitAutoStash,
  'gitAutoStashSkipRejected': c.gitAutoStashSkipRejected,
  'gitAutoStashSkipRejectedUnattended': c.gitAutoStashSkipRejectedUnattended,
  'gitSyncBetweenLoops': c.gitSyncBetweenLoops,
  'gitSyncStrategy': c.gitSyncStrategy,
  // workflow
  'workflowRequireReview': c.workflowRequireReview,
  'workflowAutoCommit': c.workflowAutoCommit,
  'workflowAutoPush': c.workflowAutoPush,
  'workflowAutoMerge': c.workflowAutoMerge,
  'workflowMergeStrategy': c.workflowMergeStrategy,
  // autopilot
  'autopilotMinOpenTasks': c.autopilotMinOpenTasks,
  'autopilotMaxPlanAdd': c.autopilotMaxPlanAdd,
  'autopilotStepSleep': c.autopilotStepSleep,
  'autopilotIdleSleep': c.autopilotIdleSleep,
  'autopilotMaxSteps': c.autopilotMaxSteps,
  'autopilotMaxFailures': c.autopilotMaxFailures,
  'autopilotMaxTaskRetries': c.autopilotMaxTaskRetries,
  'autopilotSelectionMode': c.autopilotSelectionMode,
  'autopilotFairnessWindow': c.autopilotFairnessWindow,
  'autopilotPriorityWeightP1': c.autopilotPriorityWeightP1,
  'autopilotPriorityWeightP2': c.autopilotPriorityWeightP2,
  'autopilotPriorityWeightP3': c.autopilotPriorityWeightP3,
  'autopilotReactivateBlocked': c.autopilotReactivateBlocked,
  'autopilotReactivateFailed': c.autopilotReactivateFailed,
  'autopilotBlockedCooldown': c.autopilotBlockedCooldown,
  'autopilotFailedCooldown': c.autopilotFailedCooldown,
  'autopilotLockTtl': c.autopilotLockTtl,
  'autopilotNoProgressThreshold': c.autopilotNoProgressThreshold,
  'autopilotStuckCooldown': c.autopilotStuckCooldown,
  'autopilotSelfRestart': c.autopilotSelfRestart,
  'autopilotSelfHealEnabled': c.autopilotSelfHealEnabled,
  'autopilotSelfHealMaxAttempts': c.autopilotSelfHealMaxAttempts,
  'autopilotScopeMaxFiles': c.autopilotScopeMaxFiles,
  'autopilotScopeMaxAdditions': c.autopilotScopeMaxAdditions,
  'autopilotScopeMaxDeletions': c.autopilotScopeMaxDeletions,
  'autopilotApproveBudget': c.autopilotApproveBudget,
  'autopilotManualOverride': c.autopilotManualOverride,
  'autopilotOvernightUnattendedEnabled': c.autopilotOvernightUnattendedEnabled,
  'autopilotSelfTuneEnabled': c.autopilotSelfTuneEnabled,
  'autopilotSelfTuneWindow': c.autopilotSelfTuneWindow,
  'autopilotSelfTuneMinSamples': c.autopilotSelfTuneMinSamples,
  'autopilotSelfTuneSuccessPercent': c.autopilotSelfTuneSuccessPercent,
  'autopilotReleaseTagOnReady': c.autopilotReleaseTagOnReady,
  'autopilotReleaseTagPush': c.autopilotReleaseTagPush,
  'autopilotReleaseTagPrefix': c.autopilotReleaseTagPrefix,
  'autopilotPlanningAuditEnabled': c.autopilotPlanningAuditEnabled,
  'autopilotPlanningAuditCadenceSteps': c.autopilotPlanningAuditCadenceSteps,
  'autopilotPlanningAuditMaxAdd': c.autopilotPlanningAuditMaxAdd,
  'autopilotResourceCheckEnabled': c.autopilotResourceCheckEnabled,
  'autopilotMaxStashEntries': c.autopilotMaxStashEntries,
  'autopilotMaxWallclockHours': c.autopilotMaxWallclockHours,
  'autopilotMaxSelfRestarts': c.autopilotMaxSelfRestarts,
  'autopilotMaxIterationsSafetyLimit': c.autopilotMaxIterationsSafetyLimit,
  'autopilotPreflightTimeout': c.autopilotPreflightTimeout,
  'autopilotSubtaskQueueMax': c.autopilotSubtaskQueueMax,
  'autopilotPushFailureThreshold': c.autopilotPushFailureThreshold,
  'autopilotProviderFailureThreshold': c.autopilotProviderFailureThreshold,
  'autopilotReviewContractLockEnabled': c.autopilotReviewContractLockEnabled,
  'autopilotPreflightRepairThreshold': c.autopilotPreflightRepairThreshold,
  'autopilotMaxPreflightRepairAttempts': c.autopilotMaxPreflightRepairAttempts,
  'autopilotLockHeartbeatHaltThreshold': c.autopilotLockHeartbeatHaltThreshold,
  'autopilotAdaptiveSleepEnabled': c.autopilotAdaptiveSleepEnabled,
  'autopilotAdaptiveSleepMaxMultiplier': c.autopilotAdaptiveSleepMaxMultiplier,
  'autopilotTaskDependenciesEnabled': c.autopilotTaskDependenciesEnabled,
  'autopilotSprintPlanningEnabled': c.autopilotSprintPlanningEnabled,
  'autopilotMaxSprints': c.autopilotMaxSprints,
  'autopilotSprintSize': c.autopilotSprintSize,
  'hitlEnabled': c.hitlEnabled,
  'hitlTimeoutMinutes': c.hitlTimeoutMinutes,
  'hitlGateAfterTaskDone': c.hitlGateAfterTaskDone,
  'hitlGateBeforeSprint': c.hitlGateBeforeSprint,
  'hitlGateBeforeHalt': c.hitlGateBeforeHalt,
  'visionDriftCheckEnabled': c.visionDriftCheckEnabled,
  'visionDriftCheckInterval': c.visionDriftCheckInterval,
  'reviewEvidenceMinLength': c.reviewEvidenceMinLength,
  // agents
  'agentProfiles': c.agentProfiles,
  // pipeline
  'pipelineContextInjectionEnabled': c.pipelineContextInjectionEnabled,
  'pipelineContextInjectionMaxTokens': c.pipelineContextInjectionMaxTokens,
  'contextInjectionMaxTokensByCategory': c.contextInjectionMaxTokensByCategory,
  'pipelineErrorPatternInjectionEnabled':
      c.pipelineErrorPatternInjectionEnabled,
  'pipelineImpactAnalysisEnabled': c.pipelineImpactAnalysisEnabled,
  'pipelineArchitectureGateEnabled': c.pipelineArchitectureGateEnabled,
  'pipelineForensicRecoveryEnabled': c.pipelineForensicRecoveryEnabled,
  'pipelineErrorPatternLearningEnabled': c.pipelineErrorPatternLearningEnabled,
  'pipelineImpactContextMaxFiles': c.pipelineImpactContextMaxFiles,
  'pipelineSubtaskRefinementEnabled': c.pipelineSubtaskRefinementEnabled,
  'pipelineSubtaskFeasibilityEnabled': c.pipelineSubtaskFeasibilityEnabled,
  'pipelineAcSelfCheckEnabled': c.pipelineAcSelfCheckEnabled,
  'pipelineSubtaskCommitEnabled': c.pipelineSubtaskCommitEnabled,
  'subtaskForcedNarrowingMaxSize': c.subtaskForcedNarrowingMaxSize,
  'pipelineTestDeltaGateEnabled': c.pipelineTestDeltaGateEnabled,
  'pipelineTestDeltaGateCategories': c.pipelineTestDeltaGateCategories,
  'pipelineLessonsLearnedEnabled': c.pipelineLessonsLearnedEnabled,
  'pipelineLessonsLearnedMaxLines': c.pipelineLessonsLearnedMaxLines,
  'pipelineFinalAcCheckEnabled': c.pipelineFinalAcCheckEnabled,
  // review
  'reviewFreshContext': c.reviewFreshContext,
  'reviewStrictness': c.reviewStrictness,
  'reviewMaxRounds': c.reviewMaxRounds,
  'reviewRequireEvidence': c.reviewRequireEvidence,
  'reviewDiffDeltaEnabled': c.reviewDiffDeltaEnabled,
  // reflection
  'reflectionEnabled': c.reflectionEnabled,
  'reflectionTriggerMode': c.reflectionTriggerMode,
  'reflectionTriggerLoopCount': c.reflectionTriggerLoopCount,
  'reflectionTriggerTaskCount': c.reflectionTriggerTaskCount,
  'reflectionTriggerHours': c.reflectionTriggerHours,
  'reflectionMinSamples': c.reflectionMinSamples,
  'reflectionMaxOptimizationTasks': c.reflectionMaxOptimizationTasks,
  'reflectionOptimizationPriority': c.reflectionOptimizationPriority,
  'reflectionAnalysisWindowLines': c.reflectionAnalysisWindowLines,
  // supervisor
  'supervisorReflectionOnHalt': c.supervisorReflectionOnHalt,
  'supervisorMaxInterventionsPerHour': c.supervisorMaxInterventionsPerHour,
  'supervisorCheckInterval': c.supervisorCheckInterval,
  // vision evaluation
  'visionEvaluationEnabled': c.visionEvaluationEnabled,
  'visionEvaluationInterval': c.visionEvaluationInterval,
  'visionCompletionThreshold': c.visionCompletionThreshold,
  // code health
  'codeHealthEnabled': c.codeHealthEnabled,
  'codeHealthAutoCreateTasks': c.codeHealthAutoCreateTasks,
  'codeHealthMinConfidence': c.codeHealthMinConfidence,
  'codeHealthMaxRefactorRatio': c.codeHealthMaxRefactorRatio,
  'codeHealthMaxFileLines': c.codeHealthMaxFileLines,
  'codeHealthMaxMethodLines': c.codeHealthMaxMethodLines,
  'codeHealthMaxNestingDepth': c.codeHealthMaxNestingDepth,
  'codeHealthMaxParameterCount': c.codeHealthMaxParameterCount,
  'codeHealthHotspotThreshold': c.codeHealthHotspotThreshold,
  'codeHealthHotspotWindow': c.codeHealthHotspotWindow,
  'codeHealthPatchClusterMin': c.codeHealthPatchClusterMin,
  'codeHealthReflectionEnabled': c.codeHealthReflectionEnabled,
  'codeHealthReflectionCadence': c.codeHealthReflectionCadence,
  'codeHealthLlmBudgetTokens': c.codeHealthLlmBudgetTokens,
  'codeHealthBlockFeatures': c.codeHealthBlockFeatures,
};
