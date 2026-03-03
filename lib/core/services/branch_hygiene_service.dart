// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../config/project_config.dart';
import '../git/git_service.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';

class BranchCleanupResult {
  const BranchCleanupResult({
    required this.baseBranch,
    required this.dryRun,
    required this.deletedLocalBranches,
    required this.deletedRemoteBranches,
    required this.skippedBranches,
    required this.failures,
  });

  final String baseBranch;
  final bool dryRun;
  final List<String> deletedLocalBranches;
  final List<String> deletedRemoteBranches;
  final List<String> skippedBranches;
  final List<String> failures;
}

class BranchHygieneService {
  BranchHygieneService({GitService? gitService})
    : _gitService = gitService ?? GitService();

  final GitService _gitService;

  BranchCleanupResult cleanupMergedBranches(
    String projectRoot, {
    String? baseBranch,
    String? remote,
    bool includeRemote = false,
    bool dryRun = false,
    bool onlyFeaturePrefixed = true,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return const BranchCleanupResult(
        baseBranch: '',
        dryRun: false,
        deletedLocalBranches: <String>[],
        deletedRemoteBranches: <String>[],
        skippedBranches: <String>[],
        failures: <String>['not_git_repo'],
      );
    }

    final config = ProjectConfig.load(projectRoot);
    final resolvedBase = (baseBranch == null || baseBranch.trim().isEmpty)
        ? config.gitBaseBranch
        : baseBranch.trim();
    final resolvedRemote = (remote == null || remote.trim().isEmpty)
        ? null
        : remote.trim();

    final allowedPrefixes = <String>{
      config.gitFeaturePrefix.trim(),
      'feat/',
      'fix/',
      // Common task branch prefixes used in practice. This list is intentionally
      // small; users can still opt into cleaning all merged branches via config
      // or CLI flags in the future.
      'chore/',
      'refactor/',
      'docs/',
      'test/',
      'ci/',
      'build/',
      'perf/',
      'rc/',
    }.where((value) => value.isNotEmpty).toList(growable: false);

    final merged = _gitService.localBranchesMergedInto(
      projectRoot,
      resolvedBase,
    );
    final current = _gitService.currentBranch(projectRoot).trim();

    // Always ensure we're not attempting to delete the currently checked-out
    // branch during cleanup. If we are currently on a merged feature branch,
    // switch to base first.
    if (current != resolvedBase && merged.contains(current)) {
      try {
        _gitService.checkout(projectRoot, resolvedBase);
      } catch (_) {
        // Best-effort: keep going; deletion will skip current branch.
      }
    }

    final deletedLocal = <String>[];
    final deletedRemote = <String>[];
    final skipped = <String>[];
    final failures = <String>[];

    for (final branch in merged) {
      final trimmed = branch.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed == resolvedBase) {
        skipped.add(trimmed);
        continue;
      }
      if (trimmed == _gitService.currentBranch(projectRoot).trim()) {
        skipped.add(trimmed);
        continue;
      }
      if (onlyFeaturePrefixed &&
          !allowedPrefixes.any((prefix) => trimmed.startsWith(prefix))) {
        skipped.add(trimmed);
        continue;
      }

      if (dryRun) {
        skipped.add(trimmed);
        continue;
      }

      try {
        _gitService.deleteBranch(projectRoot, trimmed);
        deletedLocal.add(trimmed);
      } catch (error) {
        failures.add('local:$trimmed:${error.toString()}');
        continue;
      }

      if (!includeRemote || resolvedRemote == null) {
        continue;
      }
      try {
        _gitService.deleteRemoteBranch(projectRoot, resolvedRemote, trimmed);
        deletedRemote.add('$resolvedRemote/$trimmed');
      } catch (error) {
        failures.add('remote:$resolvedRemote/$trimmed:${error.toString()}');
      }
    }

    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'git_branch_cleanup',
      message: dryRun
          ? 'Branch cleanup dry-run completed'
          : 'Branch cleanup completed',
      data: {
        'root': projectRoot,
        'base_branch': resolvedBase,
        'remote': resolvedRemote ?? '',
        'include_remote': includeRemote,
        'dry_run': dryRun,
        'deleted_local_count': deletedLocal.length,
        'deleted_remote_count': deletedRemote.length,
        'skipped_count': skipped.length,
        'failure_count': failures.length,
        'error_class': 'delivery',
        'error_kind': 'branch_cleanup',
      },
    );

    return BranchCleanupResult(
      baseBranch: resolvedBase,
      dryRun: dryRun,
      deletedLocalBranches: List<String>.unmodifiable(deletedLocal),
      deletedRemoteBranches: List<String>.unmodifiable(deletedRemote),
      skippedBranches: List<String>.unmodifiable(skipped),
      failures: List<String>.unmodifiable(failures),
    );
  }
}
