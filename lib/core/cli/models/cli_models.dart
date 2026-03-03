// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../models/workflow_stage.dart';

class CliErrorResponse {
  CliErrorResponse({required this.code, required this.message});

  final String code;
  final String message;

  static CliErrorResponse? tryParse(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString().trim();
    final message = (json['error'] ?? '').toString().trim();
    if (code.isEmpty || message.isEmpty) {
      return null;
    }
    return CliErrorResponse(code: code, message: message);
  }
}

class CliStatusSnapshot {
  CliStatusSnapshot({
    required this.projectRoot,
    required this.tasksTotal,
    required this.tasksOpen,
    required this.tasksBlocked,
    required this.tasksDone,
    required this.activeTask,
    required this.activeTaskId,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
    required this.workflowStage,
    required this.cycleCount,
    required this.lastUpdated,
  });

  final String projectRoot;
  final int tasksTotal;
  final int tasksOpen;
  final int tasksBlocked;
  final int tasksDone;
  final String activeTask;
  final String activeTaskId;
  final String reviewStatus;
  final String reviewUpdatedAt;
  final WorkflowStage workflowStage;
  final int cycleCount;
  final String lastUpdated;

  factory CliStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return CliStatusSnapshot(
      projectRoot: (json['project_root'] ?? '').toString(),
      tasksTotal: _toInt(json['tasks_total']),
      tasksOpen: _toInt(json['tasks_open']),
      tasksBlocked: _toInt(json['tasks_blocked']),
      tasksDone: _toInt(json['tasks_done']),
      activeTask: (json['active_task'] ?? '').toString(),
      activeTaskId: (json['active_task_id'] ?? '').toString(),
      reviewStatus: (json['review_status'] ?? '').toString(),
      reviewUpdatedAt: (json['review_updated_at'] ?? '').toString(),
      workflowStage: parseWorkflowStage(json['workflow_stage']?.toString()),
      cycleCount: _toInt(json['cycle_count']),
      lastUpdated: (json['last_updated'] ?? '').toString(),
    );
  }
}

class CliInitResponse {
  CliInitResponse({required this.initialized, required this.genaisysDir});

  final bool initialized;
  final String genaisysDir;

  factory CliInitResponse.fromJson(Map<String, dynamic> json) {
    return CliInitResponse(
      initialized: json['initialized'] == true,
      genaisysDir: (json['genaisys_dir'] ?? '').toString(),
    );
  }
}

class CliSpecInitResponse {
  CliSpecInitResponse({required this.created, required this.path});

  final bool created;
  final String path;

  factory CliSpecInitResponse.fromJson(Map<String, dynamic> json) {
    return CliSpecInitResponse(
      created: json['created'] == true,
      path: (json['path'] ?? '').toString(),
    );
  }
}

class CliPlanInitResponse {
  CliPlanInitResponse({required this.created, required this.path});

  final bool created;
  final String path;

  factory CliPlanInitResponse.fromJson(Map<String, dynamic> json) {
    return CliPlanInitResponse(
      created: json['created'] == true,
      path: (json['path'] ?? '').toString(),
    );
  }
}

class CliSubtasksInitResponse {
  CliSubtasksInitResponse({required this.created, required this.path});

  final bool created;
  final String path;

  factory CliSubtasksInitResponse.fromJson(Map<String, dynamic> json) {
    return CliSubtasksInitResponse(
      created: json['created'] == true,
      path: (json['path'] ?? '').toString(),
    );
  }
}

class CliTasksResponse {
  CliTasksResponse({required this.tasks});

  final List<CliTaskItem> tasks;

  factory CliTasksResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tasks'];
    if (raw is List) {
      return CliTasksResponse(
        tasks: raw
            .whereType<Map>()
            .map((item) => CliTaskItem.fromJson(item.cast<String, dynamic>()))
            .toList(),
      );
    }
    return CliTasksResponse(tasks: const []);
  }
}

enum CliTaskStatus { open, done, blocked }

class CliTaskItem {
  CliTaskItem({
    required this.id,
    required this.title,
    required this.section,
    required this.priority,
    required this.category,
    required this.status,
  });

  final String id;
  final String title;
  final String section;
  final String priority;
  final String category;
  final CliTaskStatus status;

  factory CliTaskItem.fromJson(Map<String, dynamic> json) {
    return CliTaskItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      status: _parseTaskStatus(json['status']?.toString()),
    );
  }
}

class CliReviewStatus {
  CliReviewStatus({required this.status, required this.updatedAt});

  final String status;
  final String updatedAt;

  factory CliReviewStatus.fromJson(Map<String, dynamic> json) {
    return CliReviewStatus(
      status: (json['review_status'] ?? '').toString(),
      updatedAt: (json['review_updated_at'] ?? '').toString(),
    );
  }
}

class CliActivateResponse {
  CliActivateResponse({required this.activated, required this.task});

  final bool activated;
  final CliTaskItem? task;

  factory CliActivateResponse.fromJson(Map<String, dynamic> json) {
    final rawTask = json['task'];
    return CliActivateResponse(
      activated: json['activated'] == true,
      task: rawTask is Map
          ? CliTaskItem.fromJson(rawTask.cast<String, dynamic>())
          : null,
    );
  }
}

class CliDeactivateResponse {
  CliDeactivateResponse({
    required this.deactivated,
    required this.keepReview,
    required this.activeTask,
    required this.activeTaskId,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
  });

  final bool deactivated;
  final bool keepReview;
  final String activeTask;
  final String activeTaskId;
  final String reviewStatus;
  final String reviewUpdatedAt;

  factory CliDeactivateResponse.fromJson(Map<String, dynamic> json) {
    return CliDeactivateResponse(
      deactivated: json['deactivated'] == true,
      keepReview: json['keep_review'] == true,
      activeTask: (json['active_task'] ?? '').toString(),
      activeTaskId: (json['active_task_id'] ?? '').toString(),
      reviewStatus: (json['review_status'] ?? '').toString(),
      reviewUpdatedAt: (json['review_updated_at'] ?? '').toString(),
    );
  }
}

class CliDoneResponse {
  CliDoneResponse({required this.done, required this.taskTitle});

  final bool done;
  final String taskTitle;

  factory CliDoneResponse.fromJson(Map<String, dynamic> json) {
    return CliDoneResponse(
      done: json['done'] == true,
      taskTitle: (json['task_title'] ?? '').toString(),
    );
  }
}

class CliBlockResponse {
  CliBlockResponse({
    required this.blocked,
    required this.taskTitle,
    required this.reason,
  });

  final bool blocked;
  final String taskTitle;
  final String? reason;

  factory CliBlockResponse.fromJson(Map<String, dynamic> json) {
    final rawReason = json['reason'];
    return CliBlockResponse(
      blocked: json['blocked'] == true,
      taskTitle: (json['task_title'] ?? '').toString(),
      reason: rawReason?.toString(),
    );
  }
}

class CliCycleResponse {
  CliCycleResponse({required this.cycleUpdated, required this.cycleCount});

  final bool cycleUpdated;
  final int cycleCount;

  factory CliCycleResponse.fromJson(Map<String, dynamic> json) {
    return CliCycleResponse(
      cycleUpdated: json['cycle_updated'] == true,
      cycleCount: _toInt(json['cycle_count']),
    );
  }
}

class CliCycleRunResponse {
  CliCycleRunResponse({
    required this.taskCycleCompleted,
    required this.reviewRecorded,
    required this.reviewDecision,
    required this.codingOk,
  });

  final bool taskCycleCompleted;
  final bool reviewRecorded;
  final String? reviewDecision;
  final bool codingOk;

  factory CliCycleRunResponse.fromJson(Map<String, dynamic> json) {
    final rawReviewDecision = json['review_decision'];
    return CliCycleRunResponse(
      taskCycleCompleted: json['task_cycle_completed'] == true,
      reviewRecorded: json['review_recorded'] == true,
      reviewDecision: rawReviewDecision?.toString(),
      codingOk: json['coding_ok'] == true,
    );
  }
}

class CliReviewDecisionResponse {
  CliReviewDecisionResponse({
    required this.reviewRecorded,
    required this.decision,
    required this.taskTitle,
    required this.note,
  });

  final bool reviewRecorded;
  final String decision;
  final String taskTitle;
  final String? note;

  factory CliReviewDecisionResponse.fromJson(Map<String, dynamic> json) {
    final rawNote = json['note'];
    return CliReviewDecisionResponse(
      reviewRecorded: json['review_recorded'] == true,
      decision: (json['decision'] ?? '').toString(),
      taskTitle: (json['task_title'] ?? '').toString(),
      note: rawNote?.toString(),
    );
  }
}

class CliReviewClearResponse {
  CliReviewClearResponse({
    required this.reviewCleared,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
    required this.note,
  });

  final bool reviewCleared;
  final String reviewStatus;
  final String reviewUpdatedAt;
  final String? note;

  factory CliReviewClearResponse.fromJson(Map<String, dynamic> json) {
    final rawNote = json['note'];
    return CliReviewClearResponse(
      reviewCleared: json['review_cleared'] == true,
      reviewStatus: (json['review_status'] ?? '').toString(),
      reviewUpdatedAt: (json['review_updated_at'] ?? '').toString(),
      note: rawNote?.toString(),
    );
  }
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

CliTaskStatus _parseTaskStatus(String? value) {
  final normalized = value?.trim().toLowerCase();
  for (final status in CliTaskStatus.values) {
    if (status.name == normalized) {
      return status;
    }
  }
  return CliTaskStatus.open;
}
