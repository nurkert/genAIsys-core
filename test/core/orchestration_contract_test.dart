import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/services/workflow_service.dart';
import 'package:genaisys/core/models/retry_scheduling_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/builders.dart';
import '../support/fake_services.dart';
import '../support/test_workspace.dart';

/// Orchestration contract tests verify cross-service invariants that
/// individual service tests cannot catch. These test the full lifecycle
/// of activate → task cycle → done, ensuring the services compose correctly.
void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_orch_');
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  /// Seed TASKS.md with two open tasks.
  void seedTasks() {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] First Task\n'
      '- [ ] [P2] [QA] Second Task\n',
    );
  }

  /// Set approved review in state and seed evidence bundle so
  /// DoneService.markDone passes validation. Uses direct state write
  /// rather than ReviewService.recordDecision to avoid AuditTrailService
  /// side effects in the test environment.
  void approveAndSeedEvidence() {
    final store = StateStore(workspace.layout.statePath);
    final state = store.read();
    store.write(
      state.copyWith(
        activeTask: state.activeTask.copyWith(
          reviewStatus: 'approved',
          reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ),
    );
    ReviewEvidenceBundleBuilder(workspace.layout)
        .withTaskId(state.activeTaskId ?? '')
        .withTaskTitle(state.activeTaskTitle ?? '')
        .withDecision('approve')
        .write();
  }

  test('full lifecycle: activate → approve → done completes cleanly', () async {
    seedTasks();
    final fakeGit = FakeGitService(isRepoValue: false);
    final activateService = ActivateService(gitService: fakeGit);
    final workflowService = WorkflowService();
    final doneService = DoneService(gitService: fakeGit);

    // 1. Activate the first task.
    final activation = activateService.activate(workspace.root.path);
    expect(activation.hasTask, isTrue);
    expect(activation.task!.title, 'First Task');

    // Verify workflow advanced to planning.
    expect(
      workflowService.getStage(workspace.root.path),
      WorkflowStage.planning,
    );

    // 2. Advance workflow to execution → review → done.
    workflowService.transition(workspace.root.path, WorkflowStage.execution);
    workflowService.transition(workspace.root.path, WorkflowStage.review);
    workflowService.transition(workspace.root.path, WorkflowStage.done);

    // 3. Set approved review + seed evidence.
    approveAndSeedEvidence();

    // 4. Mark done.
    final doneTitle = await doneService.markDone(workspace.root.path);
    expect(doneTitle, 'First Task');

    // 5. Verify clean-end state.
    final finalState = StateStore(workspace.layout.statePath).read();
    expect(finalState.workflowStage, WorkflowStage.done);

    // TASKS.md should have [x] for the first task.
    final tasksContent = File(workspace.layout.tasksPath).readAsStringSync();
    expect(tasksContent, contains('[x]'));
    expect(tasksContent, contains('First Task'));
  });

  test('clean-end invariant: state is consistent after completion', () async {
    seedTasks();
    final fakeGit = FakeGitService(isRepoValue: false);
    final activateService = ActivateService(gitService: fakeGit);
    final workflowService = WorkflowService();
    final doneService = DoneService(gitService: fakeGit);

    // Full cycle.
    activateService.activate(workspace.root.path);
    workflowService.transition(workspace.root.path, WorkflowStage.execution);
    workflowService.transition(workspace.root.path, WorkflowStage.review);
    workflowService.transition(workspace.root.path, WorkflowStage.done);
    approveAndSeedEvidence();
    await doneService.markDone(workspace.root.path);

    // Clean-end invariant: workflow is done, no stale error state.
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.workflowStage, WorkflowStage.done);
    // Task cooldown entries for completed task should be cleared.
    final cooldowns = state.taskCooldownUntil;
    for (final key in cooldowns.keys) {
      expect(key, isNot(contains('first-task')));
    }
  });

  test('no state leaks between sequential task lifecycles', () async {
    seedTasks();
    final fakeGit = FakeGitService(isRepoValue: false);
    final activateService = ActivateService(gitService: fakeGit);
    final workflowService = WorkflowService();
    final doneService = DoneService(gitService: fakeGit);

    // --- Lifecycle 1: First Task ---
    final a1 = activateService.activate(workspace.root.path);
    expect(a1.task!.title, 'First Task');

    workflowService.transition(workspace.root.path, WorkflowStage.execution);
    workflowService.transition(workspace.root.path, WorkflowStage.review);
    workflowService.transition(workspace.root.path, WorkflowStage.done);
    approveAndSeedEvidence();
    await doneService.markDone(workspace.root.path);

    final stateAfterFirst = StateStore(workspace.layout.statePath).read();
    expect(stateAfterFirst.workflowStage, WorkflowStage.done);

    // --- Lifecycle 2: Activate second task ---
    // Transition from done → planning for new cycle.
    workflowService.transition(workspace.root.path, WorkflowStage.planning);
    final a2 = activateService.activate(workspace.root.path);
    expect(a2.hasTask, isTrue);
    expect(a2.task!.title, 'Second Task');

    // Verify no stale state from first lifecycle.
    final stateAfterSecond = StateStore(workspace.layout.statePath).read();
    expect(stateAfterSecond.activeTaskTitle, 'Second Task');
    // Review status should have been cleared on activation.
    expect(stateAfterSecond.reviewStatus, isNull);
    // Forensic state should be cleared.
    expect(stateAfterSecond.forensicRecoveryAttempted, isFalse);
    expect(stateAfterSecond.forensicGuidance, isNull);
    // Consecutive failures should be reset.
    expect(stateAfterSecond.consecutiveFailures, 0);
  });

  test(
    'reject-archival invariant: rejected review keeps state consistent',
    () async {
      seedTasks();
      final fakeGit = FakeGitService(isRepoValue: false);
      final activateService = ActivateService(gitService: fakeGit);
      final reviewService = ReviewService(gitService: fakeGit);
      final workflowService = WorkflowService();

      activateService.activate(workspace.root.path);
      workflowService.transition(workspace.root.path, WorkflowStage.execution);

      // Record rejection.
      reviewService.recordDecision(workspace.root.path, decision: 'reject');

      final state = StateStore(workspace.layout.statePath).read();
      expect(state.reviewStatus, 'rejected');
      // Workflow should loop back to execution.
      expect(state.workflowStage, WorkflowStage.execution);

      // Task should still be active after reject.
      expect(state.activeTaskId, isNotNull);
      expect(state.activeTaskTitle, 'First Task');
    },
  );

  test(
    'deterministic halt invariant: task blocked after retry exhaustion',
    () async {
      seedTasks();
      final fakeGit = FakeGitService(isRepoValue: false);
      final activateService = ActivateService(gitService: fakeGit);
      final workflowService = WorkflowService();

      activateService.activate(workspace.root.path);
      workflowService.transition(workspace.root.path, WorkflowStage.execution);

      // Simulate retry exhaustion by seeding high retry count.
      final store = StateStore(workspace.layout.statePath);
      final state = store.read();
      final taskId = state.activeTaskId!;
      store.write(state.copyWith(retryScheduling: RetrySchedulingState(retryCounts: {'id:$taskId': 2})));

      // Create a fake pipeline + cycle service that will reject.
      final pipeline = _FakeTaskPipelineService(_buildRejectPipelineResult());
      final reviewService = ReviewService(gitService: fakeGit);
      final doneService = DoneService(gitService: fakeGit);
      final cycleService = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: fakeGit,
        doneService: doneService,
        maxReviewRetries: 3,
      );

      final result = await cycleService.run(
        workspace.root.path,
        codingPrompt: 'Fix the bug',
      );

      // Task should be blocked after hitting max retries.
      expect(result.taskBlocked, isTrue);
      expect(result.retryCount, 3);

      // Active task should be cleared (deterministic halt).
      final finalState = store.read();
      expect(finalState.activeTaskId, isNull);
      expect(finalState.activeTaskTitle, isNull);
    },
  );
}

// ---------------------------------------------------------------------------
// Inline fakes for orchestration contract test
// ---------------------------------------------------------------------------

TaskPipelineResult _buildRejectPipelineResult() {
  return TaskPipelineResult(
    plan: SpecAgentResult(
      path: '/tmp/plan.md',
      kind: SpecKind.plan,
      wrote: true,
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    spec: SpecAgentResult(
      path: '/tmp/spec.md',
      kind: SpecKind.spec,
      wrote: true,
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    subtasks: SpecAgentResult(
      path: '/tmp/subtasks.md',
      kind: SpecKind.subtasks,
      wrote: true,
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    coding: CodingAgentResult(
      path: '/tmp/attempt.txt',
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    review: ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: const AgentResponse(
        exitCode: 0,
        stdout: 'REJECT\nNeeds more work.',
        stderr: '',
      ),
      usedFallback: false,
    ),
  );
}

class _FakeTaskPipelineService extends TaskPipelineService {
  _FakeTaskPipelineService(this.result);

  final TaskPipelineResult result;
  int calls = 0;

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
    calls += 1;
    return result;
  }
}
