// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum AppTaskStatus { open, done, blocked }

enum AppTaskPriority { p1, p2, p3 }

enum AppTaskCategory {
  core,
  ui,
  security,
  docs,
  architecture,
  qa,
  agent,
  refactor,
  unknown,
}

class AppTaskDto {
  const AppTaskDto({
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
  final AppTaskStatus status;
}

class AppTaskListDto {
  const AppTaskListDto({required this.total, required this.tasks});

  final int total;
  final List<AppTaskDto> tasks;
}

class TaskListQuery {
  const TaskListQuery({
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
