// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../models/active_task_state.dart';
import '../../models/project_state.dart';
import '../../models/task.dart';
import '../../models/workflow_stage.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';
import '../../storage/task_writer.dart';
import '../audit_trail_service.dart';
import '../delivery/delivery_preflight_service.dart';
import '../delivery/merge_conflict_coordinator.dart';
import '../delivery/review_evidence_validator.dart';
import '../delivery/unattended_block_service.dart';
import '../merge_conflict_resolver_service.dart';
import '../agents/spec_agent_service.dart';
import '../workflow_service.dart';

class DoneService {
  DoneService({
    GitService? gitService,
    MergeConflictResolverService? mergeConflictResolver,
    int mergeConflictMaxAttempts = 3,
    ReviewEvidenceValidator? reviewEvidenceValidator,
    DeliveryPreflightService? deliveryPreflightService,
    MergeConflictCoordinator? mergeConflictCoordinator,
    UnattendedBlockService? unattendedBlockService,
    SpecAgentService? specAgentService,
  }) : _gitService = gitService ?? GitService(),
       _reviewEvidenceValidator =
           reviewEvidenceValidator ?? ReviewEvidenceValidator(),
       _deliveryPreflightService = deliveryPreflightService ??
           DeliveryPreflightService(gitService: gitService),
       _mergeConflictCoordinator = mergeConflictCoordinator ??
           MergeConflictCoordinator(
             gitService: gitService,
             mergeConflictResolver: mergeConflictResolver,
             mergeConflictMaxAttempts: mergeConflictMaxAttempts,
           ),
       _unattendedBlockService = unattendedBlockService ??
           UnattendedBlockService(gitService: gitService),
       _specAgentService = specAgentService ?? SpecAgentService();

  final GitService _gitService;
  final ReviewEvidenceValidator _reviewEvidenceValidator;
  final DeliveryPreflightService _deliveryPreflightService;
  final MergeConflictCoordinator _mergeConflictCoordinator;
  final UnattendedBlockService _unattendedBlockService;
  final SpecAgentService _specAgentService;

  Future<String> markDone(
    String projectRoot, {
    bool force = false,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final state = StateStore(layout.statePath).read();
    final activeTitle = state.activeTaskTitle;
    if (state.reviewStatus != 'approved') {
      throw StateError('Review not approved. Use: review approve');
    }
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      throw StateError('No active task set. Use: activate');
    }
    if (!force) {
      try {
        _reviewEvidenceValidator.validateReviewEvidenceBundle(
          projectRoot,
          layout: layout,
          activeTaskTitle: activeTitle.trim(),
        );
      } catch (e) {
        if (_isUnattendedMode(layout)) {
          RunLogStore(layout.runLogPath).append(
            event: 'done_evidence_warning',
            message:
                'Review evidence validation failed in unattended mode; proceeding',
            data: {
              'root': projectRoot,
              'task': activeTitle,
              'error': e.toString(),
              'error_class': 'delivery',
              'error_kind': 'evidence_warning_unattended',
            },
          );
        } else {
          rethrow;
        }
      }
    } else {
      RunLogStore(layout.runLogPath).append(
        event: 'done_force_skip_evidence',
        message: 'Skipped review evidence validation (force mode)',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'error_class': 'delivery',
          'error_kind': 'evidence_bypassed',
        },
      );
    }
    _deliveryPreflightService.deliveryPreflight(projectRoot, layout: layout);

    final match = _findActiveTask(layout, activeTitle);
    final alreadyDone = match.completion == TaskCompletion.done;

    // Git Merge Flow — always merge so the feature branch lands on the base
    // branch, even when the coding agent pre-marked the task done in TASKS.md.
    await _handleGitMerge(projectRoot);

    if (alreadyDone) {
      // Task checkbox was already ticked (e.g. by the coding agent).
      // Emit task_done for downstream consumers (activation skip logic), then
      // skip writer.markDone/audit/subtask cleanup — the merge above ensures
      // the branch lands; those steps must not run a second time.
      RunLogStore(layout.runLogPath).append(
        event: 'task_done',
        message: 'Marked task as done',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'task_id': match.id,
        },
      );
      RunLogStore(layout.runLogPath).append(
        event: 'task_already_done',
        message: 'Task already marked done in TASKS.md — skipping markDone',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'error_class': 'delivery',
          'error_kind': 'task_already_done',
        },
      );
      _clearActiveTaskState(layout);
      return activeTitle;
    }

    final writer = TaskWriter(layout.tasksPath);
    if (!writer.markDone(match)) {
      throw StateError('Failed to mark task done.');
    }

    RunLogStore(layout.runLogPath).append(
      event: 'task_done',
      message: 'Marked task as done',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'task_id': match.id,
      },
    );

    // Feature E: Post-done AC verification (non-blocking, opt-in).
    final config = ProjectConfig.load(projectRoot);
    if (config.pipelineFinalAcCheckEnabled) {
      await _runFinalAcCheck(projectRoot, layout, activeTitle);
    }

    // Feature K: Log tasks unblocked by this completion.
    if (config.autopilotTaskDependenciesEnabled) {
      _logUnblockedDependencies(projectRoot, layout, match.id, activeTitle);
    }

    AuditTrailService().recordOutcome(projectRoot, outcome: 'done');

    // Clean up any explicit per-task cooldown entries for the completed task.
    _clearTaskCooldown(layout, state);

    // Clear orphaned subtask state so completed-task subtasks are not
    // re-activated by the scheduler on the next loop.
    _clearSubtaskState(layout);
    _clearActiveTaskState(layout);

    _advanceWorkflowIfNeeded(projectRoot);

    return activeTitle;
  }

  Future<void> _handleGitMerge(String projectRoot) async {
    final layout = ProjectLayout(projectRoot);
    if (!_gitService.isGitRepo(projectRoot)) {
      return;
    }
    final config = ProjectConfig.load(projectRoot);
    final currentBranch = _gitService.currentBranch(projectRoot);
    if (_gitService.hasMergeInProgress(projectRoot)) {
      throw StateError(
        'Merge in progress. Manual intervention required to resolve merge conflict.',
      );
    }

    if (!_deliveryPreflightService.isTaskBranch(
      currentBranch,
      config: config,
    )) {
      RunLogStore(layout.runLogPath).append(
        event: 'merge_skipped',
        message: 'Skipped merge: not on a task branch',
        data: {
          'root': projectRoot,
          'branch': currentBranch,
          'error_class': 'git',
          'error_kind': 'merge_skip_not_task_branch',
        },
      );
      return;
    }

    // When auto_merge is disabled, skip the merge-to-base flow entirely.
    // The feature branch stays as-is; the user or CI can merge manually.
    if (!config.workflowAutoMerge) {
      RunLogStore(layout.runLogPath).append(
        event: 'merge_skipped',
        message: 'Skipped merge: auto_merge is disabled',
        data: {
          'root': projectRoot,
          'branch': currentBranch,
          'error_class': 'git',
          'error_kind': 'merge_skip_auto_merge_disabled',
        },
      );
      return;
    }

    final baseBranch = config.gitBaseBranch;
    if (!_gitService.branchExists(projectRoot, baseBranch)) {
      throw StateError('Base branch not found: $baseBranch');
    }
    // Commit any residual dirty state (run-log entries from delivery
    // preflight, audit trail writes) before the branch switch.  Without
    // this, dirty .genaisys/ files block the checkout to baseBranch.
    _commitResidualMetaState(projectRoot);

    // Mark merge as in-progress so a crash/retry can resume safely.
    final storeForMerge = StateStore(layout.statePath);
    _setMergeInProgress(storeForMerge, inProgress: true);

    try {
      _gitService.checkout(projectRoot, baseBranch);
      _syncBaseBranchBeforeMerge(projectRoot, baseBranch);
      await _mergeConflictCoordinator.mergeOrResolve(
        projectRoot,
        baseBranch,
        currentBranch,
      );

      _pushBase(projectRoot, baseBranch);
      _deleteMergedBranches(
        projectRoot,
        config: config,
        remote: _gitService.defaultRemote(projectRoot),
        featureBranch: currentBranch,
      );
      _setMergeInProgress(storeForMerge, inProgress: false);
      RunLogStore(layout.runLogPath).append(
        event: 'merge_completed',
        message: 'Merged feature branch into base',
        data: {
          'root': projectRoot,
          'feature_branch': currentBranch,
          'base_branch': baseBranch,
        },
      );
    } catch (e) {
      // Abort any merge-in-progress so the worktree doesn't stay in a
      // conflicted state that would fail preflight on the next step.
      try {
        _gitService.abortMerge(projectRoot);
      } catch (_) {
        // Best-effort — if no merge is in progress, abort will fail harmlessly.
      }
      _setMergeInProgress(storeForMerge, inProgress: false);
      RunLogStore(layout.runLogPath).append(
        event: 'merge_failed',
        message: 'Failed to merge feature branch into base',
        data: {
          'root': projectRoot,
          'feature_branch': currentBranch,
          'base_branch': baseBranch,
          'error': e.toString(),
          'error_class': 'git',
          'error_kind': 'merge_failed',
        },
      );
      throw StateError('Failed to merge $currentBranch into $baseBranch: $e');
    }
  }

  /// Sets or clears the `merge_in_progress` flag in STATE.json.
  /// Best-effort: silently ignores write failures.
  void _setMergeInProgress(StateStore store, {required bool inProgress}) {
    try {
      final state = store.read();
      store.write(
        state.copyWith(
          activeTask: state.activeTask.copyWith(
            mergeInProgress: inProgress,
          ),
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (_) {
      // Non-critical: state write failure is logged via merge_failed event.
    }
  }

  /// Commits any residual dirty state (run-log entries, state updates) that
  /// accumulated between the delivery preflight clean-check and the merge
  /// checkout.  Without this, dirty `.genaisys/` files block the branch
  /// switch, especially when `git.auto_stash` is disabled.
  void _commitResidualMetaState(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) return;
    if (_gitService.isClean(projectRoot)) return;
    try {
      _gitService.addAll(projectRoot);
      _gitService.commit(
        projectRoot,
        'meta(state): persist pre-merge orchestrator state',
      );
    } catch (_) {
      // Best-effort: let the merge flow handle any remaining dirty state.
    }
  }

  void _deleteMergedBranches(
    String projectRoot, {
    required ProjectConfig config,
    required String? remote,
    required String featureBranch,
  }) {
    final layout = ProjectLayout(projectRoot);
    try {
      _gitService.deleteBranch(projectRoot, featureBranch);
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_branch_deleted',
        message: 'Deleted merged local feature branch',
        data: {
          'root': projectRoot,
          'branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'branch_deleted',
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_branch_delete_failed',
        message: 'Failed to delete merged local feature branch',
        data: {
          'root': projectRoot,
          'branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'branch_delete_failed',
          'error': error.toString(),
        },
      );
      // Best-effort hygiene: do not block task completion for cleanup failures.
    }

    if (!config.gitAutoDeleteRemoteMergedBranches) {
      return;
    }
    final trimmedRemote = remote?.trim() ?? '';
    if (trimmedRemote.isEmpty) {
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_remote_branch_delete_skipped',
        message: 'Remote branch delete skipped: no remote configured',
        data: {
          'root': projectRoot,
          'branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'no_remote',
        },
      );
      return;
    }

    try {
      _gitService.deleteRemoteBranch(projectRoot, trimmedRemote, featureBranch);
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_remote_branch_deleted',
        message: 'Deleted merged remote feature branch',
        data: {
          'root': projectRoot,
          'remote': trimmedRemote,
          'branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'remote_branch_deleted',
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_remote_branch_delete_failed',
        message: 'Failed to delete merged remote feature branch',
        data: {
          'root': projectRoot,
          'remote': trimmedRemote,
          'branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'remote_branch_delete_failed',
          'error': error.toString(),
        },
      );
      // Best-effort hygiene: do not block task completion for cleanup failures.
    }
  }

  void _syncBaseBranchBeforeMerge(String projectRoot, String baseBranch) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.workflowAutoPush) {
      return; // Local-only delivery; no remote sync needed before merge.
    }
    final remote = _gitService.defaultRemote(projectRoot);
    if (remote == null || remote.trim().isEmpty) {
      // No remote configured — skip remote sync.  This is expected for
      // local-only projects and should not block delivery.
      final layout = ProjectLayout(projectRoot);
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_no_remote_warning',
        message:
            'No git remote configured — skipping base branch sync before merge',
        data: {
          'root': projectRoot,
          'base_branch': baseBranch,
          'error_class': 'delivery',
          'error_kind': 'no_remote',
        },
      );
      return;
    }
    final layout = ProjectLayout(projectRoot);
    try {
      _gitService.fetch(projectRoot, remote);
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_fetch',
        message: 'Fetched remote updates before merge',
        data: {
          'root': projectRoot,
          'remote': remote,
          'base_branch': baseBranch,
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_fetch_failed',
        message: 'Fetch before merge failed',
        data: {
          'root': projectRoot,
          'remote': remote,
          'base_branch': baseBranch,
          'error_class': 'delivery',
          'error_kind': 'fetch_failed',
          'error': error.toString(),
        },
      );
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'fetch_failed',
        message: 'Fetch before merge failed: $error',
      );
    }
    try {
      _gitService.pullFastForward(projectRoot, remote, baseBranch);
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_pull',
        message: 'Pulled base branch fast-forward before merge',
        data: {
          'root': projectRoot,
          'remote': remote,
          'base_branch': baseBranch,
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'git_delivery_pull_failed',
        message: 'Fast-forward pull before merge failed',
        data: {
          'root': projectRoot,
          'remote': remote,
          'base_branch': baseBranch,
          'error_class': 'delivery',
          'error_kind': 'upstream_diverged',
          'error': error.toString(),
        },
      );
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'upstream_diverged',
        message: 'Base branch cannot fast-forward from upstream: $error',
      );
    }
  }

  void _pushBase(String projectRoot, String baseBranch) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.workflowAutoPush) {
      return; // Local-only delivery; push skipped.
    }
    final remote = _gitService.defaultRemote(projectRoot);
    if (remote == null || remote.trim().isEmpty) {
      // No remote configured — skip push.  This is expected for local-only
      // projects and should not block delivery.
      final layout = ProjectLayout(projectRoot);
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_no_remote_warning',
        message: 'No git remote configured — skipping push after merge',
        data: {
          'root': projectRoot,
          'base_branch': baseBranch,
          'error_class': 'delivery',
          'error_kind': 'no_remote',
        },
      );
      return;
    }
    try {
      _gitService.push(projectRoot, remote, baseBranch);
      // Successful push — reset consecutive push failure counter.
      _resetConsecutivePushFailures(projectRoot);
    } catch (error) {
      _trackPushFailure(
        projectRoot,
        baseBranch: baseBranch,
        remote: remote,
        errorMessage: error.toString(),
      );
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'push_failed',
        message: 'Unable to push $baseBranch to $remote: $error',
      );
    }
  }

  /// Returns true if the push error message looks like an auth/permission
  /// issue rather than a transient network problem.
  static bool _isAuthPushFailure(String errorMessage) {
    final normalized = errorMessage.toLowerCase();
    return normalized.contains('authentication failed') ||
        normalized.contains('permission denied') ||
        normalized.contains('access denied') ||
        normalized.contains('repository not found') ||
        normalized.contains('could not read from remote repository') ||
        normalized.contains('remote rejected') ||
        normalized.contains('not authorized');
  }

  /// Increments the consecutive push failure counter in STATE.json and blocks
  /// the task when the appropriate threshold is reached. Auth/permission
  /// failures block immediately; network/transport failures use a configurable
  /// threshold (default 5).
  void _trackPushFailure(
    String projectRoot, {
    required String baseBranch,
    required String remote,
    required String errorMessage,
  }) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();
    final newCount = state.consecutiveFailures + 1;
    store.write(
      state.copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
        autopilotRun: state.autopilotRun.copyWith(
          consecutiveFailures: newCount,
          lastError: 'push_failed',
          lastErrorClass: 'delivery',
          lastErrorKind: 'push_failed',
        ),
      ),
    );
    final isAuth = _isAuthPushFailure(errorMessage);
    final config = ProjectConfig.load(projectRoot);
    final threshold = isAuth ? 1 : config.autopilotPushFailureThreshold;
    if (newCount >= threshold) {
      RunLogStore(layout.runLogPath).append(
        event: 'consecutive_push_failures_blocked',
        message:
            'Blocking task after $newCount consecutive push failures',
        data: {
          'root': projectRoot,
          'base_branch': baseBranch,
          'remote': remote,
          'consecutive_failures': newCount,
          'threshold': threshold,
          'is_auth_failure': isAuth,
          'error_class': 'delivery',
          'error_kind': 'consecutive_push_failures',
        },
      );
      final activeTitle = state.activeTaskTitle;
      if (activeTitle != null && activeTitle.trim().isNotEmpty) {
        try {
          blockActive(
            projectRoot,
            reason: 'Auto-cycle: $newCount consecutive push failures',
            diagnostics: {
              'error_class': 'delivery',
              'error_kind': 'consecutive_push_failures',
              'consecutive_failures': newCount,
              'is_auth_failure': isAuth,
            },
          );
        } catch (_) {
          // Best-effort block; the delivery gate failure below will still
          // propagate the push error.
        }
      }
    }
  }

  /// Resets the consecutive push failure counter after a successful push.
  void _resetConsecutivePushFailures(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();
    if (state.consecutiveFailures > 0) {
      store.write(
        state.copyWith(
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
          autopilotRun: state.autopilotRun.copyWith(
            consecutiveFailures: 0,
          ),
        ),
      );
    }
  }

  Never _deliveryGateFailure(
    String projectRoot, {
    required String errorKind,
    required String message,
  }) {
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'delivery_preflight_failed',
      message: 'Delivery gate blocked completion',
      data: {
        'root': projectRoot,
        'error_class': 'delivery',
        'error_kind': errorKind,
        'error': message,
      },
    );
    throw StateError(
      'Delivery preflight failed [delivery/$errorKind]: $message',
    );
  }

  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) {
    final layout = ProjectLayout(projectRoot);
    _ensureTasksFile(layout);

    final state = StateStore(layout.statePath).read();
    final activeTitle = state.activeTaskTitle;
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      throw StateError('No active task set. Use: activate');
    }
    final unattendedMode = _isUnattendedMode(layout);
    final subtaskId = state.currentSubtask?.trim();
    if (unattendedMode) {
      _unattendedBlockService.stashBlockContext(
        projectRoot,
        taskId: state.activeTaskId?.trim(),
        subtaskId: subtaskId,
      );
    }

    final match = _findActiveTask(layout, activeTitle);
    final writer = TaskWriter(layout.tasksPath);
    if (!writer.markBlocked(match, reason: reason)) {
      throw StateError('Failed to block task.');
    }

    RunLogStore(layout.runLogPath).append(
      event: 'task_blocked',
      message: 'Blocked task',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'reason': reason ?? '',
        if (state.activeTaskId != null && state.activeTaskId!.trim().isNotEmpty)
          'task_id': state.activeTaskId!.trim(),
        if (subtaskId != null && subtaskId.isNotEmpty) 'subtask_id': subtaskId,
        if (diagnostics != null) ...diagnostics,
      },
    );

    AuditTrailService().recordOutcome(
      projectRoot,
      outcome: 'blocked',
      reason: reason,
    );

    if (unattendedMode) {
      _unattendedBlockService.persistBlockStatus(
        projectRoot,
        taskTitle: activeTitle,
        reason: reason,
      );
    }

    return activeTitle;
  }

  Task _findActiveTask(ProjectLayout layout, String activeTitle) {
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final match = tasks.firstWhere(
      (task) => task.title == activeTitle,
      orElse: () => Task(
        title: activeTitle,
        priority: TaskPriority.p3,
        category: TaskCategory.unknown,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: -1,
      ),
    );
    if (match.lineIndex < 0) {
      throw StateError('Active task not found in TASKS.md');
    }
    return match;
  }

  void _ensureTasksFile(ProjectLayout layout) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
  }

  void _advanceWorkflowIfNeeded(String projectRoot) {
    final workflow = WorkflowService();
    final current = workflow.getStage(projectRoot);
    if (current == WorkflowStage.review) {
      workflow.transition(projectRoot, WorkflowStage.done);
    }
  }

  bool _isUnattendedMode(ProjectLayout layout) {
    return File(layout.autopilotLockPath).existsSync();
  }

  /// Removes any explicit cooldown entries for the completed task.
  void _clearTaskCooldown(ProjectLayout layout, ProjectState state) {
    if (state.taskCooldownUntil.isEmpty) {
      return;
    }
    final taskId = state.activeTaskId?.trim() ?? '';
    final taskTitle = state.activeTaskTitle?.trim() ?? '';
    if (taskId.isEmpty && taskTitle.isEmpty) {
      return;
    }
    final updated = Map<String, String>.from(state.taskCooldownUntil);
    var changed = false;
    if (taskId.isNotEmpty && updated.remove('id:$taskId') != null) {
      changed = true;
    }
    if (taskTitle.isNotEmpty) {
      final titleKey = 'title:${taskTitle.toLowerCase()}';
      if (updated.remove(titleKey) != null) {
        changed = true;
      }
    }
    if (changed) {
      final store = StateStore(layout.statePath);
      store.write(
        state.copyWith(
          retryScheduling: state.retryScheduling.copyWith(
            cooldownUntil: updated,
          ),
        ),
      );
    }
  }

  /// Clears subtask queue and current subtask from STATE.json so orphaned
  /// subtasks from a completed task are not re-activated later.
  void _clearSubtaskState(ProjectLayout layout) {
    final store = StateStore(layout.statePath);
    final state = store.read();
    if (state.subtaskQueue.isEmpty && state.currentSubtask == null) {
      return;
    }
    store.write(
      state.copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
        subtaskExecution: state.subtaskExecution.copyWith(
          queue: const [],
          current: null,
        ),
      ),
    );
  }

  /// Clears the active task state (id, title, review status) after task
  /// completion so state is clean for the next cycle.
  void _clearActiveTaskState(ProjectLayout layout) {
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Feature E: Runs a final AC verification against the full task spec.
  /// Non-blocking — logs result but does not abort completion.
  Future<void> _runFinalAcCheck(
    String projectRoot,
    ProjectLayout layout,
    String taskTitle,
  ) async {
    try {
      final slug = taskTitle.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final specFile = File('${layout.taskSpecsDir}/$slug.md');
      if (!specFile.existsSync()) return;

      final spec = specFile.readAsStringSync();
      final diffSummary = _gitService.isGitRepo(projectRoot)
          ? _gitService.diffSummary(projectRoot)
          : '';

      final result = await _specAgentService.checkImplementationAgainstAc(
        projectRoot,
        requirement: spec,
        diffSummary: diffSummary,
      );

      RunLogStore(layout.runLogPath).append(
        event: result.passed
            ? 'post_done_ac_check_passed'
            : 'post_done_ac_check_failed',
        message: result.reason ??
            (result.passed ? 'All ACs met' : 'AC check inconclusive'),
        data: {
          'root': projectRoot,
          'task': taskTitle,
          'skipped': result.skipped,
        },
      );
    } catch (_) {
      // Non-blocking: silently skip if AC check fails.
    }
  }

  /// Feature K: Logs which tasks are now unblocked by completion of [taskId].
  void _logUnblockedDependencies(
    String projectRoot,
    ProjectLayout layout,
    String taskId,
    String taskTitle,
  ) {
    try {
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final unblocked = tasks
          .where(
            (t) =>
                t.completion == TaskCompletion.open &&
                t.dependencyRefs.contains(taskId),
          )
          .map((t) => t.id)
          .toList(growable: false);
      if (unblocked.isNotEmpty) {
        RunLogStore(layout.runLogPath).append(
          event: 'task_dependencies_unblocked',
          message: 'Tasks unblocked by completion of "$taskTitle"',
          data: {
            'root': projectRoot,
            'completed_task_id': taskId,
            'unblocked': unblocked,
          },
        );
      }
    } catch (_) {
      // Non-critical: do not block task completion.
    }
  }
}
