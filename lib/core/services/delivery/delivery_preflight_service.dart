// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../policy/diff_budget_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

/// Runs delivery preflight checks: git cleanliness, branch context, diff budget,
/// and upstream synchronisation before allowing task completion.
class DeliveryPreflightService {
  DeliveryPreflightService({GitService? gitService})
      : _gitService = gitService ?? GitService();

  final GitService _gitService;

  /// Runs all delivery preflight checks for the given project root.
  ///
  /// Throws [StateError] with a delivery gate failure if any check fails.
  void deliveryPreflight(String projectRoot, {required ProjectLayout layout}) {
    if (!_gitService.isGitRepo(projectRoot)) {
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_skipped',
        message: 'Delivery preflight skipped: project is not a git repository',
        data: {
          'root': projectRoot,
          'error_class': 'delivery',
          'error_kind': 'not_git_repo',
        },
      );
      return;
    }
    if (_gitService.hasMergeInProgress(projectRoot)) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'merge_conflict',
        message: 'Merge in progress. Resolve conflicts before delivery.',
      );
    }
    if (!_gitService.isClean(projectRoot)) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'git_dirty',
        message: 'Git index/worktree must be clean before delivery.',
      );
    }

    final config = ProjectConfig.load(projectRoot);
    final branch = _gitService.currentBranch(projectRoot).trim();
    final baseBranch = config.gitBaseBranch.trim().isEmpty
        ? 'main'
        : config.gitBaseBranch.trim();
    final featurePrefix = config.gitFeaturePrefix.trim().isEmpty
        ? 'feat/'
        : config.gitFeaturePrefix.trim();
    final expectedContext =
        branch == baseBranch || isTaskBranch(branch, config: config);
    if (!expectedContext) {
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'branch_context',
        message:
            'Unexpected branch context "$branch". Expected "$baseBranch" or prefix "$featurePrefix".',
      );
    }

    // Diff-budget enforcement at commit time.
    if (isTaskBranch(branch, config: config) &&
        _gitService.branchExists(projectRoot, baseBranch)) {
      enforceDiffBudgetAtCommit(
        projectRoot,
        config: config,
        baseBranch: baseBranch,
        featureBranch: branch,
      );
    }

    // When auto_push is disabled, skip all remote-dependent checks.
    // Local-only delivery still validates git state, branch context, and diff
    // budget above, but does not require a configured remote.
    if (!config.workflowAutoPush) {
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_passed',
        message:
            'Delivery preflight passed (auto_push disabled, remote skipped)',
        data: {
          'root': projectRoot,
          'branch': branch,
          'base_branch': baseBranch,
          'auto_push': false,
        },
      );
      return;
    }

    final remote = _gitService.defaultRemote(projectRoot);
    if (remote == null || remote.trim().isEmpty) {
      // No remote configured but auto_push is true.  This typically happens
      // when a project is initialised locally and no remote has been added yet.
      // Downgrade to a warning rather than blocking delivery entirely.
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_no_remote_warning',
        message:
            'No git remote configured — delivery preflight skipping remote checks',
        data: {
          'root': projectRoot,
          'branch': branch,
          'base_branch': baseBranch,
          'error_class': 'delivery',
          'error_kind': 'no_remote',
          'auto_push': true,
        },
      );
      return;
    }

    try {
      _gitService.fetch(projectRoot, remote);
      final hasRemoteRef = _gitService.remoteBranchExists(
        projectRoot,
        remote,
        branch,
      );
      if (hasRemoteRef) {
        _gitService.pullFastForward(projectRoot, remote, branch);
      } else {
        // Feature branches may be local-only (unpublished). Base branch sync is
        // enforced during the merge flow.
        RunLogStore(layout.runLogPath).append(
          event: 'delivery_preflight_upstream_skipped',
          message: 'Delivery preflight upstream check skipped: no remote ref',
          data: {
            'root': projectRoot,
            'branch': branch,
            'remote': remote,
            'error_class': 'delivery',
            'error_kind': branch == baseBranch
                ? 'upstream_missing'
                : 'upstream_missing_optional',
          },
        );
        if (branch == baseBranch) {
          _deliveryGateFailure(
            projectRoot,
            errorKind: 'upstream_missing',
            message: 'Upstream ref missing for base branch "$baseBranch".',
          );
        }
      }
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'delivery_preflight_failed',
        message: 'Delivery preflight upstream check failed',
        data: {
          'root': projectRoot,
          'branch': branch,
          'remote': remote,
          'error_class': 'delivery',
          'error_kind': 'upstream_diverged',
          'error': error.toString(),
        },
      );
      _deliveryGateFailure(
        projectRoot,
        errorKind: 'upstream_diverged',
        message: 'Branch "$branch" cannot fast-forward from upstream: $error',
      );
    }

    RunLogStore(layout.runLogPath).append(
      event: 'delivery_preflight_passed',
      message: 'Delivery preflight passed',
      data: {
        'root': projectRoot,
        'branch': branch,
        'base_branch': baseBranch,
        'remote': remote,
      },
    );
  }

  /// Enforces the diff budget at commit time by comparing the feature branch
  /// against the base branch.
  void enforceDiffBudgetAtCommit(
    String projectRoot, {
    required ProjectConfig config,
    required String baseBranch,
    required String featureBranch,
  }) {
    final budget = DiffBudget(
      maxFiles: config.diffBudgetMaxFiles,
      maxAdditions: config.diffBudgetMaxAdditions,
      maxDeletions: config.diffBudgetMaxDeletions,
    );
    try {
      final stats = _gitService.diffStatsBetween(
        projectRoot,
        baseBranch,
        featureBranch,
      );
      final policy = DiffBudgetPolicy(budget: budget);
      if (!policy.allows(stats)) {
        _deliveryGateFailure(
          projectRoot,
          errorKind: 'diff_budget_at_commit',
          message:
              'Diff budget exceeded at commit time '
              '(files ${stats.filesChanged}/${budget.maxFiles}, '
              'additions ${stats.additions}/${budget.maxAdditions}, '
              'deletions ${stats.deletions}/${budget.maxDeletions}). '
              'Split the task or raise policies.diff_budget in config.yml.',
        );
      }
    } catch (e) {
      if (e is StateError && e.message.contains('diff_budget_at_commit')) {
        rethrow;
      }
      // Non-fatal: if diff stats comparison fails (e.g. no common ancestor),
      // log and continue — the pre-review diff check already passed.
      final layout = ProjectLayout(projectRoot);
      RunLogStore(layout.runLogPath).append(
        event: 'diff_budget_commit_check_skipped',
        message: 'Diff budget commit-time check skipped due to error',
        data: {
          'root': projectRoot,
          'base_branch': baseBranch,
          'feature_branch': featureBranch,
          'error_class': 'delivery',
          'error_kind': 'diff_budget_check_error',
          'error': e.toString(),
        },
      );
    }
  }

  /// Returns whether the given branch name matches a task branch pattern.
  bool isTaskBranch(String branch, {required ProjectConfig config}) {
    final trimmed = branch.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final primary = config.gitFeaturePrefix.trim();
    // Genaisys convention supports both feat/ and fix/ branches.
    return trimmed.startsWith(primary) ||
        trimmed.startsWith('feat/') ||
        trimmed.startsWith('fix/');
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
}
