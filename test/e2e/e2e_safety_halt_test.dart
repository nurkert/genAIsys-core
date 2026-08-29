import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: safety halt on repeated failures — autopilot stops after max_failures',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FailAgent(),
        autopilotMaxFailures: 2,
      );
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Impossible task\n');

      // Run loop with budget higher than max_failures to verify halt.
      final results = await harness.runAutopilotLoop(maxSteps: 5);

      // The loop should have stopped due to agent failures (caught errors).
      // FailAgent causes the pipeline to fail, which propagates as a thrown
      // exception caught by runAutopilotLoop's catch block. The loop breaks
      // early, resulting in 0 results (every step throws).
      expect(results.length, lessThanOrEqualTo(2));

      // Task was never successfully completed.
      expect(harness.isTaskDone('Impossible task'), isFalse);

      // STATE.json should reflect the failure state.
      final state = harness.readState();

      // Workflow stage should not be 'done' since the task never succeeded.
      expect(state.workflowStage.name, isNot('done'));

      // Run log should contain evidence of failures.
      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);

      // Run log should contain structured events from the failed step
      // execution. At minimum, the git_step_error_autostash or
      // task_cycle_start events should be present.
      final lines = runLog.split('\n').where((l) => l.trim().isNotEmpty);
      final eventTypes = <String>{};
      for (final line in lines) {
        try {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          final event = entry['event']?.toString();
          if (event != null) {
            eventTypes.add(event);
          }
        } catch (_) {
          // Skip non-JSON lines.
        }
      }
      // The orchestrator should have logged at least some events before the
      // failure, including activation and the error-cleanup autostash.
      expect(eventTypes, isNotEmpty);
      // The activate_task event should be logged (task was activated before
      // the agent crash).
      expect(
        eventTypes.contains('activate_task'),
        isTrue,
        reason:
            'Run log should contain activate_task event showing the task '
            'was activated before the agent failure',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
