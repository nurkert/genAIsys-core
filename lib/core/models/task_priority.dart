// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'task.dart';

/// Converts a [TaskPriority] to its numeric rank (P1=1, P2=2, P3=3).
int priorityRank(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.p1:
      return 1;
    case TaskPriority.p2:
      return 2;
    case TaskPriority.p3:
      return 3;
  }
}
