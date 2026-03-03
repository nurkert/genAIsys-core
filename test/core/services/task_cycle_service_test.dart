import 'package:test/test.dart';

import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/retry_scheduling_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/fake_services.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late FakeGitService fakeGit;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_task_cycle_svc_');
    workspace.ensureStructure();
    fakeGit = FakeGitService();
  });

  tearDown(() => workspace.dispose());

  group('_clearRetry uses persisted activeTaskRetryKey', () {
    test('clears correct counter when persisted key differs from computed key',
        () async {
      // Scenario: activeTaskId was changed mid-cycle (e.g., state corruption)
      // but the persisted retry key still points to the original task.
      workspace.writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Original task\n',
      );

      final stateStore = StateStore(workspace.layout.statePath);
      stateStore.write(
        ProjectStateBuilder()
            .withActiveTask('changed-id', 'Original task')
            .withReview('approved', updatedAt: '2026-01-01T00:00:00Z')
            .build()
            .copyWith(
              activeTask: const ActiveTaskState(
                id: 'changed-id',
                title: 'Original task',
                retryKey: 'id:original-id',
                reviewStatus: 'approved',
                reviewUpdatedAt: '2026-01-01T00:00:00Z',
              ),
              retryScheduling: const RetrySchedulingState(
                retryCounts: {'id:original-id': 2, 'id:other-task': 1},
              ),
            ),
      );

      final service = TaskCycleService(
        gitService: fakeGit,
        maxReviewRetries: 3,
      );

      // Use the subtask resume path (avoids DoneService.markDone complexity).
      final result = await service.run(
        workspace.root.path,
        codingPrompt: 'test prompt',
        isSubtask: true,
        subtaskDescription: 'test subtask',
      );

      // The resume path should have been triggered (reviewStatus was approved).
      expect(result.reviewDecision, ReviewDecision.approve);

      // The persisted key 'id:original-id' should have been cleared.
      final state = stateStore.read();
      expect(state.taskRetryCounts.containsKey('id:original-id'), isFalse);
      // Other keys should be untouched.
      expect(state.taskRetryCounts['id:other-task'], 1);
    });

    test('falls back to computed key when no persisted key exists', () async {
      workspace.writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Some task\n',
      );

      final stateStore = StateStore(workspace.layout.statePath);
      stateStore.write(
        ProjectStateBuilder()
            .withActiveTask('task-1', 'Some task')
            .withReview('approved', updatedAt: '2026-01-01T00:00:00Z')
            .build()
            .copyWith(
              // No persisted retry key — force fallback to computed key.
              activeTask: const ActiveTaskState(
                id: 'task-1',
                title: 'Some task',
                retryKey: null,
                reviewStatus: 'approved',
                reviewUpdatedAt: '2026-01-01T00:00:00Z',
              ),
              retryScheduling: const RetrySchedulingState(
                retryCounts: {'id:task-1': 3},
              ),
            ),
      );

      final service = TaskCycleService(
        gitService: fakeGit,
        maxReviewRetries: 3,
      );

      final result = await service.run(
        workspace.root.path,
        codingPrompt: 'test prompt',
        isSubtask: true,
        subtaskDescription: 'test subtask',
      );

      expect(result.reviewDecision, ReviewDecision.approve);

      // Without persisted key, _clearRetry computes 'id:task-1' and clears it.
      final state = stateStore.read();
      expect(state.taskRetryCounts.containsKey('id:task-1'), isFalse);
    });
  });
}
