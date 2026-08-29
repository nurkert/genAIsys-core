// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';
import '../models/workspace_models.dart';

/// Manages task list data, CRUD operations, and backlog helpers.
///
/// Extracted from [ProjectWorkspaceController] to isolate task-list
/// state changes so they don't trigger rebuilds in unrelated views.
class TaskController {
  TaskController({required String projectRootPath, required GenaisysApi api})
    : _projectRootPath = projectRootPath,
      _api = api;

  final String _projectRootPath;
  final GenaisysApi _api;

  AppTaskListDto _taskList = const AppTaskListDto(
    total: 0,
    tasks: <AppTaskDto>[],
  );
  AppTaskDto? _nextTask;

  /// Fires only when task list changes.
  final ValueNotifier<AppTaskListDto> taskListNotifier =
      ValueNotifier<AppTaskListDto>(
        const AppTaskListDto(total: 0, tasks: <AppTaskDto>[]),
      );

  AppTaskListDto get taskList => _taskList;
  AppTaskDto? get nextTask => _nextTask;

  List<BacklogTask> backlogTasks({String? activeTaskId}) {
    return _taskList.tasks
        .map(
          (AppTaskDto task) => _toBacklogTask(task, activeTaskId: activeTaskId),
        )
        .toList(growable: false);
  }

  List<BacklogTask> backlogTasksByStatus(
    BacklogTaskStatus status, {
    String? activeTaskId,
  }) {
    return backlogTasks(activeTaskId: activeTaskId)
        .where((BacklogTask task) => task.status == status)
        .toList(growable: false);
  }

  BacklogTask? backlogTaskById(String taskId, {String? activeTaskId}) {
    final String normalized = taskId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final BacklogTask task in backlogTasks(activeTaskId: activeTaskId)) {
      if (task.id == normalized) {
        return task;
      }
    }
    return null;
  }

  /// Applies pre-fetched results (e.g. from an isolate) without hitting the API.
  ///
  /// When [notify] is false the internal state is updated but
  /// [taskListNotifier] is **not** fired.  The caller is responsible for
  /// setting `taskListNotifier.value` later (used by the coordinator to
  /// batch all notifier updates into a single frame).
  void applyRefreshResult({
    required AppTaskListDto taskList,
    AppTaskDto? nextTask,
    bool notify = true,
  }) {
    _taskList = taskList;
    _nextTask = nextTask;
    if (notify) {
      taskListNotifier.value = taskList;
    }
  }

  /// Fetches task list and next task from the API. Returns error message or null.
  Future<String?> refresh() async {
    String? error;

    final AppResult<AppTaskListDto> tasksResult = await _api.listTasks(
      _projectRootPath,
      query: const TaskListQuery(sortByPriority: true),
    );
    if (tasksResult.ok && tasksResult.data != null) {
      _taskList = tasksResult.data!;
      taskListNotifier.value = tasksResult.data!;
    } else {
      error = tasksResult.error?.message ?? 'Failed to load tasks.';
    }

    final AppResult<AppTaskDto?> nextTaskResult = await _api.getNextTask(
      _projectRootPath,
    );
    if (nextTaskResult.ok) {
      _nextTask = nextTaskResult.data;
    } else {
      error ??= nextTaskResult.error?.message ?? 'Failed to load next task.';
    }

    return error;
  }

  Future<AppResult<TaskActivationDto>> activateNextTask({String? id}) {
    return _api.activateTask(_projectRootPath, id: id);
  }

  Future<AppResult<TaskDoneDto>> markActiveTaskDone() {
    return _api.markTaskDone(_projectRootPath);
  }

  Future<AppResult<TaskBlockedDto>> blockActiveTask({String? reason}) {
    return _api.blockTask(_projectRootPath, reason: reason);
  }

  Future<AppResult<TaskDeactivationDto>> deactivateActiveTask({
    bool keepReview = true,
  }) {
    return _api.deactivateTask(_projectRootPath, keepReview: keepReview);
  }

  Future<AppResult<TaskCreateDto>> createTask({
    required String title,
    required AppTaskPriority priority,
    AppTaskCategory category = AppTaskCategory.core,
    String section = 'Backlog',
  }) {
    return _api.createTask(
      _projectRootPath,
      title: title,
      priority: priority,
      category: category,
      section: section,
    );
  }

  Future<AppResult<TaskPriorityUpdateDto>> updateTaskPriority({
    required String taskId,
    required AppTaskPriority priority,
  }) {
    return _api.updateTaskPriority(
      _projectRootPath,
      id: taskId,
      priority: priority,
    );
  }

  Future<AppResult<TaskRefinementDto>> refineTask({
    required String title,
    bool overwrite = false,
  }) {
    return _api.refineTask(
      _projectRootPath,
      title: title,
      overwrite: overwrite,
    );
  }

  Future<AppResult<TaskMoveSectionDto>> moveTaskSection({
    required String taskId,
    required String section,
  }) {
    return _api.moveTaskSection(_projectRootPath, id: taskId, section: section);
  }

  Future<AppResult<TaskDeleteDto>> deleteTask({required String taskId}) {
    return _api.deleteTask(_projectRootPath, id: taskId);
  }

  void dispose() {
    taskListNotifier.dispose();
  }

  // ---- Private helpers ----

  BacklogTask _toBacklogTask(AppTaskDto task, {required String? activeTaskId}) {
    final bool isActive = activeTaskId != null && activeTaskId == task.id;
    final BacklogTaskStatus status = switch (task.status) {
      AppTaskStatus.done => BacklogTaskStatus.done,
      AppTaskStatus.blocked => BacklogTaskStatus.blocked,
      AppTaskStatus.open =>
        isActive ? BacklogTaskStatus.working : BacklogTaskStatus.todo,
    };

    return BacklogTask(
      id: task.id,
      title: task.title,
      description: 'Section: ${task.section} | Category: ${task.category}',
      priority: _toBacklogPriority(task.priority),
      assignedAgent: _agentForCategory(task.category),
      status: status,
      subtasks: const <BacklogSubtask>[],
    );
  }

  static BacklogTaskPriority _toBacklogPriority(String rawPriority) {
    switch (rawPriority.trim().toLowerCase()) {
      case 'p1':
        return BacklogTaskPriority.p1;
      case 'p2':
        return BacklogTaskPriority.p2;
      case 'p3':
        return BacklogTaskPriority.p3;
      default:
        return BacklogTaskPriority.p2;
    }
  }

  static String _agentForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'ui':
      case 'core':
      case 'refactor':
        return 'Codex';
      case 'docs':
      case 'architecture':
        return 'Gemini';
      case 'security':
      case 'qa':
        return 'Reviewer';
      case 'agent':
        return 'Codex';
      default:
        return 'Codex';
    }
  }
}
