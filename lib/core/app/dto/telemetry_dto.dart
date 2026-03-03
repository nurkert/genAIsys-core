// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class AppRunFailureTrendDto {
  const AppRunFailureTrendDto({
    required this.direction,
    required this.recentFailures,
    required this.previousFailures,
    required this.windowSeconds,
    required this.sampleSize,
    required this.dominantErrorKind,
  });

  final String direction;
  final int recentFailures;
  final int previousFailures;
  final int windowSeconds;
  final int sampleSize;
  final String? dominantErrorKind;
}

class AppRunRetryDistributionDto {
  const AppRunRetryDistributionDto({
    required this.samples,
    required this.retry0,
    required this.retry1,
    required this.retry2Plus,
    required this.maxRetry,
  });

  final int samples;
  final int retry0;
  final int retry1;
  final int retry2Plus;
  final int maxRetry;
}

class AppRunCooldownDto {
  const AppRunCooldownDto({
    required this.active,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.until,
    required this.sourceEvent,
    required this.reason,
  });

  final bool active;
  final int totalSeconds;
  final int remainingSeconds;
  final String? until;
  final String? sourceEvent;
  final String? reason;
}

class AppRunHealthSummaryDto {
  const AppRunHealthSummaryDto({
    required this.failureTrend,
    required this.retryDistribution,
    required this.cooldown,
  });

  final AppRunFailureTrendDto failureTrend;
  final AppRunRetryDistributionDto retryDistribution;
  final AppRunCooldownDto cooldown;
}

class AppRunLogEventDto {
  const AppRunLogEventDto({
    required this.timestamp,
    this.eventId,
    this.correlationId,
    required this.event,
    this.message,
    this.correlation,
    this.data,
  });

  final String? timestamp;
  final String? eventId;
  final String? correlationId;
  final String event;
  final String? message;
  final Map<String, Object?>? correlation;
  final Map<String, Object?>? data;
}

class AppRunTelemetryDto {
  const AppRunTelemetryDto({
    required this.recentEvents,
    this.errorClass,
    this.errorKind,
    this.errorMessage,
    this.agentExitCode,
    this.agentStderrExcerpt,
    this.lastErrorEvent,
    this.healthSummary,
  });

  final List<AppRunLogEventDto> recentEvents;
  final String? errorClass;
  final String? errorKind;
  final String? errorMessage;
  final int? agentExitCode;
  final String? agentStderrExcerpt;
  final String? lastErrorEvent;
  final AppRunHealthSummaryDto? healthSummary;
}

class AppHealthCheckDto {
  const AppHealthCheckDto({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class AppHealthSnapshotDto {
  const AppHealthSnapshotDto({
    required this.agent,
    required this.allowlist,
    required this.git,
    required this.review,
  });

  final AppHealthCheckDto agent;
  final AppHealthCheckDto allowlist;
  final AppHealthCheckDto git;
  final AppHealthCheckDto review;

  bool get allOk => agent.ok && allowlist.ok && git.ok && review.ok;
}
