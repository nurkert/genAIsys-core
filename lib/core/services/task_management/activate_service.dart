// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../models/task.dart';
import '../../models/workflow_stage.dart';
import '../../policy/interaction_parity_policy.dart';
import '../../project_layout.dart';
import '../../selection/task_selector.dart';
import '../../selection/task_selection_context.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';
import 'task_selection_context_builder.dart';
import '../workflow_service.dart';

class ActivationResult {
  ActivationResult({required this.task});

  final Task? task;

  bool get hasTask => task != null;
}

class ActivateService {
  ActivateService({GitService? gitService})
    : _gitService = gitService ?? GitService();

  final GitService _gitService;

  ActivationResult activate(
    String projectRoot, {
    String? requestedId,
    String? requestedTitle,
  }) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final selectionContext = TaskSelectionContextBuilder().build(
      projectRoot,
      tasks,
    );
    final next = _selectTask(
      tasks,
      requestedId,
      requestedTitle,
      selectionContext,
      projectRoot: projectRoot,
      layout: layout,
    );
    if (next == null) {
      RunLogStore(layout.runLogPath).append(
        event: 'activate_task',
        message: 'No open tasks to activate',
        data: {'root': projectRoot},
      );
      return ActivationResult(task: null);
    }

    _handleGitBranch(projectRoot, next);

    final stateStore = StateStore(layout.statePath);
    final state = stateStore.read();
    final updated = state.copyWith(
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
      activeTask: state.activeTask.copyWith(
        id: next.id,
        title: next.title,
        retryKey: _computeRetryKey(next.id, next.title),
        reviewStatus: null,
        reviewUpdatedAt: null,
        forensicRecoveryAttempted: false,
        forensicGuidance: null,
      ),
    );
    stateStore.write(updated);

    RunLogStore(layout.runLogPath).append(
      event: 'activate_task',
      message: 'Activated task',
      data: {'root': projectRoot, 'task': next.title, 'task_id': next.id},
    );

    _advanceWorkflowIfNeeded(projectRoot);

    return ActivationResult(task: next);
  }

  void _handleGitBranch(String projectRoot, Task task) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return;
    }
    final config = ProjectConfig.load(projectRoot);
    final baseBranch = config.gitBaseBranch;
    if (!_gitService.branchExists(projectRoot, baseBranch)) {
      // Branch may exist on remote but not locally — try to fetch it first.
      final remote = _gitService.defaultRemote(projectRoot);
      if (remote != null && remote.trim().isNotEmpty) {
        try {
          _gitService.fetch(projectRoot, remote);
        } catch (_) {
          // Best-effort: fetch may fail due to network issues.
        }
      }
      if (!_gitService.branchExists(projectRoot, baseBranch)) {
        throw StateError('Base branch not found: $baseBranch');
      }
    }
    // Sanitize ID for branch name
    final safeId = task.id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
    if (safeId.isEmpty) {
      return;
    }
    final branchName = '${config.gitFeaturePrefix}$safeId';

    if (_gitService.branchExists(projectRoot, branchName)) {
      _checkoutWithDirtyRecovery(projectRoot, branchName, config: config);
      return;
    }

    _checkoutWithDirtyRecovery(projectRoot, baseBranch, config: config);

    final remote = _gitService.defaultRemote(projectRoot);
    if (remote != null && remote.trim().isNotEmpty) {
      try {
        _gitService.pullFastForward(projectRoot, remote, baseBranch);
      } catch (_) {
        // Best-effort: pull may fail due to no remote or no network.
      }
    }

    try {
      _gitService.createBranch(projectRoot, branchName, startPoint: baseBranch);
    } catch (error) {
      throw StateError(
        'Failed to create branch $branchName from $baseBranch: $error',
      );
    }
  }

  /// Attempts `checkout`.  When it fails due to a dirty worktree and
  /// `auto_stash` is enabled, stashes the dirty changes, retries checkout,
  /// and logs the recovery.  This prevents cascading deadlocks after a
  /// failed stash-pop leaves residual changes.
  void _checkoutWithDirtyRecovery(
    String projectRoot,
    String ref, {
    required ProjectConfig config,
  }) {
    try {
      _gitService.checkout(projectRoot, ref);
      return;
    } catch (firstError) {
      // If worktree is clean, the failure is not recoverable by stashing.
      if (_gitService.isClean(projectRoot)) {
        throw StateError('Failed to checkout $ref: $firstError');
      }

      // Try auto-committing residual meta state before falling back to
      // stash logic.  Orchestrator operations (run-log, state updates)
      // frequently dirty .genaisys/ files between the step's git guard
      // and this checkout.  A meta commit resolves this without requiring
      // git.auto_stash to be enabled.
      try {
        _gitService.addAll(projectRoot);
        _gitService.commit(
          projectRoot,
          'meta(state): persist orchestrator state before checkout',
        );
        _gitService.checkout(projectRoot, ref);
        return;
      } catch (e) {
        // Meta commit didn't resolve it; fall through to stash logic or
        // throw if auto_stash is disabled.
        final layout = ProjectLayout(projectRoot);
        RunLogStore(layout.runLogPath).append(
          event: 'activate_meta_commit_failed',
          message: 'Meta commit before checkout failed, trying stash fallback',
          data: {
            'root': projectRoot,
            'ref': ref,
            'error': e.toString(),
            'error_class': 'git',
            'error_kind': 'meta_commit_failed',
          },
        );
      }

      if (!config.gitAutoStash) {
        throw StateError('Failed to checkout $ref: $firstError');
      }
    }

    // Dirty worktree — stash and retry.
    final layout = ProjectLayout(projectRoot);
    final stashMessage =
        'genaisys:activate-recovery:${DateTime.now().toUtc().microsecondsSinceEpoch}';
    try {
      _gitService.stashPush(
        projectRoot,
        message: stashMessage,
        includeUntracked: true,
      );
      RunLogStore(layout.runLogPath).append(
        event: 'activate_auto_stash_recovery',
        message: 'Stashed dirty worktree before activation checkout',
        data: {
          'root': projectRoot,
          'ref': ref,
          'stash_message': stashMessage,
          'error_class': 'activation',
          'error_kind': 'auto_stash_recovery',
        },
      );
    } catch (stashError) {
      throw StateError(
        'Failed to checkout $ref: dirty worktree and stash failed ($stashError)',
      );
    }

    try {
      _gitService.checkout(projectRoot, ref);
    } catch (retryError) {
      // Last resort: discard working changes and try once more.
      try {
        _gitService.discardWorkingChanges(projectRoot);
        _gitService.checkout(projectRoot, ref);
        RunLogStore(layout.runLogPath).append(
          event: 'activate_checkout_force_recovery',
          message: 'Checkout succeeded after discarding working changes',
          data: {
            'root': projectRoot,
            'ref': ref,
            'error_class': 'activation',
            'error_kind': 'checkout_force_recovery',
          },
        );
      } catch (forceError) {
        throw StateError(
          'Failed to checkout $ref after stash and force recovery: $forceError',
        );
      }
    }
  }

  void deactivate(String projectRoot, {bool keepReview = false}) {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);

    final stateStore = StateStore(layout.statePath);
    final current = stateStore.read();
    final updated = keepReview
        ? current.copyWith(
            lastUpdated: DateTime.now().toUtc().toIso8601String(),
            activeTask: current.activeTask.copyWith(
              id: null,
              title: null,
            ),
          )
        : current.copyWith(
            lastUpdated: DateTime.now().toUtc().toIso8601String(),
            activeTask: current.activeTask.copyWith(
              id: null,
              title: null,
              reviewStatus: null,
              reviewUpdatedAt: null,
            ),
          );
    stateStore.write(updated);

    RunLogStore(layout.runLogPath).append(
      event: 'deactivate_task',
      message: 'Cleared active task',
      data: {'root': projectRoot, 'keep_review': keepReview},
    );
  }

  Task? _selectTask(
    List<Task> tasks,
    String? requestedId,
    String? requestedTitle,
    TaskSelectionContext context, {
    required String projectRoot,
    required ProjectLayout layout,
  }) {
    if (requestedId != null && requestedId.trim().isNotEmpty) {
      final match = tasks.firstWhere(
        (task) => task.id == requestedId,
        orElse: () => Task(
          title: requestedId,
          priority: TaskPriority.p3,
          category: TaskCategory.unknown,
          completion: TaskCompletion.open,
          blocked: false,
          section: 'Backlog',
          lineIndex: -1,
        ),
      );
      if (match.lineIndex < 0) {
        throw StateError('Task id not found: $requestedId');
      }
      _ensureEligible(
        match,
        context,
        tasks,
        projectRoot: projectRoot,
        layout: layout,
      );
      return match;
    }

    if (requestedTitle != null && requestedTitle.trim().isNotEmpty) {
      final normalized = requestedTitle.trim().toLowerCase();
      // Try exact match first.
      var matches = tasks
          .where((task) => task.title.trim().toLowerCase() == normalized)
          .toList();
      // Fallback: prefix match, prefer shortest (most specific) title.
      if (matches.isEmpty) {
        matches = tasks
            .where(
              (task) => task.title.trim().toLowerCase().startsWith(normalized),
            )
            .toList();
        if (matches.length > 1) {
          matches.sort((a, b) => a.title.length.compareTo(b.title.length));
          matches = [matches.first];
        }
      }
      // Fallback: substring match, prefer shortest (most specific) title.
      if (matches.isEmpty) {
        matches = tasks
            .where(
              (task) => task.title.trim().toLowerCase().contains(normalized),
            )
            .toList();
        if (matches.length > 1) {
          // Pick shortest title as the most specific match.
          matches.sort((a, b) => a.title.length.compareTo(b.title.length));
          matches = [matches.first];
        }
      }
      if (matches.isEmpty) {
        throw StateError('Task title not found: $requestedTitle');
      }
      if (matches.length > 1) {
        final titles = matches.map((t) => t.title).join(', ');
        throw StateError(
          'Ambiguous task title "$requestedTitle" matches ${matches.length} '
          'tasks: $titles',
        );
      }
      final match = matches.first;
      _ensureEligible(
        match,
        context,
        tasks,
        projectRoot: projectRoot,
        layout: layout,
      );
      return match;
    }

    // Last-resort guard: verify the selected task hasn't already been
    // completed in the run-log (defends against stale state re-activation).
    // Loop through candidates because with auto_merge disabled, completed
    // tasks may still appear as open in TASKS.md on the main branch.
    final config = ProjectConfig.load(projectRoot);
    final remaining = List<Task>.from(tasks);
    final runLog = RunLogStore(layout.runLogPath);
    while (true) {
      final candidate = TaskSelector().nextOpenTask(
        remaining,
        context: context,
      );
      if (candidate == null) return null;
      if (!_hasTaskDoneEvent(layout, candidate.title,
          taskId: candidate.id)) {
        // Feature K: skip if dependencies are unmet.
        if (config.autopilotTaskDependenciesEnabled &&
            !_dependenciesMet(candidate, tasks)) {
          runLog.append(
            event: 'activate_skip_unmet_dependencies',
            message:
                'Skipped candidate task with unmet dependencies; trying next',
            data: {
              'root': projectRoot,
              'task': candidate.title,
              'task_id': candidate.id,
              'dependency_refs': candidate.dependencyRefs,
              'error_class': 'activation',
              'error_kind': 'unmet_dependencies',
            },
          );
          remaining.remove(candidate);
          continue;
        }
        return candidate;
      }
      runLog.append(
        event: 'activate_skip_already_done',
        message: 'Skipped candidate task that has a task_done event in '
            'run-log; trying next candidate',
        data: {
          'root': projectRoot,
          'task': candidate.title,
          'task_id': candidate.id,
          'error_class': 'activation',
          'error_kind': 'already_completed_in_log',
        },
      );
      remaining.remove(candidate);
    }
  }

  void _ensureEligible(
    Task task,
    TaskSelectionContext context,
    List<Task> allTasks, {
    required String projectRoot,
    required ProjectLayout layout,
  }) {
    if (task.completion == TaskCompletion.done) {
      throw StateError('Task already done: ${task.title}');
    }
    final parity = InteractionParityPolicy.evaluate(task, allTasks);
    if (!parity.ok) {
      RunLogStore(layout.runLogPath).append(
        event: 'activate_task_policy_blocked',
        message: 'Activation blocked by CLI-first parity policy',
        data: {
          'root': projectRoot,
          'task': task.title,
          'task_id': task.id,
          'error_class': parity.errorClass,
          'error_kind': parity.errorKind,
          'error': parity.message,
        },
      );
      throw StateError(
        parity.message ?? 'Activation blocked by parity policy.',
      );
    }
    if (context.deferNonCriticalUiTasks &&
        task.category == TaskCategory.ui &&
        task.priority != TaskPriority.p1) {
      throw StateError('Task is deferred during stabilization: ${task.title}');
    }
    // Use a fresh timestamp at the activation boundary so cooldown checks
    // are never evaluated against a stale context.now captured earlier in
    // the pipeline.
    final freshNow = DateTime.now().toUtc();
    if (task.blocked) {
      if (!context.includeBlocked) {
        throw StateError('Task is blocked: ${task.title}');
      }
      if (!task.blockedByAutoCycle) {
        throw StateError(
          'Task is blocked and not auto-reactivable: ${task.title}',
        );
      }
      if (_isCoolingDown(task, context.blockedCooldown, context,
          freshNow: freshNow)) {
        throw StateError('Task is cooling down: ${task.title}');
      }
    }
    if (_isFailed(task, context.retryCounts)) {
      if (!context.includeFailed) {
        throw StateError('Task is marked as failed: ${task.title}');
      }
      if (_isCoolingDown(task, context.failedCooldown, context,
          freshNow: freshNow)) {
        throw StateError('Task is cooling down: ${task.title}');
      }
    }
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
    TaskSelectionContext context, {
    DateTime? freshNow,
  }) {
    final now = freshNow ?? DateTime.now().toUtc();
    // Check explicit per-task cooldown timestamps from STATE.json first.
    if (_hasExplicitCooldown(task, context, freshNow: now)) {
      return true;
    }

    // Fall back to history-based cooldown (last activation time + duration).
    if (cooldown.inSeconds < 1) {
      return false;
    }
    final last =
        context.history.lastActivationByTaskId[task.id] ??
        context.history.lastActivationByTitle[_titleKey(task.title)];
    if (last == null) {
      return false;
    }
    return now.difference(last) < cooldown;
  }

  /// Returns true if the task has an explicit cooldown expiration that has
  /// not yet elapsed.
  bool _hasExplicitCooldown(
    Task task,
    TaskSelectionContext context, {
    DateTime? freshNow,
  }) {
    final now = freshNow ?? DateTime.now().toUtc();
    final cooldowns = context.taskCooldownUntil;
    if (cooldowns.isEmpty) {
      return false;
    }
    final byId = cooldowns['id:${task.id}'];
    final byTitle = cooldowns['title:${_titleKey(task.title)}'];
    final raw = byId ?? byTitle;
    if (raw == null) {
      return false;
    }
    final expiresAt = DateTime.tryParse(raw);
    if (expiresAt == null) {
      return false;
    }
    return expiresAt.toUtc().isAfter(now);
  }

  String _titleKey(String raw) {
    return raw.trim().toLowerCase();
  }

  void _ensureStateFile(ProjectLayout layout) {
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
  }

  void _ensureTasksFile(ProjectLayout layout) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
  }

  /// Returns true if the task is already completed, by checking:
  /// 1. The run-log for a `task_done` event matching [taskTitle] or [taskId].
  /// 2. TASKS.md for a `[x]` checkbox matching by ID or title.
  bool _hasTaskDoneEvent(
    ProjectLayout layout,
    String taskTitle, {
    String? taskId,
  }) {
    // --- Check 1: Run-log task_done events ---
    final logFile = File(layout.runLogPath);
    if (logFile.existsSync()) {
      List<String> lines;
      try {
        lines = logFile.readAsLinesSync();
      } on FileSystemException {
        // Best-effort: log file may not be readable (permissions, locked).
        lines = const [];
      }
      final normalizedTitle = taskTitle.trim().toLowerCase();
      // Scan backwards (most recent first) for efficiency.
      for (var i = lines.length - 1; i >= 0; i--) {
        final raw = lines[i].trim();
        if (raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          if (decoded['event']?.toString() != 'task_done') continue;
          final data = decoded['data'];
          if (data is! Map) continue;
          // Match by title.
          final logTask = data['task']?.toString().trim().toLowerCase() ?? '';
          if (logTask == normalizedTitle) return true;
          // Match by task ID.
          if (taskId != null && taskId.isNotEmpty) {
            final logTaskId = data['task_id']?.toString().trim() ?? '';
            if (logTaskId == taskId) return true;
          }
        } on FormatException {
          // Best-effort: skip malformed JSONL lines.
          continue;
        }
      }
    }

    // --- Check 2: TASKS.md done status ---
    final tasksFile = File(layout.tasksPath);
    if (tasksFile.existsSync()) {
      try {
        final tasks = TaskStore(layout.tasksPath).readTasks();
        for (final task in tasks) {
          if (task.completion != TaskCompletion.done) continue;
          // Match by ID.
          if (taskId != null && taskId.isNotEmpty && task.id == taskId) {
            return true;
          }
          // Match by title.
          if (task.title.trim().toLowerCase() ==
              taskTitle.trim().toLowerCase()) {
            return true;
          }
        }
      } catch (e) {
        // Log parse errors but fall through to false — corrupted TASKS.md
        // should not silently bypass task-done detection.
        stderr.writeln(
          '[ActivateService] TASKS.md parse error during '
          'task-done check: $e',
        );
      }
    }

    return false;
  }

  /// Computes the task-level retry key for a task at activation time.
  ///
  /// Mirrors the logic in `TaskCycleService._retryKey` (task-level only,
  /// no subtask) so the key is stable across the entire task lifecycle.
  String? _computeRetryKey(String? taskId, String? taskTitle) {
    final normalizedId = taskId?.trim();
    if (normalizedId != null && normalizedId.isNotEmpty) {
      return 'id:$normalizedId';
    }
    final normalizedTitle = taskTitle?.trim().toLowerCase();
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      return 'title:$normalizedTitle';
    }
    return null;
  }

  /// Feature K: Returns true if all dependency refs for [task] are satisfied
  /// (i.e., the referenced tasks are marked done in [allTasks]).
  bool _dependenciesMet(Task task, List<Task> allTasks) {
    if (task.dependencyRefs.isEmpty) return true;
    return task.dependencyRefs.every(
      (ref) => allTasks.any(
        (t) => t.id == ref && t.completion == TaskCompletion.done,
      ),
    );
  }

  void _advanceWorkflowIfNeeded(String projectRoot) {
    final workflow = WorkflowService();
    final current = workflow.getStage(projectRoot);
    if (current == WorkflowStage.idle || current == WorkflowStage.done) {
      workflow.transition(projectRoot, WorkflowStage.planning);
    }
  }
}
