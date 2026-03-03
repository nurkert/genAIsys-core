// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';
import '../models/task_priority.dart';
import '../policy/interaction_parity_policy.dart';
import 'task_selection_context.dart';

class TaskSelector {
  Task? nextOpenTask(List<Task> tasks, {TaskSelectionContext? context}) {
    final eligible = context == null
        ? tasks
              .where(
                (task) =>
                    task.completion == TaskCompletion.open &&
                    !task.blocked &&
                    InteractionParityPolicy.evaluate(task, tasks).ok,
              )
              .toList()
        : tasks.where((task) => _isEligible(task, context, tasks)).toList();

    if (eligible.isEmpty) {
      return null;
    }

    if (context == null || context.mode == TaskSelectionMode.priority) {
      return _selectByPriority(eligible, context);
    }

    if (context.mode == TaskSelectionMode.strictPriority) {
      return _selectByStrictPriority(eligible, tasks);
    }

    return _selectByFairness(eligible, context);
  }

  Task _selectByPriority(List<Task> tasks, TaskSelectionContext? context) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      final priorityCompare = _priorityRank(
        a.priority,
      ).compareTo(_priorityRank(b.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final activationCompare = _compareLastActivation(a, b, context);
      if (activationCompare != 0) {
        return activationCompare;
      }
      return a.lineIndex.compareTo(b.lineIndex);
    });
    return sorted.first;
  }

  /// Strict priority: always picks from the highest available priority level,
  /// then selects by line order (proxy for phase ordering in TASKS.md).
  ///
  /// Priority inversion guard: if any open, non-blocked P1 task exists in
  /// [allTasks] (the unfiltered list), refuse to select a P2+ task even if
  /// the P1 tasks are temporarily ineligible (e.g. cooling down after
  /// failure). This prevents the autopilot from working on lower-priority
  /// tasks while critical P1 work remains outstanding.
  Task? _selectByStrictPriority(List<Task> eligible, List<Task> allTasks) {
    // Check whether any P1 task is open and non-blocked in the full list.
    final hasOpenNonBlockedP1 = allTasks.any(
      (t) =>
          t.priority == TaskPriority.p1 &&
          t.completion == TaskCompletion.open &&
          !t.blocked,
    );

    final candidates = hasOpenNonBlockedP1
        ? eligible.where((t) => t.priority == TaskPriority.p1).toList()
        : eligible;

    if (candidates.isEmpty) {
      return null;
    }

    final sorted = List<Task>.from(candidates);
    sorted.sort((a, b) {
      final priorityCompare = _priorityRank(
        a.priority,
      ).compareTo(_priorityRank(b.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.lineIndex.compareTo(b.lineIndex);
    });
    return sorted.first;
  }

  Task _selectByFairness(List<Task> tasks, TaskSelectionContext context) {
    final groups = <TaskPriority, List<Task>>{
      TaskPriority.p1: [],
      TaskPriority.p2: [],
      TaskPriority.p3: [],
    };

    for (final task in tasks) {
      groups[task.priority]?.add(task);
    }

    final counts = _priorityCounts(
      context.history.priorityHistory,
      context.fairnessWindow,
    );

    TaskPriority? chosen;
    double? bestScore;
    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.isEmpty) {
        continue;
      }
      final weight = _normalizeWeight(context.priorityWeights[entry.key]);
      final count = counts[entry.key] ?? 0;
      final score = count / weight;
      if (bestScore == null ||
          score < bestScore ||
          (score == bestScore &&
              _priorityRank(entry.key) < _priorityRank(chosen!))) {
        bestScore = score;
        chosen = entry.key;
      }
    }

    if (chosen == null) {
      return _selectByPriority(tasks, context);
    }

    return _selectByPriority(groups[chosen]!, context);
  }

  bool _isEligible(
    Task task,
    TaskSelectionContext context,
    List<Task> allTasks,
  ) {
    if (task.completion != TaskCompletion.open) {
      return false;
    }

    if (!InteractionParityPolicy.evaluate(task, allTasks).ok) {
      return false;
    }

    if (context.deferNonCriticalUiTasks &&
        task.category == TaskCategory.ui &&
        task.priority != TaskPriority.p1) {
      return false;
    }

    if (task.blocked) {
      if (!context.includeBlocked) {
        return false;
      }
      if (!task.blockedByAutoCycle) {
        return false;
      }
      if (_isCoolingDown(task, context.blockedCooldown, context)) {
        return false;
      }
    }

    final failed = _isFailed(task, context.retryCounts);
    if (failed && !context.includeFailed) {
      return false;
    }
    if (failed && _isCoolingDown(task, context.failedCooldown, context)) {
      return false;
    }

    return true;
  }

  bool _isFailed(Task task, Map<String, int> retryCounts) {
    final byId = retryCounts['id:${task.id}'];
    if (byId != null && byId > 0) {
      return true;
    }
    final byTitle = retryCounts['title:${_titleKey(task.title)}'];
    return byTitle != null && byTitle > 0;
  }

  bool _isCoolingDown(
    Task task,
    Duration cooldown,
    TaskSelectionContext context,
  ) {
    if (cooldown.inSeconds < 1) {
      return false;
    }
    final last = _lastActivation(task, context);
    if (last == null) {
      return false;
    }
    return context.now.difference(last) < cooldown;
  }

  DateTime? _lastActivation(Task task, TaskSelectionContext context) {
    return context.history.lastActivationByTaskId[task.id] ??
        context.history.lastActivationByTitle[_titleKey(task.title)];
  }

  int _compareLastActivation(Task a, Task b, TaskSelectionContext? context) {
    if (context == null) {
      return 0;
    }
    final lastA = _lastActivation(a, context);
    final lastB = _lastActivation(b, context);
    if (lastA == null && lastB == null) {
      return 0;
    }
    if (lastA == null) {
      return -1;
    }
    if (lastB == null) {
      return 1;
    }
    return lastA.compareTo(lastB);
  }

  Map<TaskPriority, int> _priorityCounts(
    List<TaskPriority> history,
    int window,
  ) {
    final counts = <TaskPriority, int>{
      TaskPriority.p1: 0,
      TaskPriority.p2: 0,
      TaskPriority.p3: 0,
    };
    final limit = window < 1 ? history.length : window;
    for (var i = 0; i < history.length && i < limit; i += 1) {
      final priority = history[i];
      counts[priority] = (counts[priority] ?? 0) + 1;
    }
    return counts;
  }

  int _priorityRank(TaskPriority p) => priorityRank(p);

  int _normalizeWeight(int? raw) {
    if (raw == null || raw < 1) {
      return 1;
    }
    return raw;
  }

  String _titleKey(String raw) {
    return raw.trim().toLowerCase();
  }
}
