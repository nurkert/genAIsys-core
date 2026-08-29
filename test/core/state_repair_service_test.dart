import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/models/retry_scheduling_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/models/supervisor_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/state_repair_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Existing tests
  // ---------------------------------------------------------------------------

  test('StateRepairService clears subtasks without active task', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_repair_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(id: null, title: null),
        subtaskExecution: const SubtaskExecutionState(
          current: 'Subtask A',
          queue: ['Subtask B'],
        ),
        autopilotRun: const AutopilotRunState(running: true),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.currentSubtask, isNull);
    expect(updated.subtaskQueue, isEmpty);
    expect(updated.autopilotRunning, isFalse);
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_subtasks_without_active_task'));
    expect(report.actions, contains('cleared_stale_autopilot_state'));
  });

  test(
    'StateRepairService clears active task when TASKS.md already marks it done',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_repair_done_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [x] [P1] [CORE] My Finished Task
''');

      final tasks = TaskStore(layout.tasksPath).readTasks();
      expect(tasks, isNotEmpty);
      final finished = tasks.single;

      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(id: finished.id, title: finished.title),
          workflowStage: WorkflowStage.execution,
          subtaskExecution: const SubtaskExecutionState(
            current: 'Subtask A',
            queue: ['Subtask B'],
          ),
        ),
      );

      final report = StateRepairService().repair(temp.path);

      final updated = store.read();
      expect(updated.activeTaskId, isNull);
      expect(updated.activeTaskTitle, isNull);
      expect(updated.currentSubtask, isNull);
      expect(updated.subtaskQueue, isEmpty);
      expect(updated.workflowStage, WorkflowStage.idle);
      expect(report.changed, isTrue);
      expect(report.actions, contains('cleared_done_active_task'));
    },
  );

  // ---------------------------------------------------------------------------
  // Chunk 1: Expanded coverage for error paths and edge cases
  // ---------------------------------------------------------------------------

  test('repair is no-op when state is healthy', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_repair_noop_');
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    // Fresh state from init — nothing to repair.
    final stateBefore = StateStore(layout.statePath).read();
    final report = StateRepairService().repair(temp.path);

    expect(report.changed, isFalse);
    expect(report.actions, isEmpty);

    final stateAfter = StateStore(layout.statePath).read();
    // lastUpdated must NOT change when no repair was needed.
    expect(stateAfter.lastUpdated, stateBefore.lastUpdated);
  });

  test('repair removes current subtask from queue when duplicated', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_dup_current_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Ensure the active task exists as open in TASKS.md so it is not stale.
    File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Task 1
''');

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(id: 'task-1-3', title: 'Task 1'),
        workflowStage: WorkflowStage.execution,
        subtaskExecution: const SubtaskExecutionState(
          current: 'Subtask A',
          queue: ['Subtask A', 'Subtask B'],
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.currentSubtask, 'Subtask A');
    expect(updated.subtaskQueue, ['Subtask B']);
    expect(report.changed, isTrue);
    expect(report.actions, contains('removed_current_from_queue'));
  });

  test('repair deduplicates subtask queue', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_dedup_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Ensure the active task exists as open in TASKS.md so it is not stale.
    File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Task 1
''');

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(id: 'task-1-3', title: 'Task 1'),
        workflowStage: WorkflowStage.execution,
        subtaskExecution: const SubtaskExecutionState(
          queue: ['A', 'B', 'A', 'C', 'B'],
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.subtaskQueue, ['A', 'B', 'C']);
    expect(report.changed, isTrue);
    expect(report.actions, contains('deduped_subtask_queue'));
  });

  test(
    'repair handles corrupt STATE.json gracefully (StateStore returns initial)',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_repair_corrupt_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      // Write garbage to STATE.json. StateStore.read() catches the
      // FormatException internally and returns ProjectState.initial() —
      // so repair() never enters the catch block. This verifies the
      // graceful fallback: repair succeeds without crashing.
      File(layout.statePath).writeAsStringSync('{{not valid json at all!!');

      final report = StateRepairService().repair(temp.path);

      // Since StateStore.read() silently returns initial state, the
      // repair sees a healthy initial state — no actions needed.
      expect(report.changed, isFalse);

      // The state is readable again (StateStore returns initial).
      final state = StateStore(layout.statePath).read();
      expect(state.activeTaskId, isNull);
      expect(state.autopilotRunning, isFalse);
    },
  );

  test('repair clears stale autopilot state when lock file missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_autopilot_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Set autopilot state without creating a lock file.
    store.write(
      store.read().copyWith(
        autopilotRun: const AutopilotRunState(
          running: true,
          currentMode: 'unattended',
          consecutiveFailures: 5,
        ),
      ),
    );

    // Verify no lock file exists.
    expect(File(layout.autopilotLockPath).existsSync(), isFalse);

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.autopilotRunning, isFalse);
    expect(updated.currentMode, isNull);
    expect(updated.consecutiveFailures, 0);
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_stale_autopilot_state'));
  });

  test('repair clears stale supervisor state when PID is dead', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_supervisor_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // PID 999999 is almost certainly not running.
    store.write(
      store.read().copyWith(
        supervisor: const SupervisorState(
          running: true,
          pid: 999999,
          cooldownUntil: '2099-01-01T00:00:00Z',
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.supervisorRunning, isFalse);
    expect(updated.supervisorPid, isNull);
    expect(updated.supervisorCooldownUntil, isNull);
    expect(updated.supervisorLastHaltReason, 'stale_supervisor_recovered');
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_stale_supervisor_state'));
  });

  test('repair initializes structure when .genaisys/ is missing', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_repair_init_');
    addTearDown(() => temp.deleteSync(recursive: true));

    // No ProjectInitializer call — bare directory.
    final layout = ProjectLayout(temp.path);
    expect(Directory(layout.genaisysDir).existsSync(), isFalse);

    final report = StateRepairService().repair(temp.path);

    expect(Directory(layout.genaisysDir).existsSync(), isTrue);
    expect(report.actions, contains('initialized_structure'));
  });

  test('repair emits run-log event with all actions', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_repair_log_');
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Trigger multiple repairs: no active task + subtasks + stale autopilot.
    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(id: null, title: null),
        subtaskExecution: const SubtaskExecutionState(
          current: 'Orphan',
          queue: ['A', 'B', 'A'],
        ),
        autopilotRun: const AutopilotRunState(running: true),
      ),
    );

    final report = StateRepairService().repair(temp.path);
    expect(report.changed, isTrue);

    // Read run log and verify event was emitted.
    final runLogFile = File(layout.runLogPath);
    expect(runLogFile.existsSync(), isTrue);
    final lines = runLogFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final repairLines = lines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'state_repair';
      } catch (_) {
        return false;
      }
    }).toList();

    expect(repairLines, isNotEmpty, reason: 'Expected state_repair log event');

    final lastRepair = jsonDecode(repairLines.last) as Map<String, Object?>;
    final data = lastRepair['data'] as Map<String, Object?>?;
    expect(data, isNotNull);
    final actions = (data!['actions'] as List).cast<String>();
    expect(actions, contains('cleared_subtasks_without_active_task'));
    expect(actions, contains('cleared_stale_autopilot_state'));
  });

  // ---------------------------------------------------------------------------
  // Change #31: Orphaned subtask queue validation against spec files
  // ---------------------------------------------------------------------------

  test('repair removes orphaned subtasks not found in spec file', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_orphan_subtask_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Create TASKS.md with an open task.
    File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Add Widget Tests
''');

    // Create subtask spec file with only two subtasks.
    Directory(layout.taskSpecsDir).createSync(recursive: true);
    File('${layout.taskSpecsDir}${Platform.pathSeparator}add-widget-tests-subtasks.md')
        .writeAsStringSync('''
# Subtasks

Parent: Add Widget Tests

## Subtasks
1. Write unit tests for button widget
2. Write integration tests for form
''');

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'add-widget-tests-3',
          title: 'Add Widget Tests',
        ),
        workflowStage: WorkflowStage.execution,
        subtaskExecution: const SubtaskExecutionState(
          queue: [
            'Write unit tests for button widget',
            'Ghost subtask that does not exist in spec',
            'Write integration tests for form',
          ],
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(
      updated.subtaskQueue,
      [
        'Write unit tests for button widget',
        'Write integration tests for form',
      ],
    );
    expect(report.changed, isTrue);
    expect(report.actions, contains('orphaned_subtask_removed'));

    // Verify structured run-log event with error_class and error_kind.
    final runLogFile = File(layout.runLogPath);
    final logLines = runLogFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final orphanLogLines = logLines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'orphaned_subtask_removed';
      } catch (_) {
        return false;
      }
    }).toList();
    expect(orphanLogLines, isNotEmpty,
        reason: 'Expected orphaned_subtask_removed log event');
    final orphanEntry =
        jsonDecode(orphanLogLines.first) as Map<String, Object?>;
    final orphanData = orphanEntry['data'] as Map<String, Object?>?;
    expect(orphanData?['error_class'], 'state_repair');
    expect(orphanData?['error_kind'], 'orphaned_subtask');
  });

  // ---------------------------------------------------------------------------
  // Change #32: TASKS.md vs STATE.json parity repair
  // ---------------------------------------------------------------------------

  test(
    'repair clears active task when marked done in TASKS.md (stale parity)',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_repair_stale_done_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);

      // Task is done in TASKS.md.
      File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [x] [P1] [CORE] Implement Login Screen
''');

      store.write(
        store.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'implement-login-screen-3',
            title: 'Implement Login Screen',
            retryKey: 'implement-login-screen-retry-1',
            forensicRecoveryAttempted: true,
            forensicGuidance: 'Previous recovery attempted',
          ),
          workflowStage: WorkflowStage.execution,
          subtaskExecution: const SubtaskExecutionState(
            current: 'Add form validation',
            queue: ['Write tests'],
          ),
        ),
      );

      final report = StateRepairService().repair(temp.path);

      final updated = store.read();
      // cleared_done_active_task fires first (existing behavior).
      expect(updated.activeTaskId, isNull);
      expect(updated.activeTaskTitle, isNull);
      expect(updated.currentSubtask, isNull);
      expect(updated.subtaskQueue, isEmpty);
      expect(updated.workflowStage, WorkflowStage.idle);
      expect(report.changed, isTrue);
      expect(report.actions, contains('cleared_done_active_task'));
    },
  );

  test(
    'repair clears active task when missing from TASKS.md entirely',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_repair_stale_missing_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);

      // TASKS.md has a different task — the active task is missing.
      File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Some Other Task
''');

      store.write(
        store.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'vanished-task-99',
            title: 'Vanished Task',
            retryKey: 'vanished-retry-key',
            forensicRecoveryAttempted: true,
            forensicGuidance: 'Some old guidance',
          ),
          workflowStage: WorkflowStage.execution,
          subtaskExecution: const SubtaskExecutionState(
            current: 'Do something',
            queue: ['Next thing'],
          ),
        ),
      );

      final report = StateRepairService().repair(temp.path);

      final updated = store.read();
      expect(updated.activeTaskId, isNull);
      expect(updated.activeTaskTitle, isNull);
      expect(updated.activeTaskRetryKey, isNull);
      expect(updated.currentSubtask, isNull);
      expect(updated.subtaskQueue, isEmpty);
      expect(updated.workflowStage, WorkflowStage.idle);
      expect(updated.forensicRecoveryAttempted, isFalse);
      expect(updated.forensicGuidance, isNull);
      expect(report.changed, isTrue);
      expect(report.actions, contains('active_task_stale_cleared'));

      // Verify structured run-log event with error_class and error_kind.
      final runLogFile = File(layout.runLogPath);
      final logLines = runLogFile
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final staleLogLines = logLines.where((line) {
        try {
          final entry = jsonDecode(line) as Map<String, Object?>;
          return entry['event'] == 'active_task_stale_cleared';
        } catch (_) {
          return false;
        }
      }).toList();
      expect(staleLogLines, isNotEmpty,
          reason: 'Expected active_task_stale_cleared log event');
      final staleEntry =
          jsonDecode(staleLogLines.first) as Map<String, Object?>;
      final staleData = staleEntry['data'] as Map<String, Object?>?;
      expect(staleData?['error_class'], 'state_repair');
      expect(staleData?['error_kind'], 'active_task_stale');
    },
  );

  // ---------------------------------------------------------------------------
  // No-change scenario: valid active task + valid subtasks
  // ---------------------------------------------------------------------------

  test(
    'repair is no-op with valid active task and valid subtask queue',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_repair_valid_all_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);

      // Active task is open in TASKS.md.
      File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Build Dashboard
''');

      // Subtask spec matches the queue entries.
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}${Platform.pathSeparator}build-dashboard-subtasks.md')
          .writeAsStringSync('''
# Subtasks

Parent: Build Dashboard

## Subtasks
1. Create layout scaffold
2. Add data binding
3. Write snapshot tests
''');

      store.write(
        store.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'build-dashboard-3',
            title: 'Build Dashboard',
          ),
          workflowStage: WorkflowStage.execution,
          subtaskExecution: const SubtaskExecutionState(
            current: 'Create layout scaffold',
            queue: ['Add data binding', 'Write snapshot tests'],
          ),
        ),
      );

      final stateBefore = store.read();
      final report = StateRepairService().repair(temp.path);

      expect(report.changed, isFalse);
      expect(report.actions, isEmpty);

      final stateAfter = store.read();
      expect(stateAfter.lastUpdated, stateBefore.lastUpdated);
      expect(stateAfter.activeTaskTitle, 'Build Dashboard');
      expect(stateAfter.subtaskQueue, ['Add data binding', 'Write snapshot tests']);
    },
  );

  // ---------------------------------------------------------------------------
  // Preflight failure escalation: orphaned review, stale workflow, cooldowns
  // ---------------------------------------------------------------------------

  test('repair clears orphaned review status when no active task', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_orphan_review_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(
          id: null,
          title: null,
          reviewStatus: 'rejected',
          reviewUpdatedAt: '2026-02-20T12:00:00Z',
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.reviewStatus, isNull);
    expect(updated.reviewUpdatedAt, isNull);
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_orphaned_review_status'));

    // Verify structured run-log event.
    final runLogFile = File(layout.runLogPath);
    final logLines = runLogFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final reviewLogLines = logLines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'cleared_orphaned_review_status';
      } catch (_) {
        return false;
      }
    }).toList();
    expect(reviewLogLines, isNotEmpty,
        reason: 'Expected cleared_orphaned_review_status log event');
    final reviewData =
        (jsonDecode(reviewLogLines.first) as Map<String, Object?>)['data']
            as Map<String, Object?>?;
    expect(reviewData?['error_class'], 'state_repair');
    expect(reviewData?['error_kind'], 'orphaned_review');
  });

  test('repair does not clear review status when active task exists', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_review_active_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    // Active task is open in TASKS.md.
    File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] Active Task
''');

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'active-task-3',
          title: 'Active Task',
          reviewStatus: 'rejected',
          reviewUpdatedAt: '2026-02-20T12:00:00Z',
        ),
        workflowStage: WorkflowStage.execution,
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    // reviewStatus should be preserved because there is an active task.
    expect(updated.reviewStatus, 'rejected');
    expect(updated.reviewUpdatedAt, '2026-02-20T12:00:00Z');
    expect(report.actions, isNot(contains('cleared_orphaned_review_status')));
  });

  test('repair resets stale workflow stage to idle when no active task', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_stale_workflow_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    store.write(
      store.read().copyWith(
        activeTask: const ActiveTaskState(id: null, title: null),
        workflowStage: WorkflowStage.execution,
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.workflowStage, WorkflowStage.idle);
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_stale_workflow_stage'));

    // Verify structured run-log event.
    final runLogFile = File(layout.runLogPath);
    final logLines = runLogFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final stageLogLines = logLines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'cleared_stale_workflow_stage';
      } catch (_) {
        return false;
      }
    }).toList();
    expect(stageLogLines, isNotEmpty,
        reason: 'Expected cleared_stale_workflow_stage log event');
    final stageData =
        (jsonDecode(stageLogLines.first) as Map<String, Object?>)['data']
            as Map<String, Object?>?;
    expect(stageData?['error_class'], 'state_repair');
    expect(stageData?['error_kind'], 'stale_workflow');
  });

  test('repair removes expired cooldown entries', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_repair_expired_cooldown_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);

    final pastTime = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    final futureTime = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String();

    store.write(
      store.read().copyWith(
        retryScheduling: RetrySchedulingState(
          cooldownUntil: {
            'id:expired-task': pastTime,
            'id:future-task': futureTime,
          },
        ),
      ),
    );

    final report = StateRepairService().repair(temp.path);

    final updated = store.read();
    expect(updated.taskCooldownUntil, hasLength(1));
    expect(updated.taskCooldownUntil.containsKey('id:future-task'), isTrue);
    expect(updated.taskCooldownUntil.containsKey('id:expired-task'), isFalse);
    expect(report.changed, isTrue);
    expect(report.actions, contains('cleared_expired_cooldowns'));

    // Verify structured run-log event.
    final runLogFile = File(layout.runLogPath);
    final logLines = runLogFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final cooldownLogLines = logLines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'cleared_expired_cooldowns';
      } catch (_) {
        return false;
      }
    }).toList();
    expect(cooldownLogLines, isNotEmpty,
        reason: 'Expected cleared_expired_cooldowns log event');
    final cooldownData =
        (jsonDecode(cooldownLogLines.first) as Map<String, Object?>)['data']
            as Map<String, Object?>?;
    expect(cooldownData?['error_class'], 'state_repair');
    expect(cooldownData?['error_kind'], 'expired_cooldowns');
  });
}
