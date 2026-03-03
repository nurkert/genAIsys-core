import 'dart:io';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

/// Constructor-configurable fake for [GitService].
///
/// All methods return configurable defaults and record invocations
/// in [calls] for verification:
/// ```dart
/// final git = FakeGitService(isDirty: true);
/// myService.run(git: git);
/// expect(git.calls, contains('hasChanges'));
/// ```
class FakeGitService implements GitService {
  FakeGitService({
    this.isRepoValue = true,
    this.isCleanValue = true,
    this.currentBranchName = 'main',
    this.branchExistsValue = true,
    this.defaultRemoteName = 'origin',
    this.hasRemoteValue = true,
    this.hasMergeInProgressValue = false,
    this.conflictPathsValue = const [],
    this.changedPathsValue = const [],
    this.diffStatsValue = const DiffStats(
      filesChanged: 0,
      additions: 0,
      deletions: 0,
    ),
    this.diffSummaryValue = '',
    this.diffPatchValue = '',
    this.remoteBranchExistsValue = false,
    this.tagExistsValue = false,
    this.stashPushReturns = false,
    this.localBranchesMergedIntoValue = const [],
    this.repoRootValue,
  });

  /// Ordered record of method invocations for test assertions.
  final List<String> calls = [];

  // Configurable return values.
  bool isRepoValue;
  bool isCleanValue;
  String currentBranchName;
  bool branchExistsValue;
  String? defaultRemoteName;
  bool hasRemoteValue;
  bool hasMergeInProgressValue;
  List<String> conflictPathsValue;
  List<String> changedPathsValue;
  DiffStats diffStatsValue;
  String diffSummaryValue;
  String diffPatchValue;
  bool remoteBranchExistsValue;
  bool tagExistsValue;
  bool stashPushReturns;
  List<String> localBranchesMergedIntoValue;
  String? repoRootValue;

  /// Arguments captured from the last [createBranch] call.
  String? lastCreatedBranch;
  String? lastCreatedBranchStartPoint;

  /// Arguments captured from the last [checkout] call.
  String? lastCheckoutRef;

  /// Arguments captured from the last [commit] call.
  String? lastCommitMessage;

  /// Arguments captured from the last [merge] call.
  String? lastMergeBranch;

  /// Arguments captured from the last [push] call.
  String? lastPushRemote;
  String? lastPushBranch;

  /// Arguments captured from the last [stashPush] call.
  String? lastStashMessage;

  @override
  bool isGitRepo(String path) {
    calls.add('isGitRepo');
    return isRepoValue;
  }

  @override
  String repoRoot(String path) {
    calls.add('repoRoot');
    return repoRootValue ?? path;
  }

  @override
  String currentBranch(String path) {
    calls.add('currentBranch');
    return currentBranchName;
  }

  @override
  bool branchExists(String path, String branch) {
    calls.add('branchExists:$branch');
    return branchExistsValue;
  }

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) {
    calls.add('localBranchesMergedInto:$baseRef');
    return localBranchesMergedIntoValue;
  }

  @override
  bool isClean(String path) {
    calls.add('isClean');
    return isCleanValue;
  }

  @override
  void ensureClean(String path) {
    calls.add('ensureClean');
    if (!isCleanValue) {
      throw StateError('Repository has uncommitted changes: $path');
    }
  }

  @override
  void checkout(String path, String ref) {
    calls.add('checkout:$ref');
    lastCheckoutRef = ref;
  }

  @override
  void createBranch(String path, String branch, {String? startPoint}) {
    calls.add('createBranch:$branch');
    lastCreatedBranch = branch;
    lastCreatedBranchStartPoint = startPoint;
  }

  @override
  void merge(String path, String branch) {
    calls.add('merge:$branch');
    lastMergeBranch = branch;
  }

  @override
  List<String> conflictPaths(String path) {
    calls.add('conflictPaths');
    return conflictPathsValue;
  }

  @override
  bool hasMergeInProgress(String path) {
    calls.add('hasMergeInProgress');
    return hasMergeInProgressValue;
  }

  @override
  void abortMerge(String path) {
    calls.add('abortMerge');
  }

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {
    calls.add('deleteBranch:$branch:force=$force');
  }

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {
    calls.add('deleteRemoteBranch:$remote/$branch');
  }

  @override
  void addAll(String path) {
    calls.add('addAll');
  }

  @override
  void commit(String path, String message) {
    calls.add('commit');
    lastCommitMessage = message;
  }

  @override
  void push(String path, String remote, String branch) {
    calls.add('push:$remote/$branch');
    lastPushRemote = remote;
    lastPushBranch = branch;
  }

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) {
    calls.add('pushDryRun:$remote/$branch');
    return ProcessResult(0, 0, '', '');
  }

  @override
  void fetch(String path, String remote) {
    calls.add('fetch:$remote');
  }

  @override
  void pullFastForward(String path, String remote, String branch) {
    calls.add('pullFastForward:$remote/$branch');
  }

  @override
  bool remoteBranchExists(String path, String remote, String branch) {
    calls.add('remoteBranchExists:$remote/$branch');
    return remoteBranchExistsValue;
  }

  @override
  bool hasRemote(String path, String remote) {
    calls.add('hasRemote:$remote');
    return hasRemoteValue;
  }

  @override
  String? defaultRemote(String path) {
    calls.add('defaultRemote');
    return defaultRemoteName;
  }

  @override
  bool tagExists(String path, String tag) {
    calls.add('tagExists:$tag');
    return tagExistsValue;
  }

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {
    calls.add('createAnnotatedTag:$tag');
  }

  @override
  void pushTag(String path, String remote, String tag) {
    calls.add('pushTag:$remote/$tag');
  }

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    calls.add('stashPush');
    lastStashMessage = message;
    return stashPushReturns;
  }

  @override
  void stashPop(String path) {
    calls.add('stashPop');
  }

  @override
  List<String> changedPaths(String path) {
    calls.add('changedPaths');
    return changedPathsValue;
  }

  @override
  bool hasChanges(String path) {
    calls.add('hasChanges');
    return !isCleanValue;
  }

  @override
  DiffStats diffStats(String path) {
    calls.add('diffStats');
    return diffStatsValue;
  }

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) {
    calls.add('diffStatsBetween:$fromRef..$toRef');
    return diffStatsValue;
  }

  @override
  String diffSummary(String path) {
    calls.add('diffSummary');
    return diffSummaryValue;
  }

  @override
  String diffPatch(String path) {
    calls.add('diffPatch');
    return diffPatchValue;
  }

  @override
  void discardWorkingChanges(String path) {
    calls.add('discardWorkingChanges');
  }

  @override
  int stashCount(String path) {
    calls.add('stashCount');
    return 0;
  }

  @override
  void dropOldestStashes(String path, {required int maxKeep}) {
    calls.add('dropOldestStashes:maxKeep=$maxKeep');
  }

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {
    calls.add('removeFromIndexIfTracked:${relativePaths.length}');
  }

  @override
  void hardReset(String path, {String ref = 'HEAD'}) {
    calls.add('hardReset:$ref');
  }

  @override
  void cleanUntracked(String path) {
    calls.add('cleanUntracked');
  }

  @override
  bool hasRebaseInProgress(String path) {
    calls.add('hasRebaseInProgress');
    return false;
  }

  @override
  List<String> recentCommitMessages(String path, {int count = 10}) {
    calls.add('recentCommitMessages:$count');
    return const [];
  }

  @override
  String headCommitSha(String path, {bool short = false}) {
    calls.add('headCommitSha:short=$short');
    return short ? 'abc1234' : 'abc1234567890abcdef1234567890abcdef123456';
  }

  @override
  void resetIndex(String path) {
    calls.add('resetIndex');
  }

  @override
  int commitCount(String path) {
    calls.add('commitCount');
    return 1;
  }

  @override
  bool hasStagedChanges(String path) {
    calls.add('hasStagedChanges');
    return false;
  }

  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';

  /// Configurable reachable SHAs for [isCommitReachable].
  /// Defaults to [true] for any SHA unless overridden.
  bool Function(String sha)? isCommitReachableOverride;

  @override
  bool isCommitReachable(String path, String sha) {
    calls.add('isCommitReachable:$sha');
    return isCommitReachableOverride?.call(sha) ?? true;
  }
}

/// In-memory fake for [StateStore].
///
/// Stores state in memory without file I/O:
/// ```dart
/// final store = FakeStateStore(initial: myState);
/// expect(store.readCount, 0);
/// store.read();
/// expect(store.readCount, 1);
/// ```
class FakeStateStore extends StateStore {
  FakeStateStore({ProjectState? initial})
    : _state = initial ?? ProjectState(lastUpdated: '2026-01-01T00:00:00Z'),
      super('/dev/null');

  ProjectState _state;

  /// Number of times [read] was called.
  int readCount = 0;

  /// Number of times [write] was called.
  int writeCount = 0;

  @override
  ProjectState read() {
    readCount++;
    return _state;
  }

  @override
  void write(ProjectState state) {
    writeCount++;
    _state = state;
  }
}

/// In-memory fake for [TaskStore].
///
/// Stores tasks in memory:
/// ```dart
/// final store = FakeTaskStore(tasks: [myTask]);
/// expect(store.readTasks(), hasLength(1));
/// ```
class FakeTaskStore extends TaskStore {
  FakeTaskStore({List<Task>? tasks}) : _tasks = tasks ?? [], super('/dev/null');

  List<Task> _tasks;

  /// Replace the stored tasks.
  set tasks(List<Task> value) => _tasks = value;

  @override
  List<Task> readTasks() => List.unmodifiable(_tasks);

  @override
  bool hasOpenP1StabilizationTask() {
    return _tasks.any(
      (t) =>
          t.completion == TaskCompletion.open &&
          t.priority == TaskPriority.p1 &&
          _isStabilizationCategory(t.category),
    );
  }

  bool _isStabilizationCategory(TaskCategory category) {
    switch (category) {
      case TaskCategory.core:
      case TaskCategory.security:
      case TaskCategory.qa:
      case TaskCategory.architecture:
      case TaskCategory.refactor:
        return true;
      case TaskCategory.ui:
      case TaskCategory.docs:
      case TaskCategory.agent:
      case TaskCategory.unknown:
        return false;
    }
  }
}
