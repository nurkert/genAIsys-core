// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../models/workspace_models.dart';

/// Default card height used as fallback when measurement is unavailable.
const double kDefaultCardHeight = 112;

// ---------------------------------------------------------------------------
// BoardLocalState: immutable, authoritative view of task column assignments
// ---------------------------------------------------------------------------

/// Immutable snapshot of the board's local understanding of task assignments.
///
/// This is the **sole source of rendering truth**. Controller data is merged
/// into this state through [mergeWithController], never overwrites it.
@immutable
class BoardLocalState {
  const BoardLocalState({
    required this.tasksByStatus,
    this.inflight = const <String>{},
  });

  /// Creates an empty state with no tasks in any column.
  static const BoardLocalState empty = BoardLocalState(
    tasksByStatus: <BacklogTaskStatus, List<String>>{
      BacklogTaskStatus.blocked: <String>[],
      BacklogTaskStatus.todo: <String>[],
      BacklogTaskStatus.working: <String>[],
      BacklogTaskStatus.done: <String>[],
    },
  );

  /// Authoritative assignment of task IDs to columns, in display order.
  /// Every known task ID appears in exactly one column.
  final Map<BacklogTaskStatus, List<String>> tasksByStatus;

  /// Task IDs currently in-flight (cross-column API call pending). These are
  /// locked to their current column and cannot be moved by controller data.
  final Set<String> inflight;

  /// Returns a new state with [taskId] moved to [destination] at
  /// [insertionIndex], optionally marked as in-flight.
  BoardLocalState withTaskMoved({
    required String taskId,
    required BacklogTaskStatus destination,
    required int insertionIndex,
    required bool markInflight,
  }) {
    final Map<BacklogTaskStatus, List<String>> next =
        <BacklogTaskStatus, List<String>>{};
    for (final BacklogTaskStatus status in BacklogTaskStatus.values) {
      next[status] = List<String>.from(
        tasksByStatus[status] ?? const <String>[],
      )..remove(taskId);
    }
    final List<String> destIds = next[destination]!;
    destIds.insert(insertionIndex.clamp(0, destIds.length), taskId);

    return BoardLocalState(
      tasksByStatus: next,
      inflight: markInflight ? (<String>{...inflight, taskId}) : inflight,
    );
  }

  /// Returns a new state with a same-column reorder applied.
  BoardLocalState withSameColumnReorder({
    required String taskId,
    required BacklogTaskStatus column,
    required int insertionIndex,
  }) {
    final List<String> ids = List<String>.from(
      tasksByStatus[column] ?? const <String>[],
    );
    final int sourceIndex = ids.indexOf(taskId);
    if (sourceIndex < 0) return this;

    ids.remove(taskId);
    int normalizedIndex = insertionIndex;
    if (insertionIndex > sourceIndex) {
      normalizedIndex = insertionIndex - 1;
    }
    ids.insert(normalizedIndex.clamp(0, ids.length), taskId);

    final Map<BacklogTaskStatus, List<String>> next =
        Map<BacklogTaskStatus, List<String>>.from(tasksByStatus);
    next[column] = ids;
    return BoardLocalState(tasksByStatus: next, inflight: inflight);
  }

  /// Returns a new state with [taskId] removed from the in-flight set.
  BoardLocalState withInflightResolved(String taskId) {
    if (!inflight.contains(taskId)) return this;
    return BoardLocalState(
      tasksByStatus: tasksByStatus,
      inflight: Set<String>.from(inflight)..remove(taskId),
    );
  }

  /// Merges incoming controller data into this local state.
  ///
  /// Rules:
  /// 1. In-flight tasks stay in their local column unconditionally.
  /// 2. Non-in-flight tasks follow the controller's column assignment.
  /// 3. Tasks the controller no longer reports are removed (unless in-flight).
  /// 4. New tasks from the controller are appended at the end of their column.
  /// 5. Local ordering is preserved for retained tasks.
  BoardLocalState mergeWithController(
    Map<BacklogTaskStatus, List<BacklogTask>> controllerTasks,
  ) {
    // Build controller's view: taskId → assigned status.
    final Map<String, BacklogTaskStatus> controllerAssignment =
        <String, BacklogTaskStatus>{};
    for (final BacklogTaskStatus status in BacklogTaskStatus.values) {
      for (final BacklogTask task in controllerTasks[status]!) {
        controllerAssignment[task.id] = status;
      }
    }

    final Map<BacklogTaskStatus, List<String>> merged =
        <BacklogTaskStatus, List<String>>{};

    for (final BacklogTaskStatus status in BacklogTaskStatus.values) {
      final List<String> localOrder = tasksByStatus[status] ?? const <String>[];
      final Set<String> controllerIdsForColumn = controllerTasks[status]!
          .map((BacklogTask t) => t.id)
          .toSet();

      final List<String> retained = <String>[];

      for (final String id in localOrder) {
        if (inflight.contains(id)) {
          // Rule 1: In-flight tasks stay put unconditionally, as long as
          // the controller still knows about the task (or it's in-flight
          // anyway, meaning the API hasn't responded yet).
          if (controllerAssignment.containsKey(id) || inflight.contains(id)) {
            retained.add(id);
          }
          continue;
        }

        // Non-in-flight task.
        if (!controllerAssignment.containsKey(id)) {
          // Rule 3: Task was deleted externally. Remove.
          continue;
        }
        if (controllerAssignment[id] == status) {
          // Rule 2 (same column): Keep at its local position.
          retained.add(id);
        }
        // Rule 2 (different column): Don't add here; the task will appear
        // when we process the column the controller assigns it to.
      }

      // Rule 4: Append new tasks from the controller for this column.
      final Set<String> retainedSet = retained.toSet();
      for (final String id in controllerIdsForColumn) {
        if (!retainedSet.contains(id) && !inflight.contains(id)) {
          retained.add(id);
        }
      }

      merged[status] = retained;
    }

    return BoardLocalState(tasksByStatus: merged, inflight: inflight);
  }
}

// ---------------------------------------------------------------------------
// Drag data classes
// ---------------------------------------------------------------------------

class BacklogActiveDrag {
  BacklogActiveDrag({
    required this.taskId,
    required this.sourceStatus,
    required this.height,
  });

  final String taskId;
  final BacklogTaskStatus sourceStatus;
  final double height;

  /// Pointer offset relative to the card's top-left at drag start.
  /// Used by all columns to resolve the true pointer position from
  /// [DragTargetDetails.offset] (which is the feedback widget origin).
  Offset? anchorOffset;

  @override
  bool operator ==(Object other) {
    return other is BacklogActiveDrag &&
        other.taskId == taskId &&
        other.sourceStatus == sourceStatus &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(taskId, sourceStatus, height);
}

@immutable
class BacklogDragEnd {
  const BacklogDragEnd({
    required this.taskId,
    required this.sourceStatus,
    required this.wasAccepted,
  });

  final String taskId;
  final BacklogTaskStatus sourceStatus;
  final bool wasAccepted;
}

@immutable
class BacklogDragPayload {
  const BacklogDragPayload({required this.taskId, required this.sourceStatus});

  final String taskId;
  final BacklogTaskStatus sourceStatus;
}
