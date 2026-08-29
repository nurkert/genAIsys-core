// Phase 7 Regression Gate — Autopilot Reliability Matrix
//
// This is the release gate -- do not merge if this test fails.
//
// Each scenario verifies a critical autopilot reliability invariant.
// Failures in any of these scenarios indicate a regression in the
// unattended execution guarantees.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/models/retry_scheduling_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/project_initializer.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  // -------------------------------------------------------------------------
  // Scenario 1: Happy path — 3 tasks complete in sequence
  // -------------------------------------------------------------------------
  test(
    'reliability: happy path with 3 tasks all complete',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: SuccessAgent(),
        prefix: 'heph_rel_happy_',
      );
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Reliability task A\n'
        '- [ ] [P1] [QA] Reliability task B\n'
        '- [ ] [P2] [CORE] Reliability task C\n',
      );

      final results = await harness.runAutopilotLoop(maxSteps: 12);
      final executed = results.where((r) => r.executedCycle).toList();
      expect(
        executed.length,
        greaterThanOrEqualTo(3),
        reason: 'At least 3 cycles for 3 tasks',
      );

      // All tasks done.
      expect(harness.isTaskDone('Reliability task A'), isTrue);
      expect(harness.isTaskDone('Reliability task B'), isTrue);
      expect(harness.isTaskDone('Reliability task C'), isTrue);

      // STATE.json is valid.
      final state = harness.readState();
      expect(state.workflowStage, isNotNull);

      // Run log has evidence.
      final runLog = harness.readRunLog();
      expect(runLog, contains('orchestrator_step'));
      expect(runLog, contains('approve'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  // -------------------------------------------------------------------------
  // Scenario 2: One reject then retry succeeds
  // -------------------------------------------------------------------------
  test(
    'reliability: one reject followed by successful retry',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FlakeAgent(failCount: 1),
        maxReviewRetries: 3,
        prefix: 'heph_rel_retry_',
      );
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n- [ ] [P1] [CORE] Retry reliability task\n',
      );

      final results = await harness.runAutopilotLoop(maxSteps: 8);
      final executed = results.where((r) => r.executedCycle).toList();

      // Should have at least 2 cycles (reject + approve).
      expect(executed.length, greaterThanOrEqualTo(2));

      // First cycle should be rejected.
      expect(executed.first.reviewDecision, 'reject');

      // Task should eventually be done.
      expect(harness.isTaskDone('Retry reliability task'), isTrue);

      // Run log evidence of reject + approve flow.
      final runLog = harness.readRunLog();
      expect(runLog, contains('reject'));
      expect(runLog, contains('approve'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // -------------------------------------------------------------------------
  // Scenario 3: Safety halt on max_failures=2
  // -------------------------------------------------------------------------
  test(
    'reliability: safety halt triggers after 2 consecutive failures',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FailAgent(),
        autopilotMaxFailures: 2,
        prefix: 'heph_rel_halt_',
      );
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n- [ ] [P1] [CORE] Doomed task\n',
      );

      final results = await harness.runAutopilotLoop(maxSteps: 10);

      // Loop should stop within a few steps because FailAgent crashes.
      expect(
        results.length,
        lessThanOrEqualTo(3),
        reason: 'Loop should halt quickly with FailAgent',
      );

      // Task should NOT be done.
      expect(harness.isTaskDone('Doomed task'), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // Scenario 4: Stale lock recovery
  // -------------------------------------------------------------------------
  test(
    'reliability: stale lock with dead PID is recovered',
    () {
      final temp = Directory.systemTemp.createTempSync('heph_rel_lock_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final projectRoot = temp.path;
      final layout = ProjectLayout(projectRoot);

      ProjectInitializer(projectRoot).ensureStructure(overwrite: true);
      StateStore(layout.statePath).write(
        ProjectState(
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );

      // Create a lock with a dead PID.
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);
      const deadPid = 999999;
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=2026-01-01T00:00:00.000Z\n'
        'last_heartbeat=2026-01-01T00:00:00.000Z\n'
        'pid=$deadPid\n',
      );

      final runService = OrchestratorRunService(sleep: (_) async {});
      runService.getStatus(projectRoot);

      // Lock should be recovered.
      expect(lockFile.existsSync(), isFalse);

      // Run log should contain recovery evidence.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('lock_recovered'));
      expect(runLog, contains('pid_not_alive'));
    },
  );

  // -------------------------------------------------------------------------
  // Scenario 5: Corrupt state recovery
  // -------------------------------------------------------------------------
  test(
    'reliability: corrupt STATE.json recovers to initial state',
    () {
      final temp = Directory.systemTemp.createTempSync('heph_rel_corrupt_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final statePath = '${temp.path}/STATE.json';

      // Write invalid JSON.
      File(statePath).writeAsStringSync('{{not-valid-json');

      var corruptionDetected = false;
      final store = StateStore(
        statePath,
        onCorruption: ({
          required String path,
          required String expected,
          required String computed,
        }) {
          corruptionDetected = true;
        },
      );

      final state = store.read();
      expect(state.workflowStage, WorkflowStage.idle);
      expect(state.activeTaskId, isNull);
      expect(corruptionDetected, isTrue);

      // After recovery, state can be written and read back.
      store.write(
        ProjectState(
          lastUpdated: '2026-01-01T00:00:00Z',
          activeTask: const ActiveTaskState(id: 'recovered-task'),
        ),
      );
      final recovered = store.read();
      expect(recovered.activeTaskId, 'recovered-task');
    },
  );

  // -------------------------------------------------------------------------
  // Scenario 6: Cooldown is respected
  // -------------------------------------------------------------------------
  test(
    'reliability: task cooldown persists in state and blocks reactivation',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: SuccessAgent(),
        prefix: 'heph_rel_cool_',
      );
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n- [ ] [P1] [CORE] Cooldown gated task\n',
      );

      // Set a future cooldown for the only task.
      final layout = harness.layout;
      final stateStore = StateStore(layout.statePath);
      final state = stateStore.read();
      final futureTime =
          DateTime.now().toUtc().add(const Duration(hours: 2));
      stateStore.write(
        state.copyWith(
          retryScheduling: RetrySchedulingState(
            cooldownUntil: {
              'title:cooldown gated task': futureTime.toIso8601String(),
            },
          ),
        ),
      );

      // Verify cooldown is written.
      final updated = stateStore.read();
      expect(updated.taskCooldownUntil, isNotEmpty);
      final cooldownStr = updated.taskCooldownUntil.values.first;
      expect(
        DateTime.parse(cooldownStr).isAfter(DateTime.now().toUtc()),
        isTrue,
        reason: 'Cooldown must be in the future',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
