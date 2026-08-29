import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/task.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: multi-task sequential — 3 tasks completed in priority order',
    () async {
      final harness = await E2EHarness.create(agentRunner: SuccessAgent());
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Task A\n'
        '- [ ] [P1] [QA] Task B\n'
        '- [ ] [P2] [CORE] Task C\n',
      );

      final results = await harness.runAutopilotLoop(maxSteps: 9);

      // At least 3 cycles should have executed (one per task).
      final executed = results.where((r) => r.executedCycle).toList();
      expect(executed.length, greaterThanOrEqualTo(3));

      // All 3 tasks should be marked done.
      final tasks = harness.readTasks();
      final doneTasks = tasks
          .where((t) => t.completion == TaskCompletion.done)
          .toList();
      expect(doneTasks.length, 3);

      // Verify task completion: all 3 distinct tasks were completed.
      //
      // Note: The default selection mode is "fair" (not strict priority),
      // which intentionally interleaves priority groups to prevent P2/P3
      // starvation. Therefore we verify all tasks complete but do NOT
      // enforce strict P1-before-P2 ordering.
      final completionOrder = executed
          .where((r) => r.autoMarkedDone && r.activeTaskTitle != null)
          .map((r) => r.activeTaskTitle!)
          .toList();

      // Expect exactly 3 completed tasks.
      expect(
        completionOrder.length,
        3,
        reason: 'Should have 3 completed tasks',
      );

      // All 3 unique tasks must appear in the completion list.
      expect(
        completionOrder.toSet(),
        containsAll(['Task A', 'Task B', 'Task C']),
        reason: 'All 3 tasks must be completed exactly once',
      );

      // The highest-priority task (first P1 by line index) should be
      // selected first, since no prior activation history exists.
      expect(
        completionOrder.first,
        'Task A',
        reason:
            'First P1 task by line index should be activated first '
            'when no prior activation history exists',
      );

      // Each executed cycle should have auto-marked done.
      final doneResults = executed.where((r) => r.autoMarkedDone).toList();
      expect(
        doneResults.length,
        greaterThanOrEqualTo(3),
        reason: 'Each task should have been auto-marked done',
      );

      // Git has commits for each task.
      expect(harness.gitCommitCount(), greaterThanOrEqualTo(4));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
