// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';

/// Per-file health metrics from static analysis.
class FileHealthSnapshot {
  const FileHealthSnapshot({
    required this.filePath,
    required this.lineCount,
    required this.maxMethodLines,
    required this.maxNestingDepth,
    required this.maxParameterCount,
    required this.methodCount,
  });

  final String filePath;
  final int lineCount;
  final int maxMethodLines;
  final int maxNestingDepth;
  final int maxParameterCount;
  final int methodCount;

  Map<String, Object?> toJson() => {
    'file_path': filePath,
    'line_count': lineCount,
    'max_method_lines': maxMethodLines,
    'max_nesting_depth': maxNestingDepth,
    'max_parameter_count': maxParameterCount,
    'method_count': methodCount,
  };

  factory FileHealthSnapshot.fromJson(Map<String, Object?> json) {
    return FileHealthSnapshot(
      filePath: json['file_path'] as String? ?? '',
      lineCount: json['line_count'] as int? ?? 0,
      maxMethodLines: json['max_method_lines'] as int? ?? 0,
      maxNestingDepth: json['max_nesting_depth'] as int? ?? 0,
      maxParameterCount: json['max_parameter_count'] as int? ?? 0,
      methodCount: json['method_count'] as int? ?? 0,
    );
  }
}

/// A ledger entry recorded after each delivery.
class DeliveryHealthEntry {
  const DeliveryHealthEntry({
    this.taskId,
    this.taskTitle,
    required this.timestamp,
    required this.files,
  });

  final String? taskId;
  final String? taskTitle;
  final String timestamp;
  final List<FileHealthSnapshot> files;

  Map<String, Object?> toJson() => {
    if (taskId != null) 'task_id': taskId,
    if (taskTitle != null) 'task_title': taskTitle,
    'timestamp': timestamp,
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory DeliveryHealthEntry.fromJson(Map<String, Object?> json) {
    final filesRaw = json['files'];
    final files = <FileHealthSnapshot>[];
    if (filesRaw is List) {
      for (final item in filesRaw) {
        if (item is Map<String, Object?>) {
          files.add(FileHealthSnapshot.fromJson(item));
        }
      }
    }
    return DeliveryHealthEntry(
      taskId: json['task_id'] as String?,
      taskTitle: json['task_title'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      files: files,
    );
  }
}

/// Which detection layer produced a signal.
enum HealthSignalLayer { static, dejaVu, architectureReflection }

/// A single code health finding.
class CodeHealthSignal {
  const CodeHealthSignal({
    required this.layer,
    required this.confidence,
    required this.finding,
    required this.affectedFiles,
    this.suggestedAction,
  });

  final HealthSignalLayer layer;

  /// Confidence in the signal, 0.0–1.0.
  final double confidence;

  /// Human-readable description of the finding.
  final String finding;

  final List<String> affectedFiles;

  /// Optional suggested refactoring action.
  final String? suggestedAction;
}

/// Aggregated result of a code health evaluation.
class CodeHealthReport {
  const CodeHealthReport({
    required this.signals,
    required this.combinedConfidence,
    this.recommendedPriority,
    required this.shouldCreateTask,
  });

  final List<CodeHealthSignal> signals;
  final double combinedConfidence;
  final TaskPriority? recommendedPriority;
  final bool shouldCreateTask;

  static const CodeHealthReport empty = CodeHealthReport(
    signals: [],
    combinedConfidence: 0.0,
    shouldCreateTask: false,
  );
}
