// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../ids/task_slugger.dart';
import '../models/project_state.dart';
import '../models/task.dart';
import '../models/workflow_stage.dart';
import '../project_initializer.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import '../storage/task_store.dart';
import 'pid_liveness_service.dart';

class StateRepairReport {
  StateRepairReport({required this.changed, required this.actions});

  final bool changed;
  final List<String> actions;
}

class StateRepairService {
  StateRepairService({PidLivenessService? pidLivenessService})
      : _pidLivenessService = pidLivenessService ?? PidLivenessService();

  final PidLivenessService _pidLivenessService;

  StateRepairReport repair(String projectRoot) {
    final actions = <String>[];
    final layout = ProjectLayout(projectRoot);

    final hadGenaisys = Directory(layout.genaisysDir).existsSync();
    try {
      ProjectInitializer(projectRoot).ensureStructure(overwrite: false);
      if (!hadGenaisys && Directory(layout.genaisysDir).existsSync()) {
        actions.add('initialized_structure');
      }
    } catch (_) {
      // If we fail to initialize, continue with best-effort repairs.
    }

    ProjectState state;
    try {
      state = StateStore(layout.statePath).read();
    } catch (_) {
      state = ProjectState.initial();
      _safeWriteState(layout, state);
      actions.add('reset_state');
      _appendRepairLog(layout, projectRoot, actions);
      return StateRepairReport(changed: true, actions: actions);
    }

    var updated = state;
    var changed = false;

    final hasActiveTask =
        (state.activeTaskId?.trim().isNotEmpty ?? false) ||
        (state.activeTaskTitle?.trim().isNotEmpty ?? false);

    if (hasActiveTask && _activeTaskIsDone(layout, state)) {
      updated = updated.copyWith(
        activeTask: updated.activeTask.copyWith(
          id: null,
          title: null,
        ),
        workflowStage: WorkflowStage.idle,
        subtaskExecution: updated.subtaskExecution.copyWith(
          current: null,
          queue: const [],
        ),
      );
      actions.add('cleared_done_active_task');
      changed = true;
    }

    final activeStale = hasActiveTask && _activeTaskIsStale(layout, updated);
    if (activeStale) {
      updated = updated.copyWith(
        activeTask: updated.activeTask.copyWith(
          id: null,
          title: null,
          retryKey: null,
          forensicRecoveryAttempted: false,
          forensicGuidance: null,
        ),
        workflowStage: WorkflowStage.idle,
        subtaskExecution: updated.subtaskExecution.copyWith(
          current: null,
          queue: const [],
        ),
      );
      actions.add('active_task_stale_cleared');
      changed = true;
    }

    // Compute active-task presence from `updated` (not `state`) since earlier
    // repairs may have cleared the active task.
    final hasActiveTaskAfterRepair =
        (updated.activeTaskId?.trim().isNotEmpty ?? false) ||
        (updated.activeTaskTitle?.trim().isNotEmpty ?? false);

    // Orphaned review status: no active task but reviewStatus lingers.
    if (!hasActiveTaskAfterRepair &&
        updated.reviewStatus?.trim().isNotEmpty == true) {
      updated = updated.copyWith(
        activeTask: updated.activeTask.copyWith(
          reviewStatus: null,
          reviewUpdatedAt: null,
        ),
      );
      actions.add('cleared_orphaned_review_status');
      changed = true;
    }

    // Stale workflow stage: no active task but workflowStage is not idle.
    if (!hasActiveTaskAfterRepair &&
        updated.workflowStage != WorkflowStage.idle) {
      updated = updated.copyWith(workflowStage: WorkflowStage.idle);
      actions.add('cleared_stale_workflow_stage');
      changed = true;
    }

    if (!hasActiveTask &&
        (state.currentSubtask != null || state.subtaskQueue.isNotEmpty)) {
      updated = updated.copyWith(
        subtaskExecution: updated.subtaskExecution.copyWith(
          current: null,
          queue: const [],
        ),
      );
      actions.add('cleared_subtasks_without_active_task');
      changed = true;
    }

    if (updated.currentSubtask != null &&
        updated.subtaskQueue.contains(updated.currentSubtask)) {
      final filtered = updated.subtaskQueue
          .where((item) => item != updated.currentSubtask)
          .toList(growable: false);
      updated = updated.copyWith(
        subtaskExecution: updated.subtaskExecution.copyWith(queue: filtered),
      );
      actions.add('removed_current_from_queue');
      changed = true;
    }

    final deduped = _dedupeQueue(updated.subtaskQueue);
    if (!_sameQueue(deduped, updated.subtaskQueue)) {
      updated = updated.copyWith(
        subtaskExecution: updated.subtaskExecution.copyWith(queue: deduped),
      );
      actions.add('deduped_subtask_queue');
      changed = true;
    }

    final orphanResult = _removeOrphanedSubtasks(layout, updated);
    if (orphanResult.removedCount > 0) {
      updated = orphanResult.updatedState;
      actions.addAll(orphanResult.actions);
      changed = true;
    }

    final lockFile = File(layout.autopilotLockPath);
    if (!lockFile.existsSync() && updated.autopilotRunning) {
      updated = updated.copyWith(
        autopilotRun: updated.autopilotRun.copyWith(
          running: false,
          currentMode: null,
          consecutiveFailures: 0,
        ),
      );
      actions.add('cleared_stale_autopilot_state');
      changed = true;
    }

    final supervisorPid = updated.supervisorPid;
    final supervisorAlive =
        supervisorPid != null && _pidLivenessService.isProcessAlive(supervisorPid);
    if (updated.supervisorRunning && !supervisorAlive) {
      updated = updated.copyWith(
        supervisor: updated.supervisor.copyWith(
          running: false,
          pid: null,
          cooldownUntil: null,
          lastHaltReason: 'stale_supervisor_recovered',
        ),
      );
      actions.add('cleared_stale_supervisor_state');
      changed = true;
    }

    // Expired cooldowns: remove task cooldown entries whose timestamps are
    // in the past so they do not block future task selection.
    if (updated.taskCooldownUntil.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final cleaned = <String, String>{};
      for (final entry in updated.taskCooldownUntil.entries) {
        final expiry = DateTime.tryParse(entry.value);
        if (expiry != null && expiry.isAfter(now)) {
          cleaned[entry.key] = entry.value;
        }
      }
      if (cleaned.length != updated.taskCooldownUntil.length) {
        updated = updated.copyWith(
          retryScheduling:
              updated.retryScheduling.copyWith(cooldownUntil: cleaned),
        );
        actions.add('cleared_expired_cooldowns');
        changed = true;
      }
    }

    if (changed) {
      updated = updated.copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
      _safeWriteState(layout, updated);
      _appendRepairLog(layout, projectRoot, actions);
    }

    return StateRepairReport(changed: changed, actions: actions);
  }

  bool _activeTaskIsDone(ProjectLayout layout, ProjectState state) {
    try {
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final activeId = state.activeTaskId?.trim();
      final activeTitle = state.activeTaskTitle?.trim();
      if ((activeId == null || activeId.isEmpty) &&
          (activeTitle == null || activeTitle.isEmpty)) {
        return false;
      }

      for (final task in tasks) {
        final idMatches =
            activeId != null && activeId.isNotEmpty && task.id == activeId;
        final titleMatches =
            activeTitle != null &&
            activeTitle.isNotEmpty &&
            task.title == activeTitle;
        if (idMatches || titleMatches) {
          return task.completion == TaskCompletion.done;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` when the active task is stale: marked done `[x]` or
  /// missing entirely from TASKS.md. This is distinct from [_activeTaskIsDone]
  /// which only catches the "done" case.
  bool _activeTaskIsStale(ProjectLayout layout, ProjectState state) {
    try {
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final activeId = state.activeTaskId?.trim();
      final activeTitle = state.activeTaskTitle?.trim();
      if ((activeId == null || activeId.isEmpty) &&
          (activeTitle == null || activeTitle.isEmpty)) {
        return false;
      }

      for (final task in tasks) {
        final idMatches =
            activeId != null && activeId.isNotEmpty && task.id == activeId;
        final titleMatches =
            activeTitle != null &&
            activeTitle.isNotEmpty &&
            task.title == activeTitle;
        if (idMatches || titleMatches) {
          return task.completion == TaskCompletion.done;
        }
      }
      // Task not found in TASKS.md — stale.
      return true;
    } catch (_) {
      // If we cannot read TASKS.md, do not falsely report stale.
      return false;
    }
  }

  _OrphanRemovalResult _removeOrphanedSubtasks(
    ProjectLayout layout,
    ProjectState state,
  ) {
    final activeTitle = state.activeTaskTitle?.trim();
    if (activeTitle == null ||
        activeTitle.isEmpty ||
        state.subtaskQueue.isEmpty) {
      return _OrphanRemovalResult(
        updatedState: state,
        removedCount: 0,
        actions: const [],
      );
    }

    final specSubtasks = _loadSpecSubtasks(layout, activeTitle);
    if (specSubtasks == null) {
      // No spec file found — cannot validate; leave queue untouched.
      return _OrphanRemovalResult(
        updatedState: state,
        removedCount: 0,
        actions: const [],
      );
    }

    final specSet = specSubtasks
        .map((entry) => entry.trim().toLowerCase())
        .toSet();
    final kept = <String>[];
    final actions = <String>[];
    for (final entry in state.subtaskQueue) {
      if (specSet.contains(entry.trim().toLowerCase())) {
        kept.add(entry);
      } else {
        actions.add('orphaned_subtask_removed');
      }
    }

    if (actions.isEmpty) {
      return _OrphanRemovalResult(
        updatedState: state,
        removedCount: 0,
        actions: const [],
      );
    }

    return _OrphanRemovalResult(
      updatedState: state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(queue: kept),
      ),
      removedCount: actions.length,
      actions: actions,
    );
  }

  /// Parses the `## Subtasks` section from the spec file for [activeTitle].
  /// Returns `null` when the spec file does not exist.
  List<String>? _loadSpecSubtasks(ProjectLayout layout, String activeTitle) {
    final slug = TaskSlugger.slug(activeTitle);
    final specPath =
        '${layout.taskSpecsDir}${Platform.pathSeparator}$slug-subtasks.md';
    final file = File(specPath);
    if (!file.existsSync()) {
      return null;
    }
    try {
      final lines = file.readAsLinesSync();
      return _parseSubtaskDescriptions(lines);
    } catch (_) {
      return null;
    }
  }

  /// Extracts subtask descriptions from the `## Subtasks` section.
  /// Uses the same parsing pattern as [SubtaskSchedulerService] and
  /// [SpecAgentService] for consistency.
  List<String> _parseSubtaskDescriptions(List<String> lines) {
    final results = <String>[];
    var inSection = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('## Subtasks')) {
        inSection = true;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        inSection = false;
        continue;
      }
      if (!inSection) {
        continue;
      }
      final match = RegExp(r'^(?:(\d+)[.)]|[-*])\s+(.*)').firstMatch(trimmed);
      if (match != null) {
        final description = match.group(2)?.trim() ?? '';
        if (description.isNotEmpty) {
          results.add(description);
        }
      }
    }
    return results;
  }

  List<String> _dedupeQueue(List<String> queue) {
    if (queue.isEmpty) {
      return queue;
    }
    final seen = <String>{};
    final result = <String>[];
    for (final item in queue) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  bool _sameQueue(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  void _safeWriteState(ProjectLayout layout, ProjectState state) {
    try {
      StateStore(layout.statePath).write(state);
    } catch (_) {
      // Ignore state write failures in repair mode.
    }
  }

  void _appendRepairLog(
    ProjectLayout layout,
    String projectRoot,
    List<String> actions,
  ) {
    if (actions.isEmpty) {
      return;
    }
    try {
      final logStore = RunLogStore(layout.runLogPath);
      logStore.append(
        event: 'state_repair',
        message: 'Repaired project state',
        data: {'root': projectRoot, 'actions': actions},
      );

      // Emit structured events for reliability-critical repair actions.
      for (final action in actions) {
        if (action == 'orphaned_subtask_removed') {
          logStore.append(
            event: 'orphaned_subtask_removed',
            message: 'Removed orphaned subtask queue entry',
            data: {
              'root': projectRoot,
              'error_class': 'state_repair',
              'error_kind': 'orphaned_subtask',
            },
          );
        }
        if (action == 'active_task_stale_cleared') {
          logStore.append(
            event: 'active_task_stale_cleared',
            message: 'Cleared stale active task reference',
            data: {
              'root': projectRoot,
              'error_class': 'state_repair',
              'error_kind': 'active_task_stale',
            },
          );
        }
        if (action == 'cleared_orphaned_review_status') {
          logStore.append(
            event: 'cleared_orphaned_review_status',
            message: 'Cleared orphaned review status without active task',
            data: {
              'root': projectRoot,
              'error_class': 'state_repair',
              'error_kind': 'orphaned_review',
            },
          );
        }
        if (action == 'cleared_stale_workflow_stage') {
          logStore.append(
            event: 'cleared_stale_workflow_stage',
            message: 'Reset stale workflow stage to idle',
            data: {
              'root': projectRoot,
              'error_class': 'state_repair',
              'error_kind': 'stale_workflow',
            },
          );
        }
        if (action == 'cleared_expired_cooldowns') {
          logStore.append(
            event: 'cleared_expired_cooldowns',
            message: 'Removed expired task cooldown entries',
            data: {
              'root': projectRoot,
              'error_class': 'state_repair',
              'error_kind': 'expired_cooldowns',
            },
          );
        }
      }
    } catch (_) {
      // Ignore logging failures.
    }
  }
}

class _OrphanRemovalResult {
  const _OrphanRemovalResult({
    required this.updatedState,
    required this.removedCount,
    required this.actions,
  });

  final ProjectState updatedState;
  final int removedCount;
  final List<String> actions;
}
