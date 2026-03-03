// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all pipeline-related fields from [ProjectConfig].
class PipelineConfig {
  const PipelineConfig({
    required this.contextInjectionEnabled,
    required this.contextInjectionMaxTokens,
    required this.contextInjectionMaxTokensByCategory,
    required this.errorPatternInjectionEnabled,
    required this.impactAnalysisEnabled,
    required this.architectureGateEnabled,
    required this.forensicRecoveryEnabled,
    required this.errorPatternLearningEnabled,
    required this.impactContextMaxFiles,
    required this.subtaskRefinementEnabled,
    required this.subtaskFeasibilityEnabled,
    required this.acSelfCheckEnabled,
    required this.subtaskCommitEnabled,
    required this.subtaskForcedNarrowingMaxSize,
    required this.testDeltaGateEnabled,
    required this.testDeltaGateCategories,
    required this.lessonsLearnedEnabled,
    required this.lessonsLearnedMaxLines,
    required this.reviewDiffDeltaEnabled,
    required this.finalAcCheckEnabled,
  });

  factory PipelineConfig.fromProjectConfig(ProjectConfig c) => PipelineConfig(
    contextInjectionEnabled: c.pipelineContextInjectionEnabled,
    contextInjectionMaxTokens: c.pipelineContextInjectionMaxTokens,
    contextInjectionMaxTokensByCategory: c.contextInjectionMaxTokensByCategory,
    errorPatternInjectionEnabled: c.pipelineErrorPatternInjectionEnabled,
    impactAnalysisEnabled: c.pipelineImpactAnalysisEnabled,
    architectureGateEnabled: c.pipelineArchitectureGateEnabled,
    forensicRecoveryEnabled: c.pipelineForensicRecoveryEnabled,
    errorPatternLearningEnabled: c.pipelineErrorPatternLearningEnabled,
    impactContextMaxFiles: c.pipelineImpactContextMaxFiles,
    subtaskRefinementEnabled: c.pipelineSubtaskRefinementEnabled,
    subtaskFeasibilityEnabled: c.pipelineSubtaskFeasibilityEnabled,
    acSelfCheckEnabled: c.pipelineAcSelfCheckEnabled,
    subtaskCommitEnabled: c.pipelineSubtaskCommitEnabled,
    subtaskForcedNarrowingMaxSize: c.subtaskForcedNarrowingMaxSize,
    testDeltaGateEnabled: c.pipelineTestDeltaGateEnabled,
    testDeltaGateCategories: c.pipelineTestDeltaGateCategories,
    lessonsLearnedEnabled: c.pipelineLessonsLearnedEnabled,
    lessonsLearnedMaxLines: c.pipelineLessonsLearnedMaxLines,
    reviewDiffDeltaEnabled: c.reviewDiffDeltaEnabled,
    finalAcCheckEnabled: c.pipelineFinalAcCheckEnabled,
  );

  final bool contextInjectionEnabled;
  final int contextInjectionMaxTokens;
  final Map<String, int> contextInjectionMaxTokensByCategory;
  final bool errorPatternInjectionEnabled;
  final bool impactAnalysisEnabled;
  final bool architectureGateEnabled;
  final bool forensicRecoveryEnabled;
  final bool errorPatternLearningEnabled;
  final int impactContextMaxFiles;
  final bool subtaskRefinementEnabled;
  final bool subtaskFeasibilityEnabled;
  final bool acSelfCheckEnabled;
  final bool subtaskCommitEnabled;
  final int subtaskForcedNarrowingMaxSize;
  final bool testDeltaGateEnabled;
  final List<String> testDeltaGateCategories;
  final bool lessonsLearnedEnabled;
  final int lessonsLearnedMaxLines;
  final bool reviewDiffDeltaEnabled;
  final bool finalAcCheckEnabled;
}
