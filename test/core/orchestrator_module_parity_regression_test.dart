import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('Parity: status output keeps expected fields and last step summary', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_parity_status_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        autopilotRun: AutopilotRunState(
          lastLoopAt: '2026-02-08T10:00:00Z',
          consecutiveFailures: 2,
          lastError: 'parity-check',
          lastErrorClass: 'pipeline',
          lastErrorKind: 'review_rejected',
        ),
        subtaskExecution: SubtaskExecutionState(
          queue: const ['A', 'B'],
          current: 'A',
        ),
      ),
    );
    File(layout.runLogPath).writeAsStringSync('''
{"timestamp":"2026-02-08T10:01:00Z","event":"orchestrator_run_step","data":{"step_id":"run-1","task_id":"task-1","subtask_id":"A","decision":"approve"}}
''');

    final service = _ParityRunService(
      stepService: _SequenceStepService(const []),
    );
    final status = service.getStatus(temp.path);

    expect(status.isRunning, isFalse);
    expect(status.lastLoopAt, '2026-02-08T10:00:00Z');
    expect(status.consecutiveFailures, 2);
    expect(status.lastError, 'parity-check');
    expect(status.lastErrorClass, 'pipeline');
    expect(status.lastErrorKind, 'review_rejected');
    expect(status.subtaskQueue, ['A', 'B']);
    expect(status.currentSubtask, 'A');
    expect(status.lastStepSummary, isNotNull);
    expect(status.lastStepSummary!.stepId, 'run-1');
    expect(status.lastStepSummary!.taskId, 'task-1');
    expect(status.lastStepSummary!.subtaskId, 'A');
    expect(status.lastStepSummary!.decision, 'approve');
  });

  test('Parity: stop semantics stop running loop and release lock', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_parity_stop_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final service = _ParityRunService(
      stepService: _SequenceStepService([
        _StepCase.result(
          _stepResult(executedCycle: false, plannedTasksAdded: 0),
        ),
      ]),
      sleep: (_) async {},
    );

    final runFuture = service.run(
      temp.path,
      codingPrompt: 'Advance one step',
      stopWhenIdle: false,
      maxSteps: 1000,
      stepSleep: const Duration(milliseconds: 1),
      idleSleep: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await service.stop(temp.path);
    final result = await runFuture.timeout(const Duration(seconds: 10));

    expect(result.stoppedBySafetyHalt, isFalse);
    expect(File(layout.autopilotLockPath).existsSync(), isFalse);
    expect(File(layout.autopilotStopPath).existsSync(), isFalse);
    final state = StateStore(layout.statePath).read();
    expect(state.autopilotRunning, isFalse);
  });

  test('Parity: safety halt behavior remains unchanged', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_parity_safety_halt_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);

    final service = _ParityRunService(
      stepService: _ErrorStepService(PermanentError('forced parity halt')),
      sleep: (_) async {},
    );
    final result = await service.run(
      temp.path,
      codingPrompt: 'Advance one step',
      maxConsecutiveFailures: 1,
      maxSteps: 1,
    );

    expect(result.stoppedBySafetyHalt, isTrue);
    expect(result.failedSteps, 1);
    final runLog = File(layout.runLogPath).readAsStringSync();
    expect(runLog, contains('"event":"orchestrator_run_safety_halt"'));
  });

  test(
    'Parity: release-tag flow still tags and pushes on ready step',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_parity_tag_',
      );
      final remote = Directory.systemTemp.createTempSync(
        'genaisys_parity_tag_remote_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
        remote.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  shell_allowlist:
    - git status
  quality_gate:
    enabled: true
    commands:
      - git status --short
autopilot:
  release_tag_on_ready: true
  release_tag_push: true
  release_tag_prefix: "v"
''');
      File(
        '${temp.path}${Platform.pathSeparator}pubspec.yaml',
      ).writeAsStringSync('name: genaisys_test\nversion: 1.2.3\n');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['config', 'commit.gpgsign', 'false']);
      _runGit(remote.path, ['init', '--bare']);
      _runGit(temp.path, ['remote', 'add', 'origin', remote.path]);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '-m', 'init']);

      final shortSha = Process.runSync('git', [
        'rev-parse',
        '--short',
        'HEAD',
      ], workingDirectory: temp.path).stdout.toString().trim();
      final expectedTag = 'v1.2.3-$shortSha';

      final service = _ParityRunService(
        stepService: _SequenceStepService([
          _StepCase.result(
            _stepResult(executedCycle: true, plannedTasksAdded: 0),
          ),
        ]),
        sleep: (_) async {},
      );
      final result = await service.run(
        temp.path,
        codingPrompt: 'Advance one step',
        maxSteps: 1,
      );
      expect(result.totalSteps, 1);

      final localTag = Process.runSync('git', [
        'tag',
        '--list',
        expectedTag,
      ], workingDirectory: temp.path).stdout.toString().trim();
      expect(localTag, expectedTag);
      final remoteTag = Process.runSync('git', [
        '--git-dir',
        remote.path,
        'show-ref',
        '--verify',
        'refs/tags/$expectedTag',
      ]);
      expect(remoteTag.exitCode, 0);
    },
  );
}

class _ParityRunService extends OrchestratorRunService {
  _ParityRunService({super.stepService, super.sleep})
    : super(autopilotPreflightService: _AlwaysPassPreflightService());
}

class _AlwaysPassPreflightService extends AutopilotPreflightService {
  @override
  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    return const AutopilotPreflightResult.ok();
  }
}

class _StepCase {
  const _StepCase.result(this.result);

  final OrchestratorStepResult result;
}

class _SequenceStepService extends OrchestratorStepService {
  _SequenceStepService(this.cases);

  final List<_StepCase> cases;
  var _index = 0;

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
    if (_index >= cases.length) {
      return _stepResult(executedCycle: false, plannedTasksAdded: 0);
    }
    final current = cases[_index];
    _index += 1;
    return current.result;
  }
}

class _ErrorStepService extends OrchestratorStepService {
  _ErrorStepService(this.error);

  final Object error;

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
    throw error;
  }
}

OrchestratorStepResult _stepResult({
  required bool executedCycle,
  required int plannedTasksAdded,
  int retryCount = 0,
  String? reviewDecision,
  bool? autoMarkedDone,
}) {
  final decision = reviewDecision ?? (executedCycle ? 'approve' : null);
  final markedDone = autoMarkedDone ?? (executedCycle && decision == 'approve');
  return OrchestratorStepResult(
    executedCycle: executedCycle,
    activatedTask: false,
    activeTaskId: executedCycle ? 'task-1' : null,
    activeTaskTitle: executedCycle ? 'Task' : null,
    plannedTasksAdded: plannedTasksAdded,
    reviewDecision: decision,
    retryCount: retryCount,
    blockedTask: false,
    deactivatedTask: false,
    currentSubtask: null,
    autoMarkedDone: markedDone,
    approvedDiffStats: null,
  );
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode == 0) {
    return;
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: ${result.stderr}',
  );
}
