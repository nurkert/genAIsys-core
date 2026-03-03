import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_release_candidate_service.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';

void main() {
  test('candidate fails when required blocker lines are missing', () async {
    final root = _createProjectRoot('genaisys_candidate_missing_blockers_');
    final layout = ProjectLayout(root);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Incomplete stabilization task
''');

    final runner = _FakeShellCommandRunner(const <ShellCommandResult>[]);
    final service = AutopilotReleaseCandidateService(commandRunner: runner);

    final result = await service.runCandidate(root, skipSuites: true);

    expect(result.passed, isFalse);
    expect(result.missingDoneBlockers, isNotEmpty);
    expect(result.commandOutcomes, isEmpty);
    expect(runner.invocations, isEmpty);
  });

  test(
    'candidate passes with skip suites when blocker lines are complete',
    () async {
      final root = _createProjectRoot('genaisys_candidate_skip_suites_');
      final layout = ProjectLayout(root);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Done
${_requiredDoneBlockers.join('\n')}
''');

      final runner = _FakeShellCommandRunner(const <ShellCommandResult>[]);
      final service = AutopilotReleaseCandidateService(commandRunner: runner);

      final result = await service.runCandidate(root, skipSuites: true);

      expect(result.passed, isTrue);
      expect(result.missingDoneBlockers, isEmpty);
      expect(result.openCriticalP1Lines, isEmpty);
      expect(result.commandOutcomes, isEmpty);
      expect(runner.invocations, isEmpty);
    },
  );

  test('candidate stops at first failing suite command', () async {
    final root = _createProjectRoot('genaisys_candidate_suite_failure_');
    final layout = ProjectLayout(root);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Done
${_requiredDoneBlockers.join('\n')}
''');

    final runner = _FakeShellCommandRunner(<ShellCommandResult>[
      const ShellCommandResult(
        exitCode: 0,
        stdout: 'format ok',
        stderr: '',
        duration: Duration(milliseconds: 10),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'analyze failed',
        duration: Duration(milliseconds: 20),
        timedOut: false,
      ),
      const ShellCommandResult(
        exitCode: 0,
        stdout: 'should not run',
        stderr: '',
        duration: Duration(milliseconds: 5),
        timedOut: false,
      ),
    ]);
    final service = AutopilotReleaseCandidateService(commandRunner: runner);

    final result = await service.runCandidate(root, skipSuites: false);

    expect(result.passed, isFalse);
    expect(result.commandOutcomes, hasLength(2));
    expect(result.commandOutcomes.last.ok, isFalse);
  });

  test('pilot creates default feat branch and writes report', () async {
    final root = _createProjectRoot('genaisys_pilot_branch_report_');
    final layout = ProjectLayout(root);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Done
${_requiredDoneBlockers.join('\n')}
''');

    _initGit(root);
    final runService = _FakeOrchestratorRunService();
    final service = AutopilotReleaseCandidateService(runService: runService);

    final result = await service.runPilot(
      root,
      duration: const Duration(seconds: 5),
      maxCycles: 3,
      skipCandidate: true,
    );

    expect(result.passed, isTrue);
    expect(result.branch.startsWith('feat/pilot-'), isTrue);
    expect(File(result.reportPath).existsSync(), isTrue);
    expect(GitService().currentBranch(root), result.branch);
    expect(runService.runInvocations, 1);
    expect(runService.stopInvocations, greaterThanOrEqualTo(1));
    expect(File(layout.runLogPath).existsSync(), isTrue);
  });
}

String _createProjectRoot(String prefix) {
  final temp = Directory.systemTemp.createTempSync(prefix);
  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  addTearDown(() {
    temp.deleteSync(recursive: true);
  });
  return temp.path;
}

void _initGit(String root) {
  Process.runSync('git', ['init', '-b', 'main'], workingDirectory: root);
  Process.runSync('git', [
    'config',
    'user.email',
    'test@example.com',
  ], workingDirectory: root);
  Process.runSync('git', [
    'config',
    'user.name',
    'Test User',
  ], workingDirectory: root);
  Process.runSync('git', ['add', '-A'], workingDirectory: root);
  Process.runSync('git', [
    'commit',
    '--no-gpg-sign',
    '-m',
    'init',
  ], workingDirectory: root);
}

class _FakeShellCommandRunner implements ShellCommandRunner {
  _FakeShellCommandRunner(this._results);

  final List<ShellCommandResult> _results;
  final List<String> invocations = <String>[];
  int _index = 0;

  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    invocations.add(command);
    if (_index >= _results.length) {
      throw StateError('No fake command result for: $command');
    }
    final result = _results[_index];
    _index += 1;
    return result;
  }
}

class _FakeOrchestratorRunService extends OrchestratorRunService {
  _FakeOrchestratorRunService();

  int runInvocations = 0;
  int stopInvocations = 0;

  @override
  Future<OrchestratorRunResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle = false,
    int? maxConsecutiveFailures,
    int? maxTaskRetries,
    bool unattendedMode = false,
    bool overrideSafety = false,
  }) async {
    runInvocations += 1;
    return OrchestratorRunResult(
      totalSteps: 2,
      successfulSteps: 1,
      idleSteps: 1,
      failedSteps: 0,
      stoppedByMaxSteps: false,
      stoppedWhenIdle: true,
      stoppedBySafetyHalt: false,
    );
  }

  @override
  Future<void> stop(String projectRoot) async {
    stopInvocations += 1;
  }
}

const List<String> _requiredDoneBlockers = <String>[
  '- [x] [P1] [SEC] Redact provider secrets and auth tokens from RUN_LOG.jsonl, attempt artifacts, and CLI error surfaces',
  '- [x] [P1] [CORE] Persist normalized failure reasons (timeout, policy, provider, test, review, git) in state and status APIs',
  '- [x] [P1] [CORE] Enforce deterministic subtask scheduling tie-breakers and log scheduler decision inputs for replayability',
  '- [x] [P1] [REF] Split TaskCycleService into explicit planning/coding/testing/review stages with typed stage boundaries',
  '- [x] [P1] [REF] Refactor OrchestratorStepService into explicit state-transition handlers to reduce hidden coupling',
  '- [x] [P1] [REF] Decompose `lib/core/services/orchestrator_run_service.dart` into orchestrator modules under `lib/core/services/orchestrator/` (loop coordinator, lock handling, release-tag flow, run-log events)',
  '- [x] [P1] [QA] Add end-to-end crash-recovery tests for failures injected after each cycle stage boundary',
  '- [x] [P1] [QA] Add regression tests for lock races and concurrent CLI actions (activate, done, review, autopilot run)',
  '- [x] [P1] [SEC] Add adversarial tests for safe-write bypass attempts (path traversal, symlink edges, relative escapes)',
  '- [x] [P1] [SEC] Add adversarial tests for shell_allowlist bypass attempts (chaining, subshell, separator abuse)',
  '- [x] [P1] [CORE] Block task completion when mandatory review evidence bundle is missing or malformed',
  '- [x] [P1] [CORE] Add explicit git delivery preflight (clean index, expected branch, upstream status) before done/merge',
  '- [x] [P1] [QA] Re-enable zero-analysis-issues quality gate in CI and fail pipeline on any new analyzer warning',
  '- [x] [P1] [QA] Add minimum coverage thresholds for core orchestration and policy modules in CI',
];
