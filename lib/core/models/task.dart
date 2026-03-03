// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';
import '../ids/task_slugger.dart';
import 'task_line_parser.dart';

part 'task.freezed.dart';

enum TaskPriority { p1, p2, p3 }

enum TaskCategory {
  core,
  ui,
  security,
  docs,
  architecture,
  qa,
  agent,
  refactor,
  unknown,
}

enum TaskCompletion { open, done }

@freezed
abstract class Task with _$Task {
  const Task._();

  static final RegExp _blockedReasonPattern =
      TaskLineParser.blockedReasonPattern;

  static final RegExp _depsPattern = RegExp(
    r'[\(\[]\s*(?:needs|depends):\s*([^\)\]]+)[\)\]]',
    caseSensitive: false,
  );

  const factory Task({
    required String title,
    required TaskPriority priority,
    required TaskCategory category,
    required TaskCompletion completion,
    @Default(false) bool blocked,
    required String section,
    required int lineIndex,
    @Default(<String>[]) List<String> dependencyRefs,
  }) = _Task;

  String get id => '${TaskSlugger.slug(title)}-$lineIndex';

  String? get blockReason {
    if (!blocked) {
      return null;
    }
    final match = _blockedReasonPattern.firstMatch(title);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  bool get blockedByAutoCycle {
    final reason = blockReason;
    if (reason == null) {
      return false;
    }
    return reason.toLowerCase().startsWith('auto-cycle:');
  }

  static Task? parseLine({
    required String line,
    required String section,
    required int lineIndex,
  }) {
    final trimmed = line.trimRight();
    final match = TaskLineParser.checkboxLine.firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final completion = (match.group(1) ?? '').toLowerCase() == 'x'
        ? TaskCompletion.done
        : TaskCompletion.open;
    var remainder = match.group(2) ?? '';
    var blocked = false;
    final blockedMatch = TaskLineParser.blockedTag.firstMatch(remainder);
    if (blockedMatch != null) {
      blocked = true;
      remainder = remainder
          .replaceFirst(blockedMatch.group(0) ?? '', '')
          .trim();
    }

    final priorityMatch =
        TaskLineParser.priorityTagAnchored.firstMatch(remainder);
    TaskPriority priority = TaskPriority.p3;
    if (priorityMatch != null) {
      final value =
          priorityMatch.group(1) ??
          priorityMatch.group(2) ??
          priorityMatch.group(3);
      if (value == '1') {
        priority = TaskPriority.p1;
      } else if (value == '2') {
        priority = TaskPriority.p2;
      }
      remainder = remainder.substring(priorityMatch.end).trim();
    }

    final categoryMatch = TaskLineParser.categoryTag.firstMatch(remainder);
    TaskCategory category = TaskCategory.unknown;
    if (categoryMatch != null) {
      category = TaskLineParser.extractCategory(remainder) ??
          TaskCategory.unknown;
      remainder = remainder
          .replaceFirst(categoryMatch.group(0) ?? '', '')
          .trim();
    }

    // Parse dependency refs: [needs: slug] or (depends: a, b)
    final depsMatch = _depsPattern.firstMatch(remainder);
    final dependencyRefs = depsMatch != null
        ? depsMatch
            .group(1)!
            .split(RegExp(r'[,\s]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final cleanRemainder = depsMatch != null
        ? remainder.replaceAll(_depsPattern, '').trim()
        : remainder;

    final title = cleanRemainder.trim();
    if (title.isEmpty) {
      return null;
    }

    return Task(
      title: title,
      priority: priority,
      category: category,
      completion: completion,
      blocked: blocked,
      section: section,
      lineIndex: lineIndex,
      dependencyRefs: dependencyRefs,
    );
  }
}
