// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../policy/diff_budget_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../templates/default_files.dart';
import 'policy_simulation_service.dart';

class EvalBenchmark {
  EvalBenchmark({
    required this.id,
    required this.title,
    required this.prompt,
    this.expectedDecision,
    this.requireDiff = false,
    this.allowPolicyViolation = false,
  });

  final String id;
  final String title;
  final String prompt;
  final String? expectedDecision;
  final bool requireDiff;
  final bool allowPolicyViolation;

  factory EvalBenchmark.fromJson(Map<String, Object?> json) {
    return EvalBenchmark(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      expectedDecision:
          (json['expected_decision'] ?? '').toString().trim().isEmpty
          ? null
          : json['expected_decision'].toString(),
      requireDiff: json['require_diff'] == true,
      allowPolicyViolation: json['allow_policy_violation'] == true,
    );
  }
}

class EvalCaseResult {
  EvalCaseResult({
    required this.id,
    required this.title,
    required this.passed,
    required this.reviewDecision,
    required this.diffStats,
    required this.policyViolation,
    required this.policyMessage,
    this.reason,
  });

  final String id;
  final String title;
  final bool passed;
  final String? reviewDecision;
  final DiffStats? diffStats;
  final bool policyViolation;
  final String? policyMessage;
  final String? reason;
}

class EvalRunResult {
  EvalRunResult({
    required this.runId,
    required this.runAt,
    required this.successRate,
    required this.passed,
    required this.total,
    required this.results,
    required this.outputDir,
  });

  final String runId;
  final String runAt;
  final double successRate;
  final int passed;
  final int total;
  final List<EvalCaseResult> results;
  final String outputDir;
}

class EvalHarnessService {
  EvalHarnessService({PolicySimulationService? simulationService})
    : _simulationService = simulationService ?? PolicySimulationService();

  final PolicySimulationService _simulationService;

  Future<EvalRunResult> run(
    String projectRoot, {
    bool keepWorkspaces = false,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureFiles(layout);

    final benchmarks = _loadBenchmarks(layout);
    final runId = _buildRunId();
    final runAt = DateTime.now().toUtc().toIso8601String();
    final outputDir = _join(layout.evalResultsDir, runId);
    Directory(outputDir).createSync(recursive: true);

    RunLogStore(layout.runLogPath).append(
      event: 'eval_run_start',
      message: 'Eval harness started',
      data: {'root': projectRoot, 'run_id': runId, 'count': benchmarks.length},
    );

    final results = <EvalCaseResult>[];
    for (final benchmark in benchmarks) {
      final result = await _simulationService.run(
        projectRoot,
        codingPrompt: benchmark.prompt,
        overwriteArtifacts: false,
        keepWorkspace: keepWorkspaces,
      );
      final evaluation = _evaluate(benchmark, result);
      results.add(evaluation);
    }

    final passed = results.where((result) => result.passed).length;
    final total = results.length;
    final successRate = total == 0 ? 0.0 : (passed / total) * 100.0;

    final runPayload = _buildRunPayload(
      runId: runId,
      runAt: runAt,
      successRate: successRate,
      passed: passed,
      total: total,
      results: results,
    );
    File(
      _join(outputDir, 'run.json'),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(runPayload));

    _updateSummary(layout, runPayload);

    RunLogStore(layout.runLogPath).append(
      event: 'eval_run_complete',
      message: 'Eval harness completed',
      data: {
        'root': projectRoot,
        'run_id': runId,
        'passed': passed,
        'total': total,
        'success_rate': successRate,
      },
    );

    return EvalRunResult(
      runId: runId,
      runAt: runAt,
      successRate: successRate,
      passed: passed,
      total: total,
      results: results,
      outputDir: outputDir,
    );
  }

  void _ensureFiles(ProjectLayout layout) {
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.evalsDir).createSync(recursive: true);
    Directory(layout.evalResultsDir).createSync(recursive: true);
    final benchmarks = File(layout.evalBenchmarksPath);
    if (!benchmarks.existsSync()) {
      benchmarks.writeAsStringSync(DefaultFiles.evalBenchmarks());
    }
    final summary = File(layout.evalSummaryPath);
    if (!summary.existsSync()) {
      summary.writeAsStringSync(DefaultFiles.evalSummary());
    }
  }

  List<EvalBenchmark> _loadBenchmarks(ProjectLayout layout) {
    final file = File(layout.evalBenchmarksPath);
    if (!file.existsSync()) {
      return const [];
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return const [];
      }
      final list = decoded['benchmarks'];
      if (list is! List) {
        return const [];
      }
      return list
          .whereType<Map>()
          .map(
            (entry) => EvalBenchmark.fromJson(Map<String, Object?>.from(entry)),
          )
          .where((benchmark) => benchmark.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  EvalCaseResult _evaluate(
    EvalBenchmark benchmark,
    PolicySimulationResult result,
  ) {
    if (!result.hasTask) {
      return EvalCaseResult(
        id: benchmark.id,
        title: benchmark.title,
        passed: false,
        reviewDecision: result.reviewDecision,
        diffStats: result.diffStats,
        policyViolation: result.policyViolation,
        policyMessage: result.policyMessage,
        reason: 'no_task',
      );
    }

    final diffOk = !benchmark.requireDiff || _hasDiff(result);
    final decisionOk =
        benchmark.expectedDecision == null ||
        (result.reviewDecision ?? '') == benchmark.expectedDecision;
    final policyOk = benchmark.allowPolicyViolation || !result.policyViolation;

    final passed = diffOk && decisionOk && policyOk;
    String? reason;
    if (!passed) {
      if (!diffOk) {
        reason = 'missing_diff';
      } else if (!decisionOk) {
        reason = 'decision_mismatch';
      } else if (!policyOk) {
        reason = 'policy_violation';
      }
    }

    return EvalCaseResult(
      id: benchmark.id,
      title: benchmark.title,
      passed: passed,
      reviewDecision: result.reviewDecision,
      diffStats: result.diffStats,
      policyViolation: result.policyViolation,
      policyMessage: result.policyMessage,
      reason: reason,
    );
  }

  bool _hasDiff(PolicySimulationResult result) {
    final summary = result.diffSummary.trim();
    final patch = result.diffPatch.trim();
    if (summary.isNotEmpty || patch.isNotEmpty) {
      return true;
    }
    final stats = result.diffStats;
    if (stats == null) {
      return false;
    }
    return stats.filesChanged > 0 || stats.additions > 0 || stats.deletions > 0;
  }

  Map<String, Object?> _buildRunPayload({
    required String runId,
    required String runAt,
    required double successRate,
    required int passed,
    required int total,
    required List<EvalCaseResult> results,
  }) {
    return {
      'run_id': runId,
      'run_at': runAt,
      'success_rate': successRate,
      'passed': passed,
      'total': total,
      'results': results.map(_resultPayload).toList(),
    };
  }

  Map<String, Object?> _resultPayload(EvalCaseResult result) {
    final stats = result.diffStats;
    return {
      'id': result.id,
      'title': result.title,
      'passed': result.passed,
      'reason': result.reason,
      'review_decision': result.reviewDecision,
      'policy_violation': result.policyViolation,
      'policy_message': result.policyMessage,
      'diff_stats': stats == null
          ? null
          : {
              'files_changed': stats.filesChanged,
              'additions': stats.additions,
              'deletions': stats.deletions,
            },
    };
  }

  void _updateSummary(ProjectLayout layout, Map<String, Object?> runPayload) {
    final summaryFile = File(layout.evalSummaryPath);
    Map<String, Object?> summary;
    try {
      final decoded = jsonDecode(summaryFile.readAsStringSync());
      summary = decoded is Map
          ? Map<String, Object?>.from(decoded)
          : <String, Object?>{};
    } catch (_) {
      summary = <String, Object?>{};
    }

    final history = <Map<String, Object?>>[];
    final existing = summary['history'];
    if (existing is List) {
      for (final entry in existing) {
        if (entry is Map) {
          history.add(Map<String, Object?>.from(entry));
        }
      }
    }

    history.add({
      'run_id': runPayload['run_id'],
      'run_at': runPayload['run_at'],
      'success_rate': runPayload['success_rate'],
      'passed': runPayload['passed'],
      'total': runPayload['total'],
    });
    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }

    summary['last_run_id'] = runPayload['run_id'];
    summary['last_run_at'] = runPayload['run_at'];
    summary['success_rate'] = runPayload['success_rate'];
    summary['passed'] = runPayload['passed'];
    summary['total'] = runPayload['total'];
    summary['history'] = history;

    summaryFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(summary),
    );
  }

  String _buildRunId() {
    final now = DateTime.now().toUtc();
    final stamp = now.toIso8601String().replaceAll(':', '-');
    return 'run_$stamp';
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
