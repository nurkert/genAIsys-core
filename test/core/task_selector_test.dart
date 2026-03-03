import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';
import 'package:genaisys/core/selection/task_selection_context.dart';

void main() {
  test('TaskSelector returns null when no open tasks', () {
    final selector = TaskSelector();
    final tasks = <Task>[];

    expect(selector.nextOpenTask(tasks), isNull);
  });

  test('TaskSelector picks highest priority open task', () {
    final selector = TaskSelector();
    final tasks = [
      Task(
        title: 'Blocked priority',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: true,
        section: 'Backlog',
        lineIndex: 0,
      ),
      Task(
        title: 'Lower priority',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 2,
      ),
      Task(
        title: 'Done task',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.done,
        section: 'Backlog',
        lineIndex: 1,
      ),
      Task(
        title: 'Highest priority',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 5,
      ),
    ];

    final next = selector.nextOpenTask(tasks);
    expect(next?.title, 'Highest priority');
  });

  test('TaskSelector uses line order for same priority', () {
    final selector = TaskSelector();
    final tasks = [
      Task(
        title: 'Second',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 10,
      ),
      Task(
        title: 'First',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 3,
      ),
    ];

    final next = selector.nextOpenTask(tasks);
    expect(next?.title, 'First');
  });

  test('TaskSelector fair mode avoids starving lower priorities', () {
    final selector = TaskSelector();
    final tasks = [
      Task(
        title: 'P1 Task',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      ),
      Task(
        title: 'P2 Task',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      ),
    ];

    final context = TaskSelectionContext(
      mode: TaskSelectionMode.fair,
      fairnessWindow: 6,
      priorityWeights: const {
        TaskPriority.p1: 3,
        TaskPriority.p2: 1,
        TaskPriority.p3: 1,
      },
      deferNonCriticalUiTasks: false,
      includeBlocked: false,
      includeFailed: true,
      failedCooldown: Duration.zero,
      blockedCooldown: Duration.zero,
      retryCounts: const {},
      taskCooldownUntil: const {},
      history: TaskSelectionHistory(
        priorityHistory: const [
          TaskPriority.p1,
          TaskPriority.p1,
          TaskPriority.p1,
          TaskPriority.p1,
          TaskPriority.p1,
          TaskPriority.p1,
        ],
        lastActivationByTaskId: const {},
        lastActivationByTitle: const {},
      ),
      now: DateTime.utc(2026, 2, 5),
    );

    final next = selector.nextOpenTask(tasks, context: context);
    expect(next?.title, 'P2 Task');
  });

  test('TaskSelector respects failed cooldown', () {
    final selector = TaskSelector();
    final task = Task(
      title: 'Flaky Task',
      priority: TaskPriority.p2,
      category: TaskCategory.core,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 0,
    );
    final now = DateTime.utc(2026, 2, 5, 10, 0, 0);
    final context = TaskSelectionContext(
      mode: TaskSelectionMode.priority,
      fairnessWindow: 0,
      priorityWeights: const {
        TaskPriority.p1: 3,
        TaskPriority.p2: 2,
        TaskPriority.p3: 1,
      },
      deferNonCriticalUiTasks: false,
      includeBlocked: false,
      includeFailed: true,
      failedCooldown: const Duration(seconds: 60),
      blockedCooldown: Duration.zero,
      retryCounts: {'id:${task.id}': 1},
      taskCooldownUntil: const {},
      history: TaskSelectionHistory(
        priorityHistory: const [],
        lastActivationByTaskId: {
          task.id: now.subtract(const Duration(seconds: 30)),
        },
        lastActivationByTitle: const {},
      ),
      now: now,
    );

    final next = selector.nextOpenTask([task], context: context);
    expect(next, isNull);
  });

  test('TaskSelector defers non-critical UI tasks during stabilization', () {
    final selector = TaskSelector();
    final uiTask = Task(
      title: 'UI polish',
      priority: TaskPriority.p3,
      category: TaskCategory.ui,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 0,
    );
    final context = TaskSelectionContext(
      mode: TaskSelectionMode.priority,
      fairnessWindow: 0,
      priorityWeights: const {
        TaskPriority.p1: 3,
        TaskPriority.p2: 2,
        TaskPriority.p3: 1,
      },
      deferNonCriticalUiTasks: true,
      includeBlocked: false,
      includeFailed: true,
      failedCooldown: Duration.zero,
      blockedCooldown: Duration.zero,
      retryCounts: const {},
      taskCooldownUntil: const {},
      history: TaskSelectionHistory.empty(),
      now: DateTime.utc(2026, 2, 7),
    );

    final next = selector.nextOpenTask([uiTask], context: context);
    expect(next, isNull);
  });

  test('TaskSelector still allows P1 UI tasks during stabilization', () {
    final selector = TaskSelector();
    final uiTask = Task(
      title: 'UI outage fix',
      priority: TaskPriority.p1,
      category: TaskCategory.ui,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 0,
    );
    final context = TaskSelectionContext(
      mode: TaskSelectionMode.priority,
      fairnessWindow: 0,
      priorityWeights: const {
        TaskPriority.p1: 3,
        TaskPriority.p2: 2,
        TaskPriority.p3: 1,
      },
      deferNonCriticalUiTasks: true,
      includeBlocked: false,
      includeFailed: true,
      failedCooldown: Duration.zero,
      blockedCooldown: Duration.zero,
      retryCounts: const {},
      taskCooldownUntil: const {},
      history: TaskSelectionHistory.empty(),
      now: DateTime.utc(2026, 2, 7),
    );

    final next = selector.nextOpenTask([uiTask], context: context);
    expect(next?.title, 'UI outage fix');
  });

  test(
    'TaskSelector keeps interaction task eligible with GUI_PARITY:DONE marker',
    () {
      final selector = TaskSelector();
      final interactionTask = Task(
        title: '[INTERACTION] [GUI_PARITY:DONE] Add CLI status command',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: true,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 11),
      );

      final next = selector.nextOpenTask([interactionTask], context: context);
      expect(next?.title, interactionTask.title);
    },
  );

  test(
    'TaskSelector keeps interaction task eligible with deferred GUI parity link',
    () {
      final selector = TaskSelector();
      final linkedUiTask = Task(
        title: 'Deferred GUI parity task',
        priority: TaskPriority.p2,
        category: TaskCategory.ui,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      );
      final interactionTask = Task(
        title:
            '[INTERACTION] [GUI_PARITY:${linkedUiTask.id}] Add CLI status command',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: true,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 11),
      );

      final next = selector.nextOpenTask([
        interactionTask,
        linkedUiTask,
      ], context: context);
      expect(next?.title, interactionTask.title);
    },
  );

  test(
    'TaskSelector rejects interaction task with missing parity metadata',
    () {
      final selector = TaskSelector();
      final interactionTask = Task(
        title: '[INTERACTION] Add CLI status command',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      );
      final fallback = Task(
        title: 'Fallback task',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: true,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 11),
      );

      final next = selector.nextOpenTask([
        interactionTask,
        fallback,
      ], context: context);
      expect(next?.title, fallback.title);
    },
  );

  test('TaskSelector rejects interaction task with broken parity link', () {
    final selector = TaskSelector();
    final interactionTask = Task(
      title: '[INTERACTION] [GUI_PARITY:missing-ui-42] Add CLI status command',
      priority: TaskPriority.p1,
      category: TaskCategory.core,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 0,
    );
    final fallback = Task(
      title: 'Fallback task',
      priority: TaskPriority.p2,
      category: TaskCategory.core,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 1,
    );
    final context = TaskSelectionContext(
      mode: TaskSelectionMode.priority,
      fairnessWindow: 0,
      priorityWeights: const {
        TaskPriority.p1: 3,
        TaskPriority.p2: 2,
        TaskPriority.p3: 1,
      },
      deferNonCriticalUiTasks: false,
      includeBlocked: false,
      includeFailed: true,
      failedCooldown: Duration.zero,
      blockedCooldown: Duration.zero,
      retryCounts: const {},
      taskCooldownUntil: const {},
      history: TaskSelectionHistory.empty(),
      now: DateTime.utc(2026, 2, 11),
    );

    final next = selector.nextOpenTask([
      interactionTask,
      fallback,
    ], context: context);
    expect(next?.title, fallback.title);
  });

  test(
    'TaskSelector reactivates blocked tasks only for auto-cycle block reasons',
    () {
      final selector = TaskSelector();
      final autoCycleBlockedTask = Task(
        title:
            'Retry parser handling (Reason: Auto-cycle: review rejected 3 time(s))',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: true,
        section: 'Backlog',
        lineIndex: 0,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: true,
        includeFailed: true,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 11),
      );

      final next = selector.nextOpenTask([
        autoCycleBlockedTask,
      ], context: context);
      expect(next?.title, autoCycleBlockedTask.title);
    },
  );

  test(
    'TaskSelector keeps non-auto-cycle blocked tasks ineligible when reactivation is enabled',
    () {
      final selector = TaskSelector();
      final manuallyBlockedTask = Task(
        title: 'Native runtime wave item',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: true,
        section: 'Backlog',
        lineIndex: 0,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: true,
        includeFailed: true,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 11),
      );

      final next = selector.nextOpenTask([
        manuallyBlockedTask,
      ], context: context);
      expect(next, isNull);
    },
  );

  test(
    'TaskSelector strict_priority refuses P2 when open non-blocked P1 exists but is ineligible',
    () {
      final selector = TaskSelector();
      final p1CoolingDown = Task(
        title: 'Critical P1 fix',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      );
      final p2Ready = Task(
        title: 'P2 enhancement',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      );
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.strictPriority,
        fairnessWindow: 12,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: true,
        failedCooldown: const Duration(seconds: 120),
        blockedCooldown: Duration.zero,
        // P1 task is marked failed and cooling down.
        retryCounts: {'id:${p1CoolingDown.id}': 1},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory(
          priorityHistory: const [],
          lastActivationByTaskId: {
            p1CoolingDown.id: now.subtract(const Duration(seconds: 30)),
          },
          lastActivationByTitle: const {},
        ),
        now: now,
      );

      // P1 is open+non-blocked but cooling down (ineligible).
      // strict_priority must refuse P2 selection → return null.
      final next = selector.nextOpenTask(
        [p1CoolingDown, p2Ready],
        context: context,
      );
      expect(next, isNull);
    },
  );

  test(
    'TaskSelector strict_priority allows P2 when all P1 tasks are done or blocked',
    () {
      final selector = TaskSelector();
      final p1Done = Task(
        title: 'Done P1 task',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.done,
        section: 'Backlog',
        lineIndex: 0,
      );
      final p1Blocked = Task(
        title: 'Blocked P1 task',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: true,
        section: 'Backlog',
        lineIndex: 1,
      );
      final p2Ready = Task(
        title: 'P2 enhancement',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 2,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.strictPriority,
        fairnessWindow: 12,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: false,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 19),
      );

      // All P1 tasks are done or blocked → P2 is allowed.
      final next = selector.nextOpenTask(
        [p1Done, p1Blocked, p2Ready],
        context: context,
      );
      expect(next?.title, 'P2 enhancement');
    },
  );

  test(
    'TaskSelector priority mode still selects P2 when P1 is cooling down (regression)',
    () {
      final selector = TaskSelector();
      final p1CoolingDown = Task(
        title: 'Critical P1 fix',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 0,
      );
      final p2Ready = Task(
        title: 'P2 enhancement',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      );
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.priority,
        fairnessWindow: 0,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: true,
        failedCooldown: const Duration(seconds: 120),
        blockedCooldown: Duration.zero,
        // P1 task is marked failed and cooling down.
        retryCounts: {'id:${p1CoolingDown.id}': 1},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory(
          priorityHistory: const [],
          lastActivationByTaskId: {
            p1CoolingDown.id: now.subtract(const Duration(seconds: 30)),
          },
          lastActivationByTitle: const {},
        ),
        now: now,
      );

      // In non-strict (priority) mode, P2 should still be selected even
      // though P1 exists but is cooling down.
      final next = selector.nextOpenTask(
        [p1CoolingDown, p2Ready],
        context: context,
      );
      expect(next?.title, 'P2 enhancement');
    },
  );

  test(
    'TaskSelector strict_priority always picks P1 before P2 by line order',
    () {
      final selector = TaskSelector();
      final p2Early = Task(
        title: 'P2 task (early line)',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      );
      final p1Late = Task(
        title: 'P1 task (late line)',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 10,
      );
      final p1Early = Task(
        title: 'P1 task (early line)',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 3,
      );
      final context = TaskSelectionContext(
        mode: TaskSelectionMode.strictPriority,
        fairnessWindow: 12,
        priorityWeights: const {
          TaskPriority.p1: 3,
          TaskPriority.p2: 2,
          TaskPriority.p3: 1,
        },
        deferNonCriticalUiTasks: false,
        includeBlocked: false,
        includeFailed: false,
        failedCooldown: Duration.zero,
        blockedCooldown: Duration.zero,
        retryCounts: const {},
        taskCooldownUntil: const {},
        history: TaskSelectionHistory.empty(),
        now: DateTime.utc(2026, 2, 18),
      );

      final next = selector.nextOpenTask([
        p2Early,
        p1Late,
        p1Early,
      ], context: context);
      // Must pick P1 (not P2), and among P1 tasks, the one with lower lineIndex.
      expect(next?.title, 'P1 task (early line)');
    },
  );
}
