// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'eval_harness_service.dart';
import 'health_score_service.dart';
import 'insight_driven_task_service.dart';
import 'meta_task_service.dart';
import 'prompt_effectiveness_service.dart';
import 'readiness_gate_service.dart';
import 'retrospective_service.dart';
import 'observability/run_log_insight_service.dart';
import 'self_tuning_service.dart';
import 'trend_analysis_service.dart';

class SelfImproveResult {
  SelfImproveResult({
    this.meta,
    this.eval,
    this.tune,
    this.retrospective,
    this.insights,
    this.promptEffectiveness,
    this.insightTasks,
    this.healthReport,
    this.readiness,
    this.trend,
  });

  final MetaTaskResult? meta;
  final EvalRunResult? eval;
  final SelfTuneResult? tune;
  final RetrospectiveSummary? retrospective;
  final RunLogInsights? insights;
  final PromptEffectivenessReport? promptEffectiveness;
  final InsightTaskResult? insightTasks;
  final HealthReport? healthReport;
  final ReadinessVerdict? readiness;
  final TrendReport? trend;
}

class SelfImprovementService {
  SelfImprovementService({
    MetaTaskService? metaTaskService,
    EvalHarnessService? evalHarnessService,
    SelfTuningService? selfTuningService,
    RetrospectiveService? retrospectiveService,
    RunLogInsightService? runLogInsightService,
    PromptEffectivenessService? promptEffectivenessService,
    InsightDrivenTaskService? insightDrivenTaskService,
    HealthScoreService? healthScoreService,
    ReadinessGateService? readinessGateService,
    TrendAnalysisService? trendAnalysisService,
  }) : _metaTaskService = metaTaskService ?? MetaTaskService(),
       _evalHarnessService = evalHarnessService ?? EvalHarnessService(),
       _selfTuningService = selfTuningService ?? SelfTuningService(),
       _retrospectiveService = retrospectiveService ?? RetrospectiveService(),
       _runLogInsightService = runLogInsightService ?? RunLogInsightService(),
       _promptEffectivenessService =
           promptEffectivenessService ?? PromptEffectivenessService(),
       _insightDrivenTaskService =
           insightDrivenTaskService ?? InsightDrivenTaskService(),
       _healthScoreService = healthScoreService ?? HealthScoreService(),
       _readinessGateService = readinessGateService ?? ReadinessGateService(),
       _trendAnalysisService = trendAnalysisService ?? TrendAnalysisService();

  final MetaTaskService _metaTaskService;
  final EvalHarnessService _evalHarnessService;
  final SelfTuningService _selfTuningService;
  final RetrospectiveService _retrospectiveService;
  final RunLogInsightService _runLogInsightService;
  final PromptEffectivenessService _promptEffectivenessService;
  final InsightDrivenTaskService _insightDrivenTaskService;
  final HealthScoreService _healthScoreService;
  final ReadinessGateService _readinessGateService;
  final TrendAnalysisService _trendAnalysisService;

  Future<SelfImproveResult> run(
    String projectRoot, {
    bool runMeta = true,
    bool runEval = true,
    bool runTune = true,
    bool runAnalysis = true,
    bool keepWorkspaces = false,
  }) async {
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'self_improve_start',
      message: 'Self-improvement started',
      data: {
        'root': projectRoot,
        'run_meta': runMeta,
        'run_eval': runEval,
        'run_tune': runTune,
        'run_analysis': runAnalysis,
      },
    );

    MetaTaskResult? meta;
    EvalRunResult? eval;
    SelfTuneResult? tune;
    RetrospectiveSummary? retrospective;
    RunLogInsights? insights;
    PromptEffectivenessReport? promptEffectiveness;
    InsightTaskResult? insightTasks;
    HealthReport? healthReport;
    ReadinessVerdict? readiness;
    TrendReport? trend;

    // Phase C: Run analysis pipeline first so insights inform tuning.
    if (runAnalysis) {
      retrospective = _retrospectiveService.analyze(projectRoot);
      insights = _runLogInsightService.analyzeAndLog(projectRoot);
      promptEffectiveness = _promptEffectivenessService.analyzeAndLog(
        projectRoot,
      );
      insightTasks = _insightDrivenTaskService.generate(projectRoot);

      // Phase D: Compute health score, record trend, evaluate readiness.
      healthReport = _healthScoreService.score(
        retrospective: retrospective,
        insights: insights,
        promptEffectiveness: promptEffectiveness,
      );
      _trendAnalysisService.recordSnapshot(projectRoot, healthReport);
      trend = _trendAnalysisService.analyze(projectRoot, healthReport);
      readiness = _readinessGateService.evaluate(
        projectRoot,
        healthReport: healthReport,
      );
    }

    if (runMeta) {
      meta = _metaTaskService.ensureMetaTasks(projectRoot);
    }
    if (runEval) {
      eval = await _evalHarnessService.run(
        projectRoot,
        keepWorkspaces: keepWorkspaces,
      );
    }
    if (runTune) {
      tune = _selfTuningService.tune(projectRoot);
    }

    RunLogStore(layout.runLogPath).append(
      event: 'self_improve_complete',
      message: 'Self-improvement completed',
      data: {
        'root': projectRoot,
        'meta_created': meta?.created ?? 0,
        'eval_passed': eval?.passed ?? 0,
        'eval_total': eval?.total ?? 0,
        'tune_applied': tune?.applied ?? false,
        'retrospective_total': retrospective?.totalTasks ?? 0,
        'retrospective_completion_rate': retrospective?.completionRate ?? 0.0,
        'insights_success_rate': insights?.stepSuccessRate ?? 0.0,
        'prompt_approval_rate': promptEffectiveness?.overallApprovalRate ?? 0.0,
        'insight_tasks_created': insightTasks?.created ?? 0,
        'health_score': healthReport?.overallScore ?? 0.0,
        'health_grade': healthReport?.grade.name ?? 'unknown',
        'promotable': readiness?.promotable ?? false,
        'trend_direction': trend?.overallDirection.name ?? 'unknown',
        'trend_regressions': trend?.regressions ?? [],
      },
    );

    return SelfImproveResult(
      meta: meta,
      eval: eval,
      tune: tune,
      retrospective: retrospective,
      insights: insights,
      promptEffectiveness: promptEffectiveness,
      insightTasks: insightTasks,
      healthReport: healthReport,
      readiness: readiness,
      trend: trend,
    );
  }
}
