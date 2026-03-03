// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/task.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';

/// A goal extracted from VISION.md's "Goals (High-Level)" section.
class VisionGoal {
  const VisionGoal({required this.text, required this.keywords});

  /// Raw goal text from the VISION.md bullet.
  final String text;

  /// Lowercased keywords extracted from the goal text for matching.
  final Set<String> keywords;
}

/// Alignment score for a single task against vision goals.
class AlignmentScore {
  const AlignmentScore({
    required this.taskTitle,
    required this.score,
    required this.matchedGoals,
  });

  /// Title of the scored task.
  final String taskTitle;

  /// Alignment score in range [0.0, 1.0].
  final double score;

  /// Goal texts that matched for this task.
  final List<String> matchedGoals;
}

/// Result of a drift detection analysis.
class DriftReport {
  const DriftReport({
    required this.alignedCount,
    required this.totalCount,
    required this.alignmentRate,
    required this.driftDetected,
  });

  /// Number of recently completed tasks that aligned with vision goals.
  final int alignedCount;

  /// Total number of recently completed tasks analyzed.
  final int totalCount;

  /// Alignment rate in range [0.0, 1.0].
  final double alignmentRate;

  /// True if alignment rate fell below the drift threshold (30%).
  final bool driftDetected;
}

/// Result of a gap analysis: vision goals without matching tasks.
class GapReport {
  const GapReport({
    required this.totalGoals,
    required this.coveredGoals,
    required this.uncoveredGoals,
  });

  /// Total number of vision goals.
  final int totalGoals;

  /// Goals that have at least one matching open or completed task.
  final int coveredGoals;

  /// Goal texts that have no matching tasks in the backlog.
  final List<String> uncoveredGoals;
}

/// Analyses alignment between project tasks and the VISION.md goals.
///
/// Provides:
/// - Goal extraction from VISION.md
/// - Per-task alignment scoring via keyword overlap
/// - Drift detection (are recent completions still aligned?)
/// - Gap detection (are there vision goals without tasks?)
class VisionAlignmentService {
  VisionAlignmentService();

  /// Minimum alignment score (0.0-1.0) to count a task as "aligned".
  static const double alignmentThreshold = 0.15;

  /// Drift threshold: if fewer than 30% of recently completed tasks are
  /// aligned, drift is detected.
  static const double driftThreshold = 0.30;

  /// Minimum number of keywords required for a goal to be usable.
  static const int _minGoalKeywords = 2;

  /// Stop words excluded from keyword extraction.
  static const Set<String> _stopWords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
    'has', 'have', 'in', 'is', 'it', 'its', 'of', 'on', 'or', 'the',
    'to', 'was', 'were', 'with', 'that', 'this', 'can', 'may', 'must',
    'should', 'will', 'would', 'not', 'but', 'into', 'through', 'only',
    'after', 'before', 'between', 'each', 'every', 'all', 'any', 'both',
    'more', 'most', 'no', 'nor', 'so', 'than', 'too', 'very',
    // Common Genaisys-context words that aren't differentiating.
    'details', 'see', 'also', 'using', 'used', 'use',
  };

  /// Extracts structured goals from the VISION.md `Goals (High-Level)` section.
  List<VisionGoal> extractGoals(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final path = layout.visionPath;
    if (!File(path).existsSync()) {
      return const [];
    }
    return _parseGoals(File(path).readAsLinesSync());
  }

  /// Computes an alignment score (0.0-1.0) between a candidate title and
  /// a set of vision goals using keyword overlap (Jaccard-like).
  AlignmentScore scoreAlignment(String candidateTitle, List<VisionGoal> goals) {
    if (goals.isEmpty) {
      return AlignmentScore(
        taskTitle: candidateTitle,
        score: 0.0,
        matchedGoals: const [],
      );
    }
    final candidateKw = _extractKeywords(candidateTitle);
    if (candidateKw.isEmpty) {
      return AlignmentScore(
        taskTitle: candidateTitle,
        score: 0.0,
        matchedGoals: const [],
      );
    }

    var bestScore = 0.0;
    final matched = <String>[];

    for (final goal in goals) {
      final overlap = candidateKw.intersection(goal.keywords).length;
      if (overlap == 0) continue;
      // Modified Jaccard: overlap / min(candidate, goal) to favor small tasks
      // matching large goals.
      final denominator = candidateKw.length < goal.keywords.length
          ? candidateKw.length
          : goal.keywords.length;
      final score = denominator > 0 ? overlap / denominator : 0.0;
      if (score > bestScore) {
        bestScore = score;
      }
      if (score >= alignmentThreshold) {
        matched.add(goal.text);
      }
    }

    return AlignmentScore(
      taskTitle: candidateTitle,
      score: bestScore.clamp(0.0, 1.0),
      matchedGoals: matched,
    );
  }

  /// Detects vision drift by checking recently completed tasks against goals.
  ///
  /// Reads the last [windowSize] completed tasks and calculates how many align
  /// with vision goals. If fewer than [driftThreshold] (30%) align, drift is
  /// detected and an event is logged.
  DriftReport detectDrift(String projectRoot, {int windowSize = 20}) {
    final goals = extractGoals(projectRoot);
    if (goals.isEmpty) {
      return const DriftReport(
        alignedCount: 0,
        totalCount: 0,
        alignmentRate: 1.0,
        driftDetected: false,
      );
    }

    final layout = ProjectLayout(projectRoot);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final completed = tasks
        .where((t) => t.completion == TaskCompletion.done)
        .toList();
    // Take the last N completed tasks (they appear in file order).
    final recent = completed.length <= windowSize
        ? completed
        : completed.sublist(completed.length - windowSize);

    if (recent.isEmpty) {
      return const DriftReport(
        alignedCount: 0,
        totalCount: 0,
        alignmentRate: 1.0,
        driftDetected: false,
      );
    }

    var alignedCount = 0;
    for (final task in recent) {
      final score = scoreAlignment(task.title, goals);
      if (score.score >= alignmentThreshold) {
        alignedCount += 1;
      }
    }

    final rate = alignedCount / recent.length;
    final driftDetected = rate < driftThreshold;

    if (driftDetected) {
      final runLog = RunLogStore(layout.runLogPath);
      runLog.append(
        event: 'vision_drift_detected',
        message:
            'Vision drift: only ${(rate * 100).toStringAsFixed(1)}% of recent '
            'completed tasks aligned with vision goals '
            '($alignedCount/${recent.length})',
        data: {
          'aligned_count': alignedCount,
          'total_count': recent.length,
          'alignment_rate': rate,
          'threshold': driftThreshold,
        },
      );
    }

    return DriftReport(
      alignedCount: alignedCount,
      totalCount: recent.length,
      alignmentRate: rate,
      driftDetected: driftDetected,
    );
  }

  /// Identifies vision goals that have no matching tasks in the backlog.
  GapReport findGaps(String projectRoot) {
    final goals = extractGoals(projectRoot);
    if (goals.isEmpty) {
      return const GapReport(
        totalGoals: 0,
        coveredGoals: 0,
        uncoveredGoals: [],
      );
    }

    final layout = ProjectLayout(projectRoot);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final allTitles = tasks.map((t) => t.title).toList();

    var covered = 0;
    final uncovered = <String>[];

    for (final goal in goals) {
      var hasCoverage = false;
      for (final title in allTitles) {
        final score = scoreAlignment(title, [goal]);
        if (score.score >= alignmentThreshold) {
          hasCoverage = true;
          break;
        }
      }
      if (hasCoverage) {
        covered += 1;
      } else {
        uncovered.add(goal.text);
      }
    }

    return GapReport(
      totalGoals: goals.length,
      coveredGoals: covered,
      uncoveredGoals: uncovered,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Parses goals from VISION.md lines.
  ///
  /// Looks for the "Goals" section and collects top-level bullets as goals.
  List<VisionGoal> _parseGoals(List<String> lines) {
    var inGoalsSection = false;
    final goals = <VisionGoal>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect section headings.
      final headingMatch = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final heading = headingMatch.group(1)?.trim().toLowerCase() ?? '';
        inGoalsSection = heading.contains('goals');
        continue;
      }

      if (!inGoalsSection) continue;

      // Only collect top-level bullets (not indented detail/reference lines).
      if (line.startsWith('  ')) continue;

      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch == null) continue;

      final text = bulletMatch.group(1)?.trim() ?? '';
      if (text.isEmpty) continue;

      // Strip trailing reference lines (Details: ...) from the goal text.
      final goalText = text
          .replaceFirst(RegExp(r'\s*Details:.*$', caseSensitive: false), '')
          .trim();
      if (goalText.isEmpty) continue;

      final keywords = _extractKeywords(goalText);
      if (keywords.length < _minGoalKeywords) continue;

      goals.add(VisionGoal(text: goalText, keywords: keywords));
    }

    return goals;
  }

  /// Extracts meaningful keywords from a text by lowercasing, splitting on
  /// non-alphanumeric characters, and filtering stop words and short tokens.
  Set<String> _extractKeywords(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
    return words;
  }
}
