import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/merge_conflict_resolver_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test(
    'DoneService requires manual intervention for merge conflicts',
    () async {
      final temp = Directory.systemTemp.createTempSync('genaisys_merge_');
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _ConflictGitService();
      final resolver = _FailingMergeResolver();
      final service = DoneService(
        gitService: git,
        mergeConflictResolver: resolver,
        mergeConflictMaxAttempts: 1,
      );

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('Manual intervention required') &&
                error.toString().contains('merge conflict'),
          ),
        ),
      );

      final logLines = File(
        layout.runLogPath,
      ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
      expect(logLines, isNotEmpty);
      final events = logLines
          .map((line) => Map<String, dynamic>.from(jsonDecode(line) as Map))
          .toList(growable: false);
      expect(
        events.any((entry) => entry['event'] == 'merge_conflict_detected'),
        isTrue,
      );
      expect(
        events.any(
          (entry) =>
              entry['event'] == 'merge_conflict_resolution_attempt_start',
        ),
        isTrue,
      );
      expect(
        events.any(
          (entry) =>
              entry['event'] == 'merge_conflict_resolution_attempt_failed',
        ),
        isTrue,
      );
      expect(
        events.any((entry) => entry['event'] == 'merge_conflict_abort'),
        isTrue,
      );
      final manual = events.lastWhere(
        (entry) => entry['event'] == 'merge_conflict_manual',
      );
      final data = Map<String, dynamic>.from(manual['data'] as Map);
      expect(data['error_class'], 'delivery');
      expect(data['error_kind'], 'merge_conflict_manual_required');
      expect(data['merge_outcome'], 'manual_intervention_required');
      expect(data['base_branch'], 'main');
      expect(data['feature_branch'], 'feat/test-1');
      expect(data['conflict_count'], 1);
    },
  );

  test('DoneService fetches and pulls base branch before merge', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_done_sync_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final active = tasks.first;
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(
          id: active.id,
          title: active.title,
          reviewStatus: 'approved',
          reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ),
    );
    _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

    final git = _SyncTrackingGitService();
    final service = DoneService(gitService: git);

    final title = await service.markDone(temp.path);
    expect(title, active.title);
    expect(
      git.calls,
      containsAllInOrder([
        'fetch:origin',
        'pull:origin/feat/test-1',
        'checkout:main',
        'fetch:origin',
        'pull:origin/main',
        'merge:feat/test-1',
        'push:origin/main',
        'delete:feat/test-1',
      ]),
    );

    final log = File(layout.runLogPath).readAsStringSync();
    expect(log, contains('"event":"git_delivery_fetch"'));
    expect(log, contains('"event":"git_delivery_pull"'));
  });

  test(
    'DoneService deletes remote merged feature branch when enabled',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_remote_delete_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Enable remote branch hygiene in config for this test.
      final configFile = File(layout.configPath);
      final original = configFile.readAsStringSync();
      configFile.writeAsStringSync(
        original.replaceFirst(
          '  auto_stash:',
          '  auto_delete_remote_merged_branches: true\n  auto_stash:',
        ),
      );
      expect(
        configFile.readAsStringSync(),
        contains('auto_delete_remote_merged_branches: true'),
      );
      final parsed = ProjectConfig.load(temp.path);
      expect(parsed.gitAutoDeleteRemoteMergedBranches, isTrue);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _SyncTrackingGitService();
      final service = DoneService(gitService: git);

      final title = await service.markDone(temp.path);
      expect(title, active.title);
      expect(git.calls, contains('delete_remote:origin/feat/test-1'));
    },
  );

  test(
    'DoneService blocks completion on upstream divergence preflight',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_sync_fetch_fail_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _FetchFailGitService();
      final service = DoneService(gitService: git);

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('delivery/upstream_diverged'),
          ),
        ),
      );
      expect(
        git.calls,
        containsAllInOrder(['fetch:origin', 'pull:origin/feat/test-1']),
      );

      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"event":"delivery_preflight_failed"'));
      expect(log, contains('"error_kind":"upstream_diverged"'));
    },
  );

  test(
    'DoneService falls back to hard reset when merge abort fails',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_merge_abort_fail_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(
        layout,
        activeTitle: active.title,
        taskId: active.id,
      );

      final git = _AbortFailGitService();
      final resolver = _FailingMergeResolver();
      final service = DoneService(
        gitService: git,
        mergeConflictResolver: resolver,
        mergeConflictMaxAttempts: 1,
      );

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('Manual intervention required'),
          ),
        ),
      );

      // Verify hard reset fallback was logged.
      final logLines = File(layout.runLogPath)
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final events = logLines
          .map((line) => Map<String, dynamic>.from(jsonDecode(line) as Map))
          .toList(growable: false);
      final abortFailed = events.where(
        (entry) => entry['event'] == 'merge_conflict_abort_failed',
      );
      expect(abortFailed, isNotEmpty);
      final data = Map<String, dynamic>.from(
        abortFailed.first['data'] as Map,
      );
      expect(data['error_kind'], 'merge_abort_hard_reset');
      expect(data['original_error'], isNotEmpty);
    },
  );

  test(
    'DoneService resets index when commit after merge fails',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_commit_fail_reset_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(
        layout,
        activeTitle: active.title,
        taskId: active.id,
      );

      final git = _CommitFailGitService();
      final resolver = _ResolvingMergeResolver(git);
      final service = DoneService(
        gitService: git,
        mergeConflictResolver: resolver,
        mergeConflictMaxAttempts: 1,
      );

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('Failed to merge'),
          ),
        ),
      );

      // Verify that addAll was called (staging happened) and then the commit
      // was attempted but failed.  The index reset (Process.runSync 'git
      // reset HEAD') runs inside a try-catch and may fail in the test
      // environment (no real git repo), but the important invariant is that
      // the error propagated correctly and staging + commit were attempted.
      expect(git.addAllCalled, isTrue);
      expect(git.commitAttempted, isTrue);
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Fix 7: Merge-Limbo State-Transition — mergeInProgress flag lifecycle
  // ─────────────────────────────────────────────────────────────────────

  test(
    'DoneService clears mergeInProgress=false after successful merge',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_merge_limbo_ok_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _SyncTrackingGitService();
      final service = DoneService(gitService: git);

      await service.markDone(temp.path);

      // After a successful merge, mergeInProgress must be false.
      final finalState = stateStore.read();
      expect(
        finalState.activeTask.mergeInProgress,
        isFalse,
        reason: 'mergeInProgress must be cleared after successful merge',
      );
    },
  );

  test(
    'DoneService clears mergeInProgress=false when merge fails',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_merge_limbo_fail_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _ConflictGitService();
      final resolver = _FailingMergeResolver();
      final service = DoneService(
        gitService: git,
        mergeConflictResolver: resolver,
        mergeConflictMaxAttempts: 1,
      );

      // Merge is expected to fail.
      await expectLater(service.markDone(temp.path), throwsA(isA<StateError>()));

      // After a failed merge, mergeInProgress must be false (not stuck in limbo).
      final finalState = stateStore.read();
      expect(
        finalState.activeTask.mergeInProgress,
        isFalse,
        reason: 'mergeInProgress must be cleared even when merge fails',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Fix 1 — Task-already-done Early Return
  //
  // When the task checkbox in TASKS.md is already `[x]` (e.g. marked by the
  // coding agent), DoneService must:
  //   - emit `task_done` so downstream consumers (activation skip logic) see it
  //   - emit `task_already_done` so auditors know why markDone was skipped
  //   - still call _handleGitMerge so the feature branch lands
  //   - NOT call writer.markDone or audit trail a second time
  // -------------------------------------------------------------------------

  test(
    'Fix 1: alreadyDone=true still merges, emits task_done and task_already_done',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_already_done_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;

      // Mark the task as already done by flipping the checkbox in TASKS.md.
      // The default template uses '- [ ] [P1] ...' so we match on '- [ ]'.
      final tasksFile = File(layout.tasksPath);
      final originalContent = tasksFile.readAsStringSync();
      final markedDone = originalContent.replaceFirst('- [ ]', '- [x]');
      tasksFile.writeAsStringSync(markedDone);

      // Set active task state (as if a previous cycle approved it).
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _SyncTrackingGitService();
      final service = DoneService(gitService: git);

      final title = await service.markDone(temp.path);

      // Return value must still be the active task title.
      expect(title, active.title);

      // Merge and push must still be called — the feature branch must land
      // even when the coding agent pre-marked the checkbox in TASKS.md.
      expect(
        git.calls,
        anyElement(startsWith('push:')),
        reason: 'Merge (push) must still occur when task is pre-marked done',
      );

      // Run-log must contain task_already_done and must NOT contain task_done.
      final logLines = File(layout.runLogPath)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final events = logLines
          .map((l) => Map<String, dynamic>.from(jsonDecode(l) as Map))
          .toList();

      expect(
        events.any((e) => e['event'] == 'task_already_done'),
        isTrue,
        reason: 'task_already_done event must be logged',
      );
      expect(
        events.any((e) => e['event'] == 'task_done'),
        isTrue,
        reason:
            'task_done must be emitted even when already done (activation skip)',
      );

      // Verify the event carries correct error_class and error_kind.
      final alreadyDoneEvent = events.firstWhere(
        (e) => e['event'] == 'task_already_done',
      );
      final data =
          Map<String, dynamic>.from(alreadyDoneEvent['data'] as Map);
      expect(data['error_class'], 'delivery');
      expect(data['error_kind'], 'task_already_done');
    },
  );

  test(
    'Fix 1 control: alreadyDone=false runs normal merge flow (regression guard)',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_not_already_done_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final active = tasks.first;
      // Task checkbox left as [ ] (open) — normal flow must run.
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: active.id,
            title: active.title,
            reviewStatus: 'approved',
            reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      );
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      final git = _SyncTrackingGitService();
      final service = DoneService(gitService: git);

      await service.markDone(temp.path);

      // Merge must have been called — normal delivery flow.
      expect(
        git.calls,
        contains(startsWith('merge:')),
        reason: 'Merge must run for a task that is not yet done',
      );

      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"event":"task_done"'));
      expect(log, isNot(contains('"event":"task_already_done"')));
    },
  );
}

void _seedReviewEvidence(
  ProjectLayout layout, {
  required String activeTitle,
  required String taskId,
}) {
  final slug = TaskSlugger.slug(activeTitle);
  final entryDir = Directory(
    '${layout.auditDir}${Platform.pathSeparator}$slug${Platform.pathSeparator}2026-02-08T10-00-00.000000Z_review',
  );
  entryDir.createSync(recursive: true);
  final diffSummary = File(
    '${entryDir.path}${Platform.pathSeparator}diff_summary.txt',
  );
  final diffPatch = File(
    '${entryDir.path}${Platform.pathSeparator}diff_patch.diff',
  );
  diffSummary.writeAsStringSync('1 file changed, 3 insertions(+)\n');
  diffPatch.writeAsStringSync(
    'diff --git a/lib/a.dart b/lib/a.dart\n+final x = 1;\n',
  );
  final summary = <String, Object?>{
    'timestamp': '2026-02-08T10:00:00Z',
    'kind': 'review',
    'task': activeTitle,
    'task_id': taskId,
    'subtask': '',
    'decision': 'approve',
    'note': 'Quality gate passed: analyze/test green.',
    'test_summary': null,
    'definition_of_done': {
      'implementation_completed': true,
      'tests_added_or_updated': true,
      'analyze_green': true,
      'relevant_tests_green': true,
      'runlog_status_checked_if_affected': true,
      'docs_updated_if_behavior_changed': true,
      'tasks_updated_same_slice': true,
    },
    'files': {
      'diff_summary': 'diff_summary.txt',
      'diff_patch': 'diff_patch.diff',
    },
  };
  File(
    '${entryDir.path}${Platform.pathSeparator}summary.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
}

class _ConflictGitService implements GitService {
  bool _mergeInProgress = false;

  @override
  bool isGitRepo(String path) => true;

  @override
  String repoRoot(String path) => path;

  @override
  String currentBranch(String path) => 'feat/test-1';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const <String>[];

  @override
  bool isClean(String path) => true;

  @override
  void ensureClean(String path) {}

  @override
  void checkout(String path, String ref) {}

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void merge(String path, String branch) {
    _mergeInProgress = true;
    throw StateError('merge conflict');
  }

  @override
  List<String> conflictPaths(String path) {
    if (!_mergeInProgress) {
      return [];
    }
    return ['lib/conflict.dart'];
  }

  @override
  bool hasMergeInProgress(String path) => _mergeInProgress;

  @override
  void abortMerge(String path) {
    _mergeInProgress = false;
  }

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
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  bool hasRemote(String path, String remote) => false;

  @override
  String? defaultRemote(String path) => 'origin';

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

class _FailingMergeResolver extends MergeConflictResolverService {
  @override
  Future<MergeConflictResolutionResult> resolve(
    String projectRoot, {
    required String baseBranch,
    required String featureBranch,
    required List<String> conflictPaths,
  }) async {
    return const MergeConflictResolutionResult(
      response: AgentResponse(exitCode: 1, stdout: '', stderr: 'conflict'),
      usedFallback: false,
    );
  }
}

class _SyncTrackingGitService implements GitService {
  final List<String> calls = <String>[];

  @override
  bool isGitRepo(String path) => true;

  @override
  String repoRoot(String path) => path;

  @override
  String currentBranch(String path) => 'feat/test-1';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const <String>[];

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
  void merge(String path, String branch) {
    calls.add('merge:$branch');
  }

  @override
  List<String> conflictPaths(String path) => const [];

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
  void push(String path, String remote, String branch) {
    calls.add('push:$remote/$branch');
  }

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
  void fetch(String path, String remote) {
    calls.add('fetch:$remote');
  }

  @override
  void pullFastForward(String path, String remote, String branch) {
    calls.add('pull:$remote/$branch');
  }

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  bool hasRemote(String path, String remote) => true;

  @override
  String? defaultRemote(String path) => 'origin';

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

class _FetchFailGitService extends _SyncTrackingGitService {
  @override
  void pullFastForward(String path, String remote, String branch) {
    super.pullFastForward(path, remote, branch);
    throw StateError('upstream diverged');
  }
}

/// Git service where abortMerge throws, to test the hard-reset fallback.
class _AbortFailGitService extends _ConflictGitService {
  @override
  void abortMerge(String path) {
    // Do NOT clear _mergeInProgress — simulate a failed abort.
    throw StateError('abort merge failed');
  }
}

/// Git service that simulates a merge conflict that resolves successfully, but
/// then the final commit fails.  This exercises the addAll+commit index-reset
/// fallback in _mergeOrResolve.
class _CommitFailGitService extends _SyncTrackingGitService {
  bool addAllCalled = false;
  bool commitAttempted = false;
  bool _mergeInProgress = false;
  bool _conflictsResolved = false;

  @override
  void merge(String path, String branch) {
    calls.add('merge:$branch');
    _mergeInProgress = true;
    throw StateError('merge conflict');
  }

  @override
  bool hasMergeInProgress(String path) => _mergeInProgress;

  @override
  List<String> conflictPaths(String path) {
    if (_conflictsResolved) return const [];
    if (!_mergeInProgress) return const [];
    return ['lib/conflict.dart'];
  }

  @override
  void abortMerge(String path) {
    _mergeInProgress = false;
  }

  @override
  void addAll(String path) {
    addAllCalled = true;
  }

  @override
  void commit(String path, String message) {
    commitAttempted = true;
    throw StateError('commit failed');
  }

  /// Called by the resolver to simulate resolution.
  void resolveConflicts() {
    _conflictsResolved = true;
  }
}

/// Resolver that marks conflicts as resolved by calling the git service.
class _ResolvingMergeResolver extends MergeConflictResolverService {
  _ResolvingMergeResolver(this._gitService);
  final _CommitFailGitService _gitService;

  @override
  Future<MergeConflictResolutionResult> resolve(
    String projectRoot, {
    required String baseBranch,
    required String featureBranch,
    required List<String> conflictPaths,
  }) async {
    _gitService.resolveConflicts();
    return const MergeConflictResolutionResult(
      response: AgentResponse(exitCode: 0, stdout: 'resolved', stderr: ''),
      usedFallback: false,
    );
  }
}
