import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  group('Crash recovery matrix', () {
    test(
      'OrchestratorRunService recovers deterministically from stage-boundary fault injections',
      () async {
        const stages = ['planning', 'coding', 'testing', 'review', 'delivery'];
        for (final stage in stages) {
          final temp = Directory.systemTemp.createTempSync(
            'genaisys_reliability_stage_${stage}_',
          );
          addTearDown(() {
            temp.deleteSync(recursive: true);
          });
          ProjectInitializer(temp.path).ensureStructure(overwrite: true);
          final layout = ProjectLayout(temp.path);
          final sleeps = <Duration>[];
          final service = _MatrixOrchestratorRunService(
            stepService: _StageFaultStepService(stage: stage),
            sleep: (duration) async {
              sleeps.add(duration);
            },
          );

          final result = await service.run(
            temp.path,
            codingPrompt: 'Advance one step',
            maxSteps: 2,
            maxConsecutiveFailures: 3,
            stepSleep: const Duration(seconds: 2),
            idleSleep: const Duration(seconds: 9),
          );

          expect(result.totalSteps, 2, reason: 'stage=$stage');
          expect(result.failedSteps, 1, reason: 'stage=$stage');
          expect(result.successfulSteps, 1, reason: 'stage=$stage');
          expect(result.stoppedBySafetyHalt, isFalse, reason: 'stage=$stage');
          expect(
            sleeps,
            contains(const Duration(seconds: 2)),
            reason: 'stage=$stage',
          );

          final state = StateStore(layout.statePath).read();
          expect(state.autopilotRunning, isFalse, reason: 'stage=$stage');
          expect(state.currentMode, isNull, reason: 'stage=$stage');

          final runLog = File(layout.runLogPath).readAsStringSync();
          expect(
            runLog,
            contains('Injected crash after $stage boundary'),
            reason: 'stage=$stage',
          );
          expect(
            runLog,
            contains('"event":"orchestrator_run_transient_error"'),
          );
          expect(runLog, contains('"event":"orchestrator_run_step"'));
        }
      },
    );

    test(
      'OrchestratorRunService distinguishes no-progress idle from progress-failure',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_reliability_progress_contract_',
        );
        addTearDown(() {
          temp.deleteSync(recursive: true);
        });
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);
        final layout = ProjectLayout(temp.path);

        final service = _MatrixOrchestratorRunService(
          stepService: _SequenceStepService([
            _StepCase.result(
              _stepResult(executedCycle: false, plannedTasksAdded: 0),
            ),
            _StepCase.result(
              _stepResult(
                executedCycle: true,
                plannedTasksAdded: 0,
                reviewDecision: 'reject',
                retryCount: 1,
                autoMarkedDone: false,
              ),
            ),
          ]),
          sleep: (_) async {},
        );

        final result = await service.run(
          temp.path,
          codingPrompt: 'Advance one step',
          maxSteps: 2,
          maxConsecutiveFailures: 2,
        );

        expect(result.totalSteps, 2);
        expect(result.idleSteps, 1);
        expect(result.failedSteps, 1);
        expect(result.stoppedBySafetyHalt, isFalse);
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('"event":"orchestrator_run_step"'));
        expect(runLog, contains('"idle":true'));
        expect(runLog, contains('"progress_failure":true'));
        expect(runLog, contains('"event":"orchestrator_run_progress_failure"'));
        expect(runLog, contains('"error_kind":"review_rejected"'));
      },
    );
  });

  group('Concurrency and lock races', () {
    test(
      'OrchestratorRunService lock recovery remains deterministic under concurrent status and run',
      () async {
        for (var i = 0; i < 3; i += 1) {
          final temp = Directory.systemTemp.createTempSync(
            'genaisys_reliability_lock_race_$i',
          );
          addTearDown(() {
            temp.deleteSync(recursive: true);
          });
          ProjectInitializer(temp.path).ensureStructure(overwrite: true);
          final layout = ProjectLayout(temp.path);
          Directory(layout.locksDir).createSync(recursive: true);
          final lockFile = File(layout.autopilotLockPath);
          final now = DateTime.now().toUtc().toIso8601String();
          lockFile.writeAsStringSync('''
version=1
started_at=$now
last_heartbeat=$now
pid=999999
project_root=${temp.path}
''');

          final service = _MatrixOrchestratorRunService(
            stepService: _SequenceStepService([
              _StepCase.result(
                _stepResult(executedCycle: false, plannedTasksAdded: 0),
              ),
            ]),
            sleep: (_) async {},
          );

          final values = await Future.wait([
            Future<Object>(() => service.getStatus(temp.path)),
            service.run(
              temp.path,
              codingPrompt: 'Advance one step',
              maxSteps: 1,
            ),
          ]);
          expect(values, hasLength(2));
          expect(lockFile.existsSync(), isFalse);

          final runLog = File(layout.runLogPath).readAsStringSync();
          expect(runLog, contains('"event":"orchestrator_run_lock_recovered"'));
          expect(runLog, contains('"recovery_reason":"pid_not_alive"'));
        }
      },
    );

    test(
      'Concurrent activate/done/review actions complete without deadlock while autopilot lock is held',
      () async {
        for (var i = 0; i < 3; i += 1) {
          final temp = Directory.systemTemp.createTempSync(
            'genaisys_reliability_cli_race_$i',
          );
          addTearDown(() {
            temp.deleteSync(recursive: true);
          });
          ProjectInitializer(temp.path).ensureStructure(overwrite: true);
          final layout = ProjectLayout(temp.path);
          File(layout.tasksPath).writeAsStringSync('''
# Tasks

## Backlog
- [ ] [P1] [CORE] First task
- [ ] [P1] [CORE] Second task
''');
          final stateStore = StateStore(layout.statePath);
          stateStore.write(
            stateStore.read().copyWith(
              activeTask: ActiveTaskState(
                id: 'first-task',
                title: 'First task',
                reviewStatus: 'approved',
                reviewUpdatedAt: DateTime.now().toUtc().toIso8601String(),
              ),
            ),
          );

          final entered = Completer<void>();
          final release = Completer<void>();
          final firstService = _MatrixOrchestratorRunService(
            stepService: _BlockingStepService(
              entered: entered,
              release: release,
            ),
            sleep: (_) async {},
          );
          final secondService = _MatrixOrchestratorRunService(
            stepService: _SequenceStepService(const []),
            sleep: (_) async {},
          );

          final firstRun = firstService.run(
            temp.path,
            codingPrompt: 'Advance one step',
            maxSteps: 1,
          );
          await entered.future.timeout(const Duration(seconds: 5));

          final raceResults = await Future.wait<String>([
            Future<String>(() {
              try {
                ActivateService().activate(temp.path);
                return 'activate:ok';
              } catch (_) {
                return 'activate:error';
              }
            }),
            Future<String>(() {
              try {
                ReviewService().recordDecision(
                  temp.path,
                  decision: 'approve',
                  note: 'race check',
                );
                return 'review:ok';
              } catch (_) {
                return 'review:error';
              }
            }),
            Future<String>(() async {
              try {
                await DoneService().markDone(temp.path);
                return 'done:ok';
              } catch (_) {
                return 'done:error';
              }
            }),
            Future<String>(() async {
              try {
                await secondService.run(
                  temp.path,
                  codingPrompt: 'Advance one step',
                  maxSteps: 1,
                );
                return 'run2:ok';
              } catch (error) {
                if (error is StateError &&
                    error.message.contains('already running')) {
                  return 'run2:lock_held';
                }
                return 'run2:error';
              }
            }),
          ]).timeout(const Duration(seconds: 10));

          expect(raceResults, hasLength(4));
          expect(raceResults, contains('run2:lock_held'));

          release.complete();
          await firstRun.timeout(const Duration(seconds: 10));
          expect(File(layout.autopilotLockPath).existsSync(), isFalse);
        }
      },
    );
  });
}

class _MatrixOrchestratorRunService extends OrchestratorRunService {
  _MatrixOrchestratorRunService({super.stepService, super.sleep})
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

class _StageFaultStepService extends OrchestratorStepService {
  _StageFaultStepService({required this.stage});

  final String stage;
  var _call = 0;

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
    if (_call == 0) {
      _call += 1;
      throw TransientError('Injected crash after $stage boundary');
    }
    _call += 1;
    return _stepResult(
      executedCycle: true,
      plannedTasksAdded: 0,
      reviewDecision: 'approve',
      autoMarkedDone: true,
    );
  }
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

class _BlockingStepService extends OrchestratorStepService {
  _BlockingStepService({required this.entered, required this.release});

  final Completer<void> entered;
  final Completer<void> release;

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
    if (!entered.isCompleted) {
      entered.complete();
    }
    await release.future;
    return _stepResult(executedCycle: false, plannedTasksAdded: 0);
  }
}

class _StepCase {
  _StepCase.result(this.result);

  final OrchestratorStepResult result;
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
