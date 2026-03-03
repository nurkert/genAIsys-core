import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';

class _EnvPreflightService extends AutopilotPreflightService {
  _EnvPreflightService(this._env);

  final Map<String, String> _env;

  @override
  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    return super.check(
      projectRoot,
      environment: _env,
      requirePushReadiness: requirePushReadiness,
      preflightTimeoutOverride: preflightTimeoutOverride,
    );
  }
}

class _FailIfCalledStepService extends OrchestratorStepService {
  var calls = 0;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    calls += 1;
    throw StateError(
      'StepService must not be invoked when preflight is blocked',
    );
  }
}

class _IdleStepService extends OrchestratorStepService {
  var calls = 0;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    calls += 1;
    return OrchestratorStepResult(
      executedCycle: false,
      activatedTask: false,
      activeTaskId: null,
      activeTaskTitle: null,
      plannedTasksAdded: 0,
      reviewDecision: null,
      retryCount: 0,
      blockedTask: false,
      deactivatedTask: false,
      currentSubtask: null,
      autoMarkedDone: false,
      approvedDiffStats: null,
    );
  }
}

void main() {
  test(
    'flow: guarded merge conflict is fail-closed by preflight and blocks autonomous step execution until resolution',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_guarded_merge_conflict_preflight_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      _initGitRepo(temp.path);
      _seedMergeConflict(temp.path);

      expect(_hasMergeHead(temp.path), isTrue);

      final env = _buildHealthEnv(temp.path);
      final stepService = _FailIfCalledStepService();
      final service = OrchestratorRunService(
        stepService: stepService,
        sleep: (_) async {},
        autopilotPreflightService: _EnvPreflightService(env),
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Advance one step',
        maxSteps: 1,
        stopWhenIdle: true,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      expect(stepService.calls, 0);
      expect(result.totalSteps, 1);
      expect(result.idleSteps, 1);
      expect(result.failedSteps, 0);
      expect(result.stoppedWhenIdle, isTrue);
      expect(File(layout.autopilotLockPath).existsSync(), isFalse);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"preflight_failed"'));
      expect(runLog, contains('"error_class":"preflight"'));
      expect(runLog, contains('"error_kind":"merge_conflict"'));
      expect(runLog, contains('"step_id":"run-'));
      expect(runLog, isNot(contains('"event":"orchestrator_run_step_start"')));
      expect(runLog, isNot(contains('"event":"agent_command"')));

      // Resume gating: resolving the conflict must allow step execution again.
      _runGit(temp.path, const ['merge', '--abort']);
      expect(_hasMergeHead(temp.path), isFalse);

      final idleStepService = _IdleStepService();
      final resumed = OrchestratorRunService(
        stepService: idleStepService,
        sleep: (_) async {},
        autopilotPreflightService: _EnvPreflightService(env),
      );
      final resumedResult = await resumed.run(
        temp.path,
        codingPrompt: 'Advance one step',
        maxSteps: 1,
        stopWhenIdle: true,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      expect(idleStepService.calls, 1);
      expect(resumedResult.totalSteps, 1);
    },
  );

  test(
    'flow: guarded rebase conflict is fail-closed by preflight and blocks autonomous step execution until resolution',
    () async {
      if (Platform.isWindows) {
        return; // Uses POSIX shell + git assumptions in the fixture.
      }

      final temp = Directory.systemTemp.createTempSync(
        'genaisys_guarded_rebase_conflict_preflight_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      _initGitRepo(temp.path);
      _seedRebaseConflict(temp.path);

      expect(_hasRebaseHead(temp.path), isTrue);

      final env = _buildHealthEnv(temp.path);
      final stepService = _FailIfCalledStepService();
      final service = OrchestratorRunService(
        stepService: stepService,
        sleep: (_) async {},
        autopilotPreflightService: _EnvPreflightService(env),
      );

      final result = await service.run(
        temp.path,
        codingPrompt: 'Advance one step',
        maxSteps: 1,
        stopWhenIdle: true,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );

      expect(stepService.calls, 0);
      expect(result.totalSteps, 1);
      expect(result.idleSteps, 1);
      expect(result.failedSteps, 0);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"preflight_failed"'));
      expect(runLog, contains('"error_class":"preflight"'));
      expect(runLog, contains('"error_kind":"merge_conflict"'));
      expect(runLog, isNot(contains('"event":"orchestrator_run_step_start"')));

      _runGit(temp.path, const ['rebase', '--abort']);
      expect(_hasRebaseHead(temp.path), isFalse);

      final idleStepService = _IdleStepService();
      final resumed = OrchestratorRunService(
        stepService: idleStepService,
        sleep: (_) async {},
        autopilotPreflightService: _EnvPreflightService(env),
      );
      await resumed.run(
        temp.path,
        codingPrompt: 'Advance one step',
        maxSteps: 1,
        stopWhenIdle: true,
        stepSleep: Duration.zero,
        idleSleep: Duration.zero,
      );
      expect(idleStepService.calls, 1);
    },
  );
}

void _initGitRepo(String root) {
  _runGit(root, const ['init', '-b', 'main']);
  _runGit(root, const ['config', 'user.email', 'test@example.com']);
  _runGit(root, const ['config', 'user.name', 'Test User']);
  _runGit(root, const ['config', 'commit.gpgsign', 'false']);
}

void _seedMergeConflict(String root) {
  File('$root${Platform.pathSeparator}.gitignore').writeAsStringSync(
    '.genaisys/\n'
    'bin/\n',
  );
  final conflictFile = File('$root${Platform.pathSeparator}conflict.txt');
  conflictFile.writeAsStringSync('base\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'init']);

  _runGit(root, const ['checkout', '-b', 'feat/conflict']);
  conflictFile.writeAsStringSync('feature\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'feature']);

  _runGit(root, const ['checkout', 'main']);
  conflictFile.writeAsStringSync('main\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'main']);

  final merge = Process.runSync(
    'git',
    const ['merge', 'feat/conflict'],
    workingDirectory: root,
    runInShell: false,
  );
  expect(merge.exitCode, isNot(0), reason: 'merge should conflict');
}

void _seedRebaseConflict(String root) {
  File('$root${Platform.pathSeparator}.gitignore').writeAsStringSync(
    '.genaisys/\n'
    'bin/\n',
  );
  final conflictFile = File('$root${Platform.pathSeparator}conflict.txt');
  conflictFile.writeAsStringSync('base\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'init']);

  _runGit(root, const ['checkout', '-b', 'feat/rebase']);
  conflictFile.writeAsStringSync('feature\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'feature']);

  _runGit(root, const ['checkout', 'main']);
  conflictFile.writeAsStringSync('main\n');
  _runGit(root, const ['add', '-A']);
  _runGit(root, const ['commit', '--no-gpg-sign', '-m', 'main']);

  _runGit(root, const ['checkout', 'feat/rebase']);
  final rebase = Process.runSync(
    'git',
    const ['rebase', 'main'],
    workingDirectory: root,
    runInShell: false,
  );
  expect(rebase.exitCode, isNot(0), reason: 'rebase should conflict');
}

bool _hasMergeHead(String root) {
  return _gitExitOk(root, const ['rev-parse', '-q', '--verify', 'MERGE_HEAD']);
}

bool _hasRebaseHead(String root) {
  // REBASE_HEAD is present when a rebase is in progress; if not, exit != 0.
  return _gitExitOk(root, const ['rev-parse', '-q', '--verify', 'REBASE_HEAD']);
}

bool _gitExitOk(String root, List<String> args) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: root,
    runInShell: false,
  );
  return result.exitCode == 0;
}

String _gitStdout(String root, List<String> args) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: root,
    runInShell: false,
  );
  if (result.exitCode == 0) {
    return result.stdout.toString();
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: ${result.stderr}',
  );
}

void _runGit(String root, List<String> args) {
  _gitStdout(root, args);
}

Map<String, String> _buildHealthEnv(String root) {
  final fakeBin = Directory('$root${Platform.pathSeparator}bin')
    ..createSync(recursive: true);
  final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
    ..writeAsStringSync('#!/bin/sh\necho codex\n');
  Process.runSync('chmod', ['+x', codex.path]);
  final systemPath = Platform.environment['PATH'] ?? '';
  final separator = Platform.isWindows ? ';' : ':';
  final combinedPath = systemPath.trim().isEmpty
      ? fakeBin.path
      : '${fakeBin.path}$separator$systemPath';
  return {'PATH': combinedPath, 'OPENAI_API_KEY': 'test-key'};
}
