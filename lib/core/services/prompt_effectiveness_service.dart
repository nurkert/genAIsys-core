// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';

/// Per-persona metrics for prompt effectiveness.
class PersonaMetrics {
  const PersonaMetrics({
    required this.persona,
    this.approvals = 0,
    this.rejections = 0,
    this.noDiffs = 0,
    this.totalCycles = 0,
  });

  final String persona;
  final int approvals;
  final int rejections;
  final int noDiffs;
  final int totalCycles;

  double get approvalRate => totalCycles > 0 ? approvals / totalCycles : 0.0;

  double get rejectionRate => totalCycles > 0 ? rejections / totalCycles : 0.0;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'persona': persona,
      'approvals': approvals,
      'rejections': rejections,
      'no_diffs': noDiffs,
      'total_cycles': totalCycles,
      'approval_rate': _round(approvalRate),
      'rejection_rate': _round(rejectionRate),
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

/// Aggregate prompt effectiveness report.
class PromptEffectivenessReport {
  const PromptEffectivenessReport({
    required this.personaMetrics,
    required this.overallApprovalRate,
    required this.overallCycles,
  });

  final Map<String, PersonaMetrics> personaMetrics;
  final double overallApprovalRate;
  final int overallCycles;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'overall_cycles': overallCycles,
      'overall_approval_rate': _round(overallApprovalRate),
      'personas': {
        for (final entry in personaMetrics.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class PromptEffectivenessService {
  /// Default number of tail lines to analyze (avoids full-file scan).
  static const int defaultMaxLines = 2000;

  /// Analyze the run log for per-persona prompt effectiveness.
  ///
  /// Only the most recent [maxLines] lines are analyzed to keep memory
  /// bounded during long-running sessions.
  PromptEffectivenessReport analyze(
    String projectRoot, {
    int maxLines = defaultMaxLines,
  }) {
    final layout = ProjectLayout(projectRoot);

    // Track the persona for each cycle via correlation.
    // task_cycle_start has review_persona in data; task_cycle_end has the outcome.
    String? currentPersona;
    final personaCounts = <String, _PersonaAccumulator>{};

    final lines = RunLogStore.readTailLines(
      layout.runLogPath,
      maxLines: maxLines,
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

      final event = decoded['event']?.toString() ?? '';
      final data = decoded['data'];
      final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;

      if (event == 'task_cycle_start') {
        final persona = dataMap?['review_persona']?.toString().trim() ?? '';
        currentPersona = persona.isNotEmpty ? persona : null;
        continue;
      }

      if (event == 'task_cycle_end' && currentPersona != null) {
        final persona = currentPersona;
        final acc = personaCounts.putIfAbsent(
          persona,
          () => _PersonaAccumulator(persona),
        );
        acc.totalCycles += 1;

        final decision =
            dataMap?['review_decision']?.toString().trim().toLowerCase() ?? '';
        final blocked = dataMap?['task_blocked'] == true;

        if (decision == 'approve') {
          acc.approvals += 1;
        } else if (decision == 'reject') {
          acc.rejections += 1;
        } else if (!blocked) {
          // No review decision and not blocked → likely no diff produced.
          acc.noDiffs += 1;
        }

        currentPersona = null;
        continue;
      }
    }

    var overallApprovals = 0;
    var overallCycles = 0;
    final metrics = <String, PersonaMetrics>{};
    for (final acc in personaCounts.values) {
      metrics[acc.persona] = PersonaMetrics(
        persona: acc.persona,
        approvals: acc.approvals,
        rejections: acc.rejections,
        noDiffs: acc.noDiffs,
        totalCycles: acc.totalCycles,
      );
      overallApprovals += acc.approvals;
      overallCycles += acc.totalCycles;
    }

    return PromptEffectivenessReport(
      personaMetrics: Map.unmodifiable(metrics),
      overallApprovalRate: overallCycles > 0
          ? overallApprovals / overallCycles
          : 0.0,
      overallCycles: overallCycles,
    );
  }

  /// Analyze and persist report to the run log.
  PromptEffectivenessReport analyzeAndLog(String projectRoot) {
    final report = analyze(projectRoot);
    final layout = ProjectLayout(projectRoot);
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'prompt_effectiveness_analysis',
        message: 'Prompt effectiveness analysis completed',
        data: report.toJson(),
      );
    }
    return report;
  }

  static const _empty = PromptEffectivenessReport(
    personaMetrics: {},
    overallApprovalRate: 0.0,
    overallCycles: 0,
  );
}

class _PersonaAccumulator {
  _PersonaAccumulator(this.persona);

  final String persona;
  int approvals = 0;
  int rejections = 0;
  int noDiffs = 0;
  int totalCycles = 0;
}
