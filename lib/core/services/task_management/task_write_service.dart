// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/task.dart';
import '../../project_layout.dart';
import '../../storage/atomic_file_write.dart';
import '../../storage/run_log_store.dart';
import '../../storage/task_store.dart';

class TaskCreateResult {
  TaskCreateResult({required this.task});

  final Task task;
}

class TaskPriorityUpdateResult {
  TaskPriorityUpdateResult({required this.task});

  final Task task;
}

class TaskDeleteResult {
  TaskDeleteResult({required this.task});

  final Task task;
}

class TaskMoveResult {
  TaskMoveResult({required this.task, required this.fromSection});

  final Task task;
  final String fromSection;
}

class TaskWriteService {
  TaskCreateResult createTask(
    String projectRoot, {
    required String title,
    required TaskPriority priority,
    required TaskCategory category,
    String? section,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Task title must not be empty.');
    }

    final normalizedSection = _normalizeSection(section);
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final normalizedKey = _normalizeTitle(normalizedTitle);
    if (tasks.any((task) => _normalizeTitle(task.title) == normalizedKey)) {
      throw StateError('Task title already exists: $normalizedTitle');
    }

    final line = _formatLine(
      title: normalizedTitle,
      priority: priority,
      category: category,
      blocked: false,
      completed: false,
    );

    final file = File(layout.tasksPath);
    final lines = file.readAsLinesSync();

    final insertion = _insertLine(lines, line, normalizedSection);
    AtomicFileWrite.writeStringSync(
      layout.tasksPath,
      '${insertion.lines.join('\n').trimRight()}\n',
    );

    final task = Task.parseLine(
      line: line,
      section: insertion.section,
      lineIndex: insertion.insertIndex,
    );
    if (task == null) {
      throw StateError('Failed to parse created task line.');
    }

    RunLogStore(layout.runLogPath).append(
      event: 'task_created',
      message: 'Created task',
      data: {
        'root': projectRoot,
        'task': task.title,
        'section': task.section,
        'priority': task.priority.name,
        'category': task.category.name,
      },
    );

    return TaskCreateResult(task: task);
  }

  TaskPriorityUpdateResult updatePriority(
    String projectRoot, {
    String? id,
    String? title,
    required TaskPriority priority,
  }) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final task = _findTask(tasks, id: id, title: title);
    if (task == null) {
      throw StateError('Task not found.');
    }

    final file = File(layout.tasksPath);
    final lines = file.readAsLinesSync();
    if (task.lineIndex < 0 || task.lineIndex >= lines.length) {
      throw StateError('Task line index out of range.');
    }

    final updatedLine = _replacePriority(lines[task.lineIndex], priority);
    lines[task.lineIndex] = updatedLine;
    AtomicFileWrite.writeStringSync(
      layout.tasksPath,
      '${lines.join('\n').trimRight()}\n',
    );

    final updated = Task.parseLine(
      line: updatedLine,
      section: task.section,
      lineIndex: task.lineIndex,
    );
    if (updated == null) {
      throw StateError('Failed to parse updated task line.');
    }

    RunLogStore(layout.runLogPath).append(
      event: 'task_priority_updated',
      message: 'Updated task priority',
      data: {
        'root': projectRoot,
        'task': updated.title,
        'priority': updated.priority.name,
      },
    );

    return TaskPriorityUpdateResult(task: updated);
  }

  TaskMoveResult moveSection(
    String projectRoot, {
    String? id,
    String? title,
    required String section,
  }) {
    final normalizedSection = _normalizeSection(section);
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final task = _findTask(tasks, id: id, title: title);
    if (task == null) {
      throw StateError('Task not found.');
    }

    if (_normalizeSection(task.section) == normalizedSection) {
      return TaskMoveResult(task: task, fromSection: task.section);
    }

    final file = File(layout.tasksPath);
    final lines = file.readAsLinesSync();
    if (task.lineIndex < 0 || task.lineIndex >= lines.length) {
      throw StateError('Task line index out of range.');
    }

    final line = lines.removeAt(task.lineIndex);
    final insertion = _insertLine(lines, line, normalizedSection);
    AtomicFileWrite.writeStringSync(
      layout.tasksPath,
      '${insertion.lines.join('\n').trimRight()}\n',
    );

    final moved = Task.parseLine(
      line: line,
      section: insertion.section,
      lineIndex: insertion.insertIndex,
    );
    if (moved == null) {
      throw StateError('Failed to parse moved task line.');
    }

    RunLogStore(layout.runLogPath).append(
      event: 'task_section_moved',
      message: 'Moved task section',
      data: {
        'root': projectRoot,
        'task': moved.title,
        'from': task.section,
        'to': moved.section,
      },
    );

    return TaskMoveResult(task: moved, fromSection: task.section);
  }

  TaskDeleteResult deleteTask(String projectRoot, {String? id, String? title}) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final task = _findTask(tasks, id: id, title: title);
    if (task == null) {
      throw StateError('Task not found.');
    }

    final file = File(layout.tasksPath);
    final lines = file.readAsLinesSync();
    if (task.lineIndex < 0 || task.lineIndex >= lines.length) {
      throw StateError('Task line index out of range.');
    }

    lines.removeAt(task.lineIndex);
    AtomicFileWrite.writeStringSync(
      layout.tasksPath,
      '${lines.join('\n').trimRight()}\n',
    );

    RunLogStore(layout.runLogPath).append(
      event: 'task_deleted',
      message: 'Deleted task',
      data: {
        'root': projectRoot,
        'task': task.title,
        'id': task.id,
        'section': task.section,
        'priority': task.priority.name,
      },
    );

    return TaskDeleteResult(task: task);
  }

  Task? _findTask(List<Task> tasks, {String? id, String? title}) {
    if (id != null && id.trim().isNotEmpty) {
      return tasks
          .where((task) => task.id == id)
          .cast<Task?>()
          .firstWhere((task) => task != null, orElse: () => null);
    }
    if (title != null && title.trim().isNotEmpty) {
      final normalized = _normalizeTitle(title);
      final matches = tasks
          .where((task) => _normalizeTitle(task.title) == normalized)
          .toList();
      if (matches.isEmpty) {
        return null;
      }
      if (matches.length > 1) {
        throw StateError('Task title is not unique: $title');
      }
      return matches.first;
    }
    return null;
  }

  String _formatLine({
    required String title,
    required TaskPriority priority,
    required TaskCategory category,
    required bool completed,
    required bool blocked,
  }) {
    final checkbox = completed ? 'x' : ' ';
    final priorityTag = _priorityTag(priority);
    final categoryTag = _categoryTag(category);
    final buffer = StringBuffer('- [$checkbox]');
    if (blocked) {
      buffer.write(' [BLOCKED]');
    }
    buffer.write(' [$priorityTag] [$categoryTag] $title');
    return buffer.toString();
  }

  String _replacePriority(String line, TaskPriority priority) {
    final match = RegExp(r'^- \[[ xX]\]\s+').firstMatch(line);
    if (match == null) {
      return line;
    }
    final prefix = match.group(0)!;
    var rest = line.substring(match.end);
    var blockedToken = '';
    final blockedMatch = RegExp(
      r'^\[BLOCKED\]\s+',
      caseSensitive: false,
    ).firstMatch(rest);
    if (blockedMatch != null) {
      blockedToken = blockedMatch.group(0)!;
      rest = rest.substring(blockedMatch.end);
    }
    rest = rest.replaceFirst(
      RegExp(
        r'^(?:\[P[1-3]\]|\(P[1-3]\)|P[1-3]\s*:\s*)\s*',
        caseSensitive: false,
      ),
      '',
    );
    return '$prefix$blockedToken[${_priorityTag(priority)}] $rest'.trimRight();
  }

  _InsertionResult _insertLine(
    List<String> lines,
    String line,
    String section,
  ) {
    var sectionIndex = _findSectionIndex(lines, section);
    var sectionLabel = section;

    if (sectionIndex == -1) {
      final updated = <String>[...lines];
      if (updated.isNotEmpty && updated.last.trim().isNotEmpty) {
        updated.add('');
      }
      updated.add('## $section');
      sectionIndex = updated.length - 1;
      updated.add(line);
      return _InsertionResult(
        lines: updated,
        insertIndex: updated.length - 1,
        section: sectionLabel,
      );
    }

    sectionLabel = _extractSectionName(lines[sectionIndex]) ?? sectionLabel;

    var insertAt = lines.length;
    for (var i = sectionIndex + 1; i < lines.length; i += 1) {
      if (lines[i].trim().startsWith('## ')) {
        insertAt = i;
        break;
      }
    }

    final updated = <String>[...lines];
    updated.insert(insertAt, line);
    return _InsertionResult(
      lines: updated,
      insertIndex: insertAt,
      section: sectionLabel,
    );
  }

  int _findSectionIndex(List<String> lines, String section) {
    final needle = '## ${section.trim().toLowerCase()}';
    return lines.indexWhere((line) => line.trim().toLowerCase() == needle);
  }

  String? _extractSectionName(String line) {
    final match = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
    return match?.group(1)?.trim();
  }

  String _priorityTag(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.p1:
        return 'P1';
      case TaskPriority.p2:
        return 'P2';
      case TaskPriority.p3:
        return 'P3';
    }
  }

  String _categoryTag(TaskCategory category) {
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
        throw ArgumentError('Task category is required.');
    }
  }

  String _normalizeSection(String? section) {
    final trimmed = section?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Backlog';
    }
    return trimmed;
  }

  String _normalizeTitle(String title) {
    final stripped = title.replaceAll(
      RegExp(
        r'\s*[|()]?\s*(?:AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]\s*.+$',
        caseSensitive: false,
      ),
      '',
    );
    return stripped.trim().toLowerCase();
  }

  void _ensureTasksFile(ProjectLayout layout) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
  }
}

class _InsertionResult {
  _InsertionResult({
    required this.lines,
    required this.insertIndex,
    required this.section,
  });

  final List<String> lines;
  final int insertIndex;
  final String section;
}
