// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'task_dto.dart';

class ProjectInitializationDto {
  const ProjectInitializationDto({
    required this.initialized,
    required this.genaisysDir,
  });

  final bool initialized;
  final String genaisysDir;
}

class SpecInitializationDto {
  const SpecInitializationDto({required this.created, required this.path});

  final bool created;
  final String path;
}

class TaskActivationDto {
  const TaskActivationDto({required this.activated, required this.task});

  final bool activated;
  final AppTaskDto? task;
}

class TaskDeactivationDto {
  const TaskDeactivationDto({
    required this.deactivated,
    required this.keepReview,
    required this.activeTaskTitle,
    required this.activeTaskId,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
  });

  final bool deactivated;
  final bool keepReview;
  final String? activeTaskTitle;
  final String? activeTaskId;
  final String? reviewStatus;
  final String? reviewUpdatedAt;
}

class ReviewDecisionDto {
  const ReviewDecisionDto({
    required this.reviewRecorded,
    required this.decision,
    required this.taskTitle,
    required this.note,
  });

  final bool reviewRecorded;
  final String decision;
  final String taskTitle;
  final String? note;
}

class ReviewClearDto {
  const ReviewClearDto({
    required this.reviewCleared,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
    required this.note,
  });

  final bool reviewCleared;
  final String reviewStatus;
  final String reviewUpdatedAt;
  final String? note;
}

class TaskDoneDto {
  const TaskDoneDto({required this.done, required this.taskTitle});

  final bool done;
  final String taskTitle;
}

class TaskBlockedDto {
  const TaskBlockedDto({
    required this.blocked,
    required this.taskTitle,
    required this.reason,
  });

  final bool blocked;
  final String taskTitle;
  final String? reason;
}

class CycleTickDto {
  const CycleTickDto({required this.cycleUpdated, required this.cycleCount});

  final bool cycleUpdated;
  final int cycleCount;
}

class TaskCycleExecutionDto {
  const TaskCycleExecutionDto({
    required this.taskCycleCompleted,
    required this.reviewRecorded,
    required this.reviewDecision,
    required this.codingOk,
  });

  final bool taskCycleCompleted;
  final bool reviewRecorded;
  final String? reviewDecision;
  final bool codingOk;
}

class TaskCreateDto {
  const TaskCreateDto({required this.created, required this.task});

  final bool created;
  final AppTaskDto task;
}

class TaskPriorityUpdateDto {
  const TaskPriorityUpdateDto({required this.updated, required this.task});

  final bool updated;
  final AppTaskDto task;
}

class TaskMoveSectionDto {
  const TaskMoveSectionDto({
    required this.moved,
    required this.task,
    required this.fromSection,
    required this.toSection,
  });

  final bool moved;
  final AppTaskDto task;
  final String fromSection;
  final String toSection;
}

class TaskDeleteDto {
  const TaskDeleteDto({
    required this.deleted,
    required this.taskTitle,
    required this.taskId,
  });

  final bool deleted;
  final String taskTitle;
  final String taskId;
}

class TaskRefinementArtifactDto {
  const TaskRefinementArtifactDto({
    required this.kind,
    required this.path,
    required this.wrote,
    required this.usedFallback,
  });

  final String kind;
  final String path;
  final bool wrote;
  final bool usedFallback;
}

class TaskRefinementDto {
  const TaskRefinementDto({
    required this.refined,
    required this.title,
    required this.usedFallback,
    required this.artifacts,
  });

  final bool refined;
  final String title;
  final bool usedFallback;
  final List<TaskRefinementArtifactDto> artifacts;
}
