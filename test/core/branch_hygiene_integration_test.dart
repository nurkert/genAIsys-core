import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/branch_hygiene_service.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync(
      'genaisys_branch_hygiene_int_',
    );
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('protected-branch safeguards', () {
    test(
      'base branch is never deleted even when it appears in merged list',
      () {
        final git = _ConfigurableGitService(
          mergedIntoBase: const ['main', 'feat/a', 'feat/b'],
          currentBranchValue: 'main',
        );
        final service = BranchHygieneService(gitService: git);

        final result = service.cleanupMergedBranches(
          temp.path,
          baseBranch: 'main',
        );

        expect(result.deletedLocalBranches, isNot(contains('main')));
        expect(result.skippedBranches, contains('main'));
        expect(result.deletedLocalBranches, containsAll(['feat/a', 'feat/b']));
      },
    );

    test('current branch is never deleted even when merged', () {
      // Simulate being checked out on a non-base, non-feature branch that
      // happens to appear in the merged list but fails the prefix filter.
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/a', 'release/1.0'],
        currentBranchValue: 'release/1.0',
        checkoutShouldFail: true,
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
      );

      // release/1.0 doesn't match any allowed prefix -> skipped.
      // It's also the current branch -> doubly protected.
      expect(result.deletedLocalBranches, isNot(contains('release/1.0')));
      expect(result.skippedBranches, contains('release/1.0'));
    });

    test('auto-checkout from merged feature branch to base before cleanup', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/current', 'feat/other'],
        currentBranchValue: 'feat/current',
        checkoutChangesCurrentTo: 'main',
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
      );

      // After auto-checkout to main, feat/current should be deletable.
      expect(git.calls, contains('checkout:main'));
      expect(result.deletedLocalBranches, contains('feat/current'));
      expect(result.deletedLocalBranches, contains('feat/other'));
      expect(result.skippedBranches, contains('main'));
    });

    test('cleanup still works when auto-checkout to base fails', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/current', 'feat/other'],
        currentBranchValue: 'feat/current',
        checkoutShouldFail: true,
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
      );

      // Auto-checkout failed; feat/current is current branch -> skipped.
      expect(result.skippedBranches, contains('feat/current'));
      // Other merged branches should still be cleaned.
      expect(result.deletedLocalBranches, contains('feat/other'));
    });
  });

  group('divergence safeguards', () {
    test('local deletion failure is recorded and cleanup continues', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/a', 'feat/b', 'feat/c'],
        currentBranchValue: 'main',
        deletionFailBranches: const {'feat/b'},
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
      );

      expect(result.deletedLocalBranches, contains('feat/a'));
      expect(result.deletedLocalBranches, isNot(contains('feat/b')));
      expect(result.deletedLocalBranches, contains('feat/c'));
      expect(result.failures, hasLength(1));
      expect(result.failures.first, startsWith('local:feat/b:'));
    });

    test(
      'remote deletion failure is recorded without blocking local cleanup',
      () {
        final git = _ConfigurableGitService(
          mergedIntoBase: const ['main', 'feat/a'],
          currentBranchValue: 'main',
          remoteDeleteFailBranches: const {'feat/a'},
        );
        final service = BranchHygieneService(gitService: git);

        final result = service.cleanupMergedBranches(
          temp.path,
          baseBranch: 'main',
          remote: 'origin',
          includeRemote: true,
        );

        // Local deletion succeeded.
        expect(result.deletedLocalBranches, contains('feat/a'));
        // Remote deletion failed but was recorded.
        expect(result.deletedRemoteBranches, isEmpty);
        expect(result.failures, hasLength(1));
        expect(result.failures.first, startsWith('remote:origin/feat/a:'));
      },
    );

    test(
      'both local and remote failures for different branches are tracked independently',
      () {
        final git = _ConfigurableGitService(
          mergedIntoBase: const ['main', 'feat/a', 'fix/b', 'chore/c'],
          currentBranchValue: 'main',
          deletionFailBranches: const {'feat/a'},
          remoteDeleteFailBranches: const {'fix/b'},
        );
        final service = BranchHygieneService(gitService: git);

        final result = service.cleanupMergedBranches(
          temp.path,
          baseBranch: 'main',
          remote: 'origin',
          includeRemote: true,
        );

        // feat/a: local delete failed -> no remote attempt.
        expect(result.deletedLocalBranches, isNot(contains('feat/a')));
        expect(
          result.failures.any((f) => f.startsWith('local:feat/a:')),
          isTrue,
        );

        // fix/b: local delete succeeded, remote failed.
        expect(result.deletedLocalBranches, contains('fix/b'));
        expect(
          result.failures.any((f) => f.startsWith('remote:origin/fix/b:')),
          isTrue,
        );

        // chore/c: both succeeded.
        expect(result.deletedLocalBranches, contains('chore/c'));
        expect(result.deletedRemoteBranches, contains('origin/chore/c'));
      },
    );
  });

  group('prefix filtering', () {
    test('non-whitelisted prefixes are skipped with onlyFeaturePrefixed', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const [
          'main',
          'feat/a',
          'fix/b',
          'wip/c',
          'experiment/d',
          'chore/e',
          'refactor/f',
          'docs/g',
          'test/h',
          'ci/i',
          'build/j',
          'perf/k',
          'rc/l',
        ],
        currentBranchValue: 'main',
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
        onlyFeaturePrefixed: true,
      );

      expect(
        result.deletedLocalBranches,
        containsAll([
          'feat/a',
          'fix/b',
          'chore/e',
          'refactor/f',
          'docs/g',
          'test/h',
          'ci/i',
          'build/j',
          'perf/k',
          'rc/l',
        ]),
      );
      expect(result.skippedBranches, containsAll(['wip/c', 'experiment/d']));
      expect(result.deletedLocalBranches, isNot(contains('wip/c')));
      expect(result.deletedLocalBranches, isNot(contains('experiment/d')));
    });

    test(
      'all merged branches are cleaned when onlyFeaturePrefixed is false',
      () {
        final git = _ConfigurableGitService(
          mergedIntoBase: const ['main', 'feat/a', 'wip/b', 'experiment/c'],
          currentBranchValue: 'main',
        );
        final service = BranchHygieneService(gitService: git);

        final result = service.cleanupMergedBranches(
          temp.path,
          baseBranch: 'main',
          onlyFeaturePrefixed: false,
        );

        expect(
          result.deletedLocalBranches,
          containsAll(['feat/a', 'wip/b', 'experiment/c']),
        );
        expect(result.skippedBranches, contains('main'));
      },
    );
  });

  group('edge cases', () {
    test('non-git repo returns early with failure', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const [],
        currentBranchValue: 'main',
        isRepo: false,
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(temp.path);

      expect(result.failures, contains('not_git_repo'));
      expect(result.deletedLocalBranches, isEmpty);
      expect(result.deletedRemoteBranches, isEmpty);
    });

    test('empty merged list produces clean result with audit event', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main'],
        currentBranchValue: 'main',
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
      );

      expect(result.deletedLocalBranches, isEmpty);
      expect(result.skippedBranches, contains('main'));
      expect(result.failures, isEmpty);

      final logText = File(layout.runLogPath).readAsStringSync();
      expect(logText, contains('"event":"git_branch_cleanup"'));
    });

    test('remote branches are not deleted when includeRemote is false', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/a'],
        currentBranchValue: 'main',
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
        remote: 'origin',
        includeRemote: false,
      );

      expect(result.deletedLocalBranches, contains('feat/a'));
      expect(result.deletedRemoteBranches, isEmpty);
      expect(git.calls.where((c) => c.startsWith('delete_remote:')), isEmpty);
    });

    test('remote branches are not deleted when remote is null', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/a'],
        currentBranchValue: 'main',
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
        includeRemote: true,
        // No remote specified.
      );

      expect(result.deletedLocalBranches, contains('feat/a'));
      expect(result.deletedRemoteBranches, isEmpty);
    });
  });

  group('run log audit', () {
    test('cleanup records structured audit event with accurate counts', () {
      final git = _ConfigurableGitService(
        mergedIntoBase: const ['main', 'feat/a', 'feat/b', 'wip/c'],
        currentBranchValue: 'main',
        deletionFailBranches: const {'feat/b'},
      );
      final service = BranchHygieneService(gitService: git);

      final result = service.cleanupMergedBranches(
        temp.path,
        baseBranch: 'main',
        remote: 'origin',
        includeRemote: true,
      );

      expect(result.deletedLocalBranches, hasLength(1)); // feat/a
      expect(result.failures, hasLength(1)); // feat/b local
      expect(result.skippedBranches, hasLength(2)); // main + wip/c

      final logText = File(layout.runLogPath).readAsStringSync();
      expect(logText, contains('"event":"git_branch_cleanup"'));
      expect(logText, contains('"deleted_local_count":1'));
      expect(logText, contains('"skipped_count":2'));
      expect(logText, contains('"failure_count":1'));
    });
  });
}

/// Configurable mock [GitService] for integration tests covering various
/// safeguard and error scenarios.
class _ConfigurableGitService implements GitService {
  _ConfigurableGitService({
    required this.mergedIntoBase,
    required this.currentBranchValue,
    this.checkoutShouldFail = false,
    this.checkoutChangesCurrentTo,
    this.deletionFailBranches = const {},
    this.remoteDeleteFailBranches = const {},
    this.isRepo = true,
  }) : _currentBranch = currentBranchValue;

  final List<String> mergedIntoBase;
  final String currentBranchValue;
  final bool checkoutShouldFail;
  final String? checkoutChangesCurrentTo;
  final Set<String> deletionFailBranches;
  final Set<String> remoteDeleteFailBranches;
  final bool isRepo;
  final List<String> calls = <String>[];

  String _currentBranch;

  @override
  bool isGitRepo(String path) => isRepo;

  @override
  String repoRoot(String path) => path;

  @override
  String currentBranch(String path) => _currentBranch;

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
    if (checkoutShouldFail) {
      throw StateError('checkout failed');
    }
    if (checkoutChangesCurrentTo != null) {
      _currentBranch = checkoutChangesCurrentTo!;
    }
  }

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void merge(String path, String branch) {}

  @override
  List<String> conflictPaths(String path) => const [];

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  void abortMerge(String path) {}

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {
    calls.add('delete:$branch');
    if (deletionFailBranches.contains(branch)) {
      throw StateError('branch $branch has diverged');
    }
  }

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {
    calls.add('delete_remote:$remote/$branch');
    if (remoteDeleteFailBranches.contains(branch)) {
      throw StateError('remote delete failed for $remote/$branch');
    }
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
  List<String> changedPaths(String path) => const [];

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
