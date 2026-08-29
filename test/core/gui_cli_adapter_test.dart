import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_client.dart';
import 'package:genaisys/core/cli/cli_exit_status.dart';
import 'package:genaisys/core/legacy/gui_cli_adapter.dart';
import 'package:genaisys/core/cli/models/cli_models.dart';
import 'package:genaisys/core/models/workflow_stage.dart';

class FakeGuiCliClient extends CliClient {
  CliClientResult<CliInitResponse>? initResult;
  CliClientResult<CliStatusSnapshot>? statusResult;
  CliClientResult<CliTasksResponse>? tasksResult;
  CliClientResult<CliTaskItem>? nextResult;
  CliClientResult<CliReviewStatus>? reviewStatusResult;
  CliClientResult<CliActivateResponse>? activateResult;
  CliClientResult<CliDeactivateResponse>? deactivateResult;
  CliClientResult<CliReviewDecisionResponse>? approveResult;
  CliClientResult<CliReviewDecisionResponse>? rejectResult;
  CliClientResult<CliReviewClearResponse>? clearResult;
  CliClientResult<CliDoneResponse>? doneResult;
  CliClientResult<CliBlockResponse>? blockResult;
  CliClientResult<CliCycleResponse>? cycleResult;
  CliClientResult<CliCycleRunResponse>? cycleRunResult;
  CliClientResult<CliPlanInitResponse>? planInitResult;
  CliClientResult<CliSpecInitResponse>? specInitResult;
  CliClientResult<CliSubtasksInitResponse>? subtasksInitResult;

  String? lastInitRoot;
  bool? lastInitOverwrite;
  String? lastStatusRoot;
  String? lastTasksRoot;
  List<String>? lastTasksOptions;
  String? lastNextRoot;
  List<String>? lastNextOptions;
  String? lastReviewStatusRoot;
  String? lastActivateRoot;
  String? lastActivateId;
  String? lastActivateTitle;
  String? lastDeactivateRoot;
  bool? lastDeactivateKeepReview;
  String? lastApproveRoot;
  String? lastApproveNote;
  String? lastRejectRoot;
  String? lastRejectNote;
  String? lastClearRoot;
  String? lastClearNote;
  String? lastDoneRoot;
  String? lastBlockRoot;
  String? lastBlockReason;
  String? lastCycleRoot;
  String? lastCycleRunRoot;
  String? lastCycleRunPrompt;
  String? lastCycleRunTestSummary;
  bool? lastCycleRunOverwrite;
  String? lastPlanInitRoot;
  bool? lastPlanInitOverwrite;
  String? lastSpecInitRoot;
  bool? lastSpecInitOverwrite;
  String? lastSubtasksInitRoot;
  bool? lastSubtasksInitOverwrite;

  @override
  Future<CliClientResult<CliInitResponse>> initJson(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    lastInitRoot = projectRoot;
    lastInitOverwrite = overwrite;
    return initResult!;
  }

  @override
  Future<CliClientResult<CliStatusSnapshot>> status(String projectRoot) async {
    lastStatusRoot = projectRoot;
    return statusResult!;
  }

  @override
  Future<CliClientResult<CliTasksResponse>> tasks(
    String projectRoot, {
    List<String> options = const [],
  }) async {
    lastTasksRoot = projectRoot;
    lastTasksOptions = options;
    return tasksResult!;
  }

  @override
  Future<CliClientResult<CliTaskItem>> next(
    String projectRoot, {
    List<String> options = const [],
  }) async {
    lastNextRoot = projectRoot;
    lastNextOptions = options;
    return nextResult!;
  }

  @override
  Future<CliClientResult<CliReviewStatus>> reviewStatus(
    String projectRoot,
  ) async {
    lastReviewStatusRoot = projectRoot;
    return reviewStatusResult!;
  }

  @override
  Future<CliClientResult<CliActivateResponse>> activateJson(
    String projectRoot, {
    String? id,
    String? title,
  }) async {
    lastActivateRoot = projectRoot;
    lastActivateId = id;
    lastActivateTitle = title;
    return activateResult!;
  }

  @override
  Future<CliClientResult<CliDeactivateResponse>> deactivateJson(
    String projectRoot, {
    bool keepReview = false,
  }) async {
    lastDeactivateRoot = projectRoot;
    lastDeactivateKeepReview = keepReview;
    return deactivateResult!;
  }

  @override
  Future<CliClientResult<CliReviewDecisionResponse>> reviewApproveJson(
    String projectRoot, {
    String? note,
  }) async {
    lastApproveRoot = projectRoot;
    lastApproveNote = note;
    return approveResult!;
  }

  @override
  Future<CliClientResult<CliReviewDecisionResponse>> reviewRejectJson(
    String projectRoot, {
    String? note,
  }) async {
    lastRejectRoot = projectRoot;
    lastRejectNote = note;
    return rejectResult!;
  }

  @override
  Future<CliClientResult<CliReviewClearResponse>> reviewClearJson(
    String projectRoot, {
    String? note,
  }) async {
    lastClearRoot = projectRoot;
    lastClearNote = note;
    return clearResult!;
  }

  @override
  Future<CliClientResult<CliDoneResponse>> doneJson(String projectRoot) async {
    lastDoneRoot = projectRoot;
    return doneResult!;
  }

  @override
  Future<CliClientResult<CliBlockResponse>> blockJson(
    String projectRoot, {
    String? reason,
  }) async {
    lastBlockRoot = projectRoot;
    lastBlockReason = reason;
    return blockResult!;
  }

  @override
  Future<CliClientResult<CliCycleResponse>> cycleJson(
    String projectRoot,
  ) async {
    lastCycleRoot = projectRoot;
    return cycleResult!;
  }

  @override
  Future<CliClientResult<CliCycleRunResponse>> cycleRunJson(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) async {
    lastCycleRunRoot = projectRoot;
    lastCycleRunPrompt = prompt;
    lastCycleRunTestSummary = testSummary;
    lastCycleRunOverwrite = overwrite;
    return cycleRunResult!;
  }

  @override
  Future<CliClientResult<CliPlanInitResponse>> planInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    lastPlanInitRoot = projectRoot;
    lastPlanInitOverwrite = overwrite;
    return planInitResult!;
  }

  @override
  Future<CliClientResult<CliSpecInitResponse>> specInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    lastSpecInitRoot = projectRoot;
    lastSpecInitOverwrite = overwrite;
    return specInitResult!;
  }

  @override
  Future<CliClientResult<CliSubtasksInitResponse>> subtasksInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) async {
    lastSubtasksInitRoot = projectRoot;
    lastSubtasksInitOverwrite = overwrite;
    return subtasksInitResult!;
  }
}

CliClientResult<T> _success<T>(T data) {
  return CliClientResult<T>(
    status: CliExitStatus.success,
    stdout: '',
    stderr: '',
    data: data,
    error: null,
  );
}

CliClientResult<T> _failure<T>(
  CliExitStatus status, {
  required CliErrorResponse error,
  String stdout = '',
  String stderr = '',
}) {
  return CliClientResult<T>(
    status: status,
    stdout: stdout,
    stderr: stderr,
    data: null,
    error: error,
  );
}

void main() {
  test(
    'GuiCliAdapter.initializeProject delegates to CliClient.initJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.initResult = _success(
        CliInitResponse(
          initialized: true,
          genaisysDir: '/tmp/project/.genaisys',
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.initializeProject(
        '/tmp/project',
        overwrite: true,
      );

      expect(fakeClient.lastInitRoot, '/tmp/project');
      expect(fakeClient.lastInitOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.initialized, isTrue);
      expect(result.data!.genaisysDir, '/tmp/project/.genaisys');
    },
  );

  test('GuiCliAdapter.loadStatus delegates to CliClient.status', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.statusResult = _success(
      CliStatusSnapshot(
        projectRoot: '/tmp/project',
        tasksTotal: 1,
        tasksOpen: 1,
        tasksBlocked: 0,
        tasksDone: 0,
        activeTask: '(none)',
        activeTaskId: '(none)',
        reviewStatus: '(none)',
        reviewUpdatedAt: '(none)',
        workflowStage: WorkflowStage.idle,
        cycleCount: 0,
        lastUpdated: '2026-02-04T00:00:00Z',
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadStatus('/tmp/project');

    expect(fakeClient.lastStatusRoot, '/tmp/project');
    expect(result.ok, isTrue);
    expect(result.data!.projectRoot, '/tmp/project');
  });

  test('GuiCliAdapter.loadTasks delegates options', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.tasksResult = _success(
      CliTasksResponse(
        tasks: [
          CliTaskItem(
            id: 'alpha-1',
            title: 'Alpha',
            section: 'Backlog',
            priority: 'p1',
            category: 'core',
            status: CliTaskStatus.open,
          ),
        ],
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadTasks('/tmp/project', options: ['--open']);

    expect(fakeClient.lastTasksRoot, '/tmp/project');
    expect(fakeClient.lastTasksOptions, ['--open']);
    expect(result.ok, isTrue);
    expect(result.data!.tasks.single.id, 'alpha-1');
  });

  test('GuiCliAdapter.loadNextTask delegates options', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.nextResult = _success(
      CliTaskItem(
        id: 'alpha-1',
        title: 'Alpha',
        section: 'Backlog',
        priority: 'p1',
        category: 'core',
        status: CliTaskStatus.open,
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadNextTask(
      '/tmp/project',
      options: ['--section', 'Backlog'],
    );

    expect(fakeClient.lastNextRoot, '/tmp/project');
    expect(fakeClient.lastNextOptions, ['--section', 'Backlog']);
    expect(result.ok, isTrue);
    expect(result.data!.title, 'Alpha');
  });

  test(
    'GuiCliAdapter.loadReviewStatus delegates to CliClient.reviewStatus',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.reviewStatusResult = _success(
        CliReviewStatus(status: 'approved', updatedAt: '2026-02-04T00:00:00Z'),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.loadReviewStatus('/tmp/project');

      expect(fakeClient.lastReviewStatusRoot, '/tmp/project');
      expect(result.ok, isTrue);
      expect(result.data!.status, 'approved');
    },
  );

  test('GuiCliAdapter.loadDashboard combines status and review', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.statusResult = CliClientResult<CliStatusSnapshot>(
      status: CliExitStatus.success,
      stdout: 'status-out',
      stderr: 'status-err',
      data: CliStatusSnapshot(
        projectRoot: '/tmp/project',
        tasksTotal: 3,
        tasksOpen: 2,
        tasksBlocked: 1,
        tasksDone: 1,
        activeTask: 'Alpha',
        activeTaskId: 'alpha-1',
        reviewStatus: 'approved',
        reviewUpdatedAt: '2026-02-04T00:00:00Z',
        workflowStage: WorkflowStage.review,
        cycleCount: 5,
        lastUpdated: '2026-02-04T00:00:00Z',
      ),
      error: null,
    );
    fakeClient.reviewStatusResult = CliClientResult<CliReviewStatus>(
      status: CliExitStatus.success,
      stdout: 'review-out',
      stderr: 'review-err',
      data: CliReviewStatus(
        status: 'approved',
        updatedAt: '2026-02-04T00:00:00Z',
      ),
      error: null,
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadDashboard('/tmp/project');

    expect(fakeClient.lastStatusRoot, '/tmp/project');
    expect(fakeClient.lastReviewStatusRoot, '/tmp/project');
    expect(result.ok, isTrue);
    expect(result.data!.status.projectRoot, '/tmp/project');
    expect(result.data!.review.status, 'approved');
    expect(result.stdout, 'status-out\nreview-out');
    expect(result.stderr, 'status-err\nreview-err');
  });

  test('GuiCliAdapter.loadDashboard returns status error early', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.statusResult = _failure<CliStatusSnapshot>(
      CliExitStatus.stateError,
      error: CliErrorResponse(code: 'state_error', message: 'Missing state'),
      stderr: 'Missing state',
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadDashboard('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.error?.code, 'state_error');
    expect(fakeClient.lastStatusRoot, '/tmp/project');
    expect(fakeClient.lastReviewStatusRoot, isNull);
  });

  test('GuiCliAdapter.loadDashboard returns review error', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.statusResult = CliClientResult<CliStatusSnapshot>(
      status: CliExitStatus.success,
      stdout: 'status-out',
      stderr: 'status-err',
      data: CliStatusSnapshot(
        projectRoot: '/tmp/project',
        tasksTotal: 1,
        tasksOpen: 1,
        tasksBlocked: 0,
        tasksDone: 0,
        activeTask: '(none)',
        activeTaskId: '(none)',
        reviewStatus: '(none)',
        reviewUpdatedAt: '(none)',
        workflowStage: WorkflowStage.idle,
        cycleCount: 0,
        lastUpdated: '2026-02-04T00:00:00Z',
      ),
      error: null,
    );
    fakeClient.reviewStatusResult = _failure<CliReviewStatus>(
      CliExitStatus.stateError,
      error: CliErrorResponse(code: 'state_error', message: 'Missing review'),
      stdout: 'review-out',
      stderr: 'review-err',
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.loadDashboard('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.error?.code, 'state_error');
    expect(fakeClient.lastStatusRoot, '/tmp/project');
    expect(fakeClient.lastReviewStatusRoot, '/tmp/project');
    expect(result.stdout, 'status-out\nreview-out');
    expect(result.stderr, 'status-err\nreview-err');
  });

  test(
    'GuiCliAdapter.activateTask delegates to CliClient.activateJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.activateResult = _success(
        CliActivateResponse(
          activated: true,
          task: CliTaskItem(
            id: 'alpha-1',
            title: 'Alpha',
            section: 'Backlog',
            priority: 'p1',
            category: 'core',
            status: CliTaskStatus.open,
          ),
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.activateTask(
        '/tmp/project',
        id: 'alpha-1',
        title: null,
      );

      expect(fakeClient.lastActivateRoot, '/tmp/project');
      expect(fakeClient.lastActivateId, 'alpha-1');
      expect(fakeClient.lastActivateTitle, isNull);
      expect(result.ok, isTrue);
      expect(result.data!.activated, isTrue);
    },
  );

  test(
    'GuiCliAdapter.deactivateTask delegates to CliClient.deactivateJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.deactivateResult = _success(
        CliDeactivateResponse(
          deactivated: true,
          keepReview: true,
          activeTask: '(none)',
          activeTaskId: '(none)',
          reviewStatus: 'approved',
          reviewUpdatedAt: '2026-02-04T00:00:00Z',
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.deactivateTask(
        '/tmp/project',
        keepReview: true,
      );

      expect(fakeClient.lastDeactivateRoot, '/tmp/project');
      expect(fakeClient.lastDeactivateKeepReview, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.deactivated, isTrue);
    },
  );

  test('GuiCliAdapter.approveReview delegates note to CliClient', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.approveResult = _success(
      CliReviewDecisionResponse(
        reviewRecorded: true,
        decision: 'approved',
        taskTitle: 'Alpha',
        note: 'Looks good',
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.approveReview(
      '/tmp/project',
      note: 'Looks good',
    );

    expect(fakeClient.lastApproveRoot, '/tmp/project');
    expect(fakeClient.lastApproveNote, 'Looks good');
    expect(result.ok, isTrue);
    expect(result.data!.decision, 'approved');
  });

  test('GuiCliAdapter.rejectReview delegates note to CliClient', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.rejectResult = _success(
      CliReviewDecisionResponse(
        reviewRecorded: true,
        decision: 'rejected',
        taskTitle: 'Alpha',
        note: 'Still failing',
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.rejectReview(
      '/tmp/project',
      note: 'Still failing',
    );

    expect(fakeClient.lastRejectRoot, '/tmp/project');
    expect(fakeClient.lastRejectNote, 'Still failing');
    expect(result.ok, isTrue);
    expect(result.data!.decision, 'rejected');
  });

  test('GuiCliAdapter.clearReview delegates note to CliClient', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.clearResult = _success(
      CliReviewClearResponse(
        reviewCleared: true,
        reviewStatus: '(none)',
        reviewUpdatedAt: '2026-02-04T00:00:00Z',
        note: 'Reset',
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.clearReview('/tmp/project', note: 'Reset');

    expect(fakeClient.lastClearRoot, '/tmp/project');
    expect(fakeClient.lastClearNote, 'Reset');
    expect(result.ok, isTrue);
    expect(result.data!.reviewCleared, isTrue);
  });

  test('GuiCliAdapter.markTaskDone delegates to CliClient.doneJson', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.doneResult = _success(
      CliDoneResponse(done: true, taskTitle: 'Alpha'),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.markTaskDone('/tmp/project');

    expect(fakeClient.lastDoneRoot, '/tmp/project');
    expect(result.ok, isTrue);
    expect(result.data!.done, isTrue);
    expect(result.data!.taskTitle, 'Alpha');
  });

  test('GuiCliAdapter.blockTask delegates to CliClient.blockJson', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.blockResult = _success(
      CliBlockResponse(
        blocked: true,
        taskTitle: 'Alpha',
        reason: 'waiting on review',
      ),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.blockTask(
      '/tmp/project',
      reason: 'waiting on review',
    );

    expect(fakeClient.lastBlockRoot, '/tmp/project');
    expect(fakeClient.lastBlockReason, 'waiting on review');
    expect(result.ok, isTrue);
    expect(result.data!.blocked, isTrue);
    expect(result.data!.reason, 'waiting on review');
  });

  test('GuiCliAdapter.cycleTask delegates to CliClient.cycleJson', () async {
    final fakeClient = FakeGuiCliClient();
    fakeClient.cycleResult = _success(
      CliCycleResponse(cycleUpdated: true, cycleCount: 3),
    );
    final adapter = GuiCliAdapter(client: fakeClient);

    final result = await adapter.cycleTask('/tmp/project');

    expect(fakeClient.lastCycleRoot, '/tmp/project');
    expect(result.ok, isTrue);
    expect(result.data!.cycleUpdated, isTrue);
    expect(result.data!.cycleCount, 3);
  });

  test(
    'GuiCliAdapter.runTaskCycle delegates to CliClient.cycleRunJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.cycleRunResult = _success(
        CliCycleRunResponse(
          taskCycleCompleted: true,
          reviewRecorded: true,
          reviewDecision: 'approved',
          codingOk: true,
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.runTaskCycle(
        '/tmp/project',
        prompt: 'Implement task details',
        testSummary: 'all tests passed',
        overwrite: true,
      );

      expect(fakeClient.lastCycleRunRoot, '/tmp/project');
      expect(fakeClient.lastCycleRunPrompt, 'Implement task details');
      expect(fakeClient.lastCycleRunTestSummary, 'all tests passed');
      expect(fakeClient.lastCycleRunOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.taskCycleCompleted, isTrue);
      expect(result.data!.reviewRecorded, isTrue);
      expect(result.data!.reviewDecision, 'approved');
      expect(result.data!.codingOk, isTrue);
    },
  );

  test(
    'GuiCliAdapter.initializePlan delegates to CliClient.planInitJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.planInitResult = _success(
        CliPlanInitResponse(
          created: true,
          path: '/tmp/project/.genaisys/task_specs/task-1.plan.md',
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.initializePlan(
        '/tmp/project',
        overwrite: true,
      );

      expect(fakeClient.lastPlanInitRoot, '/tmp/project');
      expect(fakeClient.lastPlanInitOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.created, isTrue);
      expect(
        result.data!.path,
        '/tmp/project/.genaisys/task_specs/task-1.plan.md',
      );
    },
  );

  test(
    'GuiCliAdapter.initializeSpec delegates to CliClient.specInitJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.specInitResult = _success(
        CliSpecInitResponse(
          created: true,
          path: '/tmp/project/.genaisys/task_specs/task-1.spec.md',
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.initializeSpec(
        '/tmp/project',
        overwrite: true,
      );

      expect(fakeClient.lastSpecInitRoot, '/tmp/project');
      expect(fakeClient.lastSpecInitOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.created, isTrue);
      expect(
        result.data!.path,
        '/tmp/project/.genaisys/task_specs/task-1.spec.md',
      );
    },
  );

  test(
    'GuiCliAdapter.initializeSubtasks delegates to CliClient.subtasksInitJson',
    () async {
      final fakeClient = FakeGuiCliClient();
      fakeClient.subtasksInitResult = _success(
        CliSubtasksInitResponse(
          created: true,
          path: '/tmp/project/.genaisys/task_specs/task-1.subtasks.md',
        ),
      );
      final adapter = GuiCliAdapter(client: fakeClient);

      final result = await adapter.initializeSubtasks(
        '/tmp/project',
        overwrite: true,
      );

      expect(fakeClient.lastSubtasksInitRoot, '/tmp/project');
      expect(fakeClient.lastSubtasksInitOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.created, isTrue);
      expect(
        result.data!.path,
        '/tmp/project/.genaisys/task_specs/task-1.subtasks.md',
      );
    },
  );

  test('GuiCliAdapter.classifyError maps known and unknown errors', () {
    final adapter = GuiCliAdapter(client: FakeGuiCliClient());

    final known = adapter.classifyError(
      CliErrorResponse(code: 'state_error', message: 'State mismatch'),
    );
    final unknown = adapter.classifyError(
      CliErrorResponse(code: 'unexpected_code', message: 'Unexpected'),
    );

    expect(known.name, 'stateError');
    expect(unknown.name, 'unknown');
  });
}
