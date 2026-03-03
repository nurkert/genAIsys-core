import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test(
    'DoneService blocks completion when review evidence is missing',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_missing_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final active = _activateApprovedTask(layout);
      final git = _GateGitService();
      final service = DoneService(gitService: git);

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('delivery/evidence_missing'),
          ),
        ),
      );

      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"error_class":"delivery"'));
      expect(log, contains('"error_kind":"evidence_missing"'));
      expect(active.title, isNotEmpty);
    },
  );

  test(
    'DoneService blocks completion when review evidence is malformed',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_malformed_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final active = _activateApprovedTask(layout);
      _seedReviewEvidence(
        layout,
        activeTitle: active.title,
        taskId: active.id,
        malformed: true,
      );
      final service = DoneService(gitService: _GateGitService());

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('delivery/evidence_malformed'),
          ),
        ),
      );
    },
  );

  test(
    'DoneService blocks completion when definition_of_done checklist is missing',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_dod_missing_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final active = _activateApprovedTask(layout);
      _seedReviewEvidence(
        layout,
        activeTitle: active.title,
        taskId: active.id,
        includeDefinitionOfDone: false,
      );
      final service = DoneService(gitService: _GateGitService());

      await expectLater(
        service.markDone(temp.path),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('delivery/evidence_malformed') &&
                error.toString().contains('definition_of_done'),
          ),
        ),
      );
    },
  );

  test('DoneService blocks completion when repo is dirty', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_dirty_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final active = _activateApprovedTask(layout);
    _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);
    final git = _GateGitService(isCleanRepo: false);
    final service = DoneService(gitService: git);

    await expectLater(
      service.markDone(temp.path),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('delivery/git_dirty'),
        ),
      ),
    );
  });

  test(
    'DoneService blocks completion when upstream diverged and recovers after fix',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_upstream_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final active = _activateApprovedTask(layout);
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);
      final git = _GateGitService(upstreamDiverged: true);
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

      git.upstreamDiverged = false;
      final title = await service.markDone(temp.path);
      expect(title, active.title);
      final tasks = File(layout.tasksPath).readAsStringSync();
      expect(tasks, contains('- [x]'));
    },
  );

  test('DoneService succeeds with no git remote and auto_push true', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_no_remote_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    // Ensure auto_push is true (the default, but explicit for clarity).
    File(layout.configPath).writeAsStringSync('''
workflow:
  auto_push: true
  auto_merge: true
''');

    final active = _activateApprovedTask(layout);
    _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);
    // Git service with no remote configured.
    final git = _GateGitService(remoteConfigured: false);
    final service = DoneService(gitService: git);

    final title = await service.markDone(temp.path);
    expect(title, active.title);

    final log = File(layout.runLogPath).readAsStringSync();
    expect(log, contains('delivery_preflight_no_remote_warning'));

    final tasks = File(layout.tasksPath).readAsStringSync();
    expect(tasks, contains('- [x]'));
  });

  test('DoneService still pushes normally when remote is available', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_with_remote_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final active = _activateApprovedTask(layout);
    _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);
    final git = _GateGitService();
    final service = DoneService(gitService: git);

    final title = await service.markDone(temp.path);
    expect(title, active.title);

    // Verify remote push was attempted (the git service has a remote).
    expect(git.pushCalled, isTrue);
  });

  test('DoneService with force skips evidence validation', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_force_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    // Activate + approve but do NOT seed review evidence.
    _activateApprovedTask(layout);
    final git = _GateGitService();
    final service = DoneService(gitService: git);

    // Without force: should throw evidence_missing.
    await expectLater(
      service.markDone(temp.path),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('delivery/evidence_missing'),
        ),
      ),
    );

    // Re-approve since state may have been mutated.
    _activateApprovedTask(layout);

    // With force: should succeed despite missing evidence.
    final title = await service.markDone(temp.path, force: true);
    expect(title, isNotEmpty);
    final tasks = File(layout.tasksPath).readAsStringSync();
    expect(tasks, contains('- [x]'));
  });

  test('DoneService with force emits audit event', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_force_audit_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    _activateApprovedTask(layout);
    final service = DoneService(gitService: _GateGitService());

    await service.markDone(temp.path, force: true);

    final log = File(layout.runLogPath).readAsStringSync();
    expect(log, contains('done_force_skip_evidence'));
    expect(log, contains('evidence_bypassed'));
  });

  test(
    'DoneService merges and clears state when task is already done',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_already_done_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final active = _activateApprovedTask(layout);
      _seedReviewEvidence(layout, activeTitle: active.title, taskId: active.id);

      // Pre-mark the task as done in TASKS.md.
      final tasksContent = File(layout.tasksPath).readAsStringSync();
      File(layout.tasksPath).writeAsStringSync(
        tasksContent.replaceFirst('- [ ]', '- [x]'),
      );

      final git = _GateGitService();
      final service = DoneService(gitService: git);

      final title = await service.markDone(temp.path);
      expect(title, active.title);

      // Verify task_already_done was logged.
      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"event":"task_already_done"'));
      expect(log, contains('"error_kind":"task_already_done"'));

      // Verify state was cleaned: active task should be cleared.
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);
      expect(state.reviewStatus, isNull);

      // Verify merge was still attempted — feature branch must land even when
      // the checkbox was pre-marked by the coding agent.
      expect(git.pushCalled, isTrue);
    },
  );

  test(
    'DoneService blocks task after consecutive network push failures at threshold',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_done_gate_push_fail_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final git = _PushFailGitService();
      final service = DoneService(gitService: git);

      // Default network push failure threshold is 5.
      for (var i = 0; i < 5; i++) {
        // Re-activate and re-approve for each attempt.
        final active = _activateApprovedTask(layout);
        _seedReviewEvidence(
          layout,
          activeTitle: active.title,
          taskId: active.id,
        );

        await expectLater(
          service.markDone(temp.path, force: true),
          throwsA(
            predicate(
              (error) =>
                  error is StateError &&
                  error.toString().contains('push_failed'),
            ),
          ),
        );

        // Un-mark the task as done so it can be retried.
        final tasksContent = File(layout.tasksPath).readAsStringSync();
        File(layout.tasksPath).writeAsStringSync(
          tasksContent.replaceAll('- [x]', '- [ ]'),
        );
      }

      // After 5 network failures (default threshold), the task should be blocked.
      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"event":"consecutive_push_failures_blocked"'));
      expect(log, contains('"error_kind":"consecutive_push_failures"'));

      // State should reflect the failure count.
      final state = StateStore(layout.statePath).read();
      expect(state.consecutiveFailures, greaterThanOrEqualTo(5));

      // The task should be marked as blocked in TASKS.md.
      final tasks = File(layout.tasksPath).readAsStringSync();
      expect(tasks, contains('[BLOCKED]'));
    },
  );

  test('DoneService with force still requires review approval', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_gate_force_no_approve_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    // Activate but do NOT approve.
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final active = tasks.first;
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: ActiveTaskState(
          id: active.id,
          title: active.title,
          reviewStatus: 'rejected',
        ),
      ),
    );

    final service = DoneService(gitService: _GateGitService());

    await expectLater(
      service.markDone(temp.path, force: true),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('Review not approved'),
        ),
      ),
    );
  });
}

Task _activateApprovedTask(ProjectLayout layout) {
  final tasks = TaskStore(layout.tasksPath).readTasks();
  final active = tasks.first;
  final store = StateStore(layout.statePath);
  store.write(
    store.read().copyWith(
      activeTask: ActiveTaskState(
        id: active.id,
        title: active.title,
        reviewStatus: 'approved',
        reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    ),
  );
  return active;
}

void _seedReviewEvidence(
  ProjectLayout layout, {
  required String activeTitle,
  required String taskId,
  bool malformed = false,
  bool includeDefinitionOfDone = true,
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
  diffSummary.writeAsStringSync('1 file changed, 2 insertions(+).\n');
  diffPatch.writeAsStringSync(
    'diff --git a/lib/a.dart b/lib/a.dart\n+final ok = true;\n',
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
    if (includeDefinitionOfDone)
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
      if (!malformed) 'diff_patch': 'diff_patch.diff',
    },
  };

  File(
    '${entryDir.path}${Platform.pathSeparator}summary.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
}

class _GateGitService implements GitService {
  _GateGitService({
    this.isCleanRepo = true,
    this.upstreamDiverged = false,
    this.remoteConfigured = true,
  });

  bool isCleanRepo;
  bool upstreamDiverged;
  bool remoteConfigured;
  bool pushCalled = false;

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
  bool isClean(String path) => isCleanRepo;

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
  void push(String path, String remote, String branch) {
    pushCalled = true;
  }

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  void fetch(String path, String remote) {}

  @override
  void pullFastForward(String path, String remote, String branch) {
    if (upstreamDiverged) {
      throw StateError('diverged');
    }
  }

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  bool hasRemote(String path, String remote) => remoteConfigured;

  @override
  String? defaultRemote(String path) => remoteConfigured ? 'origin' : null;

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

/// Git service that always fails on push, for testing consecutive push failure
/// tracking.
class _PushFailGitService extends _GateGitService {
  _PushFailGitService() : super();

  @override
  void push(String path, String remote, String branch) {
    pushCalled = true;
    throw StateError('push rejected by remote');
  }
}
