import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('ReviewService normalizes reject context in unattended mode', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_unattended_cleanup_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'alpha-1',
          title: 'Alpha Task',
        ),
        subtaskExecution: const SubtaskExecutionState(
          current: 'Fix parser edge cases',
        ),
      ),
    );

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    File('${temp.path}${Platform.pathSeparator}.gitignore').writeAsStringSync(
      '.genaisys/RUN_LOG.jsonl\n.genaisys/STATE.json\n.genaisys/audit/\n.genaisys/locks/\n',
    );
    final tracked = File('${temp.path}${Platform.pathSeparator}tracked.txt')
      ..writeAsStringSync('base\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    tracked.writeAsStringSync('reject change\n');

    Directory(layout.locksDir).createSync(recursive: true);
    File(layout.autopilotLockPath).writeAsStringSync('lock');

    final reviewService = ReviewService();
    reviewService.recordDecision(
      temp.path,
      decision: 'reject',
      note: 'Needs changes',
    );
    reviewService.normalizeAfterReject(
      temp.path,
      note: 'Auto-clear after unattended reject',
    );

    final state = stateStore.read();
    expect(state.reviewStatus, isNull);
    expect(state.reviewUpdatedAt, isNull);

    final status = Process.runSync('git', [
      'status',
      '--porcelain',
    ], workingDirectory: temp.path);
    expect(status.exitCode, 0);
    expect(status.stdout.toString().trim(), isEmpty);

    final stash = Process.runSync('git', [
      'stash',
      'list',
    ], workingDirectory: temp.path);
    expect(stash.exitCode, 0);
    expect(stash.stdout.toString(), contains('genaisys:review-reject:'));

    final runLog = File(layout.runLogPath).readAsStringSync();
    expect(runLog, contains('"event":"review_reject"'));
    expect(runLog, contains('"event":"review_reject_autostash"'));
    expect(runLog, contains('"event":"review_cleared"'));
  });

  // -------------------------------------------------------------------------
  // Fix 2 — Stash+Discard Fail-Closed
  //
  // When both stash and discard fail (and the worktree is still dirty),
  // normalizeAfterReject must throw StateError with message
  // 'reject_cleanup_failed' and emit a structured run-log event.
  // -------------------------------------------------------------------------

  test(
    'Fix 2: stash throws + discard throws → StateError with reject_cleanup_failed',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_reject_cleanup_fail_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'beta-1',
            title: 'Beta Task',
          ),
        ),
      );

      // Create the autopilot lock file — required for unattended mode.
      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotLockPath).writeAsStringSync('lock');

      // Fake git: dirty worktree, stash throws, discard throws.
      final git = _BothFailGitService();
      final reviewService = ReviewService(gitService: git);

      expect(
        () => reviewService.normalizeAfterReject(temp.path),
        throwsA(
          predicate(
            (e) =>
                e is StateError &&
                e.toString().contains('reject_cleanup_failed'),
          ),
        ),
        reason:
            'Must throw StateError when both stash and discard fail on a dirty worktree',
      );

      // Run-log must contain reject_cleanup_failed with structured fields.
      final logLines = File(layout.runLogPath)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final events = logLines
          .map((l) => Map<String, dynamic>.from(jsonDecode(l) as Map))
          .toList();

      final failEvent = events.firstWhere(
        (e) => e['event'] == 'reject_cleanup_failed',
        orElse: () => {},
      );
      expect(
        failEvent,
        isNotEmpty,
        reason: 'reject_cleanup_failed event must be logged',
      );
      final data = Map<String, dynamic>.from(failEvent['data'] as Map);
      expect(data['error_class'], 'git');
      expect(data['error_kind'], 'reject_cleanup_failed');
    },
  );

  test(
    'Fix 2 fallback: stash throws + discard succeeds → no throw, worktree cleaned',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_reject_discard_fallback_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'gamma-1',
            title: 'Gamma Task',
          ),
        ),
      );

      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotLockPath).writeAsStringSync('lock');

      // Fake git: dirty initially, stash throws, discard succeeds (cleans up).
      final git = _StashFailDiscardSucceedGitService();
      final reviewService = ReviewService(gitService: git);

      // Must not throw when discard succeeds as the stash fallback.
      expect(
        () => reviewService.normalizeAfterReject(temp.path),
        returnsNormally,
        reason: 'Must not throw when discard succeeds as stash fallback',
      );

      // Run-log must NOT contain reject_cleanup_failed.
      final log = File(layout.runLogPath).readAsStringSync();
      expect(
        log,
        isNot(contains('"event":"reject_cleanup_failed"')),
        reason:
            'No reject_cleanup_failed when discard succeeds as fallback',
      );
    },
  );
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode == 0) {
    return;
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: ${result.stderr}',
  );
}

// ---------------------------------------------------------------------------
// Minimal fake GitService base — all methods no-op / return safe defaults.
// Subclasses override only the methods they need to control.
// ---------------------------------------------------------------------------

abstract class _MinimalFakeGitService implements GitService {
  @override
  bool isGitRepo(String path) => true;

  @override
  String repoRoot(String path) => path;

  @override
  String currentBranch(String path) => 'feat/test-1';

  @override
  bool branchExists(String path, String branch) => false;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const [];

  @override
  bool isClean(String path) => false;

  @override
  void ensureClean(String path) {}

  @override
  void checkout(String path, String ref) {}

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
  void deleteBranch(String path, String branch, {bool force = false}) {}

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}

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
  bool tagExists(String path, String tag) => false;

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {}

  @override
  void pushTag(String path, String remote, String tag) {}

  @override
  void fetch(String path, String remote) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => false;

  @override
  bool hasRemote(String path, String remote) => false;

  @override
  String? defaultRemote(String path) => null;

  @override
  bool stashPush(String path, {required String message, bool includeUntracked = true}) =>
      false;

  @override
  void stashPop(String path) {}

  @override
  List<String> changedPaths(String path) => const [];

  @override
  bool hasChanges(String path) => true; // dirty by default for reject tests

  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 1, additions: 5, deletions: 0);

  @override
  String diffSummary(String path) => '1 file changed, 5 insertions(+)';

  @override
  String diffPatch(String path) => '@@ -1 +1 @@\n+change\n';

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

/// Stash throws, discard throws, hasChanges always returns true.
/// Simulates the worst case: both cleanup paths fail on a dirty worktree.
class _BothFailGitService extends _MinimalFakeGitService {
  @override
  bool stashPush(String path, {required String message, bool includeUntracked = true}) {
    throw StateError('stash failed: no space left on device');
  }

  @override
  void discardWorkingChanges(String path) {
    throw StateError('discard failed: index locked');
  }
}

/// Stash throws, discard succeeds (clears the worktree).
/// hasChanges returns true on first call, false after discard.
class _StashFailDiscardSucceedGitService extends _MinimalFakeGitService {
  bool _discarded = false;

  @override
  bool hasChanges(String path) => !_discarded;

  @override
  bool stashPush(String path, {required String message, bool includeUntracked = true}) {
    throw StateError('stash failed: lock file exists');
  }

  @override
  void discardWorkingChanges(String path) {
    _discarded = true; // Clears the worktree.
  }
}
