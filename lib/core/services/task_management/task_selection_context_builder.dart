// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../config/project_config.dart';
import '../../models/task.dart';
import '../../project_layout.dart';
import '../../selection/task_selection_context.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';

class TaskSelectionContextBuilder {
  TaskSelectionContextBuilder({DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final DateTime Function() _now;

  TaskSelectionContext build(String projectRoot, List<Task> tasks) {
    final config = ProjectConfig.load(projectRoot);
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final hasOpenP1StabilizationTask = TaskStore(
      layout.tasksPath,
    ).hasOpenP1StabilizationTask();
    final history = TaskSelectionHistory.fromRunLog(
      layout.runLogPath,
      tasks,
      maxEntries: config.autopilotFairnessWindow,
    );

    return TaskSelectionContext(
      mode: _parseMode(config.autopilotSelectionMode),
      fairnessWindow: _normalizeWindow(config.autopilotFairnessWindow),
      priorityWeights: {
        TaskPriority.p1: _normalizeWeight(config.autopilotPriorityWeightP1),
        TaskPriority.p2: _normalizeWeight(config.autopilotPriorityWeightP2),
        TaskPriority.p3: _normalizeWeight(config.autopilotPriorityWeightP3),
      },
      deferNonCriticalUiTasks: hasOpenP1StabilizationTask,
      includeBlocked: config.autopilotReactivateBlocked,
      includeFailed: config.autopilotReactivateFailed,
      blockedCooldown: config.autopilotBlockedCooldown,
      failedCooldown: config.autopilotFailedCooldown,
      retryCounts: state.taskRetryCounts,
      taskCooldownUntil: state.taskCooldownUntil,
      history: history,
      now: _now(),
    );
  }

  TaskSelectionMode _parseMode(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'fair' || normalized == 'fairness') {
      return TaskSelectionMode.fair;
    }
    if (normalized == 'strict_priority' || normalized == 'strict-priority') {
      return TaskSelectionMode.strictPriority;
    }
    return TaskSelectionMode.priority;
  }

  int _normalizeWindow(int raw) {
    if (raw < 1) {
      return 0;
    }
    return raw;
  }

  int _normalizeWeight(int raw) {
    if (raw < 1) {
      return 1;
    }
    return raw;
  }
}
