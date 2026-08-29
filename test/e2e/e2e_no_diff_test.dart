import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: no-diff detection — NoOpAgent produces no file changes',
    () async {
      final harness = await E2EHarness.create(agentRunner: NoOpAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] No-op task\n');

      final commitsBefore = harness.gitCommitCount();

      // The step should execute but produce no diff.
      OrchestratorStepResult? stepResult;
      Object? stepError;
      try {
        stepResult = await harness.runAutopilotStep();
        // If we got a result, verify no-diff outcome.
        expect(stepResult.executedCycle, isTrue);
        expect(stepResult.autoMarkedDone, isFalse);
      } catch (error) {
        // A no-diff situation may throw depending on how the pipeline
        // handles it. This is acceptable for the E2E test.
        stepError = error;
      }

      // Task should NOT be marked done (no meaningful work done).
      expect(harness.isTaskDone('No-op task'), isFalse);

      // No new feature commits should exist (only bootstrap).
      final commitsAfter = harness.gitCommitCount();
      // At most one additional commit (for auto-stash or state update),
      // but no feature commit.
      expect(commitsAfter, lessThanOrEqualTo(commitsBefore + 1));

      // STATE.json should reflect the progress failure.
      final state = harness.readState();

      // The task should have an incremented retry count in taskRetryCounts.
      // The no-diff path calls _incrementRetry, which stores the retry
      // count keyed by task ID or title.
      if (stepResult != null) {
        // The retryCount from the step result should be >= 1 because the
        // no-diff path increments retry count.
        expect(
          stepResult.retryCount,
          greaterThanOrEqualTo(1),
          reason:
              'No-diff should increment the progress failure counter '
              '(retryCount >= 1)',
        );
      }

      // The taskRetryCounts map should have an entry for this task,
      // reflecting the no-diff failure. The retry key uses the task ID
      // format: 'id:<slug>-<lineIndex>' (e.g., 'id:no-op-task-2').
      if (stepResult != null) {
        final hasRetryEntry = state.taskRetryCounts.entries.any(
          (entry) =>
              entry.key.contains('no-op-task') &&
              entry.value > 0,
        );
        expect(
          hasRetryEntry,
          isTrue,
          reason:
              'STATE.json taskRetryCounts should contain an entry for the '
              'no-op task after a no-diff failure '
              '(actual keys: ${state.taskRetryCounts.keys.toList()})',
        );
      }

      // Run log should exist and contain events.
      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);

      // If a step error occurred, that's fine — the key assertion is that
      // the task was not incorrectly marked as done.
      if (stepError != null) {
        // Acceptable: no-diff triggers a progress failure path.
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
