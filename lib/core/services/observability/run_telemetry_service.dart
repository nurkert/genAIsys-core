// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../errors/failure_reason_mapper.dart';
import '../../models/run_log_event.dart';
import '../../project_layout.dart';

class RunFailureTrendSnapshot {
  const RunFailureTrendSnapshot({
    required this.direction,
    required this.recentFailures,
    required this.previousFailures,
    required this.windowSeconds,
    required this.sampleSize,
    this.dominantErrorKind,
  });

  final String direction;
  final int recentFailures;
  final int previousFailures;
  final int windowSeconds;
  final int sampleSize;
  final String? dominantErrorKind;
}

class RunRetryDistributionSnapshot {
  const RunRetryDistributionSnapshot({
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

class RunCooldownSnapshot {
  const RunCooldownSnapshot({
    required this.active,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.until,
    this.sourceEvent,
    this.reason,
  });

  final bool active;
  final int totalSeconds;
  final int remainingSeconds;
  final String? until;
  final String? sourceEvent;
  final String? reason;
}

class RunHealthSummarySnapshot {
  const RunHealthSummarySnapshot({
    required this.failureTrend,
    required this.retryDistribution,
    required this.cooldown,
  });

  final RunFailureTrendSnapshot failureTrend;
  final RunRetryDistributionSnapshot retryDistribution;
  final RunCooldownSnapshot cooldown;
}

const _defaultRunHealthSummary = RunHealthSummarySnapshot(
  failureTrend: RunFailureTrendSnapshot(
    direction: 'stable',
    recentFailures: 0,
    previousFailures: 0,
    windowSeconds: 900,
    sampleSize: 0,
  ),
  retryDistribution: RunRetryDistributionSnapshot(
    samples: 0,
    retry0: 0,
    retry1: 0,
    retry2Plus: 0,
    maxRetry: 0,
  ),
  cooldown: RunCooldownSnapshot(
    active: false,
    totalSeconds: 0,
    remainingSeconds: 0,
    until: null,
    sourceEvent: null,
    reason: null,
  ),
);

class RunTelemetrySnapshot {
  RunTelemetrySnapshot({
    required this.recentEvents,
    this.errorClass,
    this.errorKind,
    this.errorMessage,
    this.agentExitCode,
    this.agentStderrExcerpt,
    this.lastErrorEvent,
    this.healthSummary = _defaultRunHealthSummary,
  });

  final List<RunLogEvent> recentEvents;
  final String? errorClass;
  final String? errorKind;
  final String? errorMessage;
  final int? agentExitCode;
  final String? agentStderrExcerpt;
  final String? lastErrorEvent;
  final RunHealthSummarySnapshot healthSummary;
}

class RunTelemetryService {
  RunTelemetrySnapshot load(String projectRoot, {int recentLimit = 5}) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.runLogPath);
    if (!file.existsSync()) {
      return RunTelemetrySnapshot(recentEvents: const []);
    }

    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return RunTelemetrySnapshot(recentEvents: const []);
    }

    final start = lines.length > 200 ? lines.length - 200 : 0;
    final slice = lines.sublist(start);
    final events = <RunLogEvent>[];
    for (final raw in slice) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      final event = _parseEvent(line);
      if (event != null) {
        events.add(event);
      }
    }

    final recent = events.where((event) => _includeEvent(event.event)).toList();
    final recentEvents = recent.length > recentLimit
        ? recent.sublist(recent.length - recentLimit)
        : recent;

    final lastAgent = _findLastAgentEvent(events);
    final lastError = _findLastErrorEvent(events);
    final healthSummary = _buildHealthSummary(events);

    return RunTelemetrySnapshot(
      recentEvents: recentEvents,
      errorClass: lastError == null ? null : _reason(lastError).errorClass,
      errorKind: lastError == null ? null : _reason(lastError).errorKind,
      errorMessage: lastError == null ? null : _errorMessage(lastError),
      agentExitCode: _intOrNull(lastAgent?.data?['exit_code']),
      agentStderrExcerpt: _stringOrNull(lastAgent?.data?['stderr_excerpt']),
      lastErrorEvent: lastError?.event,
      healthSummary: healthSummary,
    );
  }

  RunHealthSummarySnapshot _buildHealthSummary(List<RunLogEvent> events) {
    final now = DateTime.now().toUtc();
    return RunHealthSummarySnapshot(
      failureTrend: _buildFailureTrend(events, now),
      retryDistribution: _buildRetryDistribution(events),
      cooldown: _buildCooldownSnapshot(events, now),
    );
  }

  RunFailureTrendSnapshot _buildFailureTrend(
    List<RunLogEvent> events,
    DateTime now,
  ) {
    const window = Duration(minutes: 15);
    const sampleWindow = Duration(hours: 1);
    final recentStart = now.subtract(window);
    final previousStart = now.subtract(window * 2);
    final sampleStart = now.subtract(sampleWindow);
    var recentFailures = 0;
    var previousFailures = 0;
    var sampleSize = 0;
    final kindCounts = <String, int>{};

    for (final event in events) {
      if (!_isErrorEvent(event.event)) {
        continue;
      }
      final timestamp = _timestampOrNull(event.timestamp);
      if (timestamp == null) {
        continue;
      }
      if (timestamp.isAfter(sampleStart) ||
          timestamp.isAtSameMomentAs(sampleStart)) {
        sampleSize += 1;
        final kind = _reason(event).errorKind;
        kindCounts[kind] = (kindCounts[kind] ?? 0) + 1;
      }
      if (timestamp.isAfter(recentStart) ||
          timestamp.isAtSameMomentAs(recentStart)) {
        recentFailures += 1;
        continue;
      }
      if ((timestamp.isAfter(previousStart) ||
              timestamp.isAtSameMomentAs(previousStart)) &&
          timestamp.isBefore(recentStart)) {
        previousFailures += 1;
      }
    }

    final direction = _failureDirection(
      recentFailures: recentFailures,
      previousFailures: previousFailures,
    );
    return RunFailureTrendSnapshot(
      direction: direction,
      recentFailures: recentFailures,
      previousFailures: previousFailures,
      windowSeconds: window.inSeconds,
      sampleSize: sampleSize,
      dominantErrorKind: _dominantKind(kindCounts),
    );
  }

  String _failureDirection({
    required int recentFailures,
    required int previousFailures,
  }) {
    if (recentFailures > previousFailures) {
      return 'rising';
    }
    if (recentFailures < previousFailures) {
      return 'falling';
    }
    return 'stable';
  }

  String? _dominantKind(Map<String, int> kindCounts) {
    if (kindCounts.isEmpty) {
      return null;
    }
    final sortedKeys = kindCounts.keys.toList(growable: false)..sort();
    String? winner;
    var maxCount = -1;
    for (final key in sortedKeys) {
      final count = kindCounts[key] ?? 0;
      if (count > maxCount) {
        maxCount = count;
        winner = key;
      }
    }
    return winner;
  }

  RunRetryDistributionSnapshot _buildRetryDistribution(
    List<RunLogEvent> events,
  ) {
    var samples = 0;
    var retry0 = 0;
    var retry1 = 0;
    var retry2Plus = 0;
    var maxRetry = 0;
    for (final event in events) {
      final retryCount = _intOrNull(event.data?['retry_count']);
      if (retryCount == null || retryCount < 0) {
        continue;
      }
      samples += 1;
      if (retryCount == 0) {
        retry0 += 1;
      } else if (retryCount == 1) {
        retry1 += 1;
      } else {
        retry2Plus += 1;
      }
      if (retryCount > maxRetry) {
        maxRetry = retryCount;
      }
    }
    return RunRetryDistributionSnapshot(
      samples: samples,
      retry0: retry0,
      retry1: retry1,
      retry2Plus: retry2Plus,
      maxRetry: maxRetry,
    );
  }

  RunCooldownSnapshot _buildCooldownSnapshot(
    List<RunLogEvent> events,
    DateTime now,
  ) {
    for (var i = events.length - 1; i >= 0; i -= 1) {
      final event = events[i];
      final seconds = _cooldownSeconds(event.data);
      if (seconds == null || seconds < 1) {
        continue;
      }
      final timestamp = _timestampOrNull(event.timestamp);
      if (timestamp == null) {
        continue;
      }
      final until = timestamp.add(Duration(seconds: seconds));
      final remaining = until.difference(now).inSeconds;
      final reason =
          _stringOrNull(event.data?['error_kind']) ??
          _stringOrNull(event.data?['reason']) ??
          _stringOrNull(event.data?['error_class']);
      final normalizedRemaining = remaining > 0 ? remaining : 0;
      return RunCooldownSnapshot(
        active: normalizedRemaining > 0,
        totalSeconds: seconds,
        remainingSeconds: normalizedRemaining,
        until: until.toUtc().toIso8601String(),
        sourceEvent: event.event,
        reason: reason,
      );
    }
    return _defaultRunHealthSummary.cooldown;
  }

  int? _cooldownSeconds(Map<String, Object?>? data) {
    if (data == null) {
      return null;
    }
    final direct = _intOrNull(data['cooldown_seconds']);
    if (direct != null && direct > 0) {
      return direct;
    }
    final backoff = _intOrNull(data['backoff_seconds']);
    if (backoff != null && backoff > 0) {
      return backoff;
    }
    final pause = _intOrNull(data['pause_seconds']);
    if (pause != null && pause > 0) {
      return pause;
    }
    return null;
  }

  DateTime? _timestampOrNull(String? timestamp) {
    if (timestamp == null || timestamp.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(timestamp)?.toUtc();
  }

  RunLogEvent? _parseEvent(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      final event = decoded['event']?.toString() ?? '';
      if (event.isEmpty) {
        return null;
      }
      return RunLogEvent(
        timestamp: decoded['timestamp']?.toString(),
        eventId: _stringOrNull(decoded['event_id']),
        correlationId: _stringOrNull(decoded['correlation_id']),
        event: event,
        message: decoded['message']?.toString(),
        correlation: decoded['correlation'] is Map
            ? Map<String, Object?>.from(decoded['correlation'])
            : null,
        data: decoded['data'] is Map
            ? Map<String, Object?>.from(decoded['data'])
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  bool _includeEvent(String event) {
    if (event.isEmpty) {
      return false;
    }
    if (event == 'status' || event == 'tasks_list' || event == 'next_task') {
      return false;
    }
    return true;
  }

  RunLogEvent? _findLastAgentEvent(List<RunLogEvent> events) {
    for (var i = events.length - 1; i >= 0; i -= 1) {
      final event = events[i];
      final data = event.data;
      if (data == null) {
        continue;
      }
      if (data.containsKey('exit_code') || data.containsKey('stderr_excerpt')) {
        return event;
      }
    }
    return null;
  }

  RunLogEvent? _findLastErrorEvent(List<RunLogEvent> events) {
    for (var i = events.length - 1; i >= 0; i -= 1) {
      final event = events[i];
      if (_isErrorEvent(event.event)) {
        return event;
      }
    }
    return null;
  }

  bool _isErrorEvent(String event) {
    return event.contains('error') ||
        event.contains('safety_halt') ||
        event == 'preflight_failed' ||
        event == 'merge_conflict_manual' ||
        event == 'merge_conflict_resolution_attempt_failed' ||
        event == 'merge_conflict_abort_failed' ||
        event == 'orchestrator_run_provider_pause' ||
        event == 'orchestrator_run_stuck' ||
        event == 'task_cycle_no_diff' ||
        event == 'review_reject' ||
        event == 'quality_gate_reject';
  }

  FailureReason _reason(RunLogEvent event) {
    final qualityGateKind = _qualityGateKindFromEvent(event);
    final dataKind = _stringOrNull(event.data?['error_kind']);
    return FailureReasonMapper.normalize(
      errorClass: _stringOrNull(event.data?['error_class']),
      errorKind: qualityGateKind ?? dataKind,
      message: _errorMessage(event),
      event: event.event,
    );
  }

  String? _errorMessage(RunLogEvent event) {
    final dataError = _stringOrNull(event.data?['error']);
    if (dataError != null && dataError.isNotEmpty) {
      return dataError;
    }
    final note = _stringOrNull(event.data?['note']);
    if (note != null && note.isNotEmpty) {
      return note;
    }
    final message = event.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return null;
  }

  String? _qualityGateKindFromEvent(RunLogEvent event) {
    if (event.event != 'quality_gate_reject' &&
        event.event != 'review_reject') {
      return null;
    }
    final text = _qualityGateText(event);
    if (text == null) {
      return null;
    }
    if (text.contains('dart analyze') || text.contains('flutter analyze')) {
      return 'analyze_failed';
    }
    if (text.contains('flutter test') || text.contains('dart test')) {
      return 'test_failed';
    }
    return 'quality_gate_failed';
  }

  String? _qualityGateText(RunLogEvent event) {
    final chunks = <String>[
      event.event,
      _stringOrNull(event.data?['error_kind']) ?? '',
      _stringOrNull(event.data?['error']) ?? '',
      _stringOrNull(event.data?['note']) ?? '',
      event.message?.trim() ?? '',
    ];
    final normalized = chunks.join('\n').toLowerCase();
    if (!_looksLikeQualityGateFailure(normalized)) {
      return null;
    }
    return normalized;
  }

  bool _looksLikeQualityGateFailure(String normalized) {
    if (!normalized.contains('quality gate') &&
        !normalized.contains('quality_gate')) {
      return false;
    }
    // Avoid false positives when review notes merely mention "quality gate"
    // (e.g. "quality gate config") without an actual gate failure.
    return normalized.contains('quality gate failed') ||
        normalized.contains('quality_gate command failed') ||
        normalized.contains('quality_gate command timed out') ||
        normalized.contains('quality gate rejected');
  }

  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
