// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'health_score_service.dart';

/// A single health score snapshot persisted for trend tracking.
class HealthScoreSnapshot {
  const HealthScoreSnapshot({
    required this.timestamp,
    required this.overallScore,
    required this.grade,
    required this.components,
  });

  final String timestamp;
  final double overallScore;
  final String grade;
  final Map<String, double> components;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp,
      'overall_score': _round(overallScore),
      'grade': grade,
      'components': {
        for (final entry in components.entries) entry.key: _round(entry.value),
      },
    };
  }

  factory HealthScoreSnapshot.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'];
    final components = <String, double>{};
    if (rawComponents is Map) {
      for (final entry in rawComponents.entries) {
        if (entry.value is num) {
          components[entry.key.toString()] = (entry.value as num).toDouble();
        }
      }
    }
    return HealthScoreSnapshot(
      timestamp: (json['timestamp'] ?? '').toString(),
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      grade: (json['grade'] ?? 'unknown').toString(),
      components: components,
    );
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

/// Direction of a detected trend.
enum TrendDirection { improving, stable, declining }

/// Per-component trend analysis result.
class ComponentTrend {
  const ComponentTrend({
    required this.name,
    required this.currentScore,
    required this.baselineScore,
    required this.delta,
    required this.direction,
  });

  final String name;
  final double currentScore;
  final double baselineScore;
  final double delta;
  final TrendDirection direction;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'current_score': _round(currentScore),
      'baseline_score': _round(baselineScore),
      'delta': _round(delta),
      'direction': direction.name,
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

/// Aggregate trend analysis report.
class TrendReport {
  const TrendReport({
    required this.overallDirection,
    required this.overallDelta,
    required this.currentScore,
    required this.baselineScore,
    required this.snapshotCount,
    required this.componentTrends,
    required this.regressions,
    required this.improvements,
    required this.timestamp,
  });

  final TrendDirection overallDirection;
  final double overallDelta;
  final double currentScore;
  final double baselineScore;
  final int snapshotCount;
  final List<ComponentTrend> componentTrends;

  /// Component names that regressed significantly (> 10 points).
  final List<String> regressions;

  /// Component names that improved significantly (> 10 points).
  final List<String> improvements;

  final String timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'overall_direction': overallDirection.name,
      'overall_delta': _round(overallDelta),
      'current_score': _round(currentScore),
      'baseline_score': _round(baselineScore),
      'snapshot_count': snapshotCount,
      'regressions': regressions,
      'improvements': improvements,
      'timestamp': timestamp,
      'component_trends': componentTrends.map((c) => c.toJson()).toList(),
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class TrendAnalysisService {
  /// Maximum number of historical snapshots to retain.
  static const int maxSnapshots = 50;

  /// Threshold for considering a delta as significant (points).
  static const double significantDelta = 10.0;

  /// Number of recent snapshots to use for the baseline average.
  static const int baselineWindow = 5;

  /// Record a health report as a snapshot for trend tracking.
  void recordSnapshot(String projectRoot, HealthReport report) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.trendSnapshotsPath);

    final componentScores = <String, double>{};
    for (final c in report.components) {
      componentScores[c.name] = c.score;
    }

    final snapshot = HealthScoreSnapshot(
      timestamp: report.timestamp,
      overallScore: report.overallScore,
      grade: report.grade.name,
      components: componentScores,
    );

    final snapshots = _loadSnapshots(file);
    snapshots.add(snapshot);

    // Trim to max.
    while (snapshots.length > maxSnapshots) {
      snapshots.removeAt(0);
    }

    _saveSnapshots(file, snapshots);
  }

  /// Analyze trends by comparing the current health report against
  /// the historical baseline (moving average of recent snapshots).
  TrendReport analyze(String projectRoot, HealthReport current) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.trendSnapshotsPath);
    final snapshots = _loadSnapshots(file);

    final timestamp = DateTime.now().toUtc().toIso8601String();

    if (snapshots.isEmpty) {
      return TrendReport(
        overallDirection: TrendDirection.stable,
        overallDelta: 0.0,
        currentScore: current.overallScore,
        baselineScore: current.overallScore,
        snapshotCount: 0,
        componentTrends: const [],
        regressions: const [],
        improvements: const [],
        timestamp: timestamp,
      );
    }

    // Compute baseline as moving average of last N snapshots.
    final windowSize = baselineWindow.clamp(1, snapshots.length);
    final window = snapshots.sublist(snapshots.length - windowSize);

    final baselineOverall = _average(window.map((s) => s.overallScore));

    // Compute per-component baselines.
    final componentNames = <String>{};
    for (final s in window) {
      componentNames.addAll(s.components.keys);
    }

    final componentTrends = <ComponentTrend>[];
    final regressions = <String>[];
    final improvements = <String>[];

    for (final name in componentNames) {
      final baselineValues = window.map((s) => s.components[name] ?? 0.0);
      final baselineScore = _average(baselineValues);

      final currentComponent = current.components.where((c) => c.name == name);
      final currentScore = currentComponent.isNotEmpty
          ? currentComponent.first.score
          : 0.0;

      final delta = currentScore - baselineScore;
      final direction = _directionFromDelta(delta);

      componentTrends.add(
        ComponentTrend(
          name: name,
          currentScore: currentScore,
          baselineScore: baselineScore,
          delta: delta,
          direction: direction,
        ),
      );

      if (delta < -significantDelta) {
        regressions.add(name);
      } else if (delta > significantDelta) {
        improvements.add(name);
      }
    }

    final overallDelta = current.overallScore - baselineOverall;
    final overallDirection = _directionFromDelta(overallDelta);

    final report = TrendReport(
      overallDirection: overallDirection,
      overallDelta: overallDelta,
      currentScore: current.overallScore,
      baselineScore: baselineOverall,
      snapshotCount: snapshots.length,
      componentTrends: componentTrends,
      regressions: regressions,
      improvements: improvements,
      timestamp: timestamp,
    );

    // Persist trend event to run log.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'trend_analysis',
        message: regressions.isNotEmpty
            ? 'Trend analysis: regressions detected in ${regressions.join(', ')}'
            : 'Trend analysis: ${overallDirection.name}',
        data: report.toJson(),
      );
    }

    return report;
  }

  TrendDirection _directionFromDelta(double delta) {
    if (delta > 5.0) return TrendDirection.improving;
    if (delta < -5.0) return TrendDirection.declining;
    return TrendDirection.stable;
  }

  double _average(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    var sum = 0.0;
    var count = 0;
    for (final v in values) {
      sum += v;
      count += 1;
    }
    return count > 0 ? sum / count : 0.0;
  }

  List<HealthScoreSnapshot> _loadSnapshots(File file) {
    if (!file.existsSync()) return [];
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (m) => HealthScoreSnapshot.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveSnapshots(File file, List<HealthScoreSnapshot> snapshots) {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    file.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(snapshots.map((s) => s.toJson()).toList()),
    );
  }
}
