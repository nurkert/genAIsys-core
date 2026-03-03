import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/task.dart';

import '../e2e/support/e2e_harness.dart';
import '../e2e/support/stub_agents.dart';

void main() {
  group('Autopilot soak test', () {
    test(
      '10-task soak: all tasks complete, no state corruption, no stale locks',
      () async {
        final harness = await E2EHarness.create(
          agentRunner: SuccessAgent(),
          prefix: 'heph_soak_10_',
        );
        addTearDown(harness.dispose);

        final taskLines = List.generate(
          10,
          (i) => '- [ ] [P1] [CORE] Soak task ${i + 1}',
        ).join('\n');
        harness.seedTasks('## Backlog\n$taskLines\n');

        // Run enough steps for 10 tasks (with buffer for plan/activate overhead).
        await harness.runAutopilotLoop(maxSteps: 30);
        // All 10 tasks should be marked as done.
        final tasks = harness.readTasks();
        final doneTasks = tasks
            .where((t) => t.completion == TaskCompletion.done)
            .toList();
        expect(
          doneTasks.length,
          10,
          reason: 'All 10 soak tasks should be completed',
        );

        // Verify each task specifically.
        for (var i = 1; i <= 10; i++) {
          expect(
            harness.isTaskDone('Soak task $i'),
            isTrue,
            reason: 'Soak task $i should be done',
          );
        }

        // STATE.json should be valid after all cycles.
        final state = harness.readState();
        expect(
          state.workflowStage,
          isNotNull,
          reason: 'Workflow stage must be valid',
        );

        // The E2E harness creates an autopilot lock file to simulate
        // unattended mode. If the lock still exists, verify it belongs to the
        // current process (not a stale orphan).
        final lockFile = File(harness.layout.autopilotLockPath);
        if (lockFile.existsSync()) {
          final content = lockFile.readAsStringSync();
          // The harness-created lock should contain the current PID.
          expect(
            content,
            contains('$pid'),
            reason:
                'Lock file, if present, should belong to the current process',
          );
        }

        // Run log should show evidence of cycles.
        final runLog = harness.readRunLog();
        expect(runLog, isNotEmpty);
        expect(
          runLog,
          contains('orchestrator_step'),
          reason: 'Run log should contain orchestrator step events',
        );

        // Git should have commits for each task.
        expect(
          harness.gitCommitCount(),
          greaterThanOrEqualTo(11),
          reason: 'At least 11 commits (1 bootstrap + 10 task cycles)',
        );
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );

    test(
      'alternating success/failure: FlakeAgent(failCount:1) completes all tasks',
      () async {
        // FlakeAgent rejects the first review per instantiation.
        // But since each task step creates a new review cycle, the first
        // review of each task is rejected, and the retry succeeds.
        final harness = await E2EHarness.create(
          agentRunner: FlakeAgent(failCount: 1),
          maxReviewRetries: 3,
          autopilotMaxFailures: 20,
          prefix: 'heph_soak_flake_',
        );
        addTearDown(harness.dispose);

        final taskLines = List.generate(
          5,
          (i) => '- [ ] [P1] [CORE] Flake soak ${i + 1}',
        ).join('\n');
        harness.seedTasks('## Backlog\n$taskLines\n');

        final results = await harness.runAutopilotLoop(maxSteps: 30);
        final executedCycles =
            results.where((r) => r.executedCycle).toList();

        // At least 5 tasks should have executed cycles.
        expect(
          executedCycles.length,
          greaterThanOrEqualTo(5),
          reason: 'At least 5 cycles for 5 tasks with retries',
        );

        // All tasks should eventually be completed.
        final tasks = harness.readTasks();
        final doneTasks = tasks
            .where((t) => t.completion == TaskCompletion.done)
            .toList();
        expect(
          doneTasks.length,
          5,
          reason: 'All 5 flake soak tasks should complete despite retries',
        );

        // Run log should show both reject and approve decisions.
        final runLog = harness.readRunLog();
        expect(runLog, contains('reject'));
        expect(runLog, contains('approve'));
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  });
}
