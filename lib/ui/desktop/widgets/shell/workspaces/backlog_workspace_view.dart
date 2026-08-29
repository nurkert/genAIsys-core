// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../core/app/app.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../models/workspace_models.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../dialogs/confirmation_dialog.dart';
import '../../shared/backlog_search_field.dart';
import 'backlog/backlog_board_state.dart';
import 'backlog/backlog_column.dart';
import 'workspace_header.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

class BacklogWorkspaceView extends StatefulWidget {
  const BacklogWorkspaceView({
    super.key,
    required this.controller,
    this.onCreateTaskRequested,
  });

  final ProjectWorkspaceController controller;
  final VoidCallback? onCreateTaskRequested;

  @override
  State<BacklogWorkspaceView> createState() => _BacklogWorkspaceViewState();
}

class _BacklogWorkspaceViewState extends State<BacklogWorkspaceView> {
  String? _selectedTaskId;
  String _searchQuery = '';

  String _priorityLabel(BacklogTaskPriority priority) {
    final strings = context.strings;
    switch (priority) {
      case BacklogTaskPriority.p1:
        return strings.backlogPriorityP1;
      case BacklogTaskPriority.p2:
        return strings.backlogPriorityP2;
      case BacklogTaskPriority.p3:
        return strings.backlogPriorityP3;
    }
  }

  List<BacklogTask> _filterTasks(List<BacklogTask> tasks) {
    if (_searchQuery.isEmpty) {
      return tasks;
    }
    final String needle = _searchQuery.toLowerCase();
    return tasks
        .where(
          (BacklogTask task) =>
              task.title.toLowerCase().contains(needle) ||
              task.description.toLowerCase().contains(needle) ||
              task.assignedAgent.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  Future<void> _handleTaskDeleted(String taskId) async {
    final strings = context.strings;
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: strings.backlogDeleteConfirmTitle,
      message: strings.backlogDeleteConfirmMessage,
      confirmLabel: strings.confirmAction,
      cancelLabel: strings.cancelAction,
      isDestructive: true,
      icon: PhosphorIconsRegular.trash,
    );
    if (confirmed != true) {
      return;
    }
    await widget.controller.deleteTask(taskId: taskId);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ValueListenableBuilder<AppTaskListDto>(
      valueListenable: widget.controller.taskListNotifier,
      builder: (BuildContext context, AppTaskListDto taskList, Widget? _) {
        final bool showLoadingSpinner =
            widget.controller.isLoading &&
            widget.controller.backlogTasks.isEmpty;

        final Widget board = _BacklogBoard(
          blockedTasks: _filterTasks(
            widget.controller.backlogTasksByStatus(BacklogTaskStatus.blocked),
          ),
          todoTasks: _filterTasks(
            widget.controller.backlogTasksByStatus(BacklogTaskStatus.todo),
          ),
          workingTasks: _filterTasks(
            widget.controller.backlogTasksByStatus(BacklogTaskStatus.working),
          ),
          doneTasks: _filterTasks(
            widget.controller.backlogTasksByStatus(BacklogTaskStatus.done),
          ),
          selectedTaskId: _selectedTaskId,
          onTaskSelected: (String taskId) {
            setState(() {
              _selectedTaskId = taskId;
            });
          },
          onTaskMoved:
              ({
                required String taskId,
                required BacklogTaskStatus destination,
              }) {
                return widget.controller.moveTaskBetweenColumns(
                  taskId: taskId,
                  destination: destination,
                );
              },
          onTaskDeleted: _handleTaskDeleted,
          priorityLabelBuilder: _priorityLabel,
          onCreateTaskRequested: widget.onCreateTaskRequested,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            WorkspaceHeader(
              title: strings.backlogTitle,
              subtitle: strings.backlogSubtitle,
              seed: 61,
            ),
            const SizedBox(height: UiChromeConfig.space12),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UiChromeConfig.space4,
              ),
              child: SizedBox(
                height: UiChromeConfig.sidebarItemHeight,
                child: BacklogSearchField(
                  placeholder: strings.backlogSearchPlaceholder,
                  value: _searchQuery,
                  onChanged: (String query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: UiChromeConfig.space10),
            Expanded(
              child: showLoadingSpinner
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : board,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Board: orchestrates columns and cross-column state
// ---------------------------------------------------------------------------

class _BacklogBoard extends StatefulWidget {
  const _BacklogBoard({
    required this.blockedTasks,
    required this.todoTasks,
    required this.workingTasks,
    required this.doneTasks,
    required this.selectedTaskId,
    required this.onTaskSelected,
    required this.onTaskMoved,
    required this.onTaskDeleted,
    required this.priorityLabelBuilder,
    this.onCreateTaskRequested,
  });

  final List<BacklogTask> blockedTasks;
  final List<BacklogTask> todoTasks;
  final List<BacklogTask> workingTasks;
  final List<BacklogTask> doneTasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final Future<void> Function({
    required String taskId,
    required BacklogTaskStatus destination,
  })
  onTaskMoved;
  final Future<void> Function(String taskId) onTaskDeleted;
  final String Function(BacklogTaskPriority priority) priorityLabelBuilder;
  final VoidCallback? onCreateTaskRequested;

  @override
  State<_BacklogBoard> createState() => _BacklogBoardState();
}

class _BacklogBoardState extends State<_BacklogBoard> {
  /// Single source of truth for task column assignments and ordering.
  /// Controller data is merged into this state, never overwrites it.
  BoardLocalState _localState = BoardLocalState.empty;

  BacklogActiveDrag? _activeDrag;

  @override
  void initState() {
    super.initState();
    _localState = _localState.mergeWithController(_controllerTasksByStatus());
  }

  @override
  void didUpdateWidget(covariant _BacklogBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localState = _localState.mergeWithController(_controllerTasksByStatus());
  }

  /// Collects controller-provided task lists into a status-keyed map.
  Map<BacklogTaskStatus, List<BacklogTask>> _controllerTasksByStatus() {
    return <BacklogTaskStatus, List<BacklogTask>>{
      BacklogTaskStatus.blocked: widget.blockedTasks,
      BacklogTaskStatus.todo: widget.todoTasks,
      BacklogTaskStatus.working: widget.workingTasks,
      BacklogTaskStatus.done: widget.doneTasks,
    };
  }

  /// Builds a lookup of all [BacklogTask] objects across all widget props.
  Map<String, BacklogTask> _buildTaskLookup() {
    final Map<String, BacklogTask> lookup = <String, BacklogTask>{};
    for (final BacklogTask t in widget.blockedTasks) {
      lookup[t.id] = t;
    }
    for (final BacklogTask t in widget.todoTasks) {
      lookup[t.id] = t;
    }
    for (final BacklogTask t in widget.workingTasks) {
      lookup[t.id] = t;
    }
    for (final BacklogTask t in widget.doneTasks) {
      lookup[t.id] = t;
    }
    return lookup;
  }

  /// Resolves a column's ordered task list from local state + widget data.
  List<BacklogTask> _resolveTaskList(
    BacklogTaskStatus status,
    Map<String, BacklogTask> allTasksById,
  ) {
    final List<String> orderedIds =
        _localState.tasksByStatus[status] ?? const <String>[];
    final List<BacklogTask> result = <BacklogTask>[];
    for (final String id in orderedIds) {
      final BacklogTask? task = allTasksById[id];
      if (task != null) {
        result.add(task);
      }
    }
    return result;
  }

  Future<void> _handleTaskDrop({
    required BacklogDragPayload payload,
    required BacklogTaskStatus destination,
    required int insertionIndex,
  }) async {
    final bool isCrossColumn = payload.sourceStatus != destination;

    setState(() {
      if (isCrossColumn) {
        _localState = _localState.withTaskMoved(
          taskId: payload.taskId,
          destination: destination,
          insertionIndex: insertionIndex,
          markInflight: true,
        );
      } else {
        _localState = _localState.withSameColumnReorder(
          taskId: payload.taskId,
          column: destination,
          insertionIndex: insertionIndex,
        );
      }
    });

    if (!isCrossColumn) {
      return;
    }

    try {
      await widget.onTaskMoved(
        taskId: payload.taskId,
        destination: destination,
      );
    } finally {
      if (mounted) {
        setState(() {
          _localState = _localState.withInflightResolved(payload.taskId);
          // Do NOT merge with controller data here — widget props may still be
          // stale (controller notified, but the framework hasn't delivered the
          // updated widget yet). The next didUpdateWidget will merge with
          // fresh data. The task stays at its local position in the meantime.
        });
      }
    }
  }

  void _handleTaskDragStarted(BacklogActiveDrag drag) {
    if (_activeDrag == drag) {
      return;
    }
    setState(() {
      _activeDrag = drag;
    });
  }

  void _handleTaskDragEnded(BacklogDragEnd details) {
    if (_activeDrag == null) {
      return;
    }
    setState(() {
      _activeDrag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final Map<String, BacklogTask> allTasksById = _buildTaskLookup();
    final List<BacklogTask> blockedTasks = _resolveTaskList(
      BacklogTaskStatus.blocked,
      allTasksById,
    );
    final List<BacklogTask> todoTasks = _resolveTaskList(
      BacklogTaskStatus.todo,
      allTasksById,
    );
    final List<BacklogTask> workingTasks = _resolveTaskList(
      BacklogTaskStatus.working,
      allTasksById,
    );
    final List<BacklogTask> doneTasks = _resolveTaskList(
      BacklogTaskStatus.done,
      allTasksById,
    );

    final Widget board = Row(
      children: <Widget>[
        Expanded(
          child: BacklogColumn(
            title: strings.backlogBlockedColumn,
            status: BacklogTaskStatus.blocked,
            tasks: blockedTasks,
            selectedTaskId: widget.selectedTaskId,
            onTaskSelected: widget.onTaskSelected,
            onTaskDropped: _handleTaskDrop,
            onTaskDeleted: widget.onTaskDeleted,
            priorityLabelBuilder: widget.priorityLabelBuilder,
            activeDrag: _activeDrag,
            onTaskDragStarted: _handleTaskDragStarted,
            onTaskDragEnded: _handleTaskDragEnded,
            onCreateTaskRequested: widget.onCreateTaskRequested,
          ),
        ),
        const SizedBox(width: UiChromeConfig.space10),
        Expanded(
          child: BacklogColumn(
            title: strings.backlogTodoColumn,
            status: BacklogTaskStatus.todo,
            tasks: todoTasks,
            selectedTaskId: widget.selectedTaskId,
            onTaskSelected: widget.onTaskSelected,
            onTaskDropped: _handleTaskDrop,
            onTaskDeleted: widget.onTaskDeleted,
            priorityLabelBuilder: widget.priorityLabelBuilder,
            activeDrag: _activeDrag,
            onTaskDragStarted: _handleTaskDragStarted,
            onTaskDragEnded: _handleTaskDragEnded,
            onCreateTaskRequested: widget.onCreateTaskRequested,
          ),
        ),
        const SizedBox(width: UiChromeConfig.space10),
        Expanded(
          child: BacklogColumn(
            title: strings.backlogWorkingColumn,
            status: BacklogTaskStatus.working,
            tasks: workingTasks,
            selectedTaskId: widget.selectedTaskId,
            onTaskSelected: widget.onTaskSelected,
            onTaskDropped: _handleTaskDrop,
            onTaskDeleted: widget.onTaskDeleted,
            priorityLabelBuilder: widget.priorityLabelBuilder,
            activeDrag: _activeDrag,
            onTaskDragStarted: _handleTaskDragStarted,
            onTaskDragEnded: _handleTaskDragEnded,
            onCreateTaskRequested: widget.onCreateTaskRequested,
          ),
        ),
        const SizedBox(width: UiChromeConfig.space10),
        Expanded(
          child: BacklogColumn(
            title: strings.backlogDoneColumn,
            status: BacklogTaskStatus.done,
            tasks: doneTasks,
            selectedTaskId: widget.selectedTaskId,
            onTaskSelected: widget.onTaskSelected,
            onTaskDropped: _handleTaskDrop,
            onTaskDeleted: widget.onTaskDeleted,
            priorityLabelBuilder: widget.priorityLabelBuilder,
            activeDrag: _activeDrag,
            onTaskDragStarted: _handleTaskDragStarted,
            onTaskDragEnded: _handleTaskDragEnded,
            onCreateTaskRequested: widget.onCreateTaskRequested,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double minColumnWidth = 228;
        final double minBoardWidth =
            (minColumnWidth * 4) + (UiChromeConfig.space10 * 3);

        if (constraints.maxWidth < minBoardWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minBoardWidth, child: board),
          );
        }
        return board;
      },
    );
  }
}
