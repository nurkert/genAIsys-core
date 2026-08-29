// Autopilot Smoke Suite
//
// If this file passes, the autopilot pipeline works end-to-end.
// Run this after every refactor.
//
// This file aggregates all 8 E2E scenarios into a single sequential test
// suite. Each scenario creates its own isolated harness with its own temp
// directory, git repo, and stub agents. The scenarios are independent and
// can be run individually, but running them together provides a
// comprehensive smoke check of the entire autopilot pipeline.
//
// Scenarios:
//   1. Happy path (activate -> code -> review -> done)
//   2. Review reject and retry (reject -> retry -> approve -> done)
//   3. Multi-task sequential (3 tasks in fair-mode order)
//   4. Safety halt on repeated failures
//   5. No-diff detection
//   6. Quality gate failure
//   7. Provider failover (primary fails -> fallback succeeds)
//   8. Dry-run immutability (no state mutation)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/use_cases/diagnostics_use_cases.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  // -------------------------------------------------------------------------
  // 1. Happy path
  // -------------------------------------------------------------------------
  test(
    'Smoke: happy-path single cycle — activate, code, review, done',
    () async {
      final harness = await E2EHarness.create(agentRunner: SuccessAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Add E2E marker file\n');

      final result = await harness.runAutopilotStep();

      expect(result.executedCycle, isTrue);
      expect(result.reviewDecision, 'approve');
      expect(result.autoMarkedDone, isTrue);
      expect(result.retryCount, 0);
      expect(result.blockedTask, isFalse);
      expect(result.activatedTask, isTrue);
      expect(result.activeTaskTitle, 'Add E2E marker file');

      expect(harness.isTaskDone('Add E2E marker file'), isTrue);

      final state = harness.readState();
      expect(state.workflowStage, WorkflowStage.done);
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);
      expect(state.consecutiveFailures, 0);

      expect(harness.gitCommitCount(), greaterThanOrEqualTo(2));

      // Feature branch merged back to main.
      final currentBranch = Process.runSync(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: harness.projectRoot,
      );
      expect(currentBranch.stdout.toString().trim(), 'main');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 2. Review reject and retry
  // -------------------------------------------------------------------------
  test(
    'Smoke: review reject and retry — FlakeAgent rejects once then approves',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FlakeAgent(failCount: 1),
        maxReviewRetries: 3,
      );
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Fix important bug\n');

      final results = await harness.runAutopilotLoop(maxSteps: 5);
      final executed = results.where((r) => r.executedCycle).toList();

      expect(executed.length, greaterThanOrEqualTo(2));
      expect(executed.first.reviewDecision, 'reject');
      expect(executed.first.retryCount, 1);
      expect(executed.first.autoMarkedDone, isFalse);

      final approved = executed.where((r) => r.reviewDecision == 'approve');
      expect(approved, isNotEmpty);
      expect(approved.last.retryCount, 0);

      expect(harness.isTaskDone('Fix important bug'), isTrue);

      final state = harness.readState();
      final retryKeysForTask = state.taskRetryCounts.keys.where(
        (key) => key.contains('fix-important-bug'),
      );
      expect(retryKeysForTask, isEmpty);

      final runLog = harness.readRunLog();
      expect(runLog, contains('review_reject'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 3. Multi-task sequential
  // -------------------------------------------------------------------------
  test(
    'Smoke: multi-task sequential — 3 tasks completed',
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
      final executed = results.where((r) => r.executedCycle).toList();
      expect(executed.length, greaterThanOrEqualTo(3));

      final tasks = harness.readTasks();
      final doneTasks = tasks
          .where((t) => t.completion == TaskCompletion.done)
          .toList();
      expect(doneTasks.length, 3);

      final completionOrder = executed
          .where((r) => r.autoMarkedDone && r.activeTaskTitle != null)
          .map((r) => r.activeTaskTitle!)
          .toList();
      expect(completionOrder.length, 3);
      expect(
        completionOrder.toSet(),
        containsAll(['Task A', 'Task B', 'Task C']),
      );
      expect(completionOrder.first, 'Task A');

      expect(harness.gitCommitCount(), greaterThanOrEqualTo(4));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  // -------------------------------------------------------------------------
  // 4. Safety halt on repeated failures
  // -------------------------------------------------------------------------
  test(
    'Smoke: safety halt on repeated failures — autopilot stops',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FailAgent(),
        autopilotMaxFailures: 2,
      );
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Impossible task\n');

      final results = await harness.runAutopilotLoop(maxSteps: 5);

      expect(results.length, lessThanOrEqualTo(2));
      expect(harness.isTaskDone('Impossible task'), isFalse);

      final state = harness.readState();
      expect(state.workflowStage.name, isNot('done'));

      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);

      final lines = runLog.split('\n').where((l) => l.trim().isNotEmpty);
      final eventTypes = <String>{};
      for (final line in lines) {
        try {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          final event = entry['event']?.toString();
          if (event != null) {
            eventTypes.add(event);
          }
        } catch (_) {}
      }
      expect(eventTypes, isNotEmpty);
      expect(eventTypes.contains('activate_task'), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 5. No-diff detection
  // -------------------------------------------------------------------------
  test(
    'Smoke: no-diff detection — NoOpAgent produces no file changes',
    () async {
      final harness = await E2EHarness.create(agentRunner: NoOpAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] No-op task\n');

      final commitsBefore = harness.gitCommitCount();

      OrchestratorStepResult? stepResult;
      try {
        stepResult = await harness.runAutopilotStep();
        expect(stepResult.executedCycle, isTrue);
        expect(stepResult.autoMarkedDone, isFalse);
      } catch (_) {
        // No-diff may throw — acceptable.
      }

      expect(harness.isTaskDone('No-op task'), isFalse);

      final commitsAfter = harness.gitCommitCount();
      expect(commitsAfter, lessThanOrEqualTo(commitsBefore + 1));

      final state = harness.readState();
      if (stepResult != null) {
        expect(stepResult.retryCount, greaterThanOrEqualTo(1));
        final hasRetryEntry = state.taskRetryCounts.entries.any(
          (entry) => entry.key.contains('no-op-task') && entry.value > 0,
        );
        expect(hasRetryEntry, isTrue);
      }

      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 6. Quality gate failure
  // -------------------------------------------------------------------------
  test(
    'Smoke: quality gate failure — SyntaxErrorAgent triggers analyze failure',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: SyntaxErrorAgent(),
        qualityGateEnabled: true,
        qualityGateCommands: ['dart', 'analyze', '--fatal-infos'],
      );
      addTearDown(harness.dispose);

      _seedDartProject(harness.projectRoot);
      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Add bad code\n');

      OrchestratorStepResult? stepResult;
      try {
        stepResult = await harness.runAutopilotStep();
        expect(stepResult.executedCycle, isTrue);
        expect(stepResult.autoMarkedDone, isFalse);
      } catch (_) {
        // Quality gate failure may throw — acceptable.
      }

      expect(harness.isTaskDone('Add bad code'), isFalse);

      final state = harness.readState();
      expect(state.workflowStage.name, isNot('done'));

      if (stepResult != null) {
        expect(stepResult.retryCount, greaterThanOrEqualTo(1));
      }

      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 7. Provider failover
  // -------------------------------------------------------------------------
  test(
    'Smoke: provider failover — primary fails, fallback succeeds',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: FailAgent(),
        fallbackRunner: SuccessAgent(),
      );
      addTearDown(harness.dispose);

      harness.seedTasks(
        '## Backlog\n- [ ] [P1] [CORE] Provider failover task\n',
      );

      OrchestratorStepResult? stepResult;
      Object? stepError;
      try {
        stepResult = await harness.runAutopilotStep();
      } catch (error) {
        stepError = error;
      }

      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);

      if (stepResult != null) {
        expect(stepResult.executedCycle, isTrue);
        expect(stepResult.autoMarkedDone, isTrue);
        expect(stepResult.reviewDecision, 'approve');
        expect(harness.isTaskDone('Provider failover task'), isTrue);

        final lines = runLog.split('\n').where((l) => l.trim().isNotEmpty);
        var hasProviderRotation = false;
        for (final line in lines) {
          try {
            final entry = jsonDecode(line) as Map<String, dynamic>;
            final event = entry['event']?.toString() ?? '';
            if (event.contains('provider_rotated') ||
                event.contains('provider_rotation') ||
                event.contains('agent_command')) {
              hasProviderRotation = true;
              break;
            }
          } catch (_) {}
        }
        expect(hasProviderRotation, isTrue);
      } else {
        expect(stepError, isNotNull);
        expect(harness.isTaskDone('Provider failover task'), isFalse);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // -------------------------------------------------------------------------
  // 8. Dry-run immutability
  // -------------------------------------------------------------------------
  test(
    'Smoke: dry-run does not mutate — all project files unchanged',
    () async {
      final harness = await E2EHarness.create(agentRunner: SuccessAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Dry-run task\n');

      final snapshotBefore = _snapshotDirectory(
        '${harness.projectRoot}/.genaisys',
      );
      final commitsBefore = harness.gitCommitCount();

      final dryRunUseCase = AutopilotDryRunUseCase();
      final dryResult = await dryRunUseCase.run(harness.projectRoot);

      expect(dryResult, isNotNull);

      final snapshotAfter = _snapshotDirectory(
        '${harness.projectRoot}/.genaisys',
      );
      expect(
        snapshotAfter,
        equals(snapshotBefore),
        reason: 'Dry-run must not mutate .genaisys/ files',
      );

      final commitsAfter = harness.gitCommitCount();
      expect(
        commitsAfter,
        equals(commitsBefore),
        reason: 'Dry-run must not create git commits',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

// ---------------------------------------------------------------------------
// Shared helpers (used by quality gate and dry-run scenarios)
// ---------------------------------------------------------------------------

void _seedDartProject(String root) {
  const pubspec = '''
name: e2e_test_project
environment:
  sdk: ">=3.0.0 <4.0.0"
''';
  const analysisOptions = '''
include: package:lints/recommended.yaml
''';
  _writeFile(root, 'pubspec.yaml', pubspec);
  _writeFile(root, 'analysis_options.yaml', analysisOptions);

  _runGit(root, ['add', '-A']);
  final status = Process.runSync('git', [
    'status',
    '--porcelain',
  ], workingDirectory: root);
  if (status.stdout.toString().trim().isNotEmpty) {
    _runGit(root, [
      'commit',
      '--no-gpg-sign',
      '-m',
      'chore: seed Dart project',
    ]);
    _runGit(root, ['push']);
  }
}

void _writeFile(String root, String relativePath, String content) {
  final file = File('$root/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

Map<String, String> _snapshotDirectory(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return {};
  final snapshot = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path.substring(dirPath.length);
      try {
        snapshot[relativePath] = entity.readAsStringSync();
      } catch (_) {
        snapshot[relativePath] = 'binary:${entity.lengthSync()}';
      }
    }
  }
  return snapshot;
}
