// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum BacklogTaskStatus { blocked, todo, working, done }

enum BacklogTaskPriority { p1, p2, p3 }

class BacklogSubtask {
  const BacklogSubtask({
    required this.id,
    required this.title,
    required this.done,
  });

  final String id;
  final String title;
  final bool done;

  BacklogSubtask copyWith({String? id, String? title, bool? done}) {
    return BacklogSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }
}

class BacklogTask {
  const BacklogTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.assignedAgent,
    required this.status,
    required this.subtasks,
  });

  final String id;
  final String title;
  final String description;
  final BacklogTaskPriority priority;
  final String assignedAgent;
  final BacklogTaskStatus status;
  final List<BacklogSubtask> subtasks;

  BacklogTask copyWith({
    String? id,
    String? title,
    String? description,
    BacklogTaskPriority? priority,
    String? assignedAgent,
    BacklogTaskStatus? status,
    List<BacklogSubtask>? subtasks,
  }) {
    return BacklogTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      assignedAgent: assignedAgent ?? this.assignedAgent,
      status: status ?? this.status,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

enum ChatMessageType { text, system, error, thinking }

enum ChatMessageStatus { sending, sent, error }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.author,
    required this.content,
    required this.fromAssistant,
    this.type = ChatMessageType.text,
    this.status = ChatMessageStatus.sent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String author;
  final String content;
  final bool fromAssistant;
  final ChatMessageType type;
  final ChatMessageStatus status;
  final DateTime timestamp;
}

class AutopilotStageSnapshot {
  const AutopilotStageSnapshot({
    required this.stage,
    required this.taskTitle,
    required this.subtaskTitle,
  });

  final String stage;
  final String taskTitle;
  final String subtaskTitle;
}
