// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Branch, merge, and checkout operations for [GitServiceImpl].
mixin _GitBranchOps on _GitSharedState {
  bool branchExists(String path, String branch) {
    final trimmed = branch.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final ref = trimmed.startsWith('refs/') ? trimmed : 'refs/heads/$trimmed';
    final result = _runGit(path, ['show-ref', '--verify', '--quiet', ref]);
    return result.exitCode == 0;
  }

  List<String> localBranchesMergedInto(String path, String baseRef) {
    final trimmedBase = baseRef.trim();
    if (trimmedBase.isEmpty) {
      throw ArgumentError('Base ref must not be empty.');
    }
    final result = _runGit(path, ['branch', '--merged', trimmedBase]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to list merged branches into $trimmedBase in: $path\n${result.stderr.toString().trim()}',
      );
    }
    final lines = result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('* ') ? line.substring(2) : line)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines;
  }

  void checkout(String path, String ref) {
    final result = _runGit(path, ['checkout', ref]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to checkout $ref in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void createBranch(String path, String branch, {String? startPoint}) {
    final args = ['checkout', '-b', branch];
    if (startPoint != null && startPoint.trim().isNotEmpty) {
      args.add(startPoint);
    }
    final result = _runGit(path, args);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to create branch $branch in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void merge(String path, String branch) {
    final result = _runGit(path, ['merge', branch]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to merge $branch in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  List<String> conflictPaths(String path) {
    final result = _runGit(path, ['diff', '--name-only', '--diff-filter=U']);
    if (result.exitCode != 0) {
      throw StateError('Unable to list merge conflicts for: $path');
    }
    return result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool hasMergeInProgress(String path) {
    final result = _runGit(path, ['rev-parse', '-q', '--verify', 'MERGE_HEAD']);
    return result.exitCode == 0;
  }

  void abortMerge(String path) {
    final result = _runGit(path, ['merge', '--abort']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to abort merge in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void deleteBranch(String path, String branch, {bool force = false}) {
    final result = _runGit(path, ['branch', force ? '-D' : '-d', branch]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to delete branch $branch in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void deleteRemoteBranch(String path, String remote, String branch) {
    final trimmedRemote = remote.trim();
    final trimmedBranch = branch.trim();
    if (trimmedRemote.isEmpty || trimmedBranch.isEmpty) {
      throw ArgumentError('Remote and branch must not be empty.');
    }
    final result = _runGitNonInteractive(path, [
      'push',
      trimmedRemote,
      '--delete',
      trimmedBranch,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to delete remote branch $trimmedRemote/$trimmedBranch in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  bool hasRebaseInProgress(String path) {
    final result =
        _runGit(path, ['rev-parse', '-q', '--verify', 'REBASE_HEAD']);
    return result.exitCode == 0;
  }
}
