// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Repository state and history operations for [GitServiceImpl].
mixin _GitHistoryOps on _GitSharedState {
  bool isGitRepo(String path) {
    final result = _runGit(path, ['rev-parse', '--is-inside-work-tree']);
    if (result.exitCode != 0) {
      return false;
    }
    return result.stdout.toString().trim() == 'true';
  }

  String repoRoot(String path) {
    final result = _runGit(path, ['rev-parse', '--show-toplevel']);
    if (result.exitCode != 0) {
      throw StateError('Not a git repository: $path');
    }
    return result.stdout.toString().trim();
  }

  String currentBranch(String path) {
    final symbolic = _runGit(path, ['symbolic-ref', '--short', 'HEAD']);
    if (symbolic.exitCode == 0) {
      return symbolic.stdout.toString().trim();
    }
    final result = _runGit(path, ['rev-parse', '--abbrev-ref', 'HEAD']);
    if (result.exitCode != 0) {
      throw StateError('Unable to read branch for: $path');
    }
    return result.stdout.toString().trim();
  }

  bool isClean(String path) {
    return !hasChanges(path);
  }

  void ensureClean(String path) {
    if (!isClean(path)) {
      throw StateError('Repository has uncommitted changes: $path');
    }
  }

  String headCommitSha(String path, {bool short = false}) {
    final args = short
        ? const ['rev-parse', '--short', 'HEAD']
        : const ['rev-parse', 'HEAD'];
    final result = _runGit(path, args);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to read HEAD commit SHA in: $path\n${result.stderr.toString().trim()}',
      );
    }
    return result.stdout.toString().trim();
  }

  List<String> recentCommitMessages(String path, {int count = 10}) {
    final normalizedCount = count < 1 ? 1 : count;
    final result = _runGit(path, ['log', '--oneline', '-$normalizedCount']);
    if (result.exitCode != 0) {
      return const [];
    }
    return result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  int commitCount(String path) {
    final result = _runGit(path, ['rev-list', '--count', 'HEAD']);
    if (result.exitCode != 0) {
      return 0;
    }
    return int.tryParse(result.stdout.toString().trim()) ?? 0;
  }

  bool isCommitReachable(String path, String sha) {
    if (sha.trim().isEmpty) return false;
    final result = _runGit(path, ['cat-file', '-e', sha]);
    return result.exitCode == 0;
  }
}
