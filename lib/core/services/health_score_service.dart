// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/health_snapshot.dart';
import 'prompt_effectiveness_service.dart';
import 'retrospective_service.dart';
import 'observability/run_log_insight_service.dart';

/// Component-level health score with a 0–100 value.
class ComponentScore {
  const ComponentScore({
    required this.name,
    required this.score,
    required this.weight,
    required this.details,
  });

  final String name;

  /// 0–100, where 100 is fully healthy.
  final double score;

  /// Relative weight (0.0–1.0) in the aggregate score.
  final double weight;

  /// Human-readable details about how the score was computed.
  final String details;

  double get weightedScore => score * weight;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'score': _round(score),
      'weight': _round(weight),
      'weighted_score': _round(weightedScore),
      'details': details,
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

/// Overall health grade derived from the aggregate score.
enum HealthGrade { healthy, degraded, critical }

/// Aggregate health report with component breakdown.
class HealthReport {
  const HealthReport({
    required this.overallScore,
    required this.grade,
    required this.components,
    required this.timestamp,
  });

  final double overallScore;
  final HealthGrade grade;
  final List<ComponentScore> components;
  final String timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'overall_score': _round(overallScore),
      'grade': grade.name,
      'timestamp': timestamp,
      'components': components.map((c) => c.toJson()).toList(),
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class HealthScoreService {
  /// Compute a quantitative health score from all available analysis sources.
  ///
  /// Components and weights:
  /// - pipeline (30%): step success rate, idle ratio
  /// - review (25%): review approval rate, prompt effectiveness
  /// - provider (15%): quota hits, blocks, provider failures
  /// - task_completion (30%): completion rate, block rate, dead letters
  HealthReport score({
    HealthSnapshot? snapshot,
    RetrospectiveSummary? retrospective,
    RunLogInsights? insights,
    PromptEffectivenessReport? promptEffectiveness,
  }) {
    final components = <ComponentScore>[
      _scorePipeline(insights, snapshot),
      _scoreReview(insights, promptEffectiveness),
      _scoreProvider(insights),
      _scoreTaskCompletion(retrospective, insights),
    ];

    var totalWeight = 0.0;
    var weightedSum = 0.0;
    for (final c in components) {
      totalWeight += c.weight;
      weightedSum += c.weightedScore;
    }

    final overall = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
    final grade = _gradeFromScore(overall);

    return HealthReport(
      overallScore: overall,
      grade: grade,
      components: components,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
  }

  ComponentScore _scorePipeline(
    RunLogInsights? insights,
    HealthSnapshot? snapshot,
  ) {
    if (insights == null || insights.totalEvents == 0) {
      // No data → neutral score, unless infra is down.
      final infraOk = snapshot?.allOk ?? true;
      return ComponentScore(
        name: 'pipeline',
        score: infraOk ? 75.0 : 25.0,
        weight: 0.30,
        details: infraOk
            ? 'No pipeline events yet; infrastructure healthy.'
            : 'No pipeline events; infrastructure check failed.',
      );
    }

    // Step success rate: 0–100.
    final successScore = insights.stepSuccessRate * 100;

    // Idle ratio penalty: high idle means the system isn't doing useful work.
    final totalSteps =
        insights.successfulSteps + insights.failedSteps + insights.idleSteps;
    final idleRatio = totalSteps > 0 ? insights.idleSteps / totalSteps : 0.0;
    final idlePenalty = idleRatio > 0.5 ? (idleRatio - 0.5) * 40 : 0.0;

    final raw = (successScore - idlePenalty).clamp(0.0, 100.0);

    return ComponentScore(
      name: 'pipeline',
      score: raw,
      weight: 0.30,
      details:
          'Success rate ${_pct(insights.stepSuccessRate)}, '
          'idle ratio ${_pct(idleRatio)}, '
          '${insights.failedSteps} failures.',
    );
  }

  ComponentScore _scoreReview(
    RunLogInsights? insights,
    PromptEffectivenessReport? promptEffectiveness,
  ) {
    final totalReviews =
        (insights?.reviewApprovals ?? 0) + (insights?.reviewRejections ?? 0);

    if (totalReviews == 0 &&
        (promptEffectiveness == null ||
            promptEffectiveness.overallCycles == 0)) {
      return const ComponentScore(
        name: 'review',
        score: 75.0,
        weight: 0.25,
        details: 'No review data yet.',
      );
    }

    // Base: review approval rate from run log insights.
    var approvalScore = insights != null
        ? insights.reviewApprovalRate * 100
        : 75.0;

    // Refine with prompt effectiveness if available.
    if (promptEffectiveness != null && promptEffectiveness.overallCycles > 0) {
      final promptScore = promptEffectiveness.overallApprovalRate * 100;
      // Blend: 60% run log, 40% prompt effectiveness.
      approvalScore = approvalScore * 0.6 + promptScore * 0.4;
    }

    return ComponentScore(
      name: 'review',
      score: approvalScore.clamp(0.0, 100.0),
      weight: 0.25,
      details:
          'Approval rate ${_pct(approvalScore / 100)}, '
          '$totalReviews total reviews.',
    );
  }

  ComponentScore _scoreProvider(RunLogInsights? insights) {
    if (insights == null || insights.totalEvents == 0) {
      return const ComponentScore(
        name: 'provider',
        score: 100.0,
        weight: 0.15,
        details: 'No provider issues detected.',
      );
    }

    // Start at 100 and deduct for quota hits and blocks.
    var raw = 100.0;

    // Each quota hit: -5 (up to 50 deduction).
    raw -= (insights.providerQuotaHits * 5).clamp(0, 50).toDouble();

    // Each provider block: -15 (up to 45 deduction).
    raw -= (insights.providerBlocks * 15).clamp(0, 45).toDouble();

    return ComponentScore(
      name: 'provider',
      score: raw.clamp(0.0, 100.0),
      weight: 0.15,
      details:
          '${insights.providerQuotaHits} quota hits, '
          '${insights.providerBlocks} blocks.',
    );
  }

  ComponentScore _scoreTaskCompletion(
    RetrospectiveSummary? retrospective,
    RunLogInsights? insights,
  ) {
    if (retrospective == null || retrospective.totalTasks == 0) {
      return const ComponentScore(
        name: 'task_completion',
        score: 75.0,
        weight: 0.30,
        details: 'No completed task data yet.',
      );
    }

    // Base: completion rate (0–100).
    final completionScore = retrospective.completionRate * 100;

    // Dead letter penalty: -10 per dead letter, up to 40.
    final deadLetterPenalty = ((insights?.deadLetterCount ?? 0) * 10)
        .clamp(0, 40)
        .toDouble();

    // High average retries penalty.
    final retryPenalty = retrospective.averageRetries > 1.0
        ? ((retrospective.averageRetries - 1.0) * 10).clamp(0.0, 20.0)
        : 0.0;

    final raw = (completionScore - deadLetterPenalty - retryPenalty).clamp(
      0.0,
      100.0,
    );

    return ComponentScore(
      name: 'task_completion',
      score: raw,
      weight: 0.30,
      details:
          'Completion ${_pct(retrospective.completionRate)}, '
          '${retrospective.blockedTasks} blocked, '
          '${insights?.deadLetterCount ?? 0} dead letters, '
          'avg retries ${_roundVal(retrospective.averageRetries)}.',
    );
  }

  HealthGrade _gradeFromScore(double score) {
    if (score >= 70) return HealthGrade.healthy;
    if (score >= 40) return HealthGrade.degraded;
    return HealthGrade.critical;
  }

  String _pct(double value) {
    return '${(value * 100).round()}%';
  }

  double _roundVal(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
