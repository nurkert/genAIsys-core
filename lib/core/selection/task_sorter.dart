// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';
import '../models/task_priority.dart';

class TaskSorter {
  List<Task> byPriorityThenLine(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      final priorityCompare =
          priorityRank(a.priority).compareTo(priorityRank(b.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.lineIndex.compareTo(b.lineIndex);
    });
    return sorted;
  }
}
