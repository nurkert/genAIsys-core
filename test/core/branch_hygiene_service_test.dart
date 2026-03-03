import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/branch_hygiene_service.dart';

void main() {
  test('BranchHygieneService deletes only merged task branches by prefix', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_branch_cleanup_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final git = _TrackingGitService(
      mergedIntoBase: const <String>[
        'main',
        'feat/a',
        'fix/b',
        'chore/c',
        'feat/d',
        'wip/skip',
      ],
      currentBranchValue: 'main',
    );
    final service = BranchHygieneService(gitService: git);

    final result = service.cleanupMergedBranches(
      temp.path,
      baseBranch: 'main',
      remote: 'origin',
      includeRemote: true,
      dryRun: false,
      onlyFeaturePrefixed: true,
    );

    expect(result.baseBranch, 'main');
    expect(
      result.deletedLocalBranches,
      containsAll(<String>['feat/a', 'fix/b', 'chore/c', 'feat/d']),
    );
    expect(result.deletedLocalBranches, isNot(contains('wip/skip')));
    expect(
      result.deletedRemoteBranches,
      containsAll(<String>[
        'origin/feat/a',
        'origin/fix/b',
        'origin/chore/c',
        'origin/feat/d',
      ]),
    );

    final logText = File(layout.runLogPath).readAsStringSync();
    expect(logText, contains('"event":"git_branch_cleanup"'));
    expect(logText, contains('"error_kind":"branch_cleanup"'));
  });

  test('BranchHygieneService dry-run does not delete branches', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_branch_cleanup_dry_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final git = _TrackingGitService(
      mergedIntoBase: const <String>['main', 'feat/a'],
      currentBranchValue: 'main',
    );
    final service = BranchHygieneService(gitService: git);

    final result = service.cleanupMergedBranches(
      temp.path,
      baseBranch: 'main',
      remote: 'origin',
      includeRemote: true,
      dryRun: true,
    );

    expect(result.dryRun, isTrue);
    expect(result.deletedLocalBranches, isEmpty);
    expect(result.deletedRemoteBranches, isEmpty);
    expect(git.calls.where((c) => c.startsWith('delete:')), isEmpty);
  });
}

class _TrackingGitService implements GitService {
  _TrackingGitService({
    required this.mergedIntoBase,
    required this.currentBranchValue,
  });

  final List<String> mergedIntoBase;
  final String currentBranchValue;
  final List<String> calls = <String>[];

  @override
  bool isGitRepo(String path) => true;

  @override
  String repoRoot(String path) => path;

  @override
  String currentBranch(String path) => currentBranchValue;

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      mergedIntoBase;

  @override
  bool isClean(String path) => true;

  @override
  void ensureClean(String path) {}

  @override
  void checkout(String path, String ref) {
    calls.add('checkout:$ref');
  }

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void merge(String path, String branch) {}

  @override
  List<String> conflictPaths(String path) => const <String>[];

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  void abortMerge(String path) {}

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {
    calls.add('delete:$branch');
  }

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {
    calls.add('delete_remote:$remote/$branch');
  }

  @override
  void addAll(String path) {}

  @override
  void commit(String path, String message) {}

  @override
  void push(String path, String remote, String branch) {}

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  void fetch(String path, String remote) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  bool hasRemote(String path, String remote) => true;

  @override
  String? defaultRemote(String path) => 'origin';

  @override
  bool tagExists(String path, String tag) => false;

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {}

  @override
  void pushTag(String path, String remote, String tag) {}

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    return false;
  }

  @override
  void stashPop(String path) {}

  @override
  List<String> changedPaths(String path) => const <String>[];

  @override
  bool hasChanges(String path) => false;

  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  String diffSummary(String path) => '';

  @override
  String diffPatch(String path) => '';

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  void discardWorkingChanges(String path) {}

  @override
  int stashCount(String path) => 0;

  @override
  void dropOldestStashes(String path, {required int maxKeep}) {}

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {}

  @override
  void hardReset(String path, {String ref = 'HEAD'}) {}

  @override
  void cleanUntracked(String path) {}

  @override
  bool hasRebaseInProgress(String path) => false;

  @override
  List<String> recentCommitMessages(String path, {int count = 10}) => const [];

  @override
  String headCommitSha(String path, {bool short = false}) => 'abc1234';

  @override
  void resetIndex(String path) {}

  @override
  int commitCount(String path) => 1;

  @override
  bool hasStagedChanges(String path) => false;

  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';
  @override
  bool isCommitReachable(String path, String sha) => true;
}
