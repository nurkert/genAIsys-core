// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

import '../../project_layout.dart';
import '../../storage/atomic_file_write.dart';
import '../health_score_service.dart';

/// Writes a structured health summary to `.genaisys/health.json`.
///
/// This file is designed to be consumed by external monitoring tools
/// (systemd watchdog scripts, cron health-checks, dashboards) without
/// parsing the full JSONL run log.
///
/// The service is called:
/// - After each supervisor segment completes.
/// - In the supervisor's finally block (halt / crash).
class HealthSummaryExporterService {
  HealthSummaryExporterService({HealthScoreService? healthScoreService})
    : _healthScoreService = healthScoreService ?? HealthScoreService();

  final HealthScoreService _healthScoreService;

  /// Write the health summary file atomically.
  ///
  /// All parameters are optional and are incorporated when available.
  /// The caller (supervisor) provides session-level metadata; the
  /// health score is computed from the provided inputs.
  void export({
    required String projectRoot,
    String? sessionId,
    String? profile,
    int? pid,
    DateTime? startedAt,
    int totalSteps = 0,
    int consecutiveFailures = 0,
    String? lastHaltReason,
    String status = 'running',
    HealthReport? healthReport,
  }) {
    final layout = ProjectLayout(projectRoot);

    final report = healthReport ?? _healthScoreService.score();

    final now = DateTime.now().toUtc();
    final uptimeSeconds = startedAt != null
        ? now.difference(startedAt.toUtc()).inSeconds
        : 0;

    final payload = <String, Object?>{
      'timestamp': now.toIso8601String(),
      'status': status,
      'pid': pid,
      'session_id': sessionId,
      'profile': profile,
      'uptime_seconds': uptimeSeconds,
      'total_steps': totalSteps,
      'health_grade': report.grade.name,
      'health_score': _round(report.overallScore),
      'last_halt_reason': lastHaltReason,
      'consecutive_failures': consecutiveFailures,
    };

    // Remove null entries for cleaner output.
    payload.removeWhere((_, v) => v == null);

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    AtomicFileWrite.writeStringSync(layout.healthSummaryPath, json);
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
