// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Remote, tag, and push/pull operations for [GitServiceImpl].
mixin _GitRemoteOps on _GitSharedState {
  void push(String path, String remote, String branch) {
    final trimmedRemote = remote.trim();
    final trimmedBranch = branch.trim();
    if (trimmedRemote.isEmpty || trimmedBranch.isEmpty) {
      throw ArgumentError('Remote and branch must not be empty.');
    }
    final result = _runGitNonInteractive(path, [
      'push',
      trimmedRemote,
      trimmedBranch,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to push $trimmedBranch to $trimmedRemote in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  ProcessResult pushDryRun(String path, String remote, String branch) {
    return _runGitNonInteractive(path, [
      'push',
      '--dry-run',
      remote.trim(),
      branch.trim(),
    ]);
  }

  void fetch(String path, String remote) {
    final trimmedRemote = remote.trim();
    if (trimmedRemote.isEmpty) {
      throw ArgumentError('Remote must not be empty.');
    }
    final result = _runGitNonInteractive(path, ['fetch', trimmedRemote]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to fetch from $trimmedRemote in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void pullFastForward(String path, String remote, String branch) {
    final trimmedRemote = remote.trim();
    final trimmedBranch = branch.trim();
    if (trimmedRemote.isEmpty || trimmedBranch.isEmpty) {
      throw ArgumentError('Remote and branch must not be empty.');
    }
    final result = _runGitNonInteractive(path, [
      'pull',
      '--ff-only',
      trimmedRemote,
      trimmedBranch,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to pull $trimmedBranch from $trimmedRemote in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  bool remoteBranchExists(String path, String remote, String branch) {
    final trimmedRemote = remote.trim();
    final trimmedBranch = branch.trim();
    if (trimmedRemote.isEmpty || trimmedBranch.isEmpty) {
      return false;
    }
    final normalizedBranch = trimmedBranch.startsWith('refs/heads/')
        ? trimmedBranch.substring('refs/heads/'.length)
        : trimmedBranch;
    final ref = normalizedBranch.startsWith('refs/remotes/')
        ? normalizedBranch
        : 'refs/remotes/$trimmedRemote/$normalizedBranch';
    final result = _runGit(path, ['show-ref', '--verify', '--quiet', ref]);
    return result.exitCode == 0;
  }

  bool hasRemote(String path, String remote) {
    final trimmedRemote = remote.trim();
    if (trimmedRemote.isEmpty) {
      return false;
    }
    final result = _runGit(path, ['remote', 'get-url', trimmedRemote]);
    return result.exitCode == 0;
  }

  String? defaultRemote(String path) {
    final result = _runGit(path, ['remote']);
    if (result.exitCode != 0) {
      throw StateError('Unable to list remotes for: $path');
    }
    final lines = result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }
    if (lines.contains('origin')) {
      return 'origin';
    }
    return lines.first;
  }

  bool tagExists(String path, String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final ref = 'refs/tags/$trimmed';
    final result = _runGit(path, ['show-ref', '--verify', '--quiet', ref]);
    return result.exitCode == 0;
  }

  void createAnnotatedTag(String path, String tag, {required String message}) {
    final trimmedTag = tag.trim();
    final trimmedMessage = message.trim();
    if (trimmedTag.isEmpty) {
      throw ArgumentError('Tag must not be empty.');
    }
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Tag message must not be empty.');
    }
    final result = _runGit(path, [
      'tag',
      '-a',
      trimmedTag,
      '-m',
      trimmedMessage,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to create tag $trimmedTag in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }

  void pushTag(String path, String remote, String tag) {
    final trimmedRemote = remote.trim();
    final trimmedTag = tag.trim();
    if (trimmedRemote.isEmpty || trimmedTag.isEmpty) {
      throw ArgumentError('Remote and tag must not be empty.');
    }
    final result = _runGitNonInteractive(path, [
      'push',
      trimmedRemote,
      'refs/tags/$trimmedTag',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to push tag $trimmedTag to $trimmedRemote in: $path\n${result.stderr.toString().trim()}',
      );
    }
  }
}
