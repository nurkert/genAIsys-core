// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../models/task.dart';
import '../../policy/diff_budget_policy.dart';
import '../../project_layout.dart';
import '../../storage/task_store.dart';

/// Classification of why a task failed after exhausting retries.
enum ForensicClassification {
  /// The spec targets too many files — the task is too large for a single pass.
  specTooLarge,

  /// Review-reject notes suggest the spec itself is wrong (wrong files, wrong
  /// requirements).
  specIncorrect,

  /// Failures stem from policy violations (diff budget, safe-write).
  policyConflict,

  /// Repeated quality-gate / test failures.
  persistentTestFailure,

  /// Review-reject notes suggest the coding approach is wrong — a different
  /// strategy is needed.
  codingApproachWrong,

  /// The task is already marked as completed (`[x]`) in TASKS.md.
  alreadyCompleted,

  /// No clear classification was possible.
  unknown,
}

/// Suggested recovery action after forensic diagnosis.
enum ForensicAction {
  /// Delete spec artifacts and regenerate with smaller scope.
  redecompose,

  /// Delete only the spec (not subtasks) and regenerate.
  regenerateSpec,

  /// Retry with anti-pattern guidance injected into the coding prompt.
  retryWithGuidance,

  /// Block the task — no recovery possible.
  block,
}

/// Result of a forensic analysis on a blocked task.
class ForensicDiagnosis {
  const ForensicDiagnosis({
    required this.classification,
    required this.evidence,
    required this.suggestedAction,
    this.guidanceText,
  });

  /// The classified root cause.
  final ForensicClassification classification;

  /// Supporting evidence collected from run-log, state, and spec.
  final List<String> evidence;

  /// The recommended recovery action.
  final ForensicAction suggestedAction;

  /// Optional guidance text to inject into the next coding prompt
  /// (for [ForensicAction.retryWithGuidance]).
  final String? guidanceText;

  Map<String, Object?> toJson() => {
    'classification': classification.name,
    'evidence': evidence,
    'suggested_action': suggestedAction.name,
    if (guidanceText != null) 'guidance_text': guidanceText,
  };
}

/// Performs rule-based forensic analysis on tasks that have exhausted their
/// retry budget.
///
/// Collects evidence from run-log entries (review-reject notes, error kinds)
/// and spec metadata (required file count), then classifies the root cause
/// without requiring an LLM call (deterministic, zero token cost).
class TaskForensicsService {
  // --- Pattern sets for classification ---

  /// Keywords in review-reject notes that indicate scope/size issues.
  static const _scopeKeywords = [
    'scope',
    'too many changes',
    'too large',
    'too big',
    'too many files',
    'break down',
    'split',
    'decompose',
  ];

  /// Keywords that indicate the spec itself is incorrect.
  static const _specIncorrectKeywords = [
    'wrong file',
    'missing file',
    'not what was specified',
    'wrong path',
    'incorrect spec',
    'wrong requirement',
    'misunderstand',
    'wrong target',
  ];

  /// Keywords that indicate a wrong coding approach.
  static const _approachKeywords = [
    'wrong approach',
    'different strategy',
    'alternative approach',
    'try a different',
    'rethink',
    'fundamentally',
    'completely wrong',
    'architecture',
  ];

  /// Error kinds that indicate policy conflicts.
  static const _policyErrorKinds = {
    'diff_budget_exceeded',
    'diff_budget',
    'diff_budget_at_commit',
    'safe_write_violation',
    'policy_violation',
  };

  /// Error kinds that indicate test/quality-gate failures.
  static const _testErrorKinds = {
    'quality_gate',
    'quality_gate_failed',
    'test_failure',
    'test_failed',
    'analyze_failed',
  };

  /// Required-file count above which we consider the spec too large.
  static const int specTooLargeFileThreshold = 5;

  /// Minimum length for a reject note to be useful as evidence.
  static const int minNoteLength = 10;

  /// Performs forensic analysis for a task that is about to be blocked.
  ///
  /// Collects review-reject notes and error kinds from the run-log, then
  /// applies rule-based classification.
  ForensicDiagnosis diagnose(
    String projectRoot, {
    String? taskTitle,
    int retryCount = 0,
    int requiredFileCount = 0,
    List<String>? errorKinds,
    DiffStats? diffStats,
    int qualityGateFailureCount = 0,
  }) {
    // Early exit: if the task is already marked done in TASKS.md, classify as
    // alreadyCompleted and suggest blocking immediately.
    if (taskTitle != null && _isTaskAlreadyCompleted(projectRoot, taskTitle)) {
      return ForensicDiagnosis(
        classification: ForensicClassification.alreadyCompleted,
        evidence: [
          'Task "$taskTitle" is already marked [x] in TASKS.md.',
          'Retry count: $retryCount',
        ],
        suggestedAction: ForensicAction.block,
      );
    }

    final rejectNotes = collectRejectNotes(projectRoot, taskTitle: taskTitle);
    final resolvedErrorKinds = errorKinds ?? _collectErrorKinds(projectRoot);
    final evidence = <String>[];

    // Collect evidence context.
    if (rejectNotes.isNotEmpty) {
      evidence.add('${rejectNotes.length} review-reject note(s) collected.');
    }
    if (resolvedErrorKinds.isNotEmpty) {
      evidence.add('Error kinds: ${resolvedErrorKinds.join(', ')}');
    }
    if (requiredFileCount > 0) {
      evidence.add('Required file count: $requiredFileCount');
    }
    if (diffStats != null) {
      evidence.add(
        'Diff stats: ${diffStats.filesChanged} files, '
        '+${diffStats.additions}/-${diffStats.deletions}',
      );
    }
    if (qualityGateFailureCount > 0) {
      evidence.add('Quality gate failures: $qualityGateFailureCount');
    }
    evidence.add('Retry count: $retryCount');

    return _classifyFromEvidence(
      rejectNotes: rejectNotes,
      errorKinds: resolvedErrorKinds,
      requiredFileCount: requiredFileCount,
      evidence: evidence,
      diffStats: diffStats,
      qualityGateFailureCount: qualityGateFailureCount,
    );
  }

  /// Collects all review-reject notes for the given task from the run-log.
  ///
  /// Scans the run-log backwards for `review_reject` events that match the
  /// task title (if provided). Returns notes sorted newest-first.
  List<String> collectRejectNotes(String projectRoot, {String? taskTitle}) {
    final layout = ProjectLayout(projectRoot);
    final logFile = File(layout.runLogPath);
    if (!logFile.existsSync()) {
      return const [];
    }

    List<String> lines;
    try {
      lines = logFile.readAsLinesSync();
    } catch (_) {
      return const [];
    }

    final notes = <String>[];
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final event = decoded['event']?.toString();
        if (event != 'review_reject') continue;

        final data = decoded['data'];
        if (data is! Map) continue;

        // If a task title is specified, only collect notes for that task.
        if (taskTitle != null && taskTitle.trim().isNotEmpty) {
          final logTask = data['task']?.toString().trim() ?? '';
          if (logTask.isNotEmpty &&
              !logTask.toLowerCase().contains(taskTitle.toLowerCase())) {
            continue;
          }
        }

        final note = data['note']?.toString();
        if (note != null &&
            note.trim().isNotEmpty &&
            note.trim().length >= minNoteLength) {
          notes.add(note.trim());
        }
      } catch (_) {
        continue;
      }
    }
    return notes;
  }

  /// Collects error kinds from the run-log (from recent events).
  List<String> _collectErrorKinds(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final logFile = File(layout.runLogPath);
    if (!logFile.existsSync()) {
      return const [];
    }

    List<String> lines;
    try {
      lines = logFile.readAsLinesSync();
    } catch (_) {
      return const [];
    }

    final kinds = <String>{};
    // Scan last 50 entries for error kinds.
    final start = lines.length > 50 ? lines.length - 50 : 0;
    for (var i = start; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final data = decoded['data'];
        if (data is! Map) continue;
        final errorKind = data['error_kind']?.toString().trim();
        if (errorKind != null && errorKind.isNotEmpty) {
          kinds.add(errorKind);
        }
      } catch (_) {
        continue;
      }
    }
    return kinds.toList();
  }

  /// Classifies the root cause from evidence using rule-based matching.
  ForensicDiagnosis _classifyFromEvidence({
    required List<String> rejectNotes,
    required List<String> errorKinds,
    required int requiredFileCount,
    required List<String> evidence,
    DiffStats? diffStats,
    int qualityGateFailureCount = 0,
  }) {
    final normalizedNotes = rejectNotes.map((n) => n.toLowerCase()).toList();
    final errorKindSet = errorKinds.map((k) => k.toLowerCase()).toSet();

    // Priority 1: Policy conflicts (hard blocks, cannot be resolved by
    // changing code approach).
    if (errorKindSet.intersection(_policyErrorKinds).isNotEmpty) {
      final matchedKinds = errorKindSet.intersection(_policyErrorKinds);
      evidence.add('Policy conflict detected: ${matchedKinds.join(', ')}');
      return ForensicDiagnosis(
        classification: ForensicClassification.policyConflict,
        evidence: evidence,
        suggestedAction: ForensicAction.block,
      );
    }

    // Priority 2: Persistent test failures (elevated by qualityGateFailureCount
    // and diffStats signals for Feature F).
    final hasTestErrorKind =
        errorKindSet.intersection(_testErrorKinds).isNotEmpty;
    final persistentTestScore =
        (hasTestErrorKind ? 2 : 0) + (qualityGateFailureCount >= 2 ? 2 : 0);
    if (persistentTestScore >= 2) {
      final matchedKinds = errorKindSet.intersection(_testErrorKinds);
      if (matchedKinds.isNotEmpty) {
        evidence.add('Test failure detected: ${matchedKinds.join(', ')}');
      }
      if (qualityGateFailureCount >= 2) {
        evidence.add(
            'Persistent quality gate failures: $qualityGateFailureCount');
      }
      return ForensicDiagnosis(
        classification: ForensicClassification.persistentTestFailure,
        evidence: evidence,
        suggestedAction: ForensicAction.retryWithGuidance,
        guidanceText:
            'Previous attempts failed quality gate / test runs. '
            'Focus on ensuring all existing tests pass before adding new code. '
            'Run tests locally before completing.',
      );
    }

    // Priority 3: Spec too large — from file count, diff size, or notes.
    var specTooLargeScore = 0;
    if (requiredFileCount > specTooLargeFileThreshold) {
      specTooLargeScore += 3;
      evidence.add(
        'Required file count ($requiredFileCount) exceeds '
        'threshold ($specTooLargeFileThreshold).',
      );
    }
    if (diffStats != null) {
      if (diffStats.filesChanged > 10) {
        specTooLargeScore += 2;
        evidence.add('Large diff: ${diffStats.filesChanged} files changed.');
      }
      if (diffStats.additions > 1500) {
        specTooLargeScore += 1;
        evidence.add('Large diff: ${diffStats.additions} additions.');
      }
    }
    if (_notesMatchAny(normalizedNotes, _scopeKeywords)) {
      specTooLargeScore += 2;
    }
    if (specTooLargeScore >= 2) {
      if (_notesMatchAny(normalizedNotes, _scopeKeywords)) {
        evidence.add('Review notes mention scope/size issues.');
      }
      return ForensicDiagnosis(
        classification: ForensicClassification.specTooLarge,
        evidence: evidence,
        suggestedAction: ForensicAction.redecompose,
        guidanceText:
            'Previous spec too large: $requiredFileCount files required '
            '(threshold: $specTooLargeFileThreshold). '
            'Decompose into subtasks that each touch max 3 files.',
      );
    }

    // Priority 4: Spec incorrect.
    if (_notesMatchAny(normalizedNotes, _specIncorrectKeywords)) {
      evidence.add('Review notes suggest spec is incorrect.');
      return ForensicDiagnosis(
        classification: ForensicClassification.specIncorrect,
        evidence: evidence,
        suggestedAction: ForensicAction.regenerateSpec,
        guidanceText:
            'Review feedback indicates the spec targets the wrong files or '
            'has incorrect requirements. Regenerate with corrected targets.',
      );
    }

    // Priority 5: Wrong coding approach.
    if (_notesMatchAny(normalizedNotes, _approachKeywords)) {
      final matchingNote = _firstMatchingNote(
        normalizedNotes,
        _approachKeywords,
        originalNotes: rejectNotes,
      );
      evidence.add('Review notes suggest wrong coding approach.');
      return ForensicDiagnosis(
        classification: ForensicClassification.codingApproachWrong,
        evidence: evidence,
        suggestedAction: ForensicAction.retryWithGuidance,
        guidanceText: matchingNote != null
            ? 'Previous approach was rejected: "$matchingNote". '
                  'Try a fundamentally different strategy.'
            : 'Previous coding approach was rejected. '
                  'Try a fundamentally different strategy.',
      );
    }

    // Default: Unknown.
    evidence.add('No clear failure pattern identified.');
    return ForensicDiagnosis(
      classification: ForensicClassification.unknown,
      evidence: evidence,
      suggestedAction: ForensicAction.block,
    );
  }

  /// Checks if any note contains any of the given keywords.
  bool _notesMatchAny(List<String> normalizedNotes, List<String> keywords) {
    for (final note in normalizedNotes) {
      for (final keyword in keywords) {
        if (note.contains(keyword)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks whether a task with [taskTitle] is already marked as done in
  /// TASKS.md.
  bool _isTaskAlreadyCompleted(String projectRoot, String taskTitle) {
    try {
      final layout = ProjectLayout(projectRoot);
      final tasksFile = File(layout.tasksPath);
      if (!tasksFile.existsSync()) return false;
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final normalized = taskTitle.trim().toLowerCase();
      return tasks.any(
        (t) =>
            t.title.trim().toLowerCase() == normalized &&
            t.completion == TaskCompletion.done,
      );
    } catch (_) {
      return false;
    }
  }

  /// Returns the first original note that matches any keyword.
  String? _firstMatchingNote(
    List<String> normalizedNotes,
    List<String> keywords, {
    required List<String> originalNotes,
  }) {
    for (var i = 0; i < normalizedNotes.length; i++) {
      for (final keyword in keywords) {
        if (normalizedNotes[i].contains(keyword)) {
          return originalNotes[i];
        }
      }
    }
    return null;
  }
}
