import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;
  late StateStore stateStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_split_reject_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(title: 'Alpha', id: 'alpha-1'),
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  void writeConfig({bool refinementEnabled = true}) {
    File(layout.configPath).writeAsStringSync(
      'pipeline:\n'
      '  subtask_refinement_enabled: $refinementEnabled\n',
    );
  }

  void setSubtaskState(String current, {Map<String, int> splitAttempts = const {}}) {
    stateStore.write(
      stateStore.read().copyWith(
        subtaskExecution: SubtaskExecutionState(
          current: current,
          splitAttempts: splitAttempts,
        ),
      ),
    );
  }

  test(
    'reject with complexity keyword triggers reactive split: retryCount==0 and queue updated',
    () async {
      writeConfig(refinementEnabled: true);
      setSubtaskState(
        'Implement huge feature touching 15 files across all modules and subsystems',
      );

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout:
                  'REJECT\n'
                  'This subtask is too large and should be broken down into '
                  'smaller pieces touching fewer files.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );

      final specAgentService = SpecAgentService(
        agentService: _SplitAgentService(
          splitResult: [
            'Add model layer for the feature',
            'Wire service logic for the feature',
            'Add integration tests for the feature',
          ],
        ),
      );

      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: _FakeReviewService(),
        gitService: null,
        doneService: _FakeDoneService(),
        specAgentService: specAgentService,
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription:
            'Implement huge feature touching 15 files across all modules and subsystems',
      );

      // Reactive split succeeded — retry counter must NOT be incremented.
      expect(result.retryCount, 0);
      expect(result.taskBlocked, isFalse);
      expect(result.reviewDecision, ReviewDecision.reject);

      // Queue should contain the 3 split subtasks.
      final state = stateStore.read();
      expect(state.subtaskQueue, [
        'Add model layer for the feature',
        'Wire service logic for the feature',
        'Add integration tests for the feature',
      ]);
      // currentSubtask must be cleared.
      expect(state.currentSubtask, isNull);
    },
  );

  test(
    'reject without complexity keyword follows normal retry path',
    () async {
      writeConfig(refinementEnabled: true);
      setSubtaskState('Fix null pointer in auth handler');

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout: 'REJECT\nThe null check is missing in the login method.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );

      var splitCalled = false;
      final specAgentService = SpecAgentService(
        agentService: _SplitAgentService(
          splitResult: ['Should not be called'],
          onCall: () => splitCalled = true,
        ),
      );

      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: _FakeReviewService(),
        gitService: null,
        doneService: _FakeDoneService(),
        specAgentService: specAgentService,
        maxReviewRetries: 5,
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Fix null pointer in auth handler',
      );

      // No complexity keyword — split must NOT be called.
      expect(splitCalled, isFalse);
      // Normal retry increment.
      expect(result.retryCount, 1);
    },
  );

  test(
    'reactive split skipped when subtask was already split once (splitAttempts guard)',
    () async {
      writeConfig(refinementEnabled: true);
      // Mark that this subtask was already split.
      setSubtaskState(
        'Huge feature split',
        splitAttempts: {'huge feature split': 1},
      );

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout:
                  'REJECT\nScope is too large, please break down this task.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );

      var splitCalled = false;
      final specAgentService = SpecAgentService(
        agentService: _SplitAgentService(
          splitResult: ['Should not be returned'],
          onCall: () => splitCalled = true,
        ),
      );

      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: _FakeReviewService(),
        gitService: null,
        doneService: _FakeDoneService(),
        specAgentService: specAgentService,
        maxReviewRetries: 5,
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Huge feature split',
      );

      // Split guard fired — agent must NOT be called.
      expect(splitCalled, isFalse);
      // Normal retry path.
      expect(result.retryCount, 1);
    },
  );

  test(
    'reactive split skipped when pipelineSubtaskRefinementEnabled is false',
    () async {
      writeConfig(refinementEnabled: false);
      setSubtaskState('Implement huge feature touching many files');

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout: 'REJECT\nThis is too large. Please split it.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );

      var splitCalled = false;
      final specAgentService = SpecAgentService(
        agentService: _SplitAgentService(
          splitResult: ['Should not be returned'],
          onCall: () => splitCalled = true,
        ),
      );

      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: _FakeReviewService(),
        gitService: null,
        doneService: _FakeDoneService(),
        specAgentService: specAgentService,
        maxReviewRetries: 5,
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'Implement huge feature touching many files',
      );

      // Config disabled — split must NOT be called.
      expect(splitCalled, isFalse);
      expect(result.retryCount, 1);
    },
  );

  test(
    'reactive split skipped when isSubtask is false',
    () async {
      writeConfig(refinementEnabled: true);

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout: 'REJECT\nScope too large, please split and decompose.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );

      var splitCalled = false;
      final specAgentService = SpecAgentService(
        agentService: _SplitAgentService(
          splitResult: ['Should not be returned'],
          onCall: () => splitCalled = true,
        ),
      );

      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: _FakeReviewService(),
        gitService: null,
        doneService: _FakeDoneService(),
        specAgentService: specAgentService,
        maxReviewRetries: 5,
      );

      // isSubtask: false — split should not apply.
      final result = await service.run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: false,
      );

      expect(splitCalled, isFalse);
      expect(result.retryCount, 1);
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

class _FakeReviewService extends ReviewService {
  @override
  String recordDecision(
    String projectRoot, {
    required String decision,
    String? note,
    String? testSummary,
  }) => super.recordDecision(
    projectRoot,
    decision: decision,
    note: note,
    testSummary: testSummary,
  );
}

class _FakeDoneService extends DoneService {
  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async =>
      'Alpha';

  @override
  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) => 'Alpha';
}


/// Agent service that returns a pre-configured split result as a numbered list.
class _SplitAgentService extends AgentService {
  _SplitAgentService({
    required this.splitResult,
    this.onCall,
  });

  final List<String> splitResult;
  final void Function()? onCall;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    onCall?.call();
    final numbered = splitResult
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: numbered, stderr: ''),
      usedFallback: false,
    );
  }
}
