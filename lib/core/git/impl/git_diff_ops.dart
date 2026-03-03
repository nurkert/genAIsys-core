// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../git_service.dart';

/// Diff and working-tree status operations for [GitServiceImpl].
mixin _GitDiffOps on _GitSharedState {
  bool hasChanges(String path) {
    // Direct porcelain scan: does NOT skip `?? dir/` entries so untracked
    // directories are caught without the fragile ls-files expansion that
    // changedPaths() relies on.
    final result = _runGit(path, ['status', '--porcelain']);
    if (result.exitCode != 0) {
      throw StateError('Unable to read git status for: $path');
    }
    for (final line in result.stdout.toString().split('\n')) {
      if (line.trim().isEmpty) continue;
      final entry = line.length > 3 ? line.substring(3).trim() : '';
      if (entry.isEmpty) continue;
      final resolved =
          entry.contains(' -> ') ? entry.split(' -> ').last.trim() : entry;
      if (resolved.isEmpty) continue;
      if (_isInternalPath(resolved)) continue;
      return true;
    }

    // Defense-in-depth: `git status --porcelain` should cover staged changes,
    // but check explicitly in case of unusual index states.
    final staged = _runGit(path, ['diff', '--cached', '--quiet']);
    if (staged.exitCode == 1) return true;

    return false;
  }

  List<String> changedPaths(String path) {
    return _statusPaths(path);
  }

  DiffStats diffStats(String path) {
    var filesChanged = 0;
    var additions = 0;
    var deletions = 0;
    final changedFiles = <String>[];

    void absorbNumstat(String output) {
      final lines = output.toString().split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parts = line.split('\t');
        if (parts.length < 3) {
          continue;
        }
        filesChanged += 1;
        additions += int.tryParse(parts[0]) ?? 0;
        deletions += int.tryParse(parts[1]) ?? 0;
        changedFiles.add(parts[2].trim());
      }
    }

    final tracked = _runGit(path, ['diff', '--numstat']);
    if (tracked.exitCode != 0) {
      throw StateError('Unable to read git diff stats for: $path');
    }
    absorbNumstat(tracked.stdout.toString());

    final untrackedPaths = _untrackedPaths(path);
    final emptySentinel = _emptyPathSentinel(path);
    for (final untracked in untrackedPaths) {
      final untrackedResult = _diffNoIndex(path, [
        'diff',
        '--no-index',
        '--numstat',
        '--',
        emptySentinel,
        untracked,
      ]);
      absorbNumstat(untrackedResult.stdout.toString());
    }

    return DiffStats(
      filesChanged: filesChanged,
      additions: additions,
      deletions: deletions,
      changedFiles: changedFiles,
    );
  }

  DiffStats diffStatsBetween(String path, String fromRef, String toRef) {
    final result = _runGit(path, ['diff', '--numstat', '$fromRef...$toRef']);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to read git diff stats between $fromRef and $toRef for: $path',
      );
    }
    var filesChanged = 0;
    var additions = 0;
    var deletions = 0;
    final changedFiles = <String>[];
    for (final line in result.stdout.toString().split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final parts = line.split('\t');
      if (parts.length < 3) {
        continue;
      }
      // Exclude .genaisys/ internal files from budget accounting,
      // consistent with working-directory diffStats filtering.
      if (_isInternalPath(parts[2])) {
        continue;
      }
      filesChanged += 1;
      additions += int.tryParse(parts[0]) ?? 0;
      deletions += int.tryParse(parts[1]) ?? 0;
      changedFiles.add(parts[2].trim());
    }
    return DiffStats(
      filesChanged: filesChanged,
      additions: additions,
      deletions: deletions,
      changedFiles: changedFiles,
    );
  }

  String diffSummaryBetween(String path, String fromRef, String toRef) {
    final result = _runGit(path, ['diff', '--stat', '$fromRef..$toRef']);
    if (result.exitCode != 0) {
      return '';
    }
    return result.stdout.toString().trim();
  }

  String diffPatchBetween(String path, String fromRef, String toRef) {
    final result = _runGit(path, ['diff', '$fromRef..$toRef']);
    if (result.exitCode != 0) {
      return '';
    }
    return result.stdout.toString();
  }

  String diffSummary(String path) {
    final config = ProjectConfig.load(path);
    final branch = currentBranch(path).trim();
    final baseBranch = config.gitBaseBranch.trim().isEmpty
        ? 'main'
        : config.gitBaseBranch.trim();

    String committed = '';
    if (branch != baseBranch &&
        _isTaskBranch(branch, config: config) &&
        branchExists(path, baseBranch)) {
      final committedResult = _runGit(path, [
        'diff',
        '--stat',
        '$baseBranch...HEAD',
      ]);
      if (committedResult.exitCode == 0) {
        committed = committedResult.stdout.toString().trim();
      }
    }

    final workingResult = _runGit(path, ['diff', '--stat']);
    if (workingResult.exitCode != 0) {
      throw StateError('Unable to read git diff for: $path');
    }
    final workingTracked = workingResult.stdout.toString().trim();
    final untracked = _untrackedPaths(path);
    final working = () {
      if (untracked.isEmpty) {
        return workingTracked;
      }
      final untrackedBlock = [
        'Untracked files:',
        ...untracked.map((p) => '- $p'),
      ].join('\n');
      if (workingTracked.isEmpty) {
        return untrackedBlock;
      }
      return '$workingTracked\n\n$untrackedBlock';
    }();

    if (committed.isEmpty) {
      return working;
    }
    if (working.trim().isEmpty) {
      return committed;
    }
    return '$committed\n\n$working';
  }

  String diffPatch(String path) {
    final config = ProjectConfig.load(path);
    final branch = currentBranch(path).trim();
    final baseBranch = config.gitBaseBranch.trim().isEmpty
        ? 'main'
        : config.gitBaseBranch.trim();

    String committed = '';
    if (branch != baseBranch &&
        _isTaskBranch(branch, config: config) &&
        branchExists(path, baseBranch)) {
      final committedResult = _runGit(path, ['diff', '$baseBranch...HEAD']);
      if (committedResult.exitCode == 0) {
        committed = committedResult.stdout.toString();
      }
    }

    final workingResult = _runGit(path, ['diff']);
    if (workingResult.exitCode != 0) {
      throw StateError('Unable to read git diff for: $path');
    }
    final workingTracked = workingResult.stdout.toString();
    final untracked = _untrackedPaths(path);
    final emptySentinel = _emptyPathSentinel(path);

    final buffer = StringBuffer();
    void append(String text) {
      if (text.trim().isEmpty) {
        return;
      }
      buffer.write(text);
      if (!text.endsWith('\n')) {
        buffer.writeln();
      }
      buffer.writeln();
    }

    append(committed);
    append(workingTracked);

    for (final file in untracked) {
      final patchResult = _diffNoIndex(path, [
        'diff',
        '--no-index',
        '--',
        emptySentinel,
        file,
      ]);
      append(patchResult.stdout.toString());
    }

    return buffer.toString();
  }
}
