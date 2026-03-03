import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';

import 'support/fake_genaisys_api.dart';

const _healthSnapshot = AppHealthSnapshotDto(
  agent: AppHealthCheckDto(ok: true, message: 'Agent ok'),
  allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ok'),
  git: AppHealthCheckDto(ok: true, message: 'Git ok'),
  review: AppHealthCheckDto(ok: true, message: 'Review ok'),
);

const _telemetrySnapshot = AppRunTelemetryDto(
  recentEvents: [],
  errorClass: null,
  errorKind: null,
  errorMessage: null,
  agentExitCode: null,
  agentStderrExcerpt: null,
  lastErrorEvent: null,
);

const _statusDto = AppStatusSnapshotDto(
  projectRoot: '/tmp/project',
  tasksTotal: 3,
  tasksOpen: 2,
  tasksDone: 1,
  tasksBlocked: 0,
  activeTaskTitle: 'Alpha',
  activeTaskId: 'alpha-1',
  reviewStatus: 'approved',
  reviewUpdatedAt: '2024-01-01T00:00:00Z',
  cycleCount: 2,
  lastUpdated: '2024-01-02T00:00:00Z',
  workflowStage: 'coding',
  health: _healthSnapshot,
  telemetry: _telemetrySnapshot,
);

const _reviewStatusDto = AppReviewStatusDto(
  status: 'approved',
  updatedAt: '2024-01-01T00:00:00Z',
);

const _taskDto = AppTaskDto(
  id: 'alpha-1',
  title: 'Alpha',
  section: 'Backlog',
  priority: 'p1',
  category: 'core',
  status: AppTaskStatus.open,
);

const _taskListDto = AppTaskListDto(total: 1, tasks: [_taskDto]);

void main() {
  group('Dashboard use cases', () {
    test('GetStatusUseCase delegates to GenaisysApi.getStatus', () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      fakeApi.getStatusHandler = (projectRoot) {
        lastProjectRoot = projectRoot;
        return Future.value(AppResult.success(_statusDto));
      };

      final useCase = GetStatusUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(lastProjectRoot, '/tmp/project');
      expect(result.ok, isTrue);
      expect(result.data!.workflowStage, 'coding');
    });

    test('GetStatusUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.getStatusHandler = (_) {
        return Future.value(
          AppResult.failure(AppError.invalidInput('Bad status request')),
        );
      };

      final useCase = GetStatusUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.invalidInput);
      expect(result.error?.code, 'invalid_input');
    });

    test(
      'GetDashboardUseCase delegates to GenaisysApi.getDashboard',
      () async {
        final fakeApi = FakeGenaisysApi();
        String? lastProjectRoot;
        fakeApi.getDashboardHandler = (projectRoot) {
          lastProjectRoot = projectRoot;
          return Future.value(
            AppResult.success(
              const AppDashboardDto(
                status: _statusDto,
                review: _reviewStatusDto,
              ),
            ),
          );
        };

        final useCase = GetDashboardUseCase(api: fakeApi);
        final result = await useCase.run('/tmp/project');

        expect(lastProjectRoot, '/tmp/project');
        expect(result.ok, isTrue);
        expect(result.data!.status.tasksTotal, 3);
        expect(result.data!.review.status, 'approved');
      },
    );

    test('GetDashboardUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.getDashboardHandler = (_) {
        return Future.value(
          AppResult.failure(AppError.notFound('Missing dashboard')),
        );
      };

      final useCase = GetDashboardUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.notFound);
      expect(result.error?.code, 'not_found');
    });
  });

  group('Project setup use cases', () {
    test(
      'InitializeProjectUseCase delegates to GenaisysApi.initializeProject',
      () async {
        final fakeApi = FakeGenaisysApi();
        String? lastProjectRoot;
        bool? lastOverwrite;
        fakeApi.initializeProjectHandler = (projectRoot, {overwrite = false}) {
          lastProjectRoot = projectRoot;
          lastOverwrite = overwrite;
          return Future.value(
            AppResult.success(
              const ProjectInitializationDto(
                initialized: true,
                genaisysDir: '/tmp/project/.genaisys',
              ),
            ),
          );
        };

        final useCase = InitializeProjectUseCase(api: fakeApi);
        final result = await useCase.run('/tmp/project', overwrite: true);

        expect(lastProjectRoot, '/tmp/project');
        expect(lastOverwrite, isTrue);
        expect(result.ok, isTrue);
        expect(result.data!.initialized, isTrue);
      },
    );

    test(
      'InitializeProjectUseCase returns failure from GenaisysApi',
      () async {
        final fakeApi = FakeGenaisysApi();
        fakeApi.initializeProjectHandler = (projectRoot, {overwrite = false}) {
          return Future.value(
            AppResult.failure(AppError.conflict('Already initialized')),
          );
        };

        final useCase = InitializeProjectUseCase(api: fakeApi);
        final result = await useCase.run('/tmp/project');

        expect(result.ok, isFalse);
        expect(result.error?.kind, AppErrorKind.conflict);
        expect(result.error?.code, 'conflict');
      },
    );

    test(
      'InitializeSpecArtifactsUseCase delegates to spec init endpoints',
      () async {
        final fakeApi = FakeGenaisysApi();
        String? planRoot;
        String? specRoot;
        String? subtasksRoot;
        bool? planOverwrite;
        bool? specOverwrite;
        bool? subtasksOverwrite;

        fakeApi.initializePlanHandler = (projectRoot, {overwrite = false}) {
          planRoot = projectRoot;
          planOverwrite = overwrite;
          return Future.value(
            AppResult.success(
              const SpecInitializationDto(created: true, path: '/tmp/plan.md'),
            ),
          );
        };
        fakeApi.initializeSpecHandler = (projectRoot, {overwrite = false}) {
          specRoot = projectRoot;
          specOverwrite = overwrite;
          return Future.value(
            AppResult.success(
              const SpecInitializationDto(created: true, path: '/tmp/spec.md'),
            ),
          );
        };
        fakeApi.initializeSubtasksHandler = (projectRoot, {overwrite = false}) {
          subtasksRoot = projectRoot;
          subtasksOverwrite = overwrite;
          return Future.value(
            AppResult.success(
              const SpecInitializationDto(
                created: true,
                path: '/tmp/subtasks.md',
              ),
            ),
          );
        };

        final useCase = InitializeSpecArtifactsUseCase(api: fakeApi);
        final plan = await useCase.initializePlan(
          '/tmp/project',
          overwrite: true,
        );
        final spec = await useCase.initializeSpec('/tmp/project');
        final subtasks = await useCase.initializeSubtasks(
          '/tmp/project',
          overwrite: true,
        );

        expect(plan.ok, isTrue);
        expect(spec.ok, isTrue);
        expect(subtasks.ok, isTrue);
        expect(planRoot, '/tmp/project');
        expect(specRoot, '/tmp/project');
        expect(subtasksRoot, '/tmp/project');
        expect(planOverwrite, isTrue);
        expect(specOverwrite, isFalse);
        expect(subtasksOverwrite, isTrue);
      },
    );

    test(
      'InitializeSpecArtifactsUseCase returns failure from GenaisysApi',
      () async {
        final fakeApi = FakeGenaisysApi();
        fakeApi.initializePlanHandler = (projectRoot, {overwrite = false}) {
          return Future.value(
            AppResult.failure(AppError.invalidInput('Bad plan input')),
          );
        };

        final useCase = InitializeSpecArtifactsUseCase(api: fakeApi);
        final result = await useCase.initializePlan('/tmp/project');

        expect(result.ok, isFalse);
        expect(result.error?.kind, AppErrorKind.invalidInput);
        expect(result.error?.code, 'invalid_input');
      },
    );
  });

  group('Review use cases', () {
    test('ManageReviewUseCase delegates review actions', () async {
      final fakeApi = FakeGenaisysApi();
      String? statusRoot;
      String? approveRoot;
      String? rejectRoot;
      String? clearRoot;
      String? approveNote;
      String? rejectNote;
      String? clearNote;

      fakeApi.getReviewStatusHandler = (projectRoot) {
        statusRoot = projectRoot;
        return Future.value(AppResult.success(_reviewStatusDto));
      };
      fakeApi.approveReviewHandler = (projectRoot, {note}) {
        approveRoot = projectRoot;
        approveNote = note;
        return Future.value(
          AppResult.success(
            const ReviewDecisionDto(
              reviewRecorded: true,
              decision: 'approved',
              taskTitle: 'Alpha',
              note: 'LGTM',
            ),
          ),
        );
      };
      fakeApi.rejectReviewHandler = (projectRoot, {note}) {
        rejectRoot = projectRoot;
        rejectNote = note;
        return Future.value(
          AppResult.success(
            const ReviewDecisionDto(
              reviewRecorded: true,
              decision: 'rejected',
              taskTitle: 'Alpha',
              note: 'Needs changes',
            ),
          ),
        );
      };
      fakeApi.clearReviewHandler = (projectRoot, {note}) {
        clearRoot = projectRoot;
        clearNote = note;
        return Future.value(
          AppResult.success(
            const ReviewClearDto(
              reviewCleared: true,
              reviewStatus: 'cleared',
              reviewUpdatedAt: '2024-01-02T00:00:00Z',
              note: 'reset',
            ),
          ),
        );
      };

      final useCase = ManageReviewUseCase(api: fakeApi);
      final status = await useCase.status('/tmp/project');
      final approve = await useCase.approve('/tmp/project', note: 'LGTM');
      final reject = await useCase.reject(
        '/tmp/project',
        note: 'Needs changes',
      );
      final clear = await useCase.clear('/tmp/project', note: 'reset');

      expect(status.ok, isTrue);
      expect(approve.ok, isTrue);
      expect(reject.ok, isTrue);
      expect(clear.ok, isTrue);
      expect(statusRoot, '/tmp/project');
      expect(approveRoot, '/tmp/project');
      expect(rejectRoot, '/tmp/project');
      expect(clearRoot, '/tmp/project');
      expect(approveNote, 'LGTM');
      expect(rejectNote, 'Needs changes');
      expect(clearNote, 'reset');
      expect(clear.data!.reviewStatus, 'cleared');
    });

    test('ManageReviewUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.rejectReviewHandler = (projectRoot, {note}) {
        return Future.value(
          AppResult.failure(AppError.preconditionFailed('No review to reject')),
        );
      };

      final useCase = ManageReviewUseCase(api: fakeApi);
      final result = await useCase.reject('/tmp/project', note: 'Nope');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.preconditionFailed);
      expect(result.error?.code, 'precondition_failed');
    });
  });

  group('Task action use cases', () {
    test('ManageTaskUseCase delegates task actions', () async {
      final fakeApi = FakeGenaisysApi();
      String? activateRoot;
      String? activateId;
      String? activateTitle;
      String? deactivateRoot;
      bool? deactivateKeepReview;
      String? doneRoot;
      String? blockRoot;
      String? blockReason;
      String? cycleRoot;
      String? cycleRunRoot;
      String? cycleRunPrompt;
      String? cycleRunTestSummary;
      bool? cycleRunOverwrite;

      fakeApi.activateTaskHandler = (projectRoot, {id, title}) {
        activateRoot = projectRoot;
        activateId = id;
        activateTitle = title;
        return Future.value(
          AppResult.success(
            const TaskActivationDto(activated: true, task: _taskDto),
          ),
        );
      };
      fakeApi.deactivateTaskHandler = (projectRoot, {keepReview = false}) {
        deactivateRoot = projectRoot;
        deactivateKeepReview = keepReview;
        return Future.value(
          AppResult.success(
            const TaskDeactivationDto(
              deactivated: true,
              keepReview: true,
              activeTaskTitle: null,
              activeTaskId: null,
              reviewStatus: 'approved',
              reviewUpdatedAt: '2024-01-01T00:00:00Z',
            ),
          ),
        );
      };
      fakeApi.markTaskDoneHandler = (projectRoot) {
        doneRoot = projectRoot;
        return Future.value(
          AppResult.success(const TaskDoneDto(done: true, taskTitle: 'Alpha')),
        );
      };
      fakeApi.blockTaskHandler = (projectRoot, {reason}) {
        blockRoot = projectRoot;
        blockReason = reason;
        return Future.value(
          AppResult.success(
            const TaskBlockedDto(
              blocked: true,
              taskTitle: 'Alpha',
              reason: 'Waiting',
            ),
          ),
        );
      };
      fakeApi.cycleHandler = (projectRoot) {
        cycleRoot = projectRoot;
        return Future.value(
          AppResult.success(
            const CycleTickDto(cycleUpdated: true, cycleCount: 2),
          ),
        );
      };
      fakeApi.runTaskCycleHandler =
          (
            projectRoot, {
            required String prompt,
            String? testSummary,
            bool overwrite = false,
          }) {
            cycleRunRoot = projectRoot;
            cycleRunPrompt = prompt;
            cycleRunTestSummary = testSummary;
            cycleRunOverwrite = overwrite;
            return Future.value(
              AppResult.success(
                const TaskCycleExecutionDto(
                  taskCycleCompleted: true,
                  reviewRecorded: true,
                  reviewDecision: 'approved',
                  codingOk: true,
                ),
              ),
            );
          };

      final useCase = ManageTaskUseCase(api: fakeApi);
      final activate = await useCase.activate(
        '/tmp/project',
        id: 'alpha-1',
        title: 'Alpha',
      );
      final deactivate = await useCase.deactivate(
        '/tmp/project',
        keepReview: true,
      );
      final done = await useCase.markDone('/tmp/project');
      final block = await useCase.block('/tmp/project', reason: 'Waiting');
      final cycle = await useCase.cycle('/tmp/project');
      final cycleRun = await useCase.runCycle(
        '/tmp/project',
        prompt: 'Implement',
        testSummary: 'All green',
        overwrite: true,
      );

      expect(activate.ok, isTrue);
      expect(deactivate.ok, isTrue);
      expect(done.ok, isTrue);
      expect(block.ok, isTrue);
      expect(cycle.ok, isTrue);
      expect(cycleRun.ok, isTrue);
      expect(activateRoot, '/tmp/project');
      expect(activateId, 'alpha-1');
      expect(activateTitle, 'Alpha');
      expect(deactivateRoot, '/tmp/project');
      expect(deactivateKeepReview, isTrue);
      expect(doneRoot, '/tmp/project');
      expect(blockRoot, '/tmp/project');
      expect(blockReason, 'Waiting');
      expect(cycleRoot, '/tmp/project');
      expect(cycleRunRoot, '/tmp/project');
      expect(cycleRunPrompt, 'Implement');
      expect(cycleRunTestSummary, 'All green');
      expect(cycleRunOverwrite, isTrue);
      expect(cycleRun.data!.reviewDecision, 'approved');
    });

    test('ManageTaskUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.activateTaskHandler = (projectRoot, {id, title}) {
        return Future.value(
          AppResult.failure(AppError.notFound('No task found')),
        );
      };

      final useCase = ManageTaskUseCase(api: fakeApi);
      final result = await useCase.activate('/tmp/project', id: 'missing');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.notFound);
      expect(result.error?.code, 'not_found');
    });
  });

  group('Task query use cases', () {
    test('ListTasksUseCase delegates to GenaisysApi.listTasks', () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      TaskListQuery? lastQuery;
      fakeApi.listTasksHandler =
          (projectRoot, {query = const TaskListQuery()}) {
            lastProjectRoot = projectRoot;
            lastQuery = query;
            return Future.value(AppResult.success(_taskListDto));
          };

      final useCase = ListTasksUseCase(api: fakeApi);
      final result = await useCase.run(
        '/tmp/project',
        query: const TaskListQuery(doneOnly: true),
      );

      expect(lastProjectRoot, '/tmp/project');
      expect(lastQuery?.doneOnly, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.tasks.single.id, 'alpha-1');
    });

    test('ListTasksUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.listTasksHandler =
          (projectRoot, {query = const TaskListQuery()}) {
            return Future.value(
              AppResult.failure(AppError.ioFailure('Disk error')),
            );
          };

      final useCase = ListTasksUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.ioFailure);
      expect(result.error?.code, 'io_failure');
    });

    test('GetNextTaskUseCase delegates to GenaisysApi.getNextTask', () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      String? lastSection;
      fakeApi.getNextTaskHandler = (projectRoot, {sectionFilter}) {
        lastProjectRoot = projectRoot;
        lastSection = sectionFilter;
        return Future.value(AppResult.success(_taskDto));
      };

      final useCase = GetNextTaskUseCase(api: fakeApi);
      final result = await useCase.run(
        '/tmp/project',
        sectionFilter: 'Backlog',
      );

      expect(lastProjectRoot, '/tmp/project');
      expect(lastSection, 'Backlog');
      expect(result.ok, isTrue);
      expect(result.data!.title, 'Alpha');
    });

    test('GetNextTaskUseCase returns failure from GenaisysApi', () async {
      final fakeApi = FakeGenaisysApi();
      fakeApi.getNextTaskHandler = (projectRoot, {sectionFilter}) {
        return Future.value(
          AppResult.failure(AppError.preconditionFailed('No tasks available')),
        );
      };

      final useCase = GetNextTaskUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error?.kind, AppErrorKind.preconditionFailed);
      expect(result.error?.code, 'precondition_failed');
    });
  });
}
