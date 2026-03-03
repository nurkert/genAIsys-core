// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../git/git_service.dart';

/// Result of an inter-loop git sync operation.
class GitSyncResult {
  const GitSyncResult({
    required this.synced,
    this.conflictsDetected = false,
    this.conflictPaths = const [],
    this.errorMessage,
  });

  final bool synced;
  final bool conflictsDetected;
  final List<String> conflictPaths;
  final String? errorMessage;
}

/// Synchronises the local branch with the remote between autopilot loops.
///
/// Supports three strategies:
/// - `fetch_only`: Only fetches remote refs without merging.
/// - `pull_ff`: Fetches and fast-forward merges the current branch.
/// - `rebase`: Fetches and rebases the current branch onto remote.
class GitSyncService {
  GitSyncService({GitService? gitService})
    : _gitService = gitService ?? GitService();

  final GitService _gitService;

  /// Performs a git sync before an autopilot loop iteration.
  ///
  /// Returns a [GitSyncResult] indicating whether the sync succeeded and
  /// whether merge conflicts were detected (for pull_ff/rebase strategies).
  GitSyncResult syncBeforeLoop(String projectRoot, {required String strategy}) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) {
        return const GitSyncResult(synced: false, errorMessage: 'not_a_repo');
      }

      final remote = _gitService.defaultRemote(projectRoot);
      if (remote == null || !_gitService.hasRemote(projectRoot, remote)) {
        return const GitSyncResult(synced: false, errorMessage: 'no_remote');
      }

      _gitService.fetch(projectRoot, remote);

      if (strategy == 'fetch_only') {
        return const GitSyncResult(synced: true);
      }

      final branch = _gitService.currentBranch(projectRoot);

      if (strategy == 'pull_ff') {
        try {
          _gitService.pullFastForward(projectRoot, remote, branch);
          return const GitSyncResult(synced: true);
        } catch (e) {
          // Check for merge conflicts.
          if (_gitService.hasMergeInProgress(projectRoot)) {
            final conflicts = _gitService.conflictPaths(projectRoot);
            _gitService.abortMerge(projectRoot);
            return GitSyncResult(
              synced: false,
              conflictsDetected: true,
              conflictPaths: conflicts,
              errorMessage: 'merge_conflict',
            );
          }
          return GitSyncResult(synced: false, errorMessage: 'pull_failed: $e');
        }
      }

      // Unknown strategy — treat as fetch_only.
      return const GitSyncResult(synced: true);
    } catch (e) {
      return GitSyncResult(synced: false, errorMessage: 'sync_error: $e');
    }
  }
}
