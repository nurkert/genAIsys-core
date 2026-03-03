// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../models/task.dart';

enum TaskSelectionMode { priority, fair, strictPriority }

class TaskSelectionContext {
  TaskSelectionContext({
    required this.mode,
    required this.fairnessWindow,
    required this.priorityWeights,
    required this.deferNonCriticalUiTasks,
    required this.includeBlocked,
    required this.includeFailed,
    required this.failedCooldown,
    required this.blockedCooldown,
    required this.retryCounts,
    required this.taskCooldownUntil,
    required this.history,
    required this.now,
  });

  final TaskSelectionMode mode;
  final int fairnessWindow;
  final Map<TaskPriority, int> priorityWeights;
  final bool deferNonCriticalUiTasks;
  final bool includeBlocked;
  final bool includeFailed;
  final Duration failedCooldown;
  final Duration blockedCooldown;
  final Map<String, int> retryCounts;

  /// Per-task cooldown expiration timestamps (task key → ISO-8601 UTC).
  final Map<String, String> taskCooldownUntil;
  final TaskSelectionHistory history;
  final DateTime now;
}

class TaskSelectionHistory {
  TaskSelectionHistory({
    required this.priorityHistory,
    required this.lastActivationByTaskId,
    required this.lastActivationByTitle,
  });

  final List<TaskPriority> priorityHistory;
  final Map<String, DateTime> lastActivationByTaskId;
  final Map<String, DateTime> lastActivationByTitle;

  factory TaskSelectionHistory.empty() {
    return TaskSelectionHistory(
      priorityHistory: const [],
      lastActivationByTaskId: const {},
      lastActivationByTitle: const {},
    );
  }

  factory TaskSelectionHistory.fromRunLog(
    String runLogPath,
    List<Task> tasks, {
    required int maxEntries,
  }) {
    final file = File(runLogPath);
    if (!file.existsSync()) {
      return TaskSelectionHistory.empty();
    }

    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return TaskSelectionHistory.empty();
    }

    final byId = <String, Task>{};
    final byTitle = <String, Task>{};
    for (final task in tasks) {
      byId[task.id] = task;
      byTitle[_titleKey(task.title)] = task;
    }

    final history = <TaskPriority>[];
    final lastById = <String, DateTime>{};
    final lastByTitle = <String, DateTime>{};
    final limit = maxEntries < 1 ? 0 : maxEntries;

    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final raw = lines[i].trim();
      if (raw.isEmpty) {
        continue;
      }
      Map<String, dynamic>? decoded;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) {
          continue;
        }
        decoded = parsed;
      } catch (_) {
        continue;
      }

      if (decoded['event'] != 'activate_task') {
        continue;
      }

      final data = decoded['data'];
      if (data is! Map) {
        continue;
      }

      final taskId = _stringOrNull(data['task_id']);
      final taskTitle = _stringOrNull(data['task']);
      Task? matched;
      if (taskId != null) {
        matched = byId[taskId];
      }
      if (matched == null && taskTitle != null) {
        matched = byTitle[_titleKey(taskTitle)];
      }
      if (matched == null) {
        continue;
      }

      final timestamp = _parseTimestamp(decoded['timestamp']);
      if (timestamp != null) {
        if (!lastById.containsKey(matched.id)) {
          lastById[matched.id] = timestamp;
        }
        final titleKey = _titleKey(matched.title);
        if (!lastByTitle.containsKey(titleKey)) {
          lastByTitle[titleKey] = timestamp;
        }
      }

      if (limit == 0 || history.length < limit) {
        history.add(matched.priority);
      }

      if (limit > 0 &&
          history.length >= limit &&
          lastById.length >= tasks.length) {
        break;
      }
    }

    return TaskSelectionHistory(
      priorityHistory: history,
      lastActivationByTaskId: lastById,
      lastActivationByTitle: lastByTitle,
    );
  }

  static String _titleKey(String raw) {
    return raw.trim().toLowerCase();
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  static DateTime? _parseTimestamp(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}
