// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../ids/task_slugger.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

/// Validates that the review evidence bundle for a task is complete, well-formed,
/// and satisfies the definition-of-done checklist before delivery.
class ReviewEvidenceValidator {
  /// Validates the full review evidence bundle for the given active task.
  ///
  /// Throws [StateError] with a delivery gate failure if any check fails.
  void validateReviewEvidenceBundle(
    String projectRoot, {
    required ProjectLayout layout,
    required String activeTaskTitle,
  }) {
    final slug = TaskSlugger.slug(activeTaskTitle);
    final taskAuditDir = Directory(
      '${layout.auditDir}${Platform.pathSeparator}$slug',
    );
    if (!taskAuditDir.existsSync()) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_missing',
        message:
            'Missing review evidence bundle for active task "$activeTaskTitle".',
      );
    }

    final candidates = taskAuditDir
        .listSync()
        .whereType<Directory>()
        .where((dir) => dir.path.endsWith('_review'))
        .toList(growable: false);
    if (candidates.isEmpty) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_missing',
        message: 'No review evidence entry found for "$activeTaskTitle".',
      );
    }

    candidates.sort(
      (a, b) => b.path.toLowerCase().compareTo(a.path.toLowerCase()),
    );
    final summaryFile = File(
      '${candidates.first.path}${Platform.pathSeparator}summary.json',
    );
    if (!summaryFile.existsSync()) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_missing',
        message:
            'Review evidence summary is missing for "$activeTaskTitle" at ${summaryFile.path}.',
      );
    }

    Map<String, dynamic> summary;
    try {
      final decoded = jsonDecode(summaryFile.readAsStringSync());
      if (decoded is! Map) {
        throw StateError('summary root is not an object');
      }
      summary = Map<String, dynamic>.from(decoded);
    } catch (error) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message: 'Review evidence summary is malformed: $error',
      );
    }

    final timestamp = _stringOrNull(summary['timestamp']);
    final kind = _stringOrNull(summary['kind']);
    final decision = _stringOrNull(summary['decision'])?.toLowerCase();
    final task = _stringOrNull(summary['task']);
    final taskId = _stringOrNull(summary['task_id']);
    final hasTaskContext =
        (task != null && task.isNotEmpty) ||
        (taskId != null && taskId.isNotEmpty);
    final hasSubtaskKey = summary.containsKey('subtask');
    final testSummary = _stringOrNull(summary['test_summary']);
    final note = _stringOrNull(summary['note']);
    final hasQualityEvidence =
        (testSummary != null && testSummary.isNotEmpty) ||
        (note != null && note.isNotEmpty);

    final filesNode = summary['files'];
    if (timestamp == null ||
        kind != 'review' ||
        (decision != 'approve' && decision != 'approved') ||
        !hasTaskContext ||
        !hasSubtaskKey ||
        filesNode is! Map ||
        !hasQualityEvidence) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message:
            'Review evidence summary is missing mandatory fields (timestamp/kind/decision/task-context/subtask/quality).',
      );
    }
    final files = Map<String, dynamic>.from(filesNode);
    validateDefinitionOfDone(projectRoot, summary);
    requireEvidenceFile(
      projectRoot,
      entryDir: candidates.first.path,
      relativePath: _stringOrNull(files['diff_summary']),
      field: 'diff_summary',
    );
    requireEvidenceFile(
      projectRoot,
      entryDir: candidates.first.path,
      relativePath: _stringOrNull(files['diff_patch']),
      field: 'diff_patch',
    );
  }

  /// Validates the definition-of-done checklist within a review evidence summary.
  void validateDefinitionOfDone(
    String projectRoot,
    Map<String, dynamic> summary,
  ) {
    final checklistNode = summary['definition_of_done'];
    if (checklistNode is! Map) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message:
            'Review evidence summary is missing mandatory definition_of_done checklist.',
      );
    }
    final checklist = Map<String, dynamic>.from(checklistNode);
    const requiredChecks = <String>[
      'implementation_completed',
      'tests_added_or_updated',
      'analyze_green',
      'relevant_tests_green',
      'runlog_status_checked_if_affected',
      'docs_updated_if_behavior_changed',
      'tasks_updated_same_slice',
    ];
    final incomplete = <String>[];
    for (final key in requiredChecks) {
      if (checklist[key] != true) {
        incomplete.add(key);
      }
    }
    if (incomplete.isNotEmpty) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message:
            'Review evidence definition_of_done is incomplete: ${incomplete.join(', ')}.',
      );
    }
  }

  /// Validates that a referenced evidence file exists and has non-empty content.
  void requireEvidenceFile(
    String projectRoot, {
    required String entryDir,
    required String? relativePath,
    required String field,
  }) {
    if (relativePath == null || relativePath.trim().isEmpty) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message: 'Review evidence file reference "$field" is missing.',
      );
    }
    final path = '$entryDir${Platform.pathSeparator}${relativePath.trim()}';
    final file = File(path);
    if (!file.existsSync()) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_missing',
        message: 'Review evidence file "$field" not found at $path.',
      );
    }
    final content = file.readAsStringSync().trim();
    if (content.isEmpty || content == '(none)') {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'evidence_malformed',
        message: 'Review evidence file "$field" is empty.',
      );
    }
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

  Never _deliveryGateFailure(
    String projectRoot, {
    required String errorKind,
    required String message,
  }) {
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'delivery_preflight_failed',
      message: 'Delivery gate blocked completion',
      data: {
        'root': projectRoot,
        'error_class': 'delivery',
        'error_kind': errorKind,
        'error': message,
      },
    );
    throw StateError(
      'Delivery preflight failed [delivery/$errorKind]: $message',
    );
  }
}
