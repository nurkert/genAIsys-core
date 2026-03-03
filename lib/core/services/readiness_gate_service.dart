// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'health_score_service.dart';

/// Individual readiness criterion result.
class ReadinessCriterion {
  const ReadinessCriterion({
    required this.name,
    required this.passed,
    required this.message,
  });

  final String name;
  final bool passed;
  final String message;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'passed': passed,
      'message': message,
    };
  }
}

/// Overall readiness verdict.
class ReadinessVerdict {
  const ReadinessVerdict({
    required this.promotable,
    required this.criteria,
    required this.blockingReasons,
    required this.timestamp,
  });

  final bool promotable;
  final List<ReadinessCriterion> criteria;
  final List<String> blockingReasons;
  final String timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'promotable': promotable,
      'blocking_reasons': blockingReasons,
      'timestamp': timestamp,
      'criteria': criteria.map((c) => c.toJson()).toList(),
    };
  }
}

class ReadinessGateService {
  ReadinessGateService({
    this.minHealthScore = 60.0,
    this.minEvalPassRate = 80.0,
  });

  /// Minimum health score (0–100) required for promotion.
  final double minHealthScore;

  /// Minimum eval harness pass rate (0–100) required for promotion.
  final double minEvalPassRate;

  /// Evaluate release readiness based on health score, open P1s, eval results,
  /// and policy compliance.
  ReadinessVerdict evaluate(
    String projectRoot, {
    required HealthReport healthReport,
  }) {
    final layout = ProjectLayout(projectRoot);
    final criteria = <ReadinessCriterion>[];
    final blocking = <String>[];

    // Criterion 1: Health score threshold.
    final healthPassed = healthReport.overallScore >= minHealthScore;
    criteria.add(
      ReadinessCriterion(
        name: 'health_score',
        passed: healthPassed,
        message: healthPassed
            ? 'Health score ${_round(healthReport.overallScore)} >= $minHealthScore.'
            : 'Health score ${_round(healthReport.overallScore)} < $minHealthScore.',
      ),
    );
    if (!healthPassed) {
      blocking.add(
        'Health score ${_round(healthReport.overallScore)} below '
        'threshold $minHealthScore.',
      );
    }

    // Criterion 2: No open P1 stabilization tasks.
    final taskStore = TaskStore(layout.tasksPath);
    final hasP1 = taskStore.hasOpenP1StabilizationTask();
    criteria.add(
      ReadinessCriterion(
        name: 'no_open_p1',
        passed: !hasP1,
        message: hasP1
            ? 'Open P1 stabilization tasks remain.'
            : 'No open P1 stabilization tasks.',
      ),
    );
    if (hasP1) {
      blocking.add('Open P1 stabilization tasks must be resolved.');
    }

    // Criterion 3: Eval harness pass rate.
    final evalResult = _loadEvalSummary(layout);
    if (evalResult != null) {
      final evalPassed = evalResult >= minEvalPassRate;
      criteria.add(
        ReadinessCriterion(
          name: 'eval_pass_rate',
          passed: evalPassed,
          message: evalPassed
              ? 'Eval pass rate ${_round(evalResult)}% >= $minEvalPassRate%.'
              : 'Eval pass rate ${_round(evalResult)}% < $minEvalPassRate%.',
        ),
      );
      if (!evalPassed) {
        blocking.add(
          'Eval harness pass rate ${_round(evalResult)}% below '
          'threshold $minEvalPassRate%.',
        );
      }
    } else {
      // No eval data is not blocking, but noted.
      criteria.add(
        const ReadinessCriterion(
          name: 'eval_pass_rate',
          passed: true,
          message: 'No eval harness data available; criterion skipped.',
        ),
      );
    }

    // Criterion 4: No critical health grade.
    final gradePassed = healthReport.grade != HealthGrade.critical;
    criteria.add(
      ReadinessCriterion(
        name: 'no_critical_grade',
        passed: gradePassed,
        message: gradePassed
            ? 'Health grade: ${healthReport.grade.name}.'
            : 'Health grade is critical; promotion blocked.',
      ),
    );
    if (!gradePassed) {
      blocking.add('Health grade is critical.');
    }

    final promotable = blocking.isEmpty;
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final verdict = ReadinessVerdict(
      promotable: promotable,
      criteria: criteria,
      blockingReasons: blocking,
      timestamp: timestamp,
    );

    // Persist to run log.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'readiness_gate_evaluation',
        message: promotable
            ? 'Release readiness gate passed'
            : 'Release readiness gate blocked',
        data: verdict.toJson(),
      );
    }

    return verdict;
  }

  /// Load the latest eval success rate from the eval summary file.
  double? _loadEvalSummary(ProjectLayout layout) {
    final file = File(layout.evalSummaryPath);
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      final rate = decoded['success_rate'];
      if (rate is num) return rate.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
