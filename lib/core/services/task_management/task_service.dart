// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/task.dart';
import '../../project_layout.dart';
import '../../selection/task_filters.dart';
import '../../selection/task_selector.dart';
import '../../selection/task_sorter.dart';
import 'task_selection_context_builder.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';

class TaskListRequest {
  TaskListRequest({
    this.openOnly = false,
    this.doneOnly = false,
    this.blockedOnly = false,
    this.activeOnly = false,
    this.sectionFilter,
    this.sortByPriority = false,
  });

  final bool openOnly;
  final bool doneOnly;
  final bool blockedOnly;
  final bool activeOnly;
  final String? sectionFilter;
  final bool sortByPriority;
}

class TaskListResult {
  TaskListResult({required this.total, required this.visible});

  final int total;
  final List<Task> visible;
}

class TaskService {
  TaskListResult listTasks(String projectRoot, TaskListRequest request) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);
    final tasks = TaskStore(layout.tasksPath).readTasks();

    List<Task> baseTasks = tasks;
    if (request.activeOnly) {
      final state = StateStore(layout.statePath).read();
      final activeId = state.activeTaskId;
      final activeTitle = state.activeTaskTitle;
      if ((activeId == null || activeId.trim().isEmpty) &&
          (activeTitle == null || activeTitle.trim().isEmpty)) {
        throw StateError('No active task set. Use: activate');
      }
      Task? activeTask;
      if (activeId != null && activeId.trim().isNotEmpty) {
        activeTask = tasks.firstWhere(
          (task) => task.id == activeId,
          orElse: () => Task(
            title: activeTitle ?? '',
            priority: TaskPriority.p3,
            category: TaskCategory.unknown,
            completion: TaskCompletion.open,
            blocked: false,
            section: 'Backlog',
            lineIndex: -1,
          ),
        );
        if (activeTask.lineIndex < 0) {
          activeTask = null;
        }
      }
      if (activeTask == null &&
          activeTitle != null &&
          activeTitle.trim().isNotEmpty) {
        final normalized = activeTitle.trim().toLowerCase();
        activeTask = tasks.firstWhere(
          (task) => task.title.trim().toLowerCase() == normalized,
          orElse: () => Task(
            title: activeTitle,
            priority: TaskPriority.p3,
            category: TaskCategory.unknown,
            completion: TaskCompletion.open,
            blocked: false,
            section: 'Backlog',
            lineIndex: -1,
          ),
        );
        if (activeTask.lineIndex < 0) {
          activeTask = null;
        }
      }
      if (activeTask == null) {
        throw StateError('Active task not found in TASKS.md');
      }
      baseTasks = [activeTask];
    }

    final filters = const TaskFilters();
    List<Task> filtered = baseTasks;
    if (request.blockedOnly) {
      filtered = filters.blockedOnly(baseTasks);
    } else if (request.openOnly && request.doneOnly) {
      filtered = baseTasks;
    } else if (request.openOnly) {
      filtered = filters.openOnly(baseTasks);
    } else if (request.doneOnly) {
      filtered = filters.doneOnly(baseTasks);
    }

    final sectionFilter = request.sectionFilter;
    if (sectionFilter != null && sectionFilter.trim().isNotEmpty) {
      filtered = filters.sectionOnly(filtered, sectionFilter);
    }

    final visible = request.sortByPriority
        ? TaskSorter().byPriorityThenLine(filtered)
        : filtered;

    return TaskListResult(total: tasks.length, visible: visible);
  }

  Task? nextTask(String projectRoot, {String? sectionFilter}) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final filtered = sectionFilter == null || sectionFilter.trim().isEmpty
        ? tasks
        : const TaskFilters().sectionOnly(tasks, sectionFilter);
    final context = TaskSelectionContextBuilder().build(projectRoot, filtered);
    return TaskSelector().nextOpenTask(filtered, context: context);
  }

  void _ensureTasksFile(ProjectLayout layout) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
  }
}
