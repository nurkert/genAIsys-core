// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Core infrastructure mixin for [GitServiceImpl].
///
/// Provides the shared process runner, private helper methods, and abstract
/// cross-mixin declarations that allow category mixins to call one another.
mixin _GitSharedState {
  // ---------------------------------------------------------------------------
  // Abstract: provided by [GitServiceImpl] via a final field
  // ---------------------------------------------------------------------------

  GitProcessRunner get _processRunner;

  // ---------------------------------------------------------------------------
  // Abstract: cross-mixin references (implemented by category mixins).
  // Declared here so that each category mixin (which depends on _GitSharedState
  // via `on _GitSharedState`) can call these methods on `this`.
  // ---------------------------------------------------------------------------

  bool hasChanges(String path);
  bool isClean(String path);
  int stashCount(String path);
  String currentBranch(String path);
  bool branchExists(String path, String branch);

  // ---------------------------------------------------------------------------
  // Concrete: process runner wrappers
  // ---------------------------------------------------------------------------

  ProcessResult _runGit(String path, List<String> args) {
    return _processRunner(
      'git',
      args,
      workingDirectory: path,
      runInShell: false,
    );
  }

  ProcessResult _runGitNonInteractive(String path, List<String> args) {
    return _processRunner(
      'git',
      args,
      workingDirectory: path,
      runInShell: false,
      environment: const {
        'GIT_TERMINAL_PROMPT': '0',
        'GCM_INTERACTIVE': 'Never',
        // Ensure remote operations fail closed instead of hanging on SSH prompts
        // (host key confirmation, passphrase, etc.). This must remain stable for
        // unattended mode.
        'GIT_SSH_COMMAND': 'ssh -oBatchMode=yes -oConnectTimeout=15',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Concrete: shared path helpers
  // ---------------------------------------------------------------------------

  bool _isInternalPath(String path) {
    final normalized = path.replaceAll('\\', '/').trimLeft();
    if (normalized == '.genaisys' || normalized == '.genaisys/') {
      return true;
    }
    return normalized.startsWith('.genaisys/');
  }

  bool _isTaskBranch(String branch, {required ProjectConfig config}) {
    final trimmed = branch.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final primary = config.gitFeaturePrefix.trim();
    return trimmed.startsWith(primary) ||
        trimmed.startsWith('feat/') ||
        trimmed.startsWith('fix/');
  }

  List<String> _statusPaths(String path) {
    final result = _runGit(path, ['status', '--porcelain']);
    if (result.exitCode != 0) {
      throw StateError('Unable to read git status for: $path');
    }
    final lines = result.stdout.toString().split('\n');
    final paths = <String>{};
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final isUntrackedEntry = line.startsWith('?? ');
      final entry = line.length > 3 ? line.substring(3).trim() : '';
      if (entry.isEmpty) {
        continue;
      }
      final resolved = entry.contains(' -> ')
          ? entry.split(' -> ').last.trim()
          : entry;
      if (resolved.isEmpty) {
        continue;
      }
      if (_isInternalPath(resolved)) {
        continue;
      }
      // `git status --porcelain` collapses untracked directories as `dir/`.
      // Use explicit untracked file listing below so policy checks can match
      // concrete file targets instead of directory placeholders.
      if (isUntrackedEntry && resolved.endsWith('/')) {
        continue;
      }
      paths.add(resolved);
    }
    for (final untracked in _untrackedPaths(path)) {
      paths.add(untracked);
    }
    return List<String>.unmodifiable(paths.toList()..sort());
  }

  List<String> _untrackedPaths(String path) {
    // `git status --porcelain` collapses untracked directories (e.g. "?? lib/"),
    // which breaks evidence generation for new files. `ls-files` returns files.
    final result = _runGit(path, [
      'ls-files',
      '--others',
      '--exclude-standard',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Unable to list untracked files for: $path');
    }
    final lines = result.stdout.toString().split('\n');
    final paths = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (_isInternalPath(trimmed)) {
        continue;
      }
      paths.add(trimmed);
    }
    return paths;
  }

  String _emptyPathSentinel(String repoPath) {
    // Prefer /dev/null, but fall back to Windows' NUL when available.
    for (final candidate in const ['/dev/null', 'NUL']) {
      final probe = _runGit(repoPath, [
        'diff',
        '--no-index',
        '--',
        candidate,
        candidate,
      ]);
      if (probe.exitCode == 0 || probe.exitCode == 1) {
        return candidate;
      }
    }
    // As a last resort, try /dev/null and let the diff call surface the error.
    return '/dev/null';
  }

  ProcessResult _diffNoIndex(String path, List<String> args) {
    final result = _runGit(path, args);
    // `git diff --no-index` returns exit code 1 when differences exist.
    if (result.exitCode == 0 || result.exitCode == 1) {
      return result;
    }
    throw StateError(
      'Unable to run git diff --no-index in: $path\n${result.stderr.toString().trim()}',
    );
  }
}
