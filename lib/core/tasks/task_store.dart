// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/task.dart' as core_task;
import '../project_layout.dart';
import '../storage/task_store.dart' as core_store;
import '../storage/task_writer.dart' as core_writer;

enum TaskStatus { open, done, blocked }

class Task {
  Task({
    required this.title,
    required this.status,
    required this.lineIndex,
    this.id,
    this.priority,
    this.category,
  });

  final String title;
  final TaskStatus status;
  final int lineIndex;
  final String? id;
  final String? priority;
  final String? category;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'category': category,
      'status': status.name,
    };
  }
}

class TaskStore {
  TaskStore(this.projectRoot) : layout = ProjectLayout(projectRoot);

  final String projectRoot;
  final ProjectLayout layout;

  List<Task> listTasks() {
    final parsed = core_store.TaskStore(layout.tasksPath).readTasks();
    return parsed.map(_toLegacyTask).toList(growable: false);
  }

  Task? nextOpenTask() {
    final tasks = listTasks();
    for (final task in tasks) {
      if (task.status == TaskStatus.open) {
        return task;
      }
    }
    return null;
  }

  void markDone(String title) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('TASKS.md not found at ${layout.tasksPath}');
    }
    final parsed = core_store.TaskStore(layout.tasksPath).readTasks();
    final target = _findByTitle(parsed, title);
    final ok = core_writer.TaskWriter(layout.tasksPath).markDone(target);
    if (!ok) {
      throw StateError('Task not found in TASKS.md: $title');
    }
  }

  void markBlocked(String title, String reason) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('TASKS.md not found at ${layout.tasksPath}');
    }
    final parsed = core_store.TaskStore(layout.tasksPath).readTasks();
    final target = _findByTitle(parsed, title);
    final ok = core_writer.TaskWriter(
      layout.tasksPath,
    ).markBlocked(target, reason: reason);
    if (!ok) {
      throw StateError('Task not found in TASKS.md: $title');
    }
  }

  core_task.Task _findByTitle(List<core_task.Task> tasks, String title) {
    for (final task in tasks) {
      if (task.title == title) {
        return task;
      }
    }
    throw StateError('Task not found in TASKS.md: $title');
  }

  Task _toLegacyTask(core_task.Task task) {
    final status = task.blocked
        ? TaskStatus.blocked
        : task.completion == core_task.TaskCompletion.done
        ? TaskStatus.done
        : TaskStatus.open;
    return Task(
      title: task.title,
      status: status,
      lineIndex: task.lineIndex,
      id: task.id,
      priority: _priorityLabel(task.priority),
      category: _categoryLabel(task.category),
    );
  }

  String? _priorityLabel(core_task.TaskPriority priority) {
    switch (priority) {
      case core_task.TaskPriority.p1:
        return 'P1';
      case core_task.TaskPriority.p2:
        return 'P2';
      case core_task.TaskPriority.p3:
        return 'P3';
    }
  }

  String? _categoryLabel(core_task.TaskCategory category) {
    switch (category) {
      case core_task.TaskCategory.core:
        return 'CORE';
      case core_task.TaskCategory.ui:
        return 'UI';
      case core_task.TaskCategory.security:
        return 'SEC';
      case core_task.TaskCategory.docs:
        return 'DOCS';
      case core_task.TaskCategory.architecture:
        return 'ARCH';
      case core_task.TaskCategory.qa:
        return 'QA';
      case core_task.TaskCategory.agent:
        return 'AGENT';
      case core_task.TaskCategory.refactor:
        return 'REF';
      case core_task.TaskCategory.unknown:
        return null;
    }
  }
}
