// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/task.dart';
import '../../project_layout.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';

class ActiveTaskResolver {
  Task? resolve(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    if (!File(layout.tasksPath).existsSync()) {
      return null;
    }
    if (!File(layout.statePath).existsSync()) {
      return null;
    }
    final tasks = TaskStore(layout.tasksPath).readTasks();
    if (tasks.isEmpty) {
      return null;
    }

    final state = StateStore(layout.statePath).read();
    final activeId = state.activeTaskId?.trim();
    final activeTitle = state.activeTaskTitle?.trim();

    if (activeId != null && activeId.isNotEmpty) {
      final match = tasks.where((task) => task.id == activeId).toList();
      if (match.isNotEmpty) {
        return match.first;
      }
    }

    if (activeTitle != null && activeTitle.isNotEmpty) {
      final normalized = activeTitle.toLowerCase();
      final match = tasks
          .where((task) => task.title.trim().toLowerCase() == normalized)
          .toList();
      if (match.isNotEmpty) {
        return match.first;
      }
    }

    return null;
  }
}
