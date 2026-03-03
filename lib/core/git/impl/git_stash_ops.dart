// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Stash operations for [GitServiceImpl].
mixin _GitStashOps on _GitSharedState {
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    final args = ['stash', 'push'];
    if (includeUntracked) {
      args.add('-u');
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isNotEmpty) {
      args.addAll(['-m', trimmedMessage]);
    }
    final result = _runGit(path, args);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to stash changes in: $path\n${result.stderr.toString().trim()}',
      );
    }
    final output = result.stdout.toString();
    if (output.contains('No local changes to save')) {
      // Verify the worktree is actually clean. If stash reports nothing to
      // save but the worktree is still dirty, something went wrong and we
      // must not silently continue.
      if (!isClean(path)) {
        final dirty = _statusPaths(path);
        throw StateError(
          'stashPush reported no changes to save but worktree is still dirty '
          'in: $path\nDirty paths: ${dirty.join(', ')}',
        );
      }
      return false;
    }
    return true;
  }

  void stashPop(String path) {
    final result = _runGit(path, ['stash', 'pop']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to re-apply stashed changes in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  int stashCount(String path) {
    final result = _runGit(path, ['stash', 'list']);
    if (result.exitCode != 0) return 0;
    final output = result.stdout.toString().trim();
    if (output.isEmpty) return 0;
    return output.split('\n').length;
  }

  void dropOldestStashes(String path, {required int maxKeep}) {
    final count = stashCount(path);
    if (count <= maxKeep) return;
    // Drop from the bottom (oldest first). Stash indices shift after each
    // drop, so always drop the last entry repeatedly.
    for (var i = 0; i < count - maxKeep; i++) {
      final result =
          _runGit(path, ['stash', 'drop', 'stash@{${count - 1 - i}}']);
      if (result.exitCode != 0) break;
    }
  }
}
