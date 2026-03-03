// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../config/project_config.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'error_pattern_registry_service.dart';
import 'health_score_service.dart';
import 'insight_driven_task_service.dart';
import 'prompt_effectiveness_service.dart';
import 'retrospective_service.dart';
import 'observability/run_log_insight_service.dart';
import 'trend_analysis_service.dart';
import 'vision_alignment_service.dart';

/// Trigger configuration for periodic productivity reflection.
class ReflectionTrigger {
  const ReflectionTrigger({required this.mode, required this.threshold});

  /// Trigger mode: 'loop_count', 'task_count', or 'time'.
  final String mode;

  /// Threshold value for the trigger mode.
  final int threshold;
}

/// Result of a productivity reflection cycle.
class ProductivityReflectionResult {
  const ProductivityReflectionResult({
    required this.triggered,
    this.insights,
    this.healthReport,
    this.trend,
    this.optimizationTasksCreated = 0,
    this.patterns = const [],
    this.drift,
    this.gaps,
  });

  final bool triggered;
  final RunLogInsights? insights;
  final HealthReport? healthReport;
  final TrendReport? trend;
  final int optimizationTasksCreated;
  final List<String> patterns;

  /// Vision drift report (null when VISION.md is unavailable).
  final DriftReport? drift;

  /// Vision gap report (null when VISION.md is unavailable).
  final GapReport? gaps;
}

/// Periodically analyses autopilot productivity and generates optimisation
/// tasks when recurring patterns are detected.
///
/// This service orchestrates existing analysis services (RunLogInsight,
/// HealthScore, TrendAnalysis, InsightDrivenTask) into a single reflection
/// cycle that can be triggered by the run loop or supervisor.
class ProductivityReflectionService {
  ProductivityReflectionService({
    RunLogInsightService? insightService,
    TrendAnalysisService? trendService,
    InsightDrivenTaskService? taskService,
    HealthScoreService? healthService,
    RetrospectiveService? retrospectiveService,
    PromptEffectivenessService? promptEffectivenessService,
    ErrorPatternRegistryService? errorPatternRegistryService,
    VisionAlignmentService? visionAlignmentService,
  }) : _insightService = insightService ?? RunLogInsightService(),
       _trendService = trendService ?? TrendAnalysisService(),
       _taskService = taskService ?? InsightDrivenTaskService(),
       _healthService = healthService ?? HealthScoreService(),
       _retrospectiveService = retrospectiveService ?? RetrospectiveService(),
       _promptEffectivenessService =
           promptEffectivenessService ?? PromptEffectivenessService(),
       _errorPatternRegistry =
           errorPatternRegistryService ?? ErrorPatternRegistryService(),
       _visionAlignmentService =
           visionAlignmentService ?? VisionAlignmentService();

  final RunLogInsightService _insightService;
  final TrendAnalysisService _trendService;
  final InsightDrivenTaskService _taskService;
  final HealthScoreService _healthService;
  final RetrospectiveService _retrospectiveService;
  final PromptEffectivenessService _promptEffectivenessService;
  final ErrorPatternRegistryService _errorPatternRegistry;
  final VisionAlignmentService _visionAlignmentService;

  /// Returns `true` if a reflection should be triggered based on the given
  /// [trigger] configuration and current counters.
  bool shouldTrigger(
    String projectRoot, {
    required int completedLoops,
    required int completedTasks,
    required Duration elapsed,
    required ReflectionTrigger trigger,
  }) {
    if (trigger.threshold <= 0) return false;

    switch (trigger.mode) {
      case 'loop_count':
        return completedLoops > 0 && completedLoops % trigger.threshold == 0;
      case 'task_count':
        return completedTasks > 0 && completedTasks % trigger.threshold == 0;
      case 'time':
        return elapsed.inHours >= trigger.threshold;
      default:
        return false;
    }
  }

  /// Performs a full productivity reflection cycle.
  ///
  /// Analyses the run log for patterns, computes health scores and trends,
  /// and generates optimisation tasks for the most impactful improvements.
  ProductivityReflectionResult reflect(
    String projectRoot, {
    int maxOptimizationTasks = 3,
    String optimizationPriority = 'P2',
  }) {
    final config = ProjectConfig.load(projectRoot);
    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);

    runLog.append(
      event: 'reflection_triggered',
      message: 'Productivity reflection started',
    );

    // Gather metrics from existing services.
    final insights = _insightService.analyzeAndLog(projectRoot);

    // Skip full reflection when the run log has too few events to produce
    // meaningful results. The threshold is configured via
    // `reflection.min_samples` (default 5).
    if (insights.totalEvents < config.reflectionMinSamples) {
      runLog.append(
        event: 'reflection_skipped',
        message:
            'Insufficient samples for reflection '
            '(${insights.totalEvents} < ${config.reflectionMinSamples})',
      );
      return const ProductivityReflectionResult(triggered: false);
    }
    final retrospective = _retrospectiveService.analyze(projectRoot);
    final promptEffectiveness = _promptEffectivenessService.analyzeAndLog(
      projectRoot,
    );

    final healthReport = _healthService.score(
      retrospective: retrospective,
      insights: insights,
      promptEffectiveness: promptEffectiveness,
    );

    _trendService.recordSnapshot(projectRoot, healthReport);
    final trend = _trendService.analyze(projectRoot, healthReport);

    // Detect recurring patterns from error kinds and merge into registry.
    final patterns = _detectPatterns(insights);
    if (insights.errorKindCounts.isNotEmpty) {
      _errorPatternRegistry.mergeObservations(
        projectRoot,
        errorKindCounts: insights.errorKindCounts,
      );
    }

    // Vision alignment: drift and gap detection.
    final drift = _visionAlignmentService.detectDrift(projectRoot);
    final gaps = _visionAlignmentService.findGaps(projectRoot);

    // Generate optimisation tasks.
    final taskResult = _taskService.generate(projectRoot);
    final effectiveCreated = taskResult.created > maxOptimizationTasks
        ? maxOptimizationTasks
        : taskResult.created;

    runLog.append(
      event: 'reflection_complete',
      message: 'Productivity reflection completed',
      data: {
        'health_score': healthReport.overallScore,
        'health_grade': healthReport.grade.name,
        'step_success_rate': insights.stepSuccessRate,
        'review_approval_rate': insights.reviewApprovalRate,
        'optimization_tasks_created': effectiveCreated,
        'patterns': patterns,
        'trend_direction': trend.overallDirection.name,
        'vision_drift_detected': drift.driftDetected,
        'vision_alignment_rate': drift.alignmentRate,
        'vision_uncovered_goals': gaps.uncoveredGoals.length,
      },
    );

    return ProductivityReflectionResult(
      triggered: true,
      insights: insights,
      healthReport: healthReport,
      trend: trend,
      optimizationTasksCreated: effectiveCreated,
      patterns: patterns,
      drift: drift,
      gaps: gaps,
    );
  }

  /// Extracts top-N recurring error patterns from run log insights.
  List<String> _detectPatterns(RunLogInsights insights) {
    if (insights.errorKindCounts.isEmpty) return const [];

    final sorted = insights.errorKindCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) => '${e.key} (${e.value}x)').toList();
  }
}
