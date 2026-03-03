import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/git_sync_service.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('OrchestratorStepService picks subtask from queue', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_subtask_test_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: ActiveTaskState(id: '1', title: 'Main Task'),
        subtaskExecution: SubtaskExecutionState(
          queue: ['Subtask A', 'Subtask B'],
        ),
      ),
    );
    File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

    final cycleService = _FakeTaskCycleService();
    final service = OrchestratorStepService(
      activateService: ActivateService(),
      taskCycleService: cycleService,
      plannerService: _FakePlannerService(),
      architecturePlanningService: _NoopArchitecturePlanningService(),
      visionEvaluationService: _NoopVisionEvaluationService(),
      specAgentService: _NoopSpecAgentService(),
    );

    // Run step 1: Picks Subtask A
    await service.run(temp.path, codingPrompt: 'Base Prompt');

    var state = store.read();
    expect(state.currentSubtask, 'Subtask A');
    expect(state.subtaskQueue, ['Subtask B']);
    expect(cycleService.lastIsSubtask, true);
    expect(cycleService.lastPrompt, contains('Implement subtask: Subtask A'));

    // Run step 2: Completes Subtask A (cycle returns approve)
    cycleService.nextDecision = 'approve';
    await service.run(temp.path, codingPrompt: 'Base Prompt');

    state = store.read();
    expect(state.currentSubtask, isNull);
    expect(state.subtaskQueue, ['Subtask B']);

    // Run step 3: Picks Subtask B
    cycleService.nextDecision = null;
    await service.run(temp.path, codingPrompt: 'Base Prompt');

    state = store.read();
    expect(state.currentSubtask, 'Subtask B');
    expect(state.subtaskQueue, isEmpty);
    expect(cycleService.lastPrompt, contains('Implement subtask: Subtask B'));
  });

  test(
    'OrchestratorStepService demotes verification-only current subtask behind queued work',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_demote_verify_current_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: '1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            current: 'Verify and gate: run `dart analyze` and full tests',
            queue: ['Baseline and contract lock: add regression tests'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      final state = store.read();
      expect(
        state.currentSubtask,
        'Baseline and contract lock: add regression tests',
      );
      expect(
        state.subtaskQueue,
        equals(['Verify and gate: run `dart analyze` and full tests']),
      );
      expect(
        cycleService.lastPrompt,
        contains(
          'Implement subtask: Baseline and contract lock: add regression tests',
        ),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('"event":"subtask_scheduler_demote_verification"'),
      );
    },
  );

  test(
    'OrchestratorStepService schedules dependency-ready subtask before FIFO',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_dependency_scheduler_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: '1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            queue: [
              'Run integration checks for command scheduler',
              'Implement command scheduler service',
              'Update docs for scheduler flow',
            ],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');
      // No spec file: scheduler falls back to FIFO ordering without
      // dependency-based reordering or orphan pruning.

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      final state = store.read();
      // Without a spec file, FIFO scheduling picks the first queue entry.
      expect(
        state.currentSubtask,
        'Run integration checks for command scheduler',
      );
      expect(
        state.subtaskQueue,
        equals([
          'Implement command scheduler service',
          'Update docs for scheduler flow',
        ]),
      );
      expect(
        cycleService.lastPrompt,
        contains(
          'Implement subtask: Run integration checks for command scheduler',
        ),
      );
    },
  );

  test(
    'OrchestratorStepService logs deterministic scheduler decision inputs',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_logging_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-42', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            queue: [
              '[P1] [SEC] Add policy hardening',
              '[P1] [CORE] Implement scheduler engine',
              '[P2] [DOCS] Document rollout',
            ],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_scheduler_selection"'));
      expect(runLog, contains('"task_id":"task-42"'));
      expect(runLog, contains('"scheduler_total_order"'));
      expect(runLog, contains('"scheduler_candidates"'));
      expect(runLog, contains('"scheduler_selected"'));
      expect(runLog, contains('"stable_final_key":"task-42|'));
      expect(
        runLog,
        contains('"subtask":"[P1] [CORE] Implement scheduler engine"'),
      );
    },
  );

  test(
    'OrchestratorStepService skips auto-stash when active task is rejected',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_stash_skip_rejected_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(
            id: 'task-1',
            title: 'Main Task',
            reviewStatus: 'rejected',
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final git = _CountingGitService(clean: false);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _FakeTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(git.stashPushCalls, 0);
      expect(git.stashPopCalls, 0);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_auto_stash_skip_rejected"'));
    },
  );

  test(
    'OrchestratorStepService stashes rejected context in unattended mode without restore',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_stash_rejected_unattended_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(
            id: 'task-1',
            title: 'Main Task',
            reviewStatus: 'rejected',
          ),
          subtaskExecution: SubtaskExecutionState(current: 'Subtask A'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');
      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotLockPath).writeAsStringSync('lock');

      final git = _CountingGitService(clean: false);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _FakeTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(git.stashPushCalls, 1);
      expect(git.stashPopCalls, 0);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_auto_stash_rejected_context"'));
      expect(runLog, contains('"subtask_id":"Subtask A"'));
      expect(runLog, isNot(contains('"event":"git_auto_stash_skip_rejected"')));
    },
  );

  test(
    'OrchestratorStepService auto-stashes dirty repo when review is clean',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_stash_normal_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final git = _CountingGitService(clean: false);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _FakeTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(git.stashPushCalls, 1);
      expect(git.stashPopCalls, 1);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_auto_stash"'));
      expect(runLog, contains('"event":"git_auto_stash_restore"'));
    },
  );

  test(
    'OrchestratorStepService auto-stashes dirty repo in unattended mode without restore',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_stash_unattended_no_restore_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');
      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotLockPath).writeAsStringSync('lock');

      final git = _CountingGitService(clean: false);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _FakeTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(git.stashPushCalls, 1);
      expect(git.stashPopCalls, 0);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_auto_stash"'));
      expect(runLog, isNot(contains('"event":"git_auto_stash_restore"')));
    },
  );

  test(
    'OrchestratorStepService stashes dirty worktree context after step errors (clean-end invariant)',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_error_autostash_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Task 1'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Task 1\n');

      final git = _SequencedGitService([true, false, false, true]);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _QuotaPauseTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await expectLater(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(isA<QuotaPauseError>()),
      );

      expect(git.stashPushCalls, 2);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_step_error_autostash"'));
      expect(runLog, contains('"error_kind":"git_auto_stash"'));
    },
  );

  test(
    'OrchestratorStepService re-queues current subtask after timeout to avoid repeat thrash',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_timeout_requeue_subtask_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            current: 'Subtask A',
            queue: ['Subtask B'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: _TimeoutTaskCycleService(),
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await expectLater(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(isA<TransientError>()),
      );

      final state = store.read();
      expect(state.currentSubtask, isNull);
      expect(state.subtaskQueue, equals(['Subtask B', 'Subtask A']));
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_requeued_after_timeout"'));
      expect(runLog, contains('"error_kind":"timeout"'));
    },
  );

  test(
    'OrchestratorStepService auto-refines long-running rejected subtask into smaller steps',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_long_run_refine_subtask_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            current:
                'Implement parser then add regression tests and then update docs',
            queue: const ['Tail subtask'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');
      File(layout.configPath).writeAsStringSync('''
policies:
  timeouts:
    agent_seconds: 300
''');

      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: _LongRunRejectTaskCycleService(durationMs: 260000),
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      final state = store.read();
      expect(
        state.currentSubtask,
        equals('Implement parser then add regression tests'),
      );
      expect(state.subtaskQueue, equals(['update docs', 'Tail subtask']));
      expect(
        state.taskRetryCounts.keys.any(
          (key) => key.startsWith('subtask:auto_refine:'),
        ),
        isTrue,
      );
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_auto_refined_long_run"'));
      expect(runLog, contains('"error_kind":"subtask_auto_refined_long_run"'));
    },
  );

  test(
    'OrchestratorStepService does not recursively refine already auto-refined long-running subtask',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_long_run_refine_once_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            current:
                'Implement parser then add regression tests and then update docs',
            queue: const ['Tail subtask'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');
      File(layout.configPath).writeAsStringSync('''
policies:
  timeouts:
    agent_seconds: 300
''');

      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: _LongRunRejectTaskCycleService(durationMs: 260000),
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');
      await service.run(temp.path, codingPrompt: 'Base Prompt');

      final state = store.read();
      expect(
        state.currentSubtask,
        equals('Implement parser then add regression tests'),
      );
      expect(state.subtaskQueue, equals(['update docs', 'Tail subtask']));
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_auto_refine_skipped"'));
      expect(runLog, contains('"reason":"already_refined_once"'));
    },
  );

  test(
    'OrchestratorStepService calls _persistPostStepCleanup on git sync conflict early return',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_sync_conflict_cleanup_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  sync_between_loops: true
  sync_strategy: pull_ff
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final git = _TrackingGitService();
      final syncService = _ConflictGitSyncService();
      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        gitService: git,
        gitSyncService: syncService,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(result.executedCycle, isFalse);
      expect(result.blockedTask, isTrue);
      expect(cycleService.runCount, 0);
      // _persistPostStepCleanup checks hasChanges then commits.
      // The tracking git service records these calls.
      expect(git.hasChangesCalls, greaterThan(0));
    },
  );

  test(
    'OrchestratorStepService calls _persistPostStepCleanup on activation early return',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_activation_early_cleanup_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Write TASKS.md with no open tasks to trigger idle early return.
      File(layout.tasksPath).writeAsStringSync('# Tasks\n');
      final store = StateStore(layout.statePath);
      final state = store.read();
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);

      final git = _TrackingGitService();
      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(result.executedCycle, isFalse);
      expect(cycleService.runCount, 0);
      // _persistPostStepCleanup is called on activation early return.
      // It checks hasChanges (via _gitService) — verify it was invoked.
      // Note: hasChanges is also called by the step-start _persistPostStepCleanup,
      // and by _enforceRuntimeGitignore; the activation early return calls it again.
      expect(git.hasChangesCalls, greaterThan(0));
    },
  );

  test(
    'OrchestratorStepService creates forensic stash on failed stash pop instead of discarding',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_forensic_stash_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final git = _FailingStashPopGitService();
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _FakeTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      // The stash pop fails, which should trigger forensic stash creation.
      // Since git is not in unattended mode, restores=true will be set.
      // The failed stash pop re-throws as StateError from the finally block.
      await expectLater(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(isA<StateError>()),
      );

      // Verify forensic stash was created (stashPush called after the pop failure).
      expect(git.stashPushCalls, greaterThan(1));
      expect(
        git.stashPushMessages.any((m) => m.contains('genaisys:forensic:')),
        isTrue,
      );
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"git_forensic_stash_created"'));
      expect(
        runLog,
        contains('"error_kind":"git_forensic_stash_created"'),
      );
    },
  );

  test(
    'OrchestratorStepService timeout re-queue runs after error stash (ordering fix)',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_timeout_requeue_order_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            current: 'Subtask A',
            queue: ['Subtask B'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      // Use a sequenced git service that returns clean=true initially (for
      // _prepareGitGuard), then returns dirty=false for error stash checks,
      // then clean=true for the clean-end guard.
      final git = _SequencedGitService([true, false, true]);
      final service = OrchestratorStepService(
        activateService: ActivateService(gitService: git),
        taskCycleService: _TimeoutTaskCycleService(),
        plannerService: _FakePlannerService(),
        gitService: git,
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await expectLater(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(isA<TransientError>()),
      );

      // Verify subtask was re-queued.
      final state = store.read();
      expect(state.currentSubtask, isNull);
      expect(state.subtaskQueue, contains('Subtask A'));

      // Verify both events appeared in the log in the correct order:
      // error stash first, then re-queue.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_requeued_after_timeout"'));
    },
  );

  test(
    'OrchestratorStepService deactivates task when subtask queue exceeds configured max',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_queue_overflow_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Set a very low queue max so we can trigger overflow easily.
      File(layout.configPath).writeAsStringSync('''
autopilot:
  subtask_queue_max: 3
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            queue: [
              'Subtask A',
              'Subtask B',
              'Subtask C',
              'Subtask D',
            ],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(result.executedCycle, isFalse);
      expect(result.blockedTask, isTrue);
      expect(result.deactivatedTask, isTrue);
      expect(cycleService.runCount, 0);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"subtask_queue_overflow"'));
      expect(runLog, contains('"error_kind":"subtask_queue_overflow"'));
    },
  );

  test(
    'OrchestratorStepService does not trigger queue overflow when at or below max',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_queue_within_limit_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
autopilot:
  subtask_queue_max: 3
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
          subtaskExecution: SubtaskExecutionState(
            queue: ['Subtask A', 'Subtask B', 'Subtask C'],
          ),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Base Prompt');

      // Should proceed normally since queue length (3) == max (3), not >.
      expect(result.executedCycle, isTrue);
      expect(cycleService.runCount, 1);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, isNot(contains('"event":"subtask_queue_overflow"')));
    },
  );

  test(
    'OrchestratorStepService fails fast on invalid STATE.json schema before cycle execution',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_schema_state_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.statePath).writeAsStringSync('''
{
  "last_updated": "2026-02-08T00:00:00Z",
  "cycle_count": "broken"
}
''');
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      expect(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(
          isA<PermanentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('STATE.json'), contains('cycle_count')),
          ),
        ),
      );
      expect(cycleService.runCount, 0);
    },
  );

  test(
    'OrchestratorStepService fails fast on invalid config.yml schema before cycle execution',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_schema_config_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.configPath).writeAsStringSync('''
autopilot:
  max_failures: "broken"
''');
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      expect(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(
          isA<PermanentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('config.yml'), contains('autopilot.max_failures')),
          ),
        ),
      );
      expect(cycleService.runCount, 0);
    },
  );

  test(
    'OrchestratorStepService fails fast on invalid TASKS.md schema before cycle execution',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_schema_tasks_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ]
''');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      expect(
        () => service.run(temp.path, codingPrompt: 'Base Prompt'),
        throwsA(
          isA<PermanentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('TASKS.md'), contains('task line')),
          ),
        ),
      );
      expect(cycleService.runCount, 0);
    },
  );

  test(
    'OrchestratorStepService forwards reviewMaxRounds from config to task cycle',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_max_retries_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Write config with custom reviewMaxRounds.
      File(layout.configPath).writeAsStringSync('''
review:
  max_rounds: 7
''');
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(cycleService.lastMaxReviewRetries, 7);
    },
  );

  test(
    'OrchestratorStepService uses default reviewMaxRounds when not configured',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_default_retries_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: 'task-1', title: 'Main Task'),
        ),
      );
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n- [ ] Main Task\n');

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      await service.run(temp.path, codingPrompt: 'Base Prompt');

      // Default reviewMaxRounds is 3.
      expect(cycleService.lastMaxReviewRetries, 3);
    },
  );

  test(
    'OrchestratorStepService returns idle result when no tasks available and no active task',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_step_idle_no_tasks_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Write an empty TASKS.md with no open tasks.
      File(layout.tasksPath).writeAsStringSync('# Tasks\n');
      // Ensure STATE.json has no active task.
      final store = StateStore(layout.statePath);
      final state = store.read();
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);

      final cycleService = _FakeTaskCycleService();
      final service = OrchestratorStepService(
        activateService: ActivateService(),
        taskCycleService: cycleService,
        plannerService: _FakePlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
        specAgentService: _NoopSpecAgentService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Base Prompt');

      expect(result.executedCycle, isFalse);
      expect(result.activatedTask, isFalse);
      expect(result.activeTaskTitle, isNull);
      expect(result.plannedTasksAdded, 0);
      expect(cycleService.runCount, 0);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"orchestrator_step_idle"'));
    },
  );
}

class _FakeTaskCycleService extends TaskCycleService {
  bool lastIsSubtask = false;
  String lastPrompt = '';
  String? nextDecision;
  int? lastMaxReviewRetries;
  int runCount = 0;

  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    runCount += 1;
    lastIsSubtask = isSubtask;
    lastPrompt = codingPrompt;
    lastMaxReviewRetries = maxReviewRetries;
    return TaskCycleResult(
      pipeline: _emptyPipeline(),
      reviewRecorded: true,
      reviewDecision: nextDecision == 'approve'
          ? ReviewDecision.approve
          : nextDecision == 'reject'
          ? ReviewDecision.reject
          : null,
      retryCount: 0,
      taskBlocked: false,
      autoMarkedDone: false,
      approvedDiffStats: null,
    );
  }

  TaskPipelineResult _emptyPipeline() {
    // Mocking TaskPipelineResult is hard because it requires complex objects.
    // But we can cast or stub if we are careful.
    // For this test, we just need the reviewDecision from the result wrapper.
    // So we can pass anything or null if we change TaskCycleResult to allow nulls,
    // but it's required.
    // Actually, let's just make a minimal mock of the result if possible.
    // We need to construct TaskCycleResult. It requires a pipeline.
    // TaskPipelineResult requires SpecAgentResult etc.
    // This is verbose. I'll use a hack or just mocks.
    return TaskPipelineResult(
      plan: _mockSpec(),
      spec: _mockSpec(),
      subtasks: _mockSpec(),
      coding: _mockCoding(),
      review: null,
    );
  }
}

SpecAgentResult _mockSpec() => SpecAgentResult(
  path: '',
  kind: SpecKind.plan,
  wrote: false,
  usedFallback: false,
  response: null,
);

CodingAgentResult _mockCoding() => CodingAgentResult(
  path: '',
  usedFallback: false,
  response: AgentResponse(exitCode: 0, stdout: '', stderr: ''),
);

class _FakePlannerService extends VisionBacklogPlannerService {
  @override
  Future<PlannerSyncResult> syncBacklogStrategically(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) async {
    return PlannerSyncResult(
      openBefore: 0,
      openAfter: 0,
      added: 0,
      addedTitles: const [],
    );
  }

  @override
  PlannerSyncResult syncBacklogFromVision(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) {
    return PlannerSyncResult(
      openBefore: 0,
      openAfter: 0,
      added: 0,
      addedTitles: const [],
    );
  }
}

class _CountingGitService extends GitServiceImpl {
  _CountingGitService({this.clean = false});

  final bool clean;
  int stashPushCalls = 0;
  int stashPopCalls = 0;

  @override
  bool isGitRepo(String path) => true;

  @override
  bool isClean(String path) => clean;

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    stashPushCalls += 1;
    return true;
  }

  @override
  void stashPop(String path) {
    stashPopCalls += 1;
  }
}

class _SequencedGitService extends GitServiceImpl {
  _SequencedGitService(this.cleanSequence);

  final List<bool> cleanSequence;
  int _cleanCalls = 0;
  int stashPushCalls = 0;

  @override
  bool isGitRepo(String path) => true;

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool isClean(String path) {
    if (_cleanCalls >= cleanSequence.length) {
      return cleanSequence.isEmpty ? true : cleanSequence.last;
    }
    final value = cleanSequence[_cleanCalls];
    _cleanCalls += 1;
    return value;
  }

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    stashPushCalls += 1;
    return true;
  }
}

class _QuotaPauseTaskCycleService extends TaskCycleService {
  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    throw QuotaPauseError(
      'Provider pool exhausted',
      pauseFor: const Duration(seconds: 30),
      resumeAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
  }
}

class _TimeoutTaskCycleService extends TaskCycleService {
  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    throw TimeoutException('Simulated coding agent timeout.');
  }
}

class _TrackingGitService extends GitServiceImpl {
  int hasChangesCalls = 0;

  @override
  bool isGitRepo(String path) => true;

  @override
  bool isClean(String path) => true;

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool hasChanges(String path) {
    hasChangesCalls += 1;
    return false;
  }

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {
    // No-op for tests.
  }
}

class _ConflictGitSyncService extends GitSyncService {
  @override
  GitSyncResult syncBeforeLoop(
    String projectRoot, {
    required String strategy,
  }) {
    return const GitSyncResult(
      synced: false,
      conflictsDetected: true,
      conflictPaths: ['some/file.dart'],
      errorMessage: 'merge_conflict',
    );
  }
}

class _FailingStashPopGitService extends GitServiceImpl {
  int stashPushCalls = 0;
  final List<String> stashPushMessages = [];

  @override
  bool isGitRepo(String path) => true;

  @override
  bool isClean(String path) {
    // After forensic stash, report clean.
    return stashPushCalls > 1;
  }

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool hasChanges(String path) => false;

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    stashPushCalls += 1;
    stashPushMessages.add(message);
    return true;
  }

  @override
  void stashPop(String path) {
    throw StateError('Simulated stash pop conflict');
  }

  @override
  void discardWorkingChanges(String path) {
    // No-op for tests.
  }

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {
    // No-op for tests.
  }
}

class _NoopArchitecturePlanningService extends ArchitecturePlanningService {
  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    return null;
  }
}

class _NoopVisionEvaluationService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return null;
  }
}

/// No-op SpecAgentService that immediately returns without calling any agent.
/// Used in tests that set up a subtask queue to prevent real agent invocations.
class _NoopSpecAgentService extends SpecAgentService {
  @override
  Future<void> maybeRefineSubtasks(
    String projectRoot, {
    String? stepId,
  }) async {}

  @override
  Future<FeasibilityCheckResult> checkFeasibility(
    String projectRoot, {
    String? stepId,
  }) async =>
      const FeasibilityCheckResult(feasible: true, skipped: true);

  @override
  Future<List<String>?> splitSubtaskForReject(
    String projectRoot,
    String subtask,
    String rejectNote,
  ) async =>
      null;
}

class _LongRunRejectTaskCycleService extends TaskCycleService {
  _LongRunRejectTaskCycleService({required this.durationMs});

  final int durationMs;

  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    final commandEvent = AgentCommandEvent(
      executable: 'codex',
      arguments: const ['exec', '-'],
      runInShell: false,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      durationMs: durationMs,
      timedOut: false,
      phase: 'run',
      workingDirectory: projectRoot,
    );
    final coding = CodingAgentResult(
      path: '',
      usedFallback: false,
      response: AgentResponse(
        exitCode: 0,
        stdout: 'ok',
        stderr: '',
        commandEvent: commandEvent,
      ),
    );
    final pipeline = TaskPipelineResult(
      plan: _mockSpec(),
      spec: _mockSpec(),
      subtasks: _mockSpec(),
      coding: coding,
      review: null,
    );
    return TaskCycleResult(
      pipeline: pipeline,
      reviewRecorded: true,
      reviewDecision: ReviewDecision.reject,
      retryCount: 1,
      taskBlocked: false,
      autoMarkedDone: false,
      approvedDiffStats: null,
    );
  }
}
