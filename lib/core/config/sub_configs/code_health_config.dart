// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all code-health-related fields from [ProjectConfig].
class CodeHealthConfig {
  const CodeHealthConfig({
    required this.enabled,
    required this.autoCreateTasks,
    required this.minConfidence,
    required this.maxRefactorRatio,
    required this.maxFileLines,
    required this.maxMethodLines,
    required this.maxNestingDepth,
    required this.maxParameterCount,
    required this.hotspotThreshold,
    required this.hotspotWindow,
    required this.patchClusterMin,
    required this.reflectionEnabled,
    required this.reflectionCadence,
    required this.llmBudgetTokens,
    required this.blockFeatures,
  });

  factory CodeHealthConfig.fromProjectConfig(ProjectConfig c) =>
      CodeHealthConfig(
        enabled: c.codeHealthEnabled,
        autoCreateTasks: c.codeHealthAutoCreateTasks,
        minConfidence: c.codeHealthMinConfidence,
        maxRefactorRatio: c.codeHealthMaxRefactorRatio,
        maxFileLines: c.codeHealthMaxFileLines,
        maxMethodLines: c.codeHealthMaxMethodLines,
        maxNestingDepth: c.codeHealthMaxNestingDepth,
        maxParameterCount: c.codeHealthMaxParameterCount,
        hotspotThreshold: c.codeHealthHotspotThreshold,
        hotspotWindow: c.codeHealthHotspotWindow,
        patchClusterMin: c.codeHealthPatchClusterMin,
        reflectionEnabled: c.codeHealthReflectionEnabled,
        reflectionCadence: c.codeHealthReflectionCadence,
        llmBudgetTokens: c.codeHealthLlmBudgetTokens,
        blockFeatures: c.codeHealthBlockFeatures,
      );

  final bool enabled;
  final bool autoCreateTasks;
  final double minConfidence;
  final double maxRefactorRatio;
  final int maxFileLines;
  final int maxMethodLines;
  final int maxNestingDepth;
  final int maxParameterCount;
  final double hotspotThreshold;
  final int hotspotWindow;
  final int patchClusterMin;
  final bool reflectionEnabled;
  final int reflectionCadence;
  final int llmBudgetTokens;
  final bool blockFeatures;
}
