// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_error.dart';
import '../../dto/autopilot_dto.dart';
import '../../dto/telemetry_dto.dart';
import '../../shared/app_error_mapper.dart';
import '../../../models/health_snapshot.dart';
import '../../../models/run_log_event.dart';
import '../../../services/orchestrator_run_service.dart';
import '../../../services/observability/run_telemetry_service.dart';

/// Maps a caught error into an [AppError] using the shared app error mapper.
AppError mapAutopilotError(Object error, StackTrace stackTrace) {
  return mapToAppError(error, stackTrace);
}

/// Holds optional stall reason and detail for autopilot status reporting.
class StallInfo {
  const StallInfo({this.reason, this.detail});

  final String? reason;
  final String? detail;
}

/// Derives stall information from the current autopilot status, health, and
/// telemetry snapshots.
StallInfo deriveStallInfo(
  AutopilotStatus status,
  HealthSnapshot health,
  RunTelemetrySnapshot telemetry,
) {
  final healthIssue = firstHealthIssue(health);
  if (healthIssue != null) {
    return healthIssue;
  }

  final telemetryReason = telemetry.errorKind ?? telemetry.errorClass;
  if (telemetryReason != null && telemetryReason.isNotEmpty) {
    final detail = telemetryDetail(telemetryReason, telemetry);
    return StallInfo(reason: telemetryReason, detail: detail);
  }

  final lastError = status.lastError?.trim();
  if (lastError != null && lastError.isNotEmpty) {
    return StallInfo(reason: 'last_error', detail: lastError);
  }

  if (!status.isRunning) {
    return const StallInfo(
      reason: 'stopped',
      detail: 'Autopilot is not running.',
    );
  }

  return const StallInfo();
}

/// Returns the first health issue as a [StallInfo], or `null` if all checks
/// pass.
StallInfo? firstHealthIssue(HealthSnapshot health) {
  if (!health.agent.ok) {
    return StallInfo(
      reason: 'agent_unavailable',
      detail: health.agent.message,
    );
  }
  if (!health.allowlist.ok) {
    return StallInfo(reason: 'allowlist', detail: health.allowlist.message);
  }
  if (!health.git.ok) {
    return StallInfo(reason: 'git', detail: health.git.message);
  }
  if (!health.review.ok) {
    return StallInfo(reason: 'review', detail: health.review.message);
  }
  return null;
}

/// Returns a human-readable detail message for a telemetry error kind.
String? telemetryDetail(String kind, RunTelemetrySnapshot telemetry) {
  final message = telemetry.errorMessage?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  switch (kind) {
    case 'no_diff':
      return 'Coding agent produced no diff.';
    case 'review_rejected':
      return 'Review rejected the last change.';
    case 'policy_violation':
      return 'A policy violation blocked progress.';
    case 'analyze_failed':
      return 'Static analysis failed in quality gate.';
    case 'test_failed':
      return 'Test command failed in quality gate.';
    case 'quality_gate_failed':
      return 'Quality gate failed before review.';
    case 'diff_budget':
      return 'Diff budget exceeded.';
    case 'agent_unavailable':
      return 'Agent executable not available.';
    case 'merge_conflict':
      return 'Merge conflict detected.';
    case 'lock_held':
      return 'Autopilot lock is already held.';
    case 'timeout':
      return 'Agent timed out.';
    case 'no_active_task':
      return 'No active task available.';
    case 'stuck':
      return 'No progress threshold reached.';
    case 'not_found':
      return 'Required file or resource not found.';
  }
  return telemetry.lastErrorEvent;
}

/// Converts a [HealthSnapshot] to an [AppHealthSnapshotDto].
AppHealthSnapshotDto toHealthDto(HealthSnapshot snapshot) {
  return AppHealthSnapshotDto(
    agent: toHealthCheckDto(snapshot.agent),
    allowlist: toHealthCheckDto(snapshot.allowlist),
    git: toHealthCheckDto(snapshot.git),
    review: toHealthCheckDto(snapshot.review),
  );
}

/// Converts a [HealthCheck] to an [AppHealthCheckDto].
AppHealthCheckDto toHealthCheckDto(HealthCheck check) {
  return AppHealthCheckDto(ok: check.ok, message: check.message);
}

/// Converts a [RunTelemetrySnapshot] to an [AppRunTelemetryDto].
AppRunTelemetryDto toTelemetryDto(RunTelemetrySnapshot snapshot) {
  return AppRunTelemetryDto(
    recentEvents: snapshot.recentEvents
        .map(toRunLogEventDto)
        .toList(growable: false),
    errorClass: snapshot.errorClass,
    errorKind: snapshot.errorKind,
    errorMessage: snapshot.errorMessage,
    agentExitCode: snapshot.agentExitCode,
    agentStderrExcerpt: snapshot.agentStderrExcerpt,
    lastErrorEvent: snapshot.lastErrorEvent,
    healthSummary: toAppRunHealthSummaryDto(snapshot.healthSummary),
  );
}

/// Converts a [RunHealthSummarySnapshot] to an [AppRunHealthSummaryDto].
AppRunHealthSummaryDto toAppRunHealthSummaryDto(
  RunHealthSummarySnapshot summary,
) {
  return AppRunHealthSummaryDto(
    failureTrend: AppRunFailureTrendDto(
      direction: summary.failureTrend.direction,
      recentFailures: summary.failureTrend.recentFailures,
      previousFailures: summary.failureTrend.previousFailures,
      windowSeconds: summary.failureTrend.windowSeconds,
      sampleSize: summary.failureTrend.sampleSize,
      dominantErrorKind: summary.failureTrend.dominantErrorKind,
    ),
    retryDistribution: AppRunRetryDistributionDto(
      samples: summary.retryDistribution.samples,
      retry0: summary.retryDistribution.retry0,
      retry1: summary.retryDistribution.retry1,
      retry2Plus: summary.retryDistribution.retry2Plus,
      maxRetry: summary.retryDistribution.maxRetry,
    ),
    cooldown: AppRunCooldownDto(
      active: summary.cooldown.active,
      totalSeconds: summary.cooldown.totalSeconds,
      remainingSeconds: summary.cooldown.remainingSeconds,
      until: summary.cooldown.until,
      sourceEvent: summary.cooldown.sourceEvent,
      reason: summary.cooldown.reason,
    ),
  );
}

/// Converts a [RunHealthSummarySnapshot] to an [AutopilotHealthSummaryDto].
AutopilotHealthSummaryDto toHealthSummaryDto(
  RunHealthSummarySnapshot summary,
) {
  return AutopilotHealthSummaryDto(
    failureTrend: AutopilotFailureTrendDto(
      direction: summary.failureTrend.direction,
      recentFailures: summary.failureTrend.recentFailures,
      previousFailures: summary.failureTrend.previousFailures,
      windowSeconds: summary.failureTrend.windowSeconds,
      sampleSize: summary.failureTrend.sampleSize,
      dominantErrorKind: summary.failureTrend.dominantErrorKind,
    ),
    retryDistribution: AutopilotRetryDistributionDto(
      samples: summary.retryDistribution.samples,
      retry0: summary.retryDistribution.retry0,
      retry1: summary.retryDistribution.retry1,
      retry2Plus: summary.retryDistribution.retry2Plus,
      maxRetry: summary.retryDistribution.maxRetry,
    ),
    cooldown: AutopilotCooldownDto(
      active: summary.cooldown.active,
      totalSeconds: summary.cooldown.totalSeconds,
      remainingSeconds: summary.cooldown.remainingSeconds,
      until: summary.cooldown.until,
      sourceEvent: summary.cooldown.sourceEvent,
      reason: summary.cooldown.reason,
    ),
  );
}

/// Converts a [RunLogEvent] to an [AppRunLogEventDto].
AppRunLogEventDto toRunLogEventDto(RunLogEvent event) {
  return AppRunLogEventDto(
    timestamp: event.timestamp,
    eventId: event.eventId,
    correlationId: event.correlationId,
    event: event.event,
    message: event.message,
    correlation: event.correlation,
    data: event.data,
  );
}

/// Holds the path and run-log excerpt for an incident bundle.
class IncidentBundle {
  const IncidentBundle({required this.path, required this.runLogExcerpt});

  final String path;
  final List<Map<String, Object?>> runLogExcerpt;
}
