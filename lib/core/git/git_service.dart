// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../policy/diff_budget_policy.dart';

part 'impl/git_shared_state.dart';
part 'impl/git_history_ops.dart';
part 'impl/git_diff_ops.dart';
part 'impl/git_branch_ops.dart';
part 'impl/git_remote_ops.dart';
part 'impl/git_stash_ops.dart';
part 'impl/git_commit_ops.dart';

typedef GitProcessRunner =
    ProcessResult Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      bool runInShell,
      Map<String, String>? environment,
    });

abstract class GitService {
  factory GitService() = GitServiceImpl;

  bool isGitRepo(String path);
  String repoRoot(String path);
  String currentBranch(String path);
  bool branchExists(String path, String branch);
  List<String> localBranchesMergedInto(String path, String baseRef);
  bool isClean(String path);
  void ensureClean(String path);
  void checkout(String path, String ref);
  void createBranch(String path, String branch, {String? startPoint});
  void merge(String path, String branch);
  List<String> conflictPaths(String path);
  bool hasMergeInProgress(String path);
  void abortMerge(String path);
  void deleteBranch(String path, String branch, {bool force = false});
  void deleteRemoteBranch(String path, String remote, String branch);
  void addAll(String path);
  void commit(String path, String message);
  void push(String path, String remote, String branch);
  ProcessResult pushDryRun(String path, String remote, String branch);
  void fetch(String path, String remote);
  void pullFastForward(String path, String remote, String branch);
  bool remoteBranchExists(String path, String remote, String branch);
  bool hasRemote(String path, String remote);
  String? defaultRemote(String path);
  bool tagExists(String path, String tag);
  void createAnnotatedTag(String path, String tag, {required String message});
  void pushTag(String path, String remote, String tag);
  bool stashPush(String path, {required String message, bool includeUntracked});
  void stashPop(String path);
  List<String> changedPaths(String path);
  bool hasChanges(String path);
  DiffStats diffStats(String path);
  DiffStats diffStatsBetween(String path, String fromRef, String toRef);
  String diffSummaryBetween(String path, String fromRef, String toRef);
  String diffPatchBetween(String path, String fromRef, String toRef);
  String diffSummary(String path);
  String diffPatch(String path);
  void discardWorkingChanges(String path);
  int stashCount(String path);
  void dropOldestStashes(String path, {required int maxKeep});

  /// Removes [relativePaths] from the git index without deleting them from
  /// disk.  Equivalent to `git rm --cached -r --ignore-unmatch`.  Safe to
  /// call when none of the paths are tracked — returns silently.
  void removeFromIndexIfTracked(String path, List<String> relativePaths);

  /// Runs `git reset --hard <ref>` to discard all working and staged changes.
  void hardReset(String path, {String ref = 'HEAD'});

  /// Runs `git clean -fd` to remove untracked files and directories.
  void cleanUntracked(String path);

  /// Returns `true` when a rebase is in progress (`REBASE_HEAD` exists).
  bool hasRebaseInProgress(String path);

  /// Returns the last [count] commit subject lines via `git log --oneline`.
  List<String> recentCommitMessages(String path, {int count = 10});

  /// Returns the HEAD commit SHA.  When [short] is `true`, returns the
  /// abbreviated form.
  String headCommitSha(String path, {bool short = false});

  /// Runs `git reset HEAD` to unstage all staged changes without modifying
  /// the working tree.
  void resetIndex(String path);

  /// Returns the total number of commits reachable from HEAD.
  int commitCount(String path);

  /// Returns `true` when there are staged changes (exit code 1 from
  /// `git diff --cached --quiet`).
  bool hasStagedChanges(String path);

  /// Returns `true` when [sha] is a valid, reachable commit in the repository.
  ///
  /// Uses `git cat-file -e <sha>` which exits 0 only when the object exists.
  /// Returns `false` for empty SHA, invalid SHA, or after force-push/history-rewrite.
  bool isCommitReachable(String path, String sha);
}

/// Concrete implementation of [GitService] composed via Dart mixins.
///
/// Each mixin handles one category of git operations:
/// - [_GitSharedState]: process runner, internal helpers
/// - [_GitHistoryOps]: repo state, branch/commit info
/// - [_GitDiffOps]: diff, status, changed paths
/// - [_GitBranchOps]: branch create/delete/merge/checkout
/// - [_GitRemoteOps]: push, pull, fetch, tags
/// - [_GitStashOps]: stash push/pop/drop
/// - [_GitCommitOps]: add, commit, reset, clean
class GitServiceImpl
    with
        _GitSharedState,
        _GitHistoryOps,
        _GitDiffOps,
        _GitBranchOps,
        _GitRemoteOps,
        _GitStashOps,
        _GitCommitOps
    implements GitService {
  GitServiceImpl({GitProcessRunner? processRunner})
    : _processRunner = processRunner ?? _defaultProcessRunner;

  @override
  final GitProcessRunner _processRunner;

  static ProcessResult _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
  }) {
    return Process.runSync(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      environment: environment,
    );
  }
}
