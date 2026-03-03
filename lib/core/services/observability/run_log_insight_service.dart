// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../config/project_config.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

/// Aggregated insights from the run log event stream.
class RunLogInsights {
  const RunLogInsights({
    required this.totalEvents,
    required this.successfulSteps,
    required this.failedSteps,
    required this.idleSteps,
    required this.reviewApprovals,
    required this.reviewRejections,
    required this.tasksCompleted,
    required this.tasksBlocked,
    required this.providerQuotaHits,
    required this.providerBlocks,
    required this.deadLetterCount,
    required this.autoHealCount,
    required this.errorKindCounts,
    required this.errorClassCounts,
    required this.providerFailureCounts,
  });

  final int totalEvents;
  final int successfulSteps;
  final int failedSteps;
  final int idleSteps;
  final int reviewApprovals;
  final int reviewRejections;
  final int tasksCompleted;
  final int tasksBlocked;
  final int providerQuotaHits;
  final int providerBlocks;
  final int deadLetterCount;
  final int autoHealCount;
  final Map<String, int> errorKindCounts;
  final Map<String, int> errorClassCounts;
  final Map<String, int> providerFailureCounts;

  double get stepSuccessRate {
    final total = successfulSteps + failedSteps;
    return total > 0 ? successfulSteps / total : 0.0;
  }

  double get reviewApprovalRate {
    final total = reviewApprovals + reviewRejections;
    return total > 0 ? reviewApprovals / total : 0.0;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'total_events': totalEvents,
      'successful_steps': successfulSteps,
      'failed_steps': failedSteps,
      'idle_steps': idleSteps,
      'step_success_rate': _round(stepSuccessRate),
      'review_approvals': reviewApprovals,
      'review_rejections': reviewRejections,
      'review_approval_rate': _round(reviewApprovalRate),
      'tasks_completed': tasksCompleted,
      'tasks_blocked': tasksBlocked,
      'provider_quota_hits': providerQuotaHits,
      'provider_blocks': providerBlocks,
      'dead_letter_count': deadLetterCount,
      'auto_heal_count': autoHealCount,
      if (errorKindCounts.isNotEmpty) 'error_kind_counts': errorKindCounts,
      if (errorClassCounts.isNotEmpty) 'error_class_counts': errorClassCounts,
      if (providerFailureCounts.isNotEmpty)
        'provider_failure_counts': providerFailureCounts,
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class RunLogInsightService {
  /// Default number of tail lines to analyze (avoids full-file scan).
  static const int defaultMaxLines = 2000;

  /// Analyze the run log and compute aggregate metrics.
  ///
  /// Only the most recent [maxLines] lines are analyzed. This keeps
  /// memory bounded during long-running sessions (week+). When [maxLines]
  /// is not specified, the value from `reflection.analysis_window_lines`
  /// config is used (default 2000).
  RunLogInsights analyze(String projectRoot, {int? maxLines}) {
    final effectiveMaxLines =
        maxLines ??
        ProjectConfig.load(projectRoot).reflectionAnalysisWindowLines;
    final layout = ProjectLayout(projectRoot);

    var totalEvents = 0;
    var successfulSteps = 0;
    var failedSteps = 0;
    var idleSteps = 0;
    var reviewApprovals = 0;
    var reviewRejections = 0;
    var tasksCompleted = 0;
    var tasksBlocked = 0;
    var providerQuotaHits = 0;
    var providerBlocks = 0;
    var deadLetterCount = 0;
    var autoHealCount = 0;
    final errorKindCounts = <String, int>{};
    final errorClassCounts = <String, int>{};
    final providerFailureCounts = <String, int>{};

    final lines = RunLogStore.readTailLines(
      layout.runLogPath,
      maxLines: effectiveMaxLines,
    );
    if (lines.isEmpty) {
      return _empty;
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      Map<String, dynamic>? decoded;
      try {
        final raw = jsonDecode(trimmed);
        if (raw is! Map) continue;
        decoded = Map<String, dynamic>.from(raw);
      } catch (_) {
        continue;
      }

      totalEvents += 1;
      final event = decoded['event']?.toString() ?? '';
      final data = decoded['data'];
      final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;

      switch (event) {
        case 'orchestrator_run_step':
        case 'orchestrator_step':
          final idle = dataMap != null && dataMap['idle'] == true;
          if (idle) {
            idleSteps += 1;
          } else {
            successfulSteps += 1;
          }
          break;

        case 'orchestrator_run_error':
        case 'orchestrator_run_transient_error':
        case 'orchestrator_run_permanent_error':
        case 'orchestrator_run_stuck':
        case 'orchestrator_run_safety_halt':
          failedSteps += 1;
          _countError(dataMap, errorKindCounts, errorClassCounts);
          break;

        case 'review_approve':
          reviewApprovals += 1;
          break;
        case 'review_reject':
          reviewRejections += 1;
          break;

        case 'task_done':
          tasksCompleted += 1;
          break;
        case 'task_blocked':
          tasksBlocked += 1;
          break;

        case 'task_dead_letter':
          deadLetterCount += 1;
          _countError(dataMap, errorKindCounts, errorClassCounts);
          break;

        case 'autopilot_supervisor_auto_heal':
          autoHealCount += 1;
          break;

        case 'provider_pool_quota_hit':
          providerQuotaHits += 1;
          final provider = dataMap?['provider']?.toString().trim() ?? '';
          if (provider.isNotEmpty) {
            providerFailureCounts[provider] =
                (providerFailureCounts[provider] ?? 0) + 1;
          }
          break;

        case 'unattended_provider_blocked':
          providerBlocks += 1;
          break;

        case 'unattended_provider_failure_increment':
          final provider = dataMap?['provider']?.toString().trim() ?? '';
          if (provider.isNotEmpty) {
            providerFailureCounts[provider] =
                (providerFailureCounts[provider] ?? 0) + 1;
          }
          break;
      }
    }

    return RunLogInsights(
      totalEvents: totalEvents,
      successfulSteps: successfulSteps,
      failedSteps: failedSteps,
      idleSteps: idleSteps,
      reviewApprovals: reviewApprovals,
      reviewRejections: reviewRejections,
      tasksCompleted: tasksCompleted,
      tasksBlocked: tasksBlocked,
      providerQuotaHits: providerQuotaHits,
      providerBlocks: providerBlocks,
      deadLetterCount: deadLetterCount,
      autoHealCount: autoHealCount,
      errorKindCounts: Map.unmodifiable(errorKindCounts),
      errorClassCounts: Map.unmodifiable(errorClassCounts),
      providerFailureCounts: Map.unmodifiable(providerFailureCounts),
    );
  }

  /// Analyze and persist insights to the run log.
  RunLogInsights analyzeAndLog(String projectRoot) {
    final insights = analyze(projectRoot);
    final layout = ProjectLayout(projectRoot);
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'run_log_insight_analysis',
        message: 'Run log insight analysis completed',
        data: insights.toJson(),
      );
    }
    return insights;
  }

  void _countError(
    Map<String, dynamic>? data,
    Map<String, int> kindCounts,
    Map<String, int> classCounts,
  ) {
    if (data == null) return;
    final kind = data['error_kind']?.toString().trim() ?? '';
    final errorClass = data['error_class']?.toString().trim() ?? '';
    if (kind.isNotEmpty) {
      kindCounts[kind] = (kindCounts[kind] ?? 0) + 1;
    }
    if (errorClass.isNotEmpty) {
      classCounts[errorClass] = (classCounts[errorClass] ?? 0) + 1;
    }
  }

  static const _empty = RunLogInsights(
    totalEvents: 0,
    successfulSteps: 0,
    failedSteps: 0,
    idleSteps: 0,
    reviewApprovals: 0,
    reviewRejections: 0,
    tasksCompleted: 0,
    tasksBlocked: 0,
    providerQuotaHits: 0,
    providerBlocks: 0,
    deadLetterCount: 0,
    autoHealCount: 0,
    errorKindCounts: {},
    errorClassCounts: {},
    providerFailureCounts: {},
  );
}
