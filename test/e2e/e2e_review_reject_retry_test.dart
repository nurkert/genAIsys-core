import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: review reject and retry — FlakeAgent rejects once then approves',
    () async {
      // FlakeAgent: first review returns REJECT, subsequent reviews delegate
      // to SuccessAgent (APPROVE). Coding always succeeds.
      //
      // The retry happens across multiple orchestrator steps:
      //   Step 1: activate → code → review(REJECT) → retryCount=1
      //   Step 2: re-activate → code → review(APPROVE) → done
      final harness = await E2EHarness.create(
        agentRunner: FlakeAgent(failCount: 1),
        maxReviewRetries: 3,
      );
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Fix important bug\n');

      // Run a loop — first step rejects, second step approves.
      final results = await harness.runAutopilotLoop(maxSteps: 5);
      final executed = results.where((r) => r.executedCycle).toList();

      // At least 2 executed cycles: one reject, one approve.
      expect(executed.length, greaterThanOrEqualTo(2));

      // First executed step should have been rejected.
      expect(executed.first.reviewDecision, 'reject');

      // First step should reflect retryCount=1 (incremented after reject).
      expect(
        executed.first.retryCount,
        1,
        reason: 'After the first reject, retryCount should be 1',
      );

      // First step should not have been marked done or blocked.
      expect(executed.first.autoMarkedDone, isFalse);
      expect(executed.first.blockedTask, isFalse);

      // Last executed step should have been approved.
      final approved = executed.where((r) => r.reviewDecision == 'approve');
      expect(approved, isNotEmpty);

      // The approved step should have zero retries (retry cleared on approve).
      expect(approved.last.retryCount, 0);

      // Task should be marked done after the successful retry.
      expect(harness.isTaskDone('Fix important bug'), isTrue);

      // STATE.json: after successful retry, taskRetryCounts for this task
      // should be cleared (the retry key is removed on approve).
      final state = harness.readState();
      // All retry keys for this task should have been removed.
      final retryKeysForTask = state.taskRetryCounts.keys.where(
        (key) => key.contains('fix-important-bug'),
      );
      expect(
        retryKeysForTask,
        isEmpty,
        reason: 'Retry counts should be cleared after successful approval',
      );

      // Run log should contain evidence of the reject + retry cycle.
      final runLog = harness.readRunLog();
      expect(runLog, contains('review_reject'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
