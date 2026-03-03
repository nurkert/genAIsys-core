import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;
  late StateStore stateStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_subtask_commit_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'my-feature-1',
          title: 'My Feature',
        ),
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  void writeConfig({bool subtaskCommitEnabled = true}) {
    File(layout.configPath).writeAsStringSync(
      'pipeline:\n  subtask_commit_enabled: $subtaskCommitEnabled\n',
    );
  }

  test(
    'subtask approve with commit enabled: commit called with subtask message, push NOT called',
    () async {
      writeConfig(subtaskCommitEnabled: true);
      final gitSpy = _GitSpy(isRepo: true, changesAvailable: true);

      final service = TaskCycleService(
        taskPipelineService: _FakeTaskPipelineService(
          _buildPipelineResult(review: _approveReview()),
        ),
        reviewService: ReviewService(gitService: gitSpy),
        gitService: gitSpy,
        doneService: _FakeDoneService(),
      );

      await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Add the login endpoint',
      );

      expect(gitSpy.commitCalls, 1, reason: 'Commit should be called once');
      expect(
        gitSpy.pushCalls,
        0,
        reason: 'Push must NOT be called for per-subtask commit',
      );
      expect(
        gitSpy.lastCommitMessage,
        contains('my-feature'),
        reason: 'Commit message should include task slug',
      );
      expect(
        gitSpy.lastCommitMessage,
        contains('Add the login endpoint'),
        reason: 'Commit message should include subtask description',
      );
    },
  );

  test(
    'subtask approve with commit disabled: falls back to commitAndPush (task-level message)',
    () async {
      writeConfig(subtaskCommitEnabled: false);
      final gitSpy = _GitSpy(isRepo: true, changesAvailable: true);

      final service = TaskCycleService(
        taskPipelineService: _FakeTaskPipelineService(
          _buildPipelineResult(review: _approveReview()),
        ),
        reviewService: ReviewService(gitService: gitSpy),
        gitService: gitSpy,
        doneService: _FakeDoneService(),
      );

      await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Add the login endpoint',
      );

      // Fallback to _commitAndPush: commit happens with generic task message.
      // No push because defaultRemote is null.
      expect(gitSpy.commitCalls, 1, reason: 'Commit called via commitAndPush');
      expect(gitSpy.pushCalls, 0, reason: 'No push when defaultRemote is null');
      expect(
        gitSpy.lastCommitMessage,
        equals('task: My Feature'),
        reason: 'Fallback uses generic task commit message',
      );
    },
  );

  test(
    'subtask approve with commit enabled but no diff: no commit, no push',
    () async {
      writeConfig(subtaskCommitEnabled: true);
      final gitSpy = _GitSpy(isRepo: true, changesAvailable: false);

      final service = TaskCycleService(
        taskPipelineService: _FakeTaskPipelineService(
          _buildPipelineResult(review: _approveReview()),
        ),
        reviewService: ReviewService(gitService: gitSpy),
        gitService: gitSpy,
        doneService: _FakeDoneService(),
      );

      await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Add the login endpoint',
      );

      expect(
        gitSpy.commitCalls,
        0,
        reason: 'No commit when worktree is clean',
      );
      expect(gitSpy.pushCalls, 0);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

TaskPipelineResult _buildPipelineResult({ReviewAgentResult? review}) {
  return TaskPipelineResult(
    plan: _specResult(SpecKind.plan),
    spec: _specResult(SpecKind.spec),
    subtasks: _specResult(SpecKind.subtasks),
    coding: CodingAgentResult(
      path: '/tmp/attempt.txt',
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    review: review,
  );
}

SpecAgentResult _specResult(SpecKind kind) {
  return SpecAgentResult(
    path: '/tmp/${kind.name}.md',
    kind: kind,
    wrote: true,
    usedFallback: false,
    response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
  );
}

ReviewAgentResult _approveReview() {
  return ReviewAgentResult(
    decision: ReviewDecision.approve,
    response: const AgentResponse(
      exitCode: 0,
      stdout: 'APPROVE\nLooks good.',
      stderr: '',
    ),
    usedFallback: false,
  );
}

class _FakeTaskPipelineService extends TaskPipelineService {
  _FakeTaskPipelineService(this.result);

  final TaskPipelineResult result;

  @override
  Future<TaskPipelineResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    ReviewPersona reviewPersona = ReviewPersona.general,
    TaskCategory? taskCategory,
    List<String> contractNotes = const [],
    int retryCount = 0,
  }) async => result;
}

class _FakeDoneService extends DoneService {
  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async =>
      'My Feature';

  @override
  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) => 'My Feature';
}

/// A spy [GitService] that records [commit] and [push] call counts.
class _GitSpy implements GitService {
  _GitSpy({required this.isRepo, required this.changesAvailable});

  final bool isRepo;
  final bool changesAvailable;

  int commitCalls = 0;
  int pushCalls = 0;
  String? lastCommitMessage;

  @override
  bool isGitRepo(String path) => isRepo;

  @override
  bool hasChanges(String path) => changesAvailable;

  @override
  void addAll(String path) {}

  @override
  void commit(String path, String message) {
    commitCalls += 1;
    lastCommitMessage = message;
  }

  @override
  void push(String path, String remote, String branch) {
    pushCalls += 1;
  }

  @override
  String? defaultRemote(String path) => null;

  @override
  String currentBranch(String path) => 'main';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) => [];

  @override
  bool isClean(String path) => !changesAvailable;

  @override
  void ensureClean(String path) {}

  @override
  void checkout(String path, String ref) {}

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void merge(String path, String branch) {}

  @override
  List<String> conflictPaths(String path) => [];

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  void abortMerge(String path) {}

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {}

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  void fetch(String path, String remote) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => false;

  @override
  bool hasRemote(String path, String remote) => false;

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
  }) => false;

  @override
  void stashPop(String path) {}

  @override
  List<String> changedPaths(String path) => [];

  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  String diffSummary(String path) => '';

  @override
  String diffPatch(String path) => '';

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
  List<String> recentCommitMessages(String path, {int count = 10}) =>
      const [];

  @override
  String headCommitSha(String path, {bool short = false}) => 'abc1234';

  @override
  void resetIndex(String path) {}

  @override
  int commitCount(String path) => 1;

  @override
  bool hasStagedChanges(String path) => false;

  @override
  String repoRoot(String path) => path;

  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';
  @override
  bool isCommitReachable(String path, String sha) => true;
}
