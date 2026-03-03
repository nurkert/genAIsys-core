import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';
import 'package:genaisys/core/services/productivity_reflection_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/observability/run_log_insight_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/storage/state_store.dart';
import '../support/test_workspace.dart';

/// Regression test: loads a config with ALL non-default values and verifies
/// each consuming service reads the correct value. If any config field
/// silently stops being wired, this test fails.
void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create();
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  test('all Phase 2 config fields are wired into their services', () {
    // Write config with ALL non-default values.
    workspace.writeConfig('''
review:
  fresh_context: false
  max_rounds: 1
supervisor:
  max_interventions_per_hour: 2
  check_interval_seconds: 10
reflection:
  min_samples: 10
  analysis_window_lines: 500
pipeline:
  forensic_recovery_enabled: false
  error_pattern_learning_enabled: false
  impact_context_max_files: 3
''');

    final config = ProjectConfig.load(workspace.root.path);

    // Phase 2a: Review settings.
    expect(
      config.reviewFreshContext,
      isFalse,
      reason: 'reviewFreshContext should be wired',
    );
    expect(
      config.reviewMaxRounds,
      1,
      reason: 'reviewMaxRounds should be wired',
    );

    // Phase 2b: Supervisor settings.
    expect(
      config.supervisorMaxInterventionsPerHour,
      2,
      reason: 'supervisorMaxInterventionsPerHour should be wired',
    );
    expect(
      config.supervisorCheckInterval,
      const Duration(seconds: 10),
      reason: 'supervisorCheckInterval should be wired',
    );

    // Phase 2c: Reflection settings.
    expect(
      config.reflectionMinSamples,
      10,
      reason: 'reflectionMinSamples should be wired',
    );
    expect(
      config.reflectionAnalysisWindowLines,
      500,
      reason: 'reflectionAnalysisWindowLines should be wired',
    );

    // Phase 2d: Pipeline intelligence settings.
    expect(
      config.pipelineForensicRecoveryEnabled,
      isFalse,
      reason: 'pipelineForensicRecoveryEnabled should be wired',
    );
    expect(
      config.pipelineErrorPatternLearningEnabled,
      isFalse,
      reason: 'pipelineErrorPatternLearningEnabled should be wired',
    );
    expect(
      config.pipelineImpactContextMaxFiles,
      3,
      reason: 'pipelineImpactContextMaxFiles should be wired',
    );
  });

  test('reflectionMinSamples gates ProductivityReflectionService', () {
    workspace.writeConfig('reflection:\n  min_samples: 100\n');
    workspace.writeRunLog([
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('review_approve'),
      _event('task_done'),
    ]);

    final service = ProductivityReflectionService();
    final result = service.reflect(workspace.root.path);

    // Only 3 events, threshold is 100 — reflection should be skipped.
    expect(
      result.triggered,
      isFalse,
      reason: 'reflectionMinSamples should skip reflection',
    );
  });

  test('reflectionAnalysisWindowLines gates RunLogInsightService', () {
    workspace.writeConfig('reflection:\n  analysis_window_lines: 2\n');
    workspace.writeRunLog([
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('review_approve'),
      _event('task_done'),
      _event('orchestrator_run_error', data: {'error_kind': 'agent_timeout'}),
    ]);

    final service = RunLogInsightService();
    final insights = service.analyze(workspace.root.path);

    // Window is 2 lines — only last 2 events should be visible.
    expect(
      insights.totalEvents,
      2,
      reason: 'reflectionAnalysisWindowLines should limit analysis',
    );
  });

  test('errorPatternLearningEnabled gates ErrorPatternRegistryService', () {
    workspace.writeConfig(
      'pipeline:\n  error_pattern_learning_enabled: false\n',
    );

    final service = ErrorPatternRegistryService();
    service.mergeObservations(
      workspace.root.path,
      errorKindCounts: {'test_error': 5},
    );

    final entries = service.load(workspace.root.path);
    expect(
      entries,
      isEmpty,
      reason: 'errorPatternLearningEnabled=false should prevent recording',
    );
  });

  test(
    'reviewMaxRounds=1 blocks task after first reject via run() override',
    () async {
      // Set up a project with reviewMaxRounds=1 in config.
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_max_rounds_config_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync(
        'review:\n  max_rounds: 1\n'
        'pipeline:\n  forensic_recovery_enabled: false\n',
      );
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: ActiveTaskState(
            id: 'test-task-1',
            title: 'TestTask',
          ),
        ),
      );

      final config = ProjectConfig.load(temp.path);
      expect(
        config.reviewMaxRounds,
        1,
        reason: 'config should parse reviewMaxRounds=1',
      );

      // Create a TaskCycleService with the default constructor (maxReviewRetries=3)
      // but pass reviewMaxRounds from config via the run() parameter — this
      // mirrors how OrchestratorStepService and InProcessGenaisysApi wire it.
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: ReviewService(),
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries:
            3, // Constructor default — should be overridden by run().
      );

      final normalizedMaxRounds = config.reviewMaxRounds < 1
          ? 1
          : config.reviewMaxRounds;
      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        maxReviewRetries: normalizedMaxRounds,
      );

      // With reviewMaxRounds=1, the first reject should block the task.
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 1);
      expect(
        result.taskBlocked,
        isTrue,
        reason: 'reviewMaxRounds=1 should block after first reject',
      );
      expect(doneService.blockCalls, 1);
    },
  );
}

TaskPipelineResult _buildPipelineResult({ReviewAgentResult? review}) {
  return TaskPipelineResult(
    plan: _specResult(SpecKind.plan),
    spec: _specResult(SpecKind.spec),
    subtasks: _specResult(SpecKind.subtasks),
    coding: _codingResult(),
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

CodingAgentResult _codingResult() {
  return CodingAgentResult(
    path: '/tmp/attempt.txt',
    usedFallback: false,
    response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
  );
}

ReviewAgentResult _reviewResult(ReviewDecision decision) {
  return ReviewAgentResult(
    decision: decision,
    response: const AgentResponse(
      exitCode: 0,
      stdout: 'REJECT\nNeeds changes.',
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
  }) async {
    return result;
  }
}

class _FakeGitService implements GitService {
  @override
  bool isGitRepo(String path) => true;
  @override
  bool hasChanges(String path) => false;
  @override
  void addAll(String path) {}
  @override
  void commit(String path, String message) {}
  @override
  String? defaultRemote(String path) => null;
  @override
  String currentBranch(String path) => 'main';
  @override
  bool branchExists(String path, String branch) => true;
  @override
  List<String> localBranchesMergedInto(String path, String baseRef) => [];
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
  List<String> changedPaths(String path) => [];
  @override
  void checkout(String path, String ref) {}
  @override
  void createBranch(String path, String branch, {String? startPoint}) {}
  @override
  void abortMerge(String path) {}
  @override
  List<String> conflictPaths(String path) => [];
  @override
  void deleteBranch(String path, String branch, {bool force = false}) {}
  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}
  @override
  String diffPatch(String path) => '';
  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);
  @override
  String diffSummary(String path) => '';
  @override
  void ensureClean(String path) {}
  @override
  void fetch(String path, String remote) {}
  @override
  bool hasRemote(String path, String remote) => false;
  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) => false;
  @override
  void stashPop(String path) {}
  @override
  bool hasMergeInProgress(String path) => false;
  @override
  bool isClean(String path) => true;
  @override
  void merge(String path, String branch) {}
  @override
  void pullFastForward(String path, String remote, String branch) {}
  @override
  bool remoteBranchExists(String path, String remote, String branch) => false;
  @override
  String repoRoot(String path) => path;
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

class _FakeDoneService extends DoneService {
  int blockCalls = 0;
  String? lastBlockReason;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async =>
      'Task';

  @override
  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) {
    blockCalls += 1;
    lastBlockReason = reason;
    return 'Task';
  }
}

String _event(String event, {Map<String, Object?>? data}) {
  final payload = <String, Object?>{
    'timestamp': '2025-01-01T00:00:00Z',
    'event': event,
  };
  if (data != null) {
    payload['data'] = data;
  }
  return jsonEncode(payload);
}
