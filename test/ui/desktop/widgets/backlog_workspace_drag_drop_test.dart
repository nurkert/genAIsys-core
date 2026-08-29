import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/ui/desktop/controllers/project_workspace_controller.dart';
import 'package:genaisys/ui/desktop/localization/desktop_localization.dart';
import 'package:genaisys/ui/desktop/models/workspace_models.dart';
import 'package:genaisys/ui/desktop/widgets/shell/workspaces/backlog_workspace_view.dart';

void main() {
  testWidgets('backlog board shows quick-create plus in blocked and todo', (
    WidgetTester tester,
  ) async {
    final _TestBacklogController controller = _TestBacklogController(
      tasks: const <BacklogTask>[
        BacklogTask(
          id: 'task-1',
          title: 'Task',
          description: 'Desc',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
      ],
    );
    addTearDown(controller.dispose);

    var createRequests = 0;

    await tester.pumpWidget(
      _wrapForTest(
        BacklogWorkspaceView(
          controller: controller,
          onCreateTaskRequested: () {
            createRequests += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder plusButtons = find.byIcon(Icons.add);
    expect(plusButtons, findsNWidgets(2));

    await tester.tap(plusButtons.first);
    await tester.pumpAndSettle();
    expect(createRequests, 1);
  });

  testWidgets(
    'backlog cards can be moved between columns with direct drag and drop',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-1',
            title: 'Refactor backlog drag',
            description: 'Make desktop drag and drop immediate.',
            priority: BacklogTaskPriority.p1,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder taskCard = find.byKey(const Key('backlog.task.task-1'));
      final Finder doneColumn = find.byKey(const Key('backlog.column.done'));
      final Finder blockedColumn = find.byKey(
        const Key('backlog.column.blocked'),
      );

      expect(taskCard, findsOneWidget);
      expect(doneColumn, findsOneWidget);
      expect(blockedColumn, findsOneWidget);

      final TestGesture moveToDone = await tester.startGesture(
        tester.getCenter(taskCard),
      );
      await tester.pump();
      await moveToDone.moveTo(tester.getCenter(doneColumn));
      await tester.pump();
      await moveToDone.up();
      await tester.pumpAndSettle();

      expect(controller.moves.length, 1);
      expect(controller.moves.first.taskId, 'task-1');
      expect(controller.moves.first.destination, BacklogTaskStatus.done);
      expect(
        controller.backlogTasksByStatus(BacklogTaskStatus.done).single.id,
        'task-1',
      );

      final TestGesture moveToBlocked = await tester.startGesture(
        tester.getCenter(taskCard),
      );
      await tester.pump();
      await moveToBlocked.moveTo(tester.getCenter(blockedColumn));
      await tester.pump();
      await moveToBlocked.up();
      await tester.pumpAndSettle();

      expect(controller.moves.length, 2);
      expect(controller.moves.last.taskId, 'task-1');
      expect(controller.moves.last.destination, BacklogTaskStatus.blocked);
      expect(
        controller.backlogTasksByStatus(BacklogTaskStatus.blocked).single.id,
        'task-1',
      );
    },
  );

  testWidgets(
    'backlog cards can be re-ordered inside the same column via upper-half drop',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-1',
            title: 'First task',
            description: 'A',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-2',
            title: 'Second task',
            description: 'B',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder firstTaskCard = find.byKey(const Key('backlog.task.task-1'));
      final Finder secondTaskCard = find.byKey(
        const Key('backlog.task.task-2'),
      );

      expect(firstTaskCard, findsOneWidget);
      expect(secondTaskCard, findsOneWidget);

      // Drag second task to the upper portion of first task (insert above it).
      final Rect firstRect = tester.getRect(firstTaskCard);
      final Offset aboveFirstTask = Offset(
        firstRect.center.dx,
        firstRect.top + (firstRect.height * 0.15),
      );

      final TestGesture reorderGesture = await tester.startGesture(
        tester.getCenter(secondTaskCard),
      );
      await tester.pump();
      await reorderGesture.moveTo(aboveFirstTask);
      await tester.pump();
      await reorderGesture.up();
      await tester.pumpAndSettle();

      expect(controller.moves, isEmpty);

      expect(firstTaskCard, findsOneWidget);
      expect(secondTaskCard, findsOneWidget);
      expect(
        tester.getTopLeft(secondTaskCard).dy,
        lessThan(tester.getTopLeft(firstTaskCard).dy),
      );
    },
  );

  testWidgets(
    'hovering upper/lower half of a task previews insertion above/below',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-1',
            title: 'First task',
            description: 'A',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-2',
            title: 'Second task',
            description: 'B',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder firstTaskCard = find.byKey(const Key('backlog.task.task-1'));
      final Finder secondTaskCard = find.byKey(
        const Key('backlog.task.task-2'),
      );

      // Start drag from second task.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(secondTaskCard),
      );
      await tester.pump();
      // Let the source-shrink animation settle so card positions stabilize.
      await tester.pumpAndSettle();

      // Measure first card position DURING drag (after source card shrinks).
      final Rect firstRectDuringDrag = tester.getRect(firstTaskCard);
      final Offset hoverUpperHalf = Offset(
        firstRectDuringDrag.center.dx,
        firstRectDuringDrag.top + (firstRectDuringDrag.height * 0.25),
      );

      await gesture.moveTo(hoverUpperHalf);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.moves, isEmpty);
      expect(
        tester.getTopLeft(secondTaskCard).dy,
        lessThan(tester.getTopLeft(firstTaskCard).dy),
      );
    },
  );

  testWidgets(
    'dragging onto lower half inserts directly below that task (no off-by-one)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-1',
            title: 'First task',
            description: 'A',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-2',
            title: 'Second task',
            description: 'B',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-3',
            title: 'Third task',
            description: 'C',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder firstTaskCard = find.byKey(const Key('backlog.task.task-1'));
      final Finder secondTaskCard = find.byKey(
        const Key('backlog.task.task-2'),
      );
      final Finder thirdTaskCard = find.byKey(const Key('backlog.task.task-3'));

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(firstTaskCard),
      );
      await tester.pump();
      // Let source shrink animation settle so card positions stabilize.
      await tester.pumpAndSettle();

      final Rect secondRectDuringDrag = tester.getRect(secondTaskCard);
      final Offset hoverLowerHalfOfSecond = Offset(
        secondRectDuringDrag.center.dx,
        secondRectDuringDrag.top + (secondRectDuringDrag.height * 0.75),
      );
      await gesture.moveTo(hoverLowerHalfOfSecond);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.moves, isEmpty);
      final double secondDy = tester.getTopLeft(secondTaskCard).dy;
      final double firstDy = tester.getTopLeft(firstTaskCard).dy;
      final double thirdDy = tester.getTopLeft(thirdTaskCard).dy;
      expect(firstDy, greaterThan(secondDy));
      expect(firstDy, lessThan(thirdDy));
    },
  );

  testWidgets(
    'lower-half insertion follows cursor position even with non-centered grab',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-1',
            title: 'First task',
            description: 'A',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-2',
            title: 'Second task',
            description: 'B',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-3',
            title: 'Third task',
            description: 'C',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder firstTaskCard = find.byKey(const Key('backlog.task.task-1'));
      final Finder secondTaskCard = find.byKey(
        const Key('backlog.task.task-2'),
      );
      final Finder thirdTaskCard = find.byKey(const Key('backlog.task.task-3'));

      final Rect firstRect = tester.getRect(firstTaskCard);
      final Offset startNearBottom = Offset(
        firstRect.center.dx,
        firstRect.top + (firstRect.height * 0.92),
      );

      final TestGesture gesture = await tester.startGesture(startNearBottom);
      await tester.pump();
      // Let source shrink animation settle so card positions stabilize.
      await tester.pumpAndSettle();

      final Rect secondRectDuringDrag = tester.getRect(secondTaskCard);
      final Offset hoverLowerHalfOfSecond = Offset(
        secondRectDuringDrag.center.dx,
        secondRectDuringDrag.top + (secondRectDuringDrag.height * 0.75),
      );
      await gesture.moveTo(hoverLowerHalfOfSecond);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.moves, isEmpty);
      final double secondDy = tester.getTopLeft(secondTaskCard).dy;
      final double firstDy = tester.getTopLeft(firstTaskCard).dy;
      final double thirdDy = tester.getTopLeft(thirdTaskCard).dy;
      expect(firstDy, greaterThan(secondDy));
      expect(firstDy, lessThan(thirdDy));
    },
  );

  testWidgets('canceling a drag restores the task to its original position', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _TestBacklogController controller = _TestBacklogController(
      tasks: const <BacklogTask>[
        BacklogTask(
          id: 'task-1',
          title: 'First task',
          description: 'A',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
        BacklogTask(
          id: 'task-2',
          title: 'Second task',
          description: 'B',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrapForTest(BacklogWorkspaceView(controller: controller)),
    );
    await tester.pumpAndSettle();

    final Finder firstTaskCard = find.byKey(const Key('backlog.task.task-1'));
    final Finder secondTaskCard = find.byKey(const Key('backlog.task.task-2'));
    final double firstTaskBefore = tester.getTopLeft(firstTaskCard).dy;
    final double secondTaskBefore = tester.getTopLeft(secondTaskCard).dy;

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(firstTaskCard),
    );
    await tester.pump();
    await gesture.moveTo(const Offset(8, 8));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.moves, isEmpty);
    expect(tester.getTopLeft(firstTaskCard).dy, equals(firstTaskBefore));
    expect(tester.getTopLeft(secondTaskCard).dy, equals(secondTaskBefore));
  });
  testWidgets(
    'cross-column drop preserves insertion position after controller refresh',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestBacklogController controller = _TestBacklogController(
        tasks: const <BacklogTask>[
          BacklogTask(
            id: 'task-src',
            title: 'Source task to move',
            description: 'Will be moved cross-column',
            priority: BacklogTaskPriority.p1,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.blocked,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-a',
            title: 'Task A in todo',
            description: 'First in todo',
            priority: BacklogTaskPriority.p1,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-b',
            title: 'Task B in todo',
            description: 'Second in todo',
            priority: BacklogTaskPriority.p2,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
          BacklogTask(
            id: 'task-c',
            title: 'Task C in todo',
            description: 'Third in todo',
            priority: BacklogTaskPriority.p3,
            assignedAgent: 'Codex',
            status: BacklogTaskStatus.todo,
            subtasks: <BacklogSubtask>[],
          ),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapForTest(BacklogWorkspaceView(controller: controller)),
      );
      await tester.pumpAndSettle();

      final Finder srcCard = find.byKey(const Key('backlog.task.task-src'));
      final Finder cardA = find.byKey(const Key('backlog.task.task-a'));
      final Finder cardB = find.byKey(const Key('backlog.task.task-b'));
      final Finder cardC = find.byKey(const Key('backlog.task.task-c'));

      expect(srcCard, findsOneWidget);
      expect(cardA, findsOneWidget);
      expect(cardB, findsOneWidget);
      expect(cardC, findsOneWidget);

      // Drag source task from blocked to the upper half of task-b in todo
      // (should insert between task-a and task-b).
      final Rect cardBRect = tester.getRect(cardB);
      final Offset dropTarget = Offset(
        cardBRect.center.dx,
        cardBRect.top + (cardBRect.height * 0.25),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(srcCard),
      );
      await tester.pump();
      await gesture.moveTo(dropTarget);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify the controller received the cross-column move.
      expect(controller.moves.length, 1);
      expect(controller.moves.first.taskId, 'task-src');
      expect(controller.moves.first.destination, BacklogTaskStatus.todo);

      // After refresh settles, verify task ordering in the todo column:
      // task-a, task-src (inserted), task-b, task-c.
      final double aDy = tester.getTopLeft(cardA).dy;
      final double srcDy = tester.getTopLeft(srcCard).dy;
      final double bDy = tester.getTopLeft(cardB).dy;
      final double cDy = tester.getTopLeft(cardC).dy;

      expect(
        srcDy,
        greaterThan(aDy),
        reason: 'task-src should be below task-a',
      );
      expect(srcDy, lessThan(bDy), reason: 'task-src should be above task-b');
      expect(bDy, lessThan(cDy), reason: 'task-b should be above task-c');
    },
  );

  // ---------------------------------------------------------------------------
  // Race-condition regression tests
  // ---------------------------------------------------------------------------

  testWidgets('cross-column drop survives multiple rapid controller rebuilds', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _TestBacklogController controller = _TestBacklogController(
      tasks: const <BacklogTask>[
        BacklogTask(
          id: 'task-src',
          title: 'Source task',
          description: 'Will be moved',
          priority: BacklogTaskPriority.p1,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.blocked,
          subtasks: <BacklogSubtask>[],
        ),
        BacklogTask(
          id: 'task-a',
          title: 'Task A',
          description: 'First in todo',
          priority: BacklogTaskPriority.p1,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
        BacklogTask(
          id: 'task-b',
          title: 'Task B',
          description: 'Second in todo',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
      ],
    );
    // Simulate the real controller firing 3 notifyListeners calls.
    controller.extraNotifyCount = 3;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrapForTest(BacklogWorkspaceView(controller: controller)),
    );
    await tester.pumpAndSettle();

    final Finder srcCard = find.byKey(const Key('backlog.task.task-src'));
    final Finder cardA = find.byKey(const Key('backlog.task.task-a'));
    final Finder cardB = find.byKey(const Key('backlog.task.task-b'));

    // Drag task-src from blocked to upper half of task-b.
    final Rect cardBRect = tester.getRect(cardB);
    final Offset dropTarget = Offset(
      cardBRect.center.dx,
      cardBRect.top + (cardBRect.height * 0.25),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(srcCard),
    );
    await tester.pump();
    await gesture.moveTo(dropTarget);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify: task-src is between task-a and task-b, NOT at the bottom.
    final double aDy = tester.getTopLeft(cardA).dy;
    final double srcDy = tester.getTopLeft(srcCard).dy;
    final double bDy = tester.getTopLeft(cardB).dy;

    expect(srcDy, greaterThan(aDy), reason: 'task-src below task-a');
    expect(srcDy, lessThan(bDy), reason: 'task-src above task-b');
  });

  testWidgets('polling refresh during in-flight does not displace task', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _TestBacklogController controller = _TestBacklogController(
      tasks: const <BacklogTask>[
        BacklogTask(
          id: 'task-src',
          title: 'Source task',
          description: 'Will be moved',
          priority: BacklogTaskPriority.p1,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.blocked,
          subtasks: <BacklogSubtask>[],
        ),
        BacklogTask(
          id: 'task-a',
          title: 'Task A',
          description: 'First in todo',
          priority: BacklogTaskPriority.p1,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
      ],
    );
    // Don't update the task status — simulates stale polling data.
    controller.skipStatusUpdate = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrapForTest(BacklogWorkspaceView(controller: controller)),
    );
    await tester.pumpAndSettle();

    final Finder srcCard = find.byKey(const Key('backlog.task.task-src'));
    final Finder todoColumn = find.byKey(const Key('backlog.column.todo'));

    // Drag task-src from blocked to todo column.
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(srcCard),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(todoColumn));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Task should be visible in todo column despite stale controller data.
    expect(srcCard, findsOneWidget);

    // Now simulate a stale polling refresh (controller data unchanged).
    controller.simulatePollingRefresh();
    await tester.pumpAndSettle();

    // Task must still be visible — in-flight protection prevents displacement.
    expect(srcCard, findsOneWidget);
  });

  testWidgets('same-column reorder is stable across controller rebuilds', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _TestBacklogController controller = _TestBacklogController(
      tasks: const <BacklogTask>[
        BacklogTask(
          id: 'task-1',
          title: 'First',
          description: 'A',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
        BacklogTask(
          id: 'task-2',
          title: 'Second',
          description: 'B',
          priority: BacklogTaskPriority.p2,
          assignedAgent: 'Codex',
          status: BacklogTaskStatus.todo,
          subtasks: <BacklogSubtask>[],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrapForTest(BacklogWorkspaceView(controller: controller)),
    );
    await tester.pumpAndSettle();

    final Finder firstCard = find.byKey(const Key('backlog.task.task-1'));
    final Finder secondCard = find.byKey(const Key('backlog.task.task-2'));

    // Drag second task above first.
    final Rect firstRect = tester.getRect(firstCard);
    final Offset aboveFirst = Offset(
      firstRect.center.dx,
      firstRect.top + (firstRect.height * 0.15),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(secondCard),
    );
    await tester.pump();
    await gesture.moveTo(aboveFirst);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify reorder: task-2 should be above task-1.
    expect(
      tester.getTopLeft(secondCard).dy,
      lessThan(tester.getTopLeft(firstCard).dy),
    );

    // Now simulate a polling refresh (controller still has original order).
    controller.simulatePollingRefresh();
    await tester.pumpAndSettle();

    // Same-column reorder must survive the polling rebuild.
    expect(
      tester.getTopLeft(secondCard).dy,
      lessThan(tester.getTopLeft(firstCard).dy),
      reason: 'Same-column reorder must survive controller rebuild',
    );
  });
}

Widget _wrapForTest(Widget child) {
  final DesktopLocalizationController localizationController =
      DesktopLocalizationController();
  return MaterialApp(
    home: DesktopLocalizationScope(
      controller: localizationController,
      child: Scaffold(body: child),
    ),
  );
}

class _TestBacklogController extends ProjectWorkspaceController {
  _TestBacklogController({required List<BacklogTask> tasks})
    : _tasks = List<BacklogTask>.from(tasks),
      super(projectRootPath: '/tmp/genaisys-backlog-test');

  List<BacklogTask> _tasks;
  final List<_MoveRecord> moves = <_MoveRecord>[];
  int _taskListTick = 0;
  final ValueNotifier<AppTaskListDto> _taskListNotifier =
      ValueNotifier<AppTaskListDto>(
        const AppTaskListDto(total: 0, tasks: <AppTaskDto>[]),
      );

  /// Extra notifyListeners calls to simulate the real controller's 3 calls.
  int extraNotifyCount = 0;

  /// When true, moveTaskBetweenColumns throws to simulate API failure.
  bool simulateApiFailure = false;

  /// When true, the task status update is skipped (simulates stale data).
  bool skipStatusUpdate = false;

  @override
  bool get isLoading => false;

  @override
  ValueNotifier<AppTaskListDto> get taskListNotifier => _taskListNotifier;

  @override
  List<BacklogTask> get backlogTasks => List<BacklogTask>.unmodifiable(_tasks);

  @override
  List<BacklogTask> backlogTasksByStatus(BacklogTaskStatus status) {
    return _tasks
        .where((BacklogTask task) => task.status == status)
        .toList(growable: false);
  }

  /// Fires a "polling-style" notifier bump without changing task data.
  /// Simulates a stale polling refresh arriving while a drag is in-flight.
  void simulatePollingRefresh() {
    _taskListTick += 1;
    _taskListNotifier.value = AppTaskListDto(
      total: _taskListTick,
      tasks: const <AppTaskDto>[],
    );
  }

  @override
  Future<void> moveTaskBetweenColumns({
    required String taskId,
    required BacklogTaskStatus destination,
  }) async {
    if (simulateApiFailure) {
      throw Exception('Simulated API failure');
    }

    moves.add(_MoveRecord(taskId: taskId, destination: destination));

    // Simulate the real controller's first notifyListeners (actionInProgress).
    notifyListeners();

    if (!skipStatusUpdate) {
      _tasks = _tasks
          .map(
            (BacklogTask task) =>
                task.id == taskId ? task.copyWith(status: destination) : task,
          )
          .toList(growable: false);
    }

    _taskListTick += 1;
    _taskListNotifier.value = AppTaskListDto(
      total: _taskListTick,
      tasks: const <AppTaskDto>[],
    );
    notifyListeners();

    // Simulate extra notification cycles (real controller fires 3 times).
    for (int i = 0; i < extraNotifyCount; i++) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _taskListNotifier.dispose();
    super.dispose();
  }
}

class _MoveRecord {
  const _MoveRecord({required this.taskId, required this.destination});

  final String taskId;
  final BacklogTaskStatus destination;
}
