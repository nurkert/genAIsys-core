import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/fake_services.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late FakeGitService fakeGit;
  late DoneService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_done_svc_');
    workspace.ensureStructure();
    fakeGit = FakeGitService(isRepoValue: false);
    service = DoneService(gitService: fakeGit);
  });

  tearDown(() => workspace.dispose());

  /// Seed an active task with approved review and evidence bundle.
  void seedApprovedTask({
    String title = 'My Task',
    WorkflowStage stage = WorkflowStage.review,
  }) {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] $title\n',
    );
    final state = ProjectStateBuilder()
        .withActiveTask('my-task-1', title)
        .withReview('approved')
        .withWorkflowStage(stage)
        .build();
    StateStore(workspace.layout.statePath).write(state);

    // Write evidence bundle required by markDone validation.
    ReviewEvidenceBundleBuilder(workspace.layout)
        .withTaskId('my-task-1')
        .withTaskTitle(title)
        .withDecision('approve')
        .write();
  }

  test('successful markDone with valid evidence (no git)', () async {
    seedApprovedTask();

    final result = await service.markDone(workspace.root.path);

    expect(result, 'My Task');

    // TASKS.md should have [x] now.
    final tasksContent = File(workspace.layout.tasksPath).readAsStringSync();
    expect(tasksContent, contains('[x]'));

    // State should reflect completion.
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.workflowStage, WorkflowStage.done);
  });

  test('markDone blocked when review not approved', () async {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] Task\n',
    );
    final state = ProjectStateBuilder()
        .withActiveTask('task-1', 'Task')
        .withReview('rejected')
        .build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.markDone(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Review not approved'),
        ),
      ),
    );
  });

  test('markDone blocked when no active task', () async {
    final state = ProjectStateBuilder()
        .withNoActiveTask()
        .withReview('approved')
        .build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.markDone(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No active task set'),
        ),
      ),
    );
  });

  test('markDone clears per-task cooldown entries', () async {
    seedApprovedTask(title: 'Cooldown Task');

    // Seed cooldown entries.
    final store = StateStore(workspace.layout.statePath);
    final cooldownState = store.read();
    store.write(
      cooldownState.copyWith(
        retryScheduling: cooldownState.retryScheduling.copyWith(
          cooldownUntil: {
            'id:my-task-1': '2099-01-01T00:00:00Z',
            'title:cooldown task': '2099-01-01T00:00:00Z',
          },
        ),
      ),
    );

    await service.markDone(workspace.root.path);

    final state = store.read();
    // Cooldown for completed task should be cleared.
    expect(state.taskCooldownUntil, isEmpty);
  });

  test('blockActive marks task as BLOCKED in TASKS.md', () {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] Block me\n',
    );
    final state = ProjectStateBuilder()
        .withActiveTask('block-me-1', 'Block me')
        .withWorkflowStage(WorkflowStage.execution)
        .build();
    StateStore(workspace.layout.statePath).write(state);

    service.blockActive(workspace.root.path, reason: 'Auto-cycle: test reason');

    final tasksContent = File(workspace.layout.tasksPath).readAsStringSync();
    expect(tasksContent, contains('[BLOCKED]'));
    expect(tasksContent, contains('test reason'));
  });

  test('blockActive without active task throws', () {
    workspace.writeTasks('## Backlog\n');
    final state = ProjectStateBuilder().withNoActiveTask().build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.blockActive(workspace.root.path, reason: 'test'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No active task set'),
        ),
      ),
    );
  });

  test('markDone blocked when review evidence bundle is missing', () async {
    // Set up an approved task but do NOT write the evidence bundle.
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] No Evidence Task\n',
    );
    final state = ProjectStateBuilder()
        .withActiveTask('no-evidence-1', 'No Evidence Task')
        .withReview('approved')
        .withWorkflowStage(WorkflowStage.review)
        .build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.markDone(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('evidence'),
        ),
      ),
    );
  });

  test('git delivery success path with feature branch merge', () async {
    // Configure FakeGitService as a git repo on a feature branch.
    final gitService = FakeGitService(
      isRepoValue: true,
      isCleanValue: true,
      currentBranchName: 'feat/my-task-1',
      branchExistsValue: true,
      defaultRemoteName: null, // no remote, local-only delivery
      hasMergeInProgressValue: false,
    );
    final gitDoneService = DoneService(gitService: gitService);
    seedApprovedTask();

    final result = await gitDoneService.markDone(workspace.root.path);

    expect(result, 'My Task');

    // TASKS.md should have the task marked done.
    final tasksContent = File(workspace.layout.tasksPath).readAsStringSync();
    expect(tasksContent, contains('[x]'));

    // State should reflect completion.
    final updatedState = StateStore(workspace.layout.statePath).read();
    expect(updatedState.workflowStage, WorkflowStage.done);
  });

  test('delivery preflight fails when git dirty', () async {
    // Use git repo that is dirty.
    final dirtyGit = FakeGitService(isRepoValue: true, isCleanValue: false);
    final dirtyService = DoneService(gitService: dirtyGit);
    seedApprovedTask();

    expect(
      () => dirtyService.markDone(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('clean before delivery'),
        ),
      ),
    );
  });

  test('delivery preflight fails when merge in progress', () async {
    final mergeGit = FakeGitService(
      isRepoValue: true,
      isCleanValue: true,
      hasMergeInProgressValue: true,
    );
    final mergeService = DoneService(gitService: mergeGit);
    seedApprovedTask();

    expect(
      () => mergeService.markDone(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          anyOf(contains('Merge in progress'), contains('merge_conflict')),
        ),
      ),
    );
  });

  test('markDone clears subtask queue and current subtask', () async {
    seedApprovedTask(title: 'Subtask Task');

    // Seed subtask state.
    final store = StateStore(workspace.layout.statePath);
    final subtaskState = store.read();
    store.write(
      subtaskState.copyWith(
        subtaskExecution: subtaskState.subtaskExecution.copyWith(
          queue: ['subtask-a', 'subtask-b', 'subtask-c'],
          current: 'subtask-a',
        ),
      ),
    );

    // Verify the subtask state is present before markDone.
    final before = store.read();
    expect(before.subtaskQueue, isNotEmpty);
    expect(before.currentSubtask, isNotNull);

    await service.markDone(workspace.root.path);

    // After markDone, subtask state must be cleared.
    final after = store.read();
    expect(after.subtaskQueue, isEmpty);
    expect(after.currentSubtask, isNull);
  });

  test(
    'markDone still emits task_done and merges when checkbox already [x]',
    () async {
      // Simulate agent marking [x] during coding on a feature branch.
      workspace.writeTasks(
        '## Backlog\n'
        '- [x] [P1] [CORE] Already Done Task\n',
      );
      final state = ProjectStateBuilder()
          .withActiveTask('already-done-task-1', 'Already Done Task')
          .withReview('approved')
          .withWorkflowStage(WorkflowStage.review)
          .build();
      StateStore(workspace.layout.statePath).write(state);

      // Write evidence bundle.
      ReviewEvidenceBundleBuilder(workspace.layout)
          .withTaskId('already-done-task-1')
          .withTaskTitle('Already Done Task')
          .withDecision('approve')
          .write();

      // Use a git service configured for feature branch merge.
      final gitService = FakeGitService(
        isRepoValue: true,
        isCleanValue: true,
        currentBranchName: 'feat/already-done-task-1',
        branchExistsValue: true,
        defaultRemoteName: null,
        hasMergeInProgressValue: false,
      );
      final gitDoneService = DoneService(gitService: gitService);

      final result = await gitDoneService.markDone(workspace.root.path);
      expect(result, 'Already Done Task');

      // task_done must be emitted for downstream activation-skip logic.
      final runLogContent =
          File(workspace.layout.runLogPath).readAsStringSync();
      final events = runLogContent
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();
      final taskDoneEvents =
          events.where((e) => e['event'] == 'task_done').toList();
      expect(taskDoneEvents, isNotEmpty,
          reason: 'task_done must be emitted so activate_service can skip '
              'already-done tasks');

      // task_already_done should also be logged.
      final alreadyDoneEvents =
          events.where((e) => e['event'] == 'task_already_done').toList();
      expect(alreadyDoneEvents, isNotEmpty);

      // Git merge should have been invoked (checkout was called).
      final checkouts =
          gitService.calls.where((c) => c.startsWith('checkout:')).toList();
      expect(checkouts, isNotEmpty,
          reason: 'Merge flow should execute even when checkbox is [x]');
    },
  );
}
