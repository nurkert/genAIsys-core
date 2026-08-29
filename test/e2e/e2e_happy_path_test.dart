import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: happy-path single cycle — activate, code, review, done',
    () async {
      final harness = await E2EHarness.create(agentRunner: SuccessAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Add E2E marker file\n');

      final result = await harness.runAutopilotStep();

      // Cycle executed successfully.
      expect(result.executedCycle, isTrue);
      expect(result.reviewDecision, 'approve');
      expect(result.autoMarkedDone, isTrue);

      // Step result fields should reflect zero retries and no blocking.
      expect(result.retryCount, 0);
      expect(result.blockedTask, isFalse);
      expect(result.activatedTask, isTrue);
      expect(result.activeTaskTitle, 'Add E2E marker file');

      // Task marked as done in TASKS.md.
      expect(harness.isTaskDone('Add E2E marker file'), isTrue);
      final tasks = harness.readTasks();
      final doneCount = tasks
          .where((t) => t.completion == TaskCompletion.done)
          .length;
      expect(doneCount, 1);

      // STATE.json reflects completion.
      final state = harness.readState();
      expect(state.workflowStage, WorkflowStage.done);

      // After completion, active task should be cleared.
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);

      // No consecutive failures should be recorded for a clean run.
      expect(state.consecutiveFailures, 0);

      // Git has commits (bootstrap + feature work).
      expect(harness.gitCommitCount(), greaterThanOrEqualTo(2));

      // Feature branch should have been merged back to main.
      // After DoneService._handleGitMerge, we should be on main and the
      // feature branch should have been deleted.
      final branchResult = Process.runSync(
        'git',
        ['branch', '--list'],
        workingDirectory: harness.projectRoot,
      );
      final branches = branchResult.stdout
          .toString()
          .split('\n')
          .map((b) => b.trim().replaceFirst('* ', ''))
          .where((b) => b.isNotEmpty)
          .toList();
      // Feature branch (feat/*) should not exist after merge.
      final featureBranches =
          branches.where((b) => b.startsWith('feat/')).toList();
      expect(
        featureBranches,
        isEmpty,
        reason: 'Feature branch should be deleted after merge to main',
      );

      // Current branch should be main after merge.
      final currentBranch = Process.runSync(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: harness.projectRoot,
      );
      expect(currentBranch.stdout.toString().trim(), 'main');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
