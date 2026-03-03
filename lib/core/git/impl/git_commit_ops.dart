// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Staging, commit, and working-tree cleanup operations for [GitServiceImpl].
mixin _GitCommitOps on _GitSharedState {
  void addAll(String path) {
    final result = _runGit(path, ['add', '-A']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to add changes in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void commit(String path, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Commit message must not be empty.');
    }
    final result = _runGit(path, ['commit', '--no-gpg-sign', '-m', trimmed]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to commit in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void resetIndex(String path) {
    final result = _runGit(path, ['reset', 'HEAD']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to reset index in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  bool hasStagedChanges(String path) {
    final result = _runGit(path, ['diff', '--cached', '--quiet']);
    // Exit code 0 means no staged changes, 1 means there are staged changes.
    return result.exitCode == 1;
  }

  void hardReset(String path, {String ref = 'HEAD'}) {
    final result = _runGit(path, ['reset', '--hard', ref]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to hard reset to $ref in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void discardWorkingChanges(String path) {
    _runGit(path, ['checkout', '.']);
    _runGit(path, ['clean', '-fd']);
  }

  void cleanUntracked(String path) {
    final result = _runGit(path, ['clean', '-fd']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to clean untracked files in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void removeFromIndexIfTracked(String path, List<String> relativePaths) {
    if (relativePaths.isEmpty) return;
    final result = _runGit(path, [
      'rm',
      '--cached',
      '-r',
      '--ignore-unmatch',
      '--quiet',
      ...relativePaths,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'git rm --cached failed in: $path\n${result.stderr}',
      );
    }

    // Verify removal: check that none of the paths are still in the index.
    // This catches silent failures where `git rm --cached` succeeds but the
    // file remains tracked (e.g. due to submodule or sparse-checkout edge
    // cases).
    for (final relativePath in relativePaths) {
      final verify = _runGit(
        path,
        ['ls-files', '--error-unmatch', relativePath],
      );
      // Exit code 0 means the file is still tracked — removal failed silently.
      if (verify.exitCode == 0) {
        stderr.writeln(
          'WARNING: removeFromIndexIfTracked: "$relativePath" is still '
          'tracked after git rm --cached in: $path',
        );
      }
    }
  }
}
