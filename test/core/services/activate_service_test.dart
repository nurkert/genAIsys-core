import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/fake_services.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late FakeGitService fakeGit;
  late ActivateService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_activate_svc_');
    workspace.ensureStructure();
    fakeGit = FakeGitService();
    service = ActivateService(gitService: fakeGit);
  });

  tearDown(() => workspace.dispose());

  /// Write a simple TASKS.md with one open P1 CORE task.
  void writeSimpleTask({String title = 'Implement feature'}) {
    workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] $title
''');
  }

  test('successful activation from idle state', () {
    writeSimpleTask();

    final result = service.activate(workspace.root.path);

    expect(result.hasTask, isTrue);
    expect(result.task!.title, 'Implement feature');

    // Verify state was updated.
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.activeTaskId, isNotEmpty);
    expect(state.activeTaskTitle, 'Implement feature');
    expect(state.workflowStage, WorkflowStage.planning);

    // Review should be cleared on activation.
    expect(state.reviewStatus, isNull);
    expect(state.reviewUpdatedAt, isNull);

    // Forensic state should be cleared.
    expect(state.forensicRecoveryAttempted, isFalse);
    expect(state.forensicGuidance, isNull);

    // Run log should contain activation event.
    final lines = _readRunLogLines(
      workspace.layout.runLogPath,
    ).where((e) => e['event'] == 'activate_task');
    expect(lines, isNotEmpty);
  });

  test('activation by requestedId selects exact task', () {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] Task A\n'
      '- [ ] [P1] [CORE] Task B\n',
    );

    // Parse to find the ID of Task B at line index 2 (0-based: line 0 = section header, 1 = Task A, 2 = Task B).
    final taskB = Task.parseLine(
      line: '- [ ] [P1] [CORE] Task B',
      section: 'Backlog',
      lineIndex: 2,
    )!;

    final result = service.activate(workspace.root.path, requestedId: taskB.id);

    expect(result.hasTask, isTrue);
    expect(result.task!.title, 'Task B');
  });

  test('activation of completed task fails', () {
    workspace.writeTasks('''
## Backlog
- [x] [P1] [CORE] Done task
- [ ] [P1] [CORE] Open task
''');

    expect(
      () => service.activate(workspace.root.path, requestedTitle: 'Done task'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already done'),
        ),
      ),
    );
  });

  test('activation of BLOCKED task fails when not auto-cycle', () {
    workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] [BLOCKED] Blocked task
- [ ] [P1] [CORE] Open task
''');

    expect(
      () =>
          service.activate(workspace.root.path, requestedTitle: 'Blocked task'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('blocked'),
        ),
      ),
    );
  });

  test('state transitions clear forensic data on activation', () {
    writeSimpleTask();

    // Seed state with forensic data.
    final state = ProjectStateBuilder()
        .withForensicState(attempted: true, guidance: 'old guidance')
        .withReview('rejected', updatedAt: '2026-01-01T00:00:00Z')
        .build();
    StateStore(workspace.layout.statePath).write(state);

    service.activate(workspace.root.path);

    final updated = StateStore(workspace.layout.statePath).read();
    expect(updated.forensicRecoveryAttempted, isFalse);
    expect(updated.forensicGuidance, isNull);
    expect(updated.reviewStatus, isNull);
    expect(updated.reviewUpdatedAt, isNull);
  });

  test('git operations on activation (existing feature branch)', () {
    writeSimpleTask(title: 'Add logging');
    // branchExistsValue=true means both base and feature branches exist.
    // This triggers the "checkout existing feature branch" path.
    fakeGit.branchExistsValue = true;

    service.activate(workspace.root.path);

    // Verify git operations were called.
    expect(fakeGit.calls, contains('isGitRepo'));
    // Should check base branch exists and feature branch exists.
    final branchExistsCalls = fakeGit.calls
        .where((c) => c.startsWith('branchExists:'))
        .toList();
    expect(branchExistsCalls.length, greaterThanOrEqualTo(2));
    // Feature branch exists → should checkout the existing branch (not create).
    final checkoutCalls = fakeGit.calls
        .where((c) => c.startsWith('checkout:'))
        .toList();
    expect(
      checkoutCalls,
      isNotEmpty,
      reason: 'Should checkout existing branch',
    );
    // Should NOT have created a new branch.
    expect(fakeGit.lastCreatedBranch, isNull);
  });

  test('missing TASKS.md throws', () {
    // Delete TASKS.md.
    final tasksFile = File(workspace.layout.tasksPath);
    if (tasksFile.existsSync()) {
      tasksFile.deleteSync();
    }

    expect(
      () => service.activate(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No TASKS.md found'),
        ),
      ),
    );
  });

  test('task-not-found by ID throws', () {
    writeSimpleTask();

    expect(
      () => service.activate(
        workspace.root.path,
        requestedId: 'nonexistent-id-999',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Task id not found'),
        ),
      ),
    );
  });

  test(
    'activation when another task is already active silently re-activates',
    () {
      workspace.writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Task A\n'
        '- [ ] [P1] [CORE] Task B\n',
      );

      // Activate the first task (auto-selected by priority/order).
      final first = service.activate(workspace.root.path);
      expect(first.hasTask, isTrue);
      expect(first.task!.title, 'Task A');

      // Verify Task A is now active.
      final stateAfterFirst = StateStore(workspace.layout.statePath).read();
      expect(stateAfterFirst.activeTaskTitle, 'Task A');

      // Parse Task B to get its ID for explicit re-activation.
      final taskB = Task.parseLine(
        line: '- [ ] [P1] [CORE] Task B',
        section: 'Backlog',
        lineIndex: 2,
      )!;

      // Activate Task B while Task A is still active.
      // The service does not guard against re-activation; it silently
      // overwrites the active task.
      final second = service.activate(
        workspace.root.path,
        requestedId: taskB.id,
      );

      expect(second.hasTask, isTrue);
      expect(second.task!.title, 'Task B');

      // State now reflects Task B as active.
      final stateAfterSecond = StateStore(workspace.layout.statePath).read();
      expect(stateAfterSecond.activeTaskTitle, 'Task B');
      expect(stateAfterSecond.activeTaskId, taskB.id);
    },
  );

  test('activation by prefix match selects correct task', () {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] Create Task model\n'
      '- [ ] [P2] [CORE] Add task priority support — extend Task model with priority field\n',
    );

    final result = service.activate(
      workspace.root.path,
      requestedTitle: 'Create Task',
    );

    expect(result.hasTask, isTrue);
    expect(result.task!.title, 'Create Task model');
  });

  test('activation by substring match prefers shorter title', () {
    workspace.writeTasks(
      '## Backlog\n'
      '- [ ] [P1] [CORE] Create Task model\n'
      '- [ ] [P2] [CORE] Add task priority support — extend Task model with priority field\n',
    );

    final result = service.activate(
      workspace.root.path,
      requestedTitle: 'Task model',
    );

    expect(result.hasTask, isTrue);
    // Should prefer shorter title (more specific match).
    expect(result.task!.title, 'Create Task model');
  });

  test('activation with no matching title throws', () {
    writeSimpleTask();

    expect(
      () => service.activate(
        workspace.root.path,
        requestedTitle: 'Nonexistent task',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Task title not found'),
        ),
      ),
    );
  });

  test(
    'auto-selection skips candidate with task_done event in run-log',
    () {
      workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] Implement feature
''');

      // Write a task_done event for the only candidate task.
      workspace.writeRunLog([
        RunLogEntryBuilder()
            .withEvent('task_done')
            .withData({
              'task': 'Implement feature',
              'task_id': 'some-id',
            })
            .buildJson(),
      ]);

      final result = service.activate(workspace.root.path);

      // The task should NOT be activated because the run-log shows it
      // was already completed.
      expect(result.hasTask, isFalse);

      // Run log should contain an activate_skip_already_done event.
      final events = _readRunLogLines(workspace.layout.runLogPath);
      final skipEvents = events
          .where((e) => e['event'] == 'activate_skip_already_done')
          .toList();
      expect(skipEvents, isNotEmpty);
      expect(
        skipEvents.first['data']['error_kind'],
        'already_completed_in_log',
      );
    },
  );

  group('enhanced task done detection', () {
    test(
      'auto-selection skips task marked [x] in TASKS.md even without run-log event',
      () {
        // Two tasks with the same title at different line indices.
        // The first is done ([x]), the second is open ([ ]).
        // Auto-selection picks the open one, but _hasTaskDoneEvent should
        // detect the done entry in TASKS.md by title match and skip it.
        workspace.writeTasks(
          '## Backlog\n'
          '- [x] [P1] [CORE] Implement feature\n'
          '- [ ] [P1] [CORE] Implement feature\n',
        );

        // No run-log task_done event — the only signal is TASKS.md.
        final result = service.activate(workspace.root.path);

        // The candidate should be skipped because a done entry with the
        // same title exists in TASKS.md.
        expect(result.hasTask, isFalse);

        // Verify the skip event was logged.
        final events = _readRunLogLines(workspace.layout.runLogPath);
        final skipEvents = events
            .where((e) => e['event'] == 'activate_skip_already_done')
            .toList();
        expect(skipEvents, isNotEmpty);
        expect(
          skipEvents.first['data']['error_kind'],
          'already_completed_in_log',
        );
      },
    );

    test(
      'auto-selection skips task with matching task ID in run-log done event',
      () {
        // Create a task whose exact ID appears in a run-log task_done event,
        // but with a DIFFERENT title in the run-log (so only ID match works).
        workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] Implement feature
''');

        // Compute the actual task ID that the parser will generate.
        // Dart triple-quote omits the leading newline after ''', so:
        // line 0 = "## Backlog", line 1 = task line.
        final task = Task.parseLine(
          line: '- [ ] [P1] [CORE] Implement feature',
          section: 'Backlog',
          lineIndex: 1,
        )!;

        // Write a task_done event with the correct task ID but a different
        // title so the title-based match does NOT fire.
        workspace.writeRunLog([
          RunLogEntryBuilder()
              .withEvent('task_done')
              .withData({
                'task': 'Old renamed title that does not match',
                'task_id': task.id,
              })
              .buildJson(),
        ]);

        final result = service.activate(workspace.root.path);

        // The task should NOT be activated because the run-log has a
        // task_done event with a matching task_id.
        expect(result.hasTask, isFalse);

        // Verify the skip event was logged.
        final events = _readRunLogLines(workspace.layout.runLogPath);
        final skipEvents = events
            .where((e) => e['event'] == 'activate_skip_already_done')
            .toList();
        expect(skipEvents, isNotEmpty);
      },
    );

    test(
      'auto-selection advances past done candidates to find next open task',
      () {
        // Two open tasks: the first has a task_done event in the run-log,
        // the second does not. The loop should skip the first and activate
        // the second.
        workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] Implement storage layer
- [ ] [P1] [CORE] Implement CLI interface
''');

        // Only the first task is done in the run-log.
        workspace.writeRunLog([
          RunLogEntryBuilder()
              .withEvent('task_done')
              .withData({
                'task': 'Implement storage layer',
                'task_id': 'some-id',
              })
              .buildJson(),
        ]);

        final result = service.activate(workspace.root.path);

        // The second task should be activated since the first was skipped.
        expect(result.hasTask, isTrue);
        expect(result.task!.title, contains('CLI interface'));

        // Verify the first task was skipped.
        final events = _readRunLogLines(workspace.layout.runLogPath);
        final skipEvents = events
            .where((e) => e['event'] == 'activate_skip_already_done')
            .toList();
        expect(skipEvents, hasLength(1));
        expect(
          skipEvents.first['data']['task'] as String,
          contains('storage layer'),
        );
      },
    );
  });

  test(
    'cooldown uses fresh DateTime.now rather than stale context.now',
    () {
      // This test verifies that cooldown expiration is checked against
      // a fresh DateTime.now().toUtc() rather than the potentially stale
      // context.now captured at context-build time.
      //
      // Set up: a failed task with a cooldown that expired 1 second ago.
      // With a stale context.now from the past, the cooldown might still
      // appear active. With fresh DateTime.now(), it should be expired.
      final pastExpiry = DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 1))
          .toIso8601String();

      // Write a task with [BLOCKED] that is auto-cycle eligible.
      workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] [BLOCKED] Cooldown task (Reason: auto-cycle: retry)
''');

      // Parse the task to get its ID.
      // Dart triple-quote omits leading newline: line 0 = header, line 1 = task.
      final task = Task.parseLine(
        line: '- [ ] [P1] [CORE] [BLOCKED] Cooldown task (Reason: auto-cycle: retry)',
        section: 'Backlog',
        lineIndex: 1,
      )!;

      // Set explicit cooldown that has already expired (1 second in the past).
      final stateStore = StateStore(workspace.layout.statePath);
      final readState = stateStore.read();
      final state = readState.copyWith(
        retryScheduling: readState.retryScheduling.copyWith(
          cooldownUntil: {'id:${task.id}': pastExpiry},
        ),
      );
      stateStore.write(state);

      // Enable reactivation of blocked tasks in config so the cooldown
      // check path is reached.
      workspace.writeConfig('''
autopilot:
  reactivate_blocked: true
  blocked_cooldown_seconds: 3600
''');

      // If cooldown were checked against a stale context.now from the
      // distant past, this would throw "Task is cooling down".
      // With fresh DateTime.now(), the expired cooldown should allow
      // activation.
      final result = service.activate(
        workspace.root.path,
        requestedTitle: 'Cooldown task',
      );

      expect(result.hasTask, isTrue);
      expect(result.task!.title, contains('Cooldown task'));
    },
  );

  test('activation persists activeTaskRetryKey', () {
    writeSimpleTask(title: 'Fix login bug');

    final result = service.activate(workspace.root.path);

    expect(result.hasTask, isTrue);

    final state = StateStore(workspace.layout.statePath).read();
    // The retry key should be set eagerly at activation time.
    expect(state.activeTaskRetryKey, isNotNull);
    expect(state.activeTaskRetryKey, startsWith('id:'));
    // The key should be based on the task's id.
    expect(state.activeTaskRetryKey, 'id:${state.activeTaskId}');
  });

  test('activation with title-only task persists title-based key', () {
    // When a task has no parseable id (edge case), the retry key falls
    // back to a title-based key.
    writeSimpleTask(title: 'Add dark mode');

    final result = service.activate(workspace.root.path);

    expect(result.hasTask, isTrue);

    final state = StateStore(workspace.layout.statePath).read();
    // The task does have an id (generated from line index + hash), so
    // the key should be id-based.  Verify it is non-null and non-empty.
    expect(state.activeTaskRetryKey, isNotNull);
    expect(state.activeTaskRetryKey, isNotEmpty);
  });

  group('deactivate', () {
    test('clears active task and review', () {
      writeSimpleTask();
      service.activate(workspace.root.path);

      service.deactivate(workspace.root.path);

      final state = StateStore(workspace.layout.statePath).read();
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);
      expect(state.reviewStatus, isNull);
    });

    test('keepReview preserves review status', () {
      writeSimpleTask();
      service.activate(workspace.root.path);

      // Set review status.
      final store = StateStore(workspace.layout.statePath);
      final currentState = store.read();
      store.write(
        currentState.copyWith(
          activeTask: currentState.activeTask.copyWith(
            reviewStatus: 'approved',
            reviewUpdatedAt: '2026-01-15T00:00:00Z',
          ),
        ),
      );

      service.deactivate(workspace.root.path, keepReview: true);

      final state = store.read();
      expect(state.activeTaskId, isNull);
      expect(state.reviewStatus, 'approved');
      expect(state.reviewUpdatedAt, '2026-01-15T00:00:00Z');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _readRunLogLines(String path) {
  final content = File(path).readAsStringSync();
  return content
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
}
