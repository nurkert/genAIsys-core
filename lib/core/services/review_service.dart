// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../git/git_service.dart';
import '../models/workflow_stage.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import '../services/audit_trail_service.dart';
import 'workflow_service.dart';

class ReviewStatusSnapshot {
  ReviewStatusSnapshot({required this.status, required this.updatedAt});

  final String status;
  final String updatedAt;
}

class ReviewService {
  ReviewService({GitService? gitService})
    : _gitService = gitService ?? GitService();

  final GitService _gitService;

  ReviewStatusSnapshot status(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final state = StateStore(layout.statePath).read();
    final status = state.reviewStatus == null || state.reviewStatus!.isEmpty
        ? '(none)'
        : state.reviewStatus!;
    final updatedAt =
        state.reviewUpdatedAt == null || state.reviewUpdatedAt!.isEmpty
        ? '(none)'
        : state.reviewUpdatedAt!;
    return ReviewStatusSnapshot(status: status, updatedAt: updatedAt);
  }

  void clear(String projectRoot, {String? note}) {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final stateStore = StateStore(layout.statePath);
    final current = stateStore.read();
    final updated = current.copyWith(
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
      activeTask: current.activeTask.copyWith(
        reviewStatus: null,
        reviewUpdatedAt: null,
      ),
    );
    stateStore.write(updated);
    RunLogStore(layout.runLogPath).append(
      event: 'review_cleared',
      message: 'Cleared review status',
      data: {'root': projectRoot, 'note': note ?? ''},
    );

    if (current.workflowStage == WorkflowStage.review) {
      WorkflowService().transition(projectRoot, WorkflowStage.execution);
    }
  }

  String recordDecision(
    String projectRoot, {
    required String decision,
    String? note,
    String? testSummary,
  }) {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final stateStore = StateStore(layout.statePath);
    final state = stateStore.read();
    final activeTitle = state.activeTaskTitle;
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      // In unattended mode, missing active task during review decision can
      // result from aggressive state repair. Log and return a placeholder
      // rather than throwing, which would trigger cascading failures.
      if (File(ProjectLayout(projectRoot).autopilotLockPath).existsSync()) {
        RunLogStore(layout.runLogPath).append(
          event: 'review_decision_no_active_task',
          message: 'Review decision with no active task '
              '(unattended — skipping decision recording)',
          data: {
            'root': projectRoot,
            'decision': decision,
            'error_class': 'review',
            'error_kind': 'no_active_task',
          },
        );
        return '(unknown)';
      }
      throw StateError('No active task set. Use: activate');
    }

    final updated = state.copyWith(
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
      activeTask: state.activeTask.copyWith(
        reviewStatus: decision == 'approve' ? 'approved' : 'rejected',
        reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    stateStore.write(updated);

    RunLogStore(layout.runLogPath).append(
      event: 'review_$decision',
      message: 'Review decision recorded',
      data: {'root': projectRoot, 'task': activeTitle, 'note': note ?? ''},
    );

    AuditTrailService().recordReviewDecision(
      projectRoot,
      decision: decision,
      note: note,
      testSummary: testSummary,
    );

    _advanceWorkflowIfNeeded(projectRoot, state.workflowStage, decision);
    return activeTitle;
  }

  void normalizeAfterReject(String projectRoot, {String? note}) {
    if (!_isUnattendedMode(projectRoot)) {
      return;
    }

    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final state = StateStore(layout.statePath).read();
    final taskId = state.activeTaskId?.trim();
    final subtaskId = state.currentSubtask?.trim();
    var stashed = false;
    final stashMessage = _buildRejectStashMessage(
      taskId: taskId,
      subtaskId: subtaskId,
    );

    if (_gitService.isGitRepo(projectRoot) &&
        _gitService.hasChanges(projectRoot)) {
      try {
        stashed = _gitService.stashPush(
          projectRoot,
          message: stashMessage,
          includeUntracked: true,
        );
      } catch (error) {
        RunLogStore(layout.runLogPath).append(
          event: 'review_reject_autostash_failed',
          message: 'Failed to stash rejected worktree context',
          data: {
            'root': projectRoot,
            if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
            if (subtaskId != null && subtaskId.isNotEmpty)
              'subtask_id': subtaskId,
            'stash_message': stashMessage,
            'error': error.toString(),
          },
        );
      }
    }

    // Fallback: if stash failed or was partial and the worktree is still dirty,
    // discard the remaining changes. Rejected code is unwanted, and the
    // Clean-End guard in orchestrator_step_service provides a second safety net.
    if (!stashed && _gitService.hasChanges(projectRoot)) {
      try {
        _gitService.discardWorkingChanges(projectRoot);
        stashed = true;
      } catch (e) {
        // Log failure; Clean-End guard in orchestrator provides final safety net.
        RunLogStore(layout.runLogPath).append(
          event: 'review_reject_discard_failed',
          message: 'Failed to discard rejected working changes',
          data: {
            'root': projectRoot,
            'error': e.toString(),
            'error_class': 'git',
            'error_kind': 'discard_failed',
          },
        );
      }
    }

    // Fail-closed: if both stash and discard failed and the worktree is still
    // dirty, throw so the orchestrator can route to errorRecovery instead of
    // silently continuing with a dirty worktree.
    if (!stashed && _gitService.isGitRepo(projectRoot) &&
        _gitService.hasChanges(projectRoot)) {
      RunLogStore(layout.runLogPath).append(
        event: 'reject_cleanup_failed',
        message: 'Both stash and discard failed — worktree may be dirty.',
        data: {
          'root': projectRoot,
          if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
          if (subtaskId != null && subtaskId.isNotEmpty)
            'subtask_id': subtaskId,
          'error_class': 'git',
          'error_kind': 'reject_cleanup_failed',
        },
      );
      throw StateError(
        'reject_cleanup_failed: stash and discard both failed for $projectRoot',
      );
    }

    RunLogStore(layout.runLogPath).append(
      event: 'review_reject_autostash',
      message: stashed
          ? 'Stashed rejected worktree context for unattended retry'
          : 'No rejected worktree changes to stash for unattended retry',
      data: {
        'root': projectRoot,
        if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
        if (subtaskId != null && subtaskId.isNotEmpty) 'subtask_id': subtaskId,
        'stash_applied': stashed,
        'stash_message': stashMessage,
      },
    );

    clear(
      projectRoot,
      note: note ?? 'Auto-cleared review reject for unattended continuation.',
    );
  }

  void _ensureStateFile(ProjectLayout layout) {
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
  }

  bool _isUnattendedMode(String projectRoot) {
    return File(ProjectLayout(projectRoot).autopilotLockPath).existsSync();
  }

  String _buildRejectStashMessage({String? taskId, String? subtaskId}) {
    final taskToken = (taskId != null && taskId.isNotEmpty) ? taskId : 'none';
    final subtaskToken = (subtaskId != null && subtaskId.isNotEmpty)
        ? _sanitizeToken(subtaskId)
        : 'none';
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'genaisys:review-reject:$timestamp:task:$taskToken:subtask:$subtaskToken';
  }

  String _sanitizeToken(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[.-]+'), '')
        .replaceAll(RegExp(r'[.-]+$'), '');
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized;
  }

  void _advanceWorkflowIfNeeded(
    String projectRoot,
    WorkflowStage current,
    String decision,
  ) {
    final workflow = WorkflowService();
    var stage = current;
    if (stage == WorkflowStage.execution) {
      workflow.transition(projectRoot, WorkflowStage.review);
      stage = WorkflowStage.review;
    }
    if (stage != WorkflowStage.review) {
      return;
    }
    final target = decision == 'approve'
        ? WorkflowStage.done
        : WorkflowStage.execution;
    workflow.transition(projectRoot, target);
  }
}
