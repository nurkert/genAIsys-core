// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';

/// Structured insight extracted from a completed or blocked task.
class TaskRetrospective {
  const TaskRetrospective({
    required this.task,
    this.taskId,
    required this.outcome,
    required this.retryCount,
    this.reviewDecision,
    this.blockingStage,
    this.errorKind,
    this.errorClass,
    this.durationSeconds,
    this.subtaskCount,
    this.timestamp,
  });

  final String task;
  final String? taskId;

  /// One of: 'done', 'blocked', 'error'.
  final String outcome;
  final int retryCount;
  final String? reviewDecision;
  final String? blockingStage;
  final String? errorKind;
  final String? errorClass;
  final int? durationSeconds;
  final int? subtaskCount;
  final String? timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'task': task,
      if (taskId != null) 'task_id': taskId,
      'outcome': outcome,
      'retry_count': retryCount,
      if (reviewDecision != null) 'review_decision': reviewDecision,
      if (blockingStage != null) 'blocking_stage': blockingStage,
      if (errorKind != null) 'error_kind': errorKind,
      if (errorClass != null) 'error_class': errorClass,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (subtaskCount != null) 'subtask_count': subtaskCount,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }
}

/// Aggregated pattern summary across multiple retrospectives.
class RetrospectiveSummary {
  const RetrospectiveSummary({
    required this.totalTasks,
    required this.completedTasks,
    required this.blockedTasks,
    required this.errorTasks,
    required this.averageRetries,
    required this.topBlockingStages,
    required this.topErrorKinds,
  });

  final int totalTasks;
  final int completedTasks;
  final int blockedTasks;
  final int errorTasks;
  final double averageRetries;

  /// Blocking stages ordered by frequency (descending).
  final List<MapEntry<String, int>> topBlockingStages;

  /// Error kinds ordered by frequency (descending).
  final List<MapEntry<String, int>> topErrorKinds;

  double get completionRate =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  double get blockRate => totalTasks > 0 ? blockedTasks / totalTasks : 0.0;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'total_tasks': totalTasks,
      'completed_tasks': completedTasks,
      'blocked_tasks': blockedTasks,
      'error_tasks': errorTasks,
      'completion_rate': _round(completionRate),
      'block_rate': _round(blockRate),
      'average_retries': _round(averageRetries),
      'top_blocking_stages': {
        for (final entry in topBlockingStages) entry.key: entry.value,
      },
      'top_error_kinds': {
        for (final entry in topErrorKinds) entry.key: entry.value,
      },
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class RetrospectiveService {
  /// Extract retrospectives from the run log.
  List<TaskRetrospective> collect(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.runLogPath);
    if (!file.existsSync()) {
      return const [];
    }

    final entries = <TaskRetrospective>[];
    final lines = file.readAsLinesSync();

    // Track task cycle start timestamps for duration calculation.
    final cycleStartTimes = <String, String>{};

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
      if (data is! Map) continue;
      final dataMap = Map<String, dynamic>.from(data);

      if (event == 'task_cycle_start') {
        final task = _str(dataMap['root']);
        final ts = _str(decoded['timestamp']);
        if (task != null && ts != null) {
          cycleStartTimes[task] = ts;
        }
        continue;
      }

      if (event == 'task_done') {
        final task = _str(dataMap['task']);
        if (task == null || task.isEmpty) continue;
        entries.add(
          TaskRetrospective(
            task: task,
            taskId: _str(dataMap['task_id']),
            outcome: 'done',
            retryCount: 0,
            timestamp: _str(decoded['timestamp']),
          ),
        );
        continue;
      }

      if (event == 'task_dead_letter') {
        final task = _str(dataMap['task']);
        if (task == null || task.isEmpty) continue;
        entries.add(
          TaskRetrospective(
            task: task,
            taskId: _str(dataMap['task_id']),
            outcome: 'blocked',
            retryCount: _int(dataMap['retry_count']),
            blockingStage: _str(dataMap['blocking_stage']),
            errorKind: _str(dataMap['last_error_kind']),
            errorClass: _str(dataMap['last_error_class']),
            timestamp: _str(decoded['timestamp']),
          ),
        );
        continue;
      }

      if (event == 'task_blocked') {
        final task = _str(dataMap['task']);
        if (task == null || task.isEmpty) continue;
        // Avoid duplicating dead-letter entries which also produce task_blocked.
        final reason = _str(dataMap['reason']) ?? '';
        final isAutoCycle = reason.toLowerCase().startsWith('auto-cycle:');
        if (isAutoCycle) continue; // Already captured via task_dead_letter.
        entries.add(
          TaskRetrospective(
            task: task,
            taskId: _str(dataMap['task_id']),
            outcome: 'blocked',
            retryCount: _int(dataMap['retry_count']),
            blockingStage: _str(dataMap['blocking_stage']),
            errorKind: _str(dataMap['error_kind']),
            errorClass: _str(dataMap['error_class']),
            timestamp: _str(decoded['timestamp']),
          ),
        );
        continue;
      }

      if (event == 'task_cycle_end') {
        final blocked = dataMap['task_blocked'] == true;
        final decision = _str(dataMap['review_decision']);
        final retryCount = _int(dataMap['retry_count']);
        if (blocked || (decision == 'reject' && retryCount > 0)) {
          // This intermediate rejection is tracked for retry patterns
          // but the final outcome (done/blocked) is the primary record.
        }
      }
    }

    return entries;
  }

  /// Compute an aggregated summary from collected retrospectives.
  RetrospectiveSummary summarize(List<TaskRetrospective> retrospectives) {
    if (retrospectives.isEmpty) {
      return const RetrospectiveSummary(
        totalTasks: 0,
        completedTasks: 0,
        blockedTasks: 0,
        errorTasks: 0,
        averageRetries: 0.0,
        topBlockingStages: [],
        topErrorKinds: [],
      );
    }

    var completed = 0;
    var blocked = 0;
    var errors = 0;
    var totalRetries = 0;
    final blockingStages = <String, int>{};
    final errorKinds = <String, int>{};

    for (final retro in retrospectives) {
      totalRetries += retro.retryCount;
      switch (retro.outcome) {
        case 'done':
          completed += 1;
          break;
        case 'blocked':
          blocked += 1;
          if (retro.blockingStage != null) {
            blockingStages[retro.blockingStage!] =
                (blockingStages[retro.blockingStage!] ?? 0) + 1;
          }
          if (retro.errorKind != null) {
            errorKinds[retro.errorKind!] =
                (errorKinds[retro.errorKind!] ?? 0) + 1;
          }
          break;
        default:
          errors += 1;
          if (retro.errorKind != null) {
            errorKinds[retro.errorKind!] =
                (errorKinds[retro.errorKind!] ?? 0) + 1;
          }
      }
    }

    final total = retrospectives.length;
    final sortedStages = blockingStages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedKinds = errorKinds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RetrospectiveSummary(
      totalTasks: total,
      completedTasks: completed,
      blockedTasks: blocked,
      errorTasks: errors,
      averageRetries: total > 0 ? totalRetries / total : 0.0,
      topBlockingStages: sortedStages,
      topErrorKinds: sortedKinds,
    );
  }

  /// Run retrospective analysis and persist insights to run log.
  RetrospectiveSummary analyze(String projectRoot) {
    final retrospectives = collect(projectRoot);
    final summary = summarize(retrospectives);
    final layout = ProjectLayout(projectRoot);
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'retrospective_analysis',
        message: 'Post-task retrospective analysis completed',
        data: summary.toJson(),
      );
    }
    return summary;
  }

  String? _str(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }
}
