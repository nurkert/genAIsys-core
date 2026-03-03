// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';

class DeadLetterEntry {
  const DeadLetterEntry({
    required this.timestamp,
    required this.task,
    this.taskId,
    this.subtaskId,
    required this.blockingStage,
    required this.retryCount,
    required this.reason,
    this.lastError,
    this.lastErrorClass,
    this.lastErrorKind,
  });

  final String timestamp;
  final String task;
  final String? taskId;
  final String? subtaskId;
  final String blockingStage;
  final int retryCount;
  final String reason;
  final String? lastError;
  final String? lastErrorClass;
  final String? lastErrorKind;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp,
      'task': task,
      if (taskId != null) 'task_id': taskId,
      if (subtaskId != null) 'subtask_id': subtaskId,
      'blocking_stage': blockingStage,
      'retry_count': retryCount,
      'reason': reason,
      if (lastError != null) 'last_error': lastError,
      if (lastErrorClass != null) 'last_error_class': lastErrorClass,
      if (lastErrorKind != null) 'last_error_kind': lastErrorKind,
    };
  }
}

class DeadLetterQueryService {
  List<DeadLetterEntry> query(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.runLogPath);
    if (!file.existsSync()) {
      return const [];
    }

    final entries = <DeadLetterEntry>[];
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map) {
          continue;
        }
        if (decoded['event'] != 'task_dead_letter') {
          continue;
        }
        final data = decoded['data'];
        if (data is! Map) {
          continue;
        }
        final task = _str(data['task']);
        if (task == null || task.isEmpty) {
          continue;
        }
        entries.add(
          DeadLetterEntry(
            timestamp: _str(decoded['timestamp']) ?? '',
            task: task,
            taskId: _str(data['task_id']),
            subtaskId: _str(data['subtask_id']),
            blockingStage: _str(data['blocking_stage']) ?? 'unknown',
            retryCount: _int(data['retry_count']),
            reason: _str(data['reason']) ?? '',
            lastError: _str(data['last_error']),
            lastErrorClass: _str(data['last_error_class']),
            lastErrorKind: _str(data['last_error_kind']),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return entries;
  }

  String? _str(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return 0;
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}
