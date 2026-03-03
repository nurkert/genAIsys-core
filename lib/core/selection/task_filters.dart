// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';

class TaskFilters {
  const TaskFilters();

  List<Task> openOnly(List<Task> tasks) {
    return tasks
        .where((task) => task.completion == TaskCompletion.open)
        .toList();
  }

  List<Task> doneOnly(List<Task> tasks) {
    return tasks
        .where((task) => task.completion == TaskCompletion.done)
        .toList();
  }

  List<Task> blockedOnly(List<Task> tasks) {
    return tasks.where((task) => task.blocked).toList();
  }

  List<Task> sectionOnly(List<Task> tasks, String section) {
    final target = section.trim().toLowerCase();
    return tasks
        .where((task) => task.section.trim().toLowerCase() == target)
        .toList();
  }
}
