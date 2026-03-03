// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

import '../models/supervisor_state.dart';
import '../project_layout.dart';
import '../storage/atomic_file_write.dart';
import 'observability/health_summary_exporter_service.dart';

/// Encapsulates all health-reporting I/O for the autopilot supervisor:
/// heartbeat writes, health summary exports, and exit summary persistence.
///
/// All public methods are best-effort and never throw — the supervisor loop
/// must not be blocked by monitoring I/O failures.
class SupervisorHealthReporter {
  SupervisorHealthReporter({
    HealthSummaryExporterService? healthSummaryExporter,
  }) : _healthSummaryExporter =
           healthSummaryExporter ?? HealthSummaryExporterService();

  final HealthSummaryExporterService _healthSummaryExporter;

  /// Write a UTC timestamp to the heartbeat file for external watchdog use.
  ///
  /// Systemd or cron scripts can `stat` this file; if it is older than a
  /// threshold, the supervisor is likely hung.
  void writeHeartbeat(String projectRoot, {required DateTime now}) {
    try {
      final layout = ProjectLayout(projectRoot);
      AtomicFileWrite.writeStringSync(layout.heartbeatPath, now.toIso8601String());
    } catch (_) {
      // Heartbeat write must never block the supervisor loop.
    }
  }

  /// Export a structured health summary for external monitoring.
  void exportHealthSummary(
    String projectRoot, {
    required String sessionId,
    required String profile,
    required int pid,
    required DateTime startedAt,
    required int totalSteps,
    required int consecutiveFailures,
    required String? lastHaltReason,
    required String status,
  }) {
    try {
      _healthSummaryExporter.export(
        projectRoot: projectRoot,
        sessionId: sessionId,
        profile: profile,
        pid: pid,
        startedAt: startedAt,
        totalSteps: totalSteps,
        consecutiveFailures: consecutiveFailures,
        lastHaltReason: lastHaltReason,
        status: status,
      );
    } catch (_) {
      // Health summary export must never block the supervisor loop.
    }
  }

  /// Write a structured exit summary to `.genaisys/audit/exit_summary.json`.
  void writeExitSummary(
    String projectRoot, {
    required String sessionId,
    required String haltReason,
    required int? exitCode,
    required int restartCount,
    required int segmentsCompleted,
    required int lowSignalStreak,
    required DateTime startedAt,
    required DateTime now,
    required SupervisorState supervisorState,
  }) {
    try {
      final layout = ProjectLayout(projectRoot);
      final uptimeSeconds = now.difference(startedAt).inSeconds;

      final payload = <String, Object?>{
        'session_id': sessionId,
        'halt_reason': haltReason,
        'exit_code': exitCode,
        'restart_count': restartCount,
        'segments_completed': segmentsCompleted,
        'low_signal_streak': lowSignalStreak,
        'uptime_seconds': uptimeSeconds,
        'timestamp': now.toIso8601String(),
        'throughput_snapshot': {
          'window_started_at': supervisorState.throughputWindowStartedAt,
          'steps': supervisorState.throughputSteps,
          'rejects': supervisorState.throughputRejects,
          'high_retries': supervisorState.throughputHighRetries,
        },
      };

      final json = const JsonEncoder.withIndent('  ').convert(payload);
      AtomicFileWrite.writeStringSync(layout.exitSummaryPath, json);
    } catch (_) {
      // Exit summary write must never block supervisor shutdown.
    }
  }
}
