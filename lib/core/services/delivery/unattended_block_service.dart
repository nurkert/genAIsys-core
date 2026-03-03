// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../git/git_service.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

/// Handles dirty-worktree stashing and git persistence of block status
/// during unattended (autopilot) task blocking.
class UnattendedBlockService {
  UnattendedBlockService({GitService? gitService})
      : _gitService = gitService ?? GitService();

  final GitService _gitService;

  /// Stashes any dirty worktree state before an unattended block, so the
  /// clean-end invariant is maintained.
  void stashBlockContext(
    String projectRoot, {
    String? taskId,
    String? subtaskId,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return;
    }
    if (!_gitService.hasChanges(projectRoot)) {
      return;
    }
    final layout = ProjectLayout(projectRoot);
    final message = buildBlockContextStashMessage(
      taskId: taskId,
      subtaskId: subtaskId,
    );
    var stashed = false;
    try {
      stashed = _gitService.stashPush(
        projectRoot,
        message: message,
        includeUntracked: true,
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'task_block_context_stash_failed',
        message: 'Failed to stash dirty worktree before unattended block',
        data: {
          'root': projectRoot,
          if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
          if (subtaskId != null && subtaskId.isNotEmpty)
            'subtask_id': subtaskId,
          'stash_message': message,
          'error': error.toString(),
        },
      );
      return;
    }
    if (!stashed) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'task_block_context_stashed',
      message: 'Stashed dirty worktree before unattended block persistence',
      data: {
        'root': projectRoot,
        if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
        if (subtaskId != null && subtaskId.isNotEmpty) 'subtask_id': subtaskId,
        'stash_message': message,
      },
    );
  }

  /// Persists the block status (TASKS.md update, state changes) as a git
  /// commit and optionally pushes to remote.
  void persistBlockStatus(
    String projectRoot, {
    required String taskTitle,
    String? reason,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return;
    }

    final layout = ProjectLayout(projectRoot);
    final commitMessage = buildBlockCommitMessage(taskTitle, reason: reason);
    try {
      // Stage everything including .genaisys/ meta-files (TASKS.md block
      // status). GitService.hasChanges() filters internal paths so it cannot
      // be used as an early-return guard here.
      _gitService.addAll(projectRoot);
      if (!_gitService.hasStagedChanges(projectRoot)) {
        return;
      }
      _gitService.commit(projectRoot, commitMessage);
      final remote = _gitService.defaultRemote(projectRoot);
      if (remote != null && remote.trim().isNotEmpty) {
        final branch = _gitService.currentBranch(projectRoot);
        _gitService.push(projectRoot, remote, branch);
      }
      RunLogStore(layout.runLogPath).append(
        event: 'task_block_meta_commit',
        message: 'Persisted unattended block status in git',
        data: {
          'root': projectRoot,
          'task': taskTitle,
          'reason': reason ?? '',
          'commit_message': commitMessage,
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'task_block_meta_commit_failed',
        message: 'Failed to persist unattended block status',
        data: {
          'root': projectRoot,
          'task': taskTitle,
          'reason': reason ?? '',
          'commit_message': commitMessage,
          'error': error.toString(),
        },
      );
      fallbackStashBlockStatus(
        projectRoot,
        taskTitle: taskTitle,
        reason: reason,
        failure: error.toString(),
      );
    }
  }

  /// Falls back to stashing when the block-status commit fails.
  void fallbackStashBlockStatus(
    String projectRoot, {
    required String taskTitle,
    String? reason,
    required String failure,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return;
    }
    // No hasChanges() guard — same reason as persistBlockStatus: the dirty
    // files may be .genaisys/ meta-files that hasChanges() filters out.
    final layout = ProjectLayout(projectRoot);
    final taskToken = sanitizeToken(taskTitle);
    final message = 'genaisys:block-meta-fallback:task:$taskToken';
    var stashed = false;
    try {
      stashed = _gitService.stashPush(
        projectRoot,
        message: message,
        includeUntracked: true,
      );
    } catch (_) {
      stashed = false;
    }
    RunLogStore(layout.runLogPath).append(
      event: stashed ? 'task_block_meta_stashed' : 'task_block_meta_dirty',
      message: stashed
          ? 'Stashed unattended block status as fallback after commit failure'
          : 'Unattended block status remains dirty after commit failure',
      data: {
        'root': projectRoot,
        'task': taskTitle,
        'reason': reason ?? '',
        'failure': failure,
        'stash_message': message,
        'stash_applied': stashed,
      },
    );
  }

  /// Builds the stash message for block-context stashing.
  String buildBlockContextStashMessage({String? taskId, String? subtaskId}) {
    final taskToken = (taskId != null && taskId.isNotEmpty) ? taskId : 'none';
    final subtaskToken = (subtaskId != null && subtaskId.isNotEmpty)
        ? sanitizeToken(subtaskId)
        : 'none';
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'genaisys:task-block-context:$timestamp:task:$taskToken:subtask:$subtaskToken';
  }

  /// Builds the commit message for block-status persistence.
  String buildBlockCommitMessage(String taskTitle, {String? reason}) {
    final taskToken = sanitizeToken(taskTitle);
    final reasonToken = reason == null || reason.trim().isEmpty
        ? ''
        : ' (${truncate(reason.trim(), 60)})';
    return 'meta(task): block $taskToken$reasonToken';
  }

  /// Sanitizes a string for use in git messages/refs.
  String sanitizeToken(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[.-]+'), '')
        .replaceAll(RegExp(r'[.-]+$'), '');
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized;
  }

  /// Truncates text to a maximum length, appending '...' if truncated.
  String truncate(String text, int maxLength) {
    if (maxLength <= 0 || text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

}
