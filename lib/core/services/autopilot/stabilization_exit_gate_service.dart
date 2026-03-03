// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/task.dart';

class StabilizationExitGateResult {
  const StabilizationExitGateResult({
    required this.tasksFileExists,
    required this.openP1Count,
    required this.openP1Lines,
    required this.openPostStabilizationUnblockedCount,
    required this.openPostStabilizationUnblockedLines,
  });

  final bool tasksFileExists;
  final int openP1Count;
  final List<String> openP1Lines;
  final int openPostStabilizationUnblockedCount;
  final List<String> openPostStabilizationUnblockedLines;

  bool get featureFreezeLifted => openP1Count == 0;

  bool get hasViolation =>
      !featureFreezeLifted && openPostStabilizationUnblockedCount > 0;

  bool get ok => tasksFileExists && !hasViolation;

  String? get errorKind {
    if (!tasksFileExists) {
      return 'tasks_missing';
    }
    if (hasViolation) {
      return 'stabilization_exit_gate';
    }
    return null;
  }

  String get message {
    if (!tasksFileExists) {
      return 'No TASKS.md found for stabilization exit gate check.';
    }
    if (!hasViolation) {
      if (featureFreezeLifted) {
        return 'Feature freeze can be lifted: open P1 count is 0.';
      }
      return 'Feature freeze remains active: post-stabilization waves stay blocked while open P1 tasks exist.';
    }
    final firstLeak = openPostStabilizationUnblockedLines.isEmpty
        ? ''
        : ' First violating line: ${openPostStabilizationUnblockedLines.first}';
    return 'Stabilization exit gate violation: open P1 tasks=$openP1Count, '
        'open post-stabilization unblocked tasks='
        '$openPostStabilizationUnblockedCount.$firstLeak';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ok': ok,
      'feature_freeze_lifted': featureFreezeLifted,
      'open_p1_count': openP1Count,
      'open_post_stabilization_unblocked_count':
          openPostStabilizationUnblockedCount,
      'error_kind': errorKind,
      'message': message,
      'open_p1_lines': openP1Lines,
      'open_post_stabilization_unblocked_lines':
          openPostStabilizationUnblockedLines,
    };
  }
}

class StabilizationExitGateService {
  static final RegExp _sectionPattern = RegExp(r'^#{2,6}\s+(.+)$');
  static final RegExp _openTaskPattern = RegExp(r'^\s*-\s+\[\s*\]\s+');
  static final RegExp _priorityP1Pattern = RegExp(
    r'(?:\[P1\]|\(P1\)|\bP1\s*:)',
    caseSensitive: false,
  );
  static final RegExp _blockedPattern = RegExp(
    r'\[BLOCKED\]',
    caseSensitive: false,
  );

  /// Reads `TASKS.md` from [tasksPath], counts open P1 tasks and open
  /// post-stabilization unblocked tasks, and returns whether the
  /// stabilization exit gate passes.
  StabilizationExitGateResult evaluate(String tasksPath) {
    final file = File(tasksPath);
    if (!file.existsSync()) {
      return const StabilizationExitGateResult(
        tasksFileExists: false,
        openP1Count: 0,
        openP1Lines: <String>[],
        openPostStabilizationUnblockedCount: 0,
        openPostStabilizationUnblockedLines: <String>[],
      );
    }
    return evaluateFromText(file.readAsStringSync());
  }

  StabilizationExitGateResult evaluateFromText(String tasksContent) {
    var currentSection = 'Backlog';
    final openP1Lines = <String>[];
    final openPostStabilizationUnblockedLines = <String>[];

    for (final rawLine in tasksContent.split('\n')) {
      final sectionMatch = _sectionPattern.firstMatch(rawLine.trim());
      if (sectionMatch != null) {
        currentSection = sectionMatch.group(1)?.trim() ?? currentSection;
        continue;
      }

      if (!_openTaskPattern.hasMatch(rawLine)) {
        continue;
      }

      final normalizedLine = rawLine.trimLeft();
      final parsed = Task.parseLine(
        line: normalizedLine,
        section: currentSection,
        lineIndex: -1,
      );

      final openP1 =
          (parsed != null &&
              parsed.completion == TaskCompletion.open &&
              parsed.priority == TaskPriority.p1) ||
          _priorityP1Pattern.hasMatch(normalizedLine);
      if (openP1) {
        openP1Lines.add(rawLine.trimRight());
      }

      if (_isPostStabilizationSection(currentSection) &&
          !_isBlocked(normalizedLine, parsed)) {
        openPostStabilizationUnblockedLines.add(rawLine.trimRight());
      }
    }

    return StabilizationExitGateResult(
      tasksFileExists: true,
      openP1Count: openP1Lines.length,
      openP1Lines: List<String>.unmodifiable(openP1Lines),
      openPostStabilizationUnblockedCount:
          openPostStabilizationUnblockedLines.length,
      openPostStabilizationUnblockedLines: List<String>.unmodifiable(
        openPostStabilizationUnblockedLines,
      ),
    );
  }

  bool _isBlocked(String normalizedLine, Task? parsed) {
    if (parsed != null) {
      return parsed.blocked;
    }
    return _blockedPattern.hasMatch(normalizedLine);
  }

  bool _isPostStabilizationSection(String section) {
    final normalized = section.trim().toLowerCase();
    if (normalized.contains('post-stabilization feature wave')) {
      return true;
    }
    return normalized.contains('post stabilization feature wave');
  }
}
