// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'task.dart';
import 'task_line_parser.dart';

class TaskDraft {
  TaskDraft({
    required this.title,
    required this.priority,
    required this.category,
    required this.acceptanceCriteria,
    this.source,
  });

  final String title;
  final TaskPriority priority;
  final TaskCategory category;
  final String acceptanceCriteria;
  final String? source;

  TaskDraft copyWith({
    String? title,
    TaskPriority? priority,
    TaskCategory? category,
    String? acceptanceCriteria,
    String? source,
  }) {
    return TaskDraft(
      title: title ?? this.title,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      source: source ?? this.source,
    );
  }

  String toTaskLine() {
    final priorityTag = _priorityTag(priority);
    final categoryTag = _categoryTag(category);
    final acceptance = acceptanceCriteria.trim().isEmpty
        ? _defaultAcceptance(title)
        : acceptanceCriteria.trim();
    return '- [ ] [$priorityTag] [$categoryTag] $title | AC: $acceptance';
  }

  String normalizedKey() {
    return _normalizeTitleKey(title);
  }

  static TaskDraft? parseLine(
    String raw, {
    TaskPriority defaultPriority = TaskPriority.p2,
    TaskCategory defaultCategory = TaskCategory.core,
  }) {
    var content = raw.trim();
    if (content.isEmpty) {
      return null;
    }
    content = content.replaceFirst(TaskLineParser.listPrefix, '');
    content = content.replaceFirst(TaskLineParser.numberedPrefix, '');

    TaskPriority priority = _extractPriority(content) ?? defaultPriority;
    TaskCategory category = _extractCategory(content) ?? defaultCategory;

    var acceptance = _extractAcceptance(content);
    content = _stripAcceptance(content);

    content = _stripTags(content);
    content = _cleanupTitle(content);
    if (content.isEmpty) {
      return null;
    }

    return TaskDraft(
      title: content,
      priority: priority,
      category: category,
      acceptanceCriteria: acceptance ?? '',
    );
  }

  static String _normalizeTitleKey(String title) {
    return title.toLowerCase().replaceAll(TaskLineParser.titleNormalize, ' ').trim();
  }

  static TaskPriority? _extractPriority(String value) =>
      TaskLineParser.extractPriority(value);

  static TaskCategory? _extractCategory(String value) =>
      TaskLineParser.extractCategory(value);

  static String? _extractAcceptance(String value) {
    final match = TaskLineParser.acceptancePattern.firstMatch(value);
    final acceptance = match?.group(1)?.trim();
    if (acceptance == null || acceptance.isEmpty) {
      return null;
    }
    return _truncate(acceptance, 160);
  }

  static String _stripAcceptance(String value) {
    return value.replaceAll(TaskLineParser.stripAcceptancePattern, '');
  }

  static String _stripTags(String value) {
    var cleaned = value.replaceAll(TaskLineParser.categoryTag, '');
    cleaned = cleaned.replaceAll(TaskLineParser.blockedTag, '');
    cleaned = cleaned.replaceAll(TaskLineParser.stripPriorityTag, '');
    return cleaned;
  }

  static String _cleanupTitle(String value) {
    var trimmed = value.replaceAll(TaskLineParser.whitespace, ' ').trim();
    trimmed = trimmed.replaceFirst(TaskLineParser.leadingPunctuation, '').trim();
    trimmed = trimmed.replaceFirst(TaskLineParser.trailingPunctuation, '').trim();
    return trimmed;
  }

  static String _defaultAcceptance(String title) {
    return _truncate(
      'The change for "$title" is implemented and verified by tests or manual check.',
      160,
    );
  }

  static String _priorityTag(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.p1:
        return 'P1';
      case TaskPriority.p2:
        return 'P2';
      case TaskPriority.p3:
        return 'P3';
    }
  }

  static String _categoryTag(TaskCategory category) {
    switch (category) {
      case TaskCategory.core:
        return 'CORE';
      case TaskCategory.ui:
        return 'UI';
      case TaskCategory.security:
        return 'SEC';
      case TaskCategory.docs:
        return 'DOCS';
      case TaskCategory.architecture:
        return 'ARCH';
      case TaskCategory.qa:
        return 'QA';
      case TaskCategory.agent:
        return 'AGENT';
      case TaskCategory.refactor:
        return 'REF';
      case TaskCategory.unknown:
        return 'CORE';
    }
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1)}…';
  }
}
