// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/task.dart';

class TaskStore {
  TaskStore(this.tasksPath);

  final String tasksPath;
  static const String _defaultSection = 'Backlog';
  static final RegExp _openTaskPattern = RegExp(r'^- \[( )\]\s+');
  static final RegExp _sectionPattern = RegExp(r'^##\s+(.+)$');
  static final RegExp _priorityPattern = RegExp(
    r'(?:\[P[1-3]\]|\(P[1-3]\)|\bP[1-3]\s*:)',
    caseSensitive: false,
  );
  static final RegExp _priorityP1Pattern = RegExp(
    r'(?:\[P1\]|\(P1\)|\bP1\s*:)',
    caseSensitive: false,
  );
  static final RegExp _categoryPattern = RegExp(
    r'\[(UI|SEC|DOCS|ARCH|QA|AGENT|CORE|REF|REFACTOR)\]',
    caseSensitive: false,
  );
  static final RegExp _stabilizationCategoryPattern = RegExp(
    r'\[(SEC|ARCH|QA|CORE|REF|REFACTOR)\]',
    caseSensitive: false,
  );

  List<Task> readTasks() {
    final file = File(tasksPath);
    if (!file.existsSync()) {
      return [];
    }
    final lines = file.readAsLinesSync();
    final tasks = <Task>[];
    var currentSection = _defaultSection;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final sectionMatch = _sectionPattern.firstMatch(line.trim());
      if (sectionMatch != null) {
        currentSection = sectionMatch.group(1)?.trim() ?? currentSection;
        continue;
      }
      final task = Task.parseLine(
        line: line,
        section: currentSection,
        lineIndex: i,
      );
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  bool hasOpenP1StabilizationTask() {
    final file = File(tasksPath);
    if (!file.existsSync()) {
      return false;
    }
    final lines = file.readAsLinesSync();
    var currentSection = _defaultSection;
    for (final rawLine in lines) {
      final sectionMatch = _sectionPattern.firstMatch(rawLine.trim());
      if (sectionMatch != null) {
        currentSection = sectionMatch.group(1)?.trim() ?? currentSection;
        continue;
      }
      final line = rawLine.trim();
      if (_lineSignalsOpenP1StabilizationTask(line, currentSection)) {
        return true;
      }
    }
    return false;
  }

  bool _lineSignalsOpenP1StabilizationTask(String line, String section) {
    if (!_openTaskPattern.hasMatch(line)) {
      return false;
    }

    final parsed = Task.parseLine(line: line, section: section, lineIndex: -1);
    if (parsed != null &&
        parsed.completion == TaskCompletion.open &&
        parsed.priority == TaskPriority.p1 &&
        _isStabilizationCategory(parsed.category)) {
      return true;
    }

    final hasP1Marker = _priorityP1Pattern.hasMatch(line);
    final hasPriorityMarker = _priorityPattern.hasMatch(line);
    final hasStabilizationCategory = _stabilizationCategoryPattern.hasMatch(
      line,
    );
    final hasCategoryMarker = _categoryPattern.hasMatch(line);
    if ((hasP1Marker && !hasCategoryMarker) ||
        (hasStabilizationCategory && !hasPriorityMarker)) {
      return true;
    }

    final sectionIndicatesStabilization = section.toLowerCase().contains(
      'stabilization',
    );
    if (sectionIndicatesStabilization &&
        (!hasPriorityMarker || !hasCategoryMarker)) {
      return true;
    }

    return false;
  }

  bool _isStabilizationCategory(TaskCategory category) {
    switch (category) {
      case TaskCategory.core:
      case TaskCategory.security:
      case TaskCategory.qa:
      case TaskCategory.architecture:
      case TaskCategory.refactor:
        return true;
      case TaskCategory.ui:
      case TaskCategory.docs:
      case TaskCategory.agent:
      case TaskCategory.unknown:
        return false;
    }
  }
}
