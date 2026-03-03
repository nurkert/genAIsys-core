// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all reflection- and supervisor-related fields from
/// [ProjectConfig], as well as vision drift/evaluation fields.
class ReflectionConfig {
  const ReflectionConfig({
    required this.enabled,
    required this.triggerMode,
    required this.triggerLoopCount,
    required this.triggerTaskCount,
    required this.triggerHours,
    required this.minSamples,
    required this.maxOptimizationTasks,
    required this.optimizationPriority,
    required this.analysisWindowLines,
    required this.supervisorReflectionOnHalt,
    required this.supervisorMaxInterventionsPerHour,
    required this.supervisorCheckInterval,
    required this.visionDriftCheckEnabled,
    required this.visionDriftCheckInterval,
    required this.visionEvaluationEnabled,
    required this.visionEvaluationInterval,
    required this.visionCompletionThreshold,
  });

  factory ReflectionConfig.fromProjectConfig(ProjectConfig c) =>
      ReflectionConfig(
        enabled: c.reflectionEnabled,
        triggerMode: c.reflectionTriggerMode,
        triggerLoopCount: c.reflectionTriggerLoopCount,
        triggerTaskCount: c.reflectionTriggerTaskCount,
        triggerHours: c.reflectionTriggerHours,
        minSamples: c.reflectionMinSamples,
        maxOptimizationTasks: c.reflectionMaxOptimizationTasks,
        optimizationPriority: c.reflectionOptimizationPriority,
        analysisWindowLines: c.reflectionAnalysisWindowLines,
        supervisorReflectionOnHalt: c.supervisorReflectionOnHalt,
        supervisorMaxInterventionsPerHour: c.supervisorMaxInterventionsPerHour,
        supervisorCheckInterval: c.supervisorCheckInterval,
        visionDriftCheckEnabled: c.visionDriftCheckEnabled,
        visionDriftCheckInterval: c.visionDriftCheckInterval,
        visionEvaluationEnabled: c.visionEvaluationEnabled,
        visionEvaluationInterval: c.visionEvaluationInterval,
        visionCompletionThreshold: c.visionCompletionThreshold,
      );

  final bool enabled;
  final String triggerMode;
  final int triggerLoopCount;
  final int triggerTaskCount;
  final int triggerHours;
  final int minSamples;
  final int maxOptimizationTasks;
  final String optimizationPriority;
  final int analysisWindowLines;
  final bool supervisorReflectionOnHalt;
  final int supervisorMaxInterventionsPerHour;
  final Duration supervisorCheckInterval;
  final bool visionDriftCheckEnabled;
  final int visionDriftCheckInterval;
  final bool visionEvaluationEnabled;
  final int visionEvaluationInterval;
  final double visionCompletionThreshold;
}
