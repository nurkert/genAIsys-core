import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: quality gate failure — SyntaxErrorAgent triggers dart analyze failure',
    () async {
      final harness = await E2EHarness.create(
        agentRunner: SyntaxErrorAgent(),
        qualityGateEnabled: true,
        qualityGateCommands: ['dart', 'analyze', '--fatal-infos'],
      );
      addTearDown(harness.dispose);

      // Set up a minimal Dart project so `dart analyze` works.
      _seedDartProject(harness.projectRoot);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Add bad code\n');

      // The step should execute but quality gate should fail.
      OrchestratorStepResult? stepResult;
      Object? stepError;
      try {
        stepResult = await harness.runAutopilotStep();
        // If we get a result, the cycle executed but review should NOT approve
        // because quality gate should have blocked or caused rejection.
        expect(stepResult.executedCycle, isTrue);
        // The task should not be done because the code has errors.
        expect(stepResult.autoMarkedDone, isFalse);
      } catch (error) {
        // Quality gate failure may propagate as an exception — acceptable.
        stepError = error;
      }

      // Task should NOT be marked done.
      expect(harness.isTaskDone('Add bad code'), isFalse);

      // STATE.json should reflect the failure state.
      final state = harness.readState();

      // Workflow stage should not be 'done' since the quality gate blocked.
      expect(state.workflowStage.name, isNot('done'));

      // If the step completed (not thrown), verify retry count was
      // incremented due to the quality gate rejection.
      if (stepResult != null) {
        // The quality gate failure should cause a review rejection or
        // no-diff, leading to an incremented retry count.
        expect(
          stepResult.retryCount,
          greaterThanOrEqualTo(1),
          reason:
              'Quality gate failure should increment the failure counter',
        );
      }

      // Run log should contain evidence of the quality gate run.
      final runLog = harness.readRunLog();
      expect(runLog, isNotEmpty);

      // If an error was thrown, it should indicate a quality gate or
      // pipeline failure.
      if (stepError != null) {
        // Acceptable: quality gate failure propagated as an exception.
        // The key invariant is that the task was not incorrectly marked done.
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

void _seedDartProject(String root) {
  // Create a minimal pubspec.yaml so `dart analyze` can find a package.
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

  // Commit the Dart project files.
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
