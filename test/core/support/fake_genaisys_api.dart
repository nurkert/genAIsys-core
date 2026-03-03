import 'package:genaisys/core/app/app.dart';

typedef InitProjectHandler =
    Future<AppResult<ProjectInitializationDto>> Function(
      String projectRoot, {
      bool overwrite,
    });
typedef StatusHandler =
    Future<AppResult<AppStatusSnapshotDto>> Function(String projectRoot);
typedef ListTasksHandler =
    Future<AppResult<AppTaskListDto>> Function(
      String projectRoot, {
      TaskListQuery query,
    });
typedef NextTaskHandler =
    Future<AppResult<AppTaskDto?>> Function(
      String projectRoot, {
      String? sectionFilter,
    });
typedef ReviewStatusHandler =
    Future<AppResult<AppReviewStatusDto>> Function(String projectRoot);
typedef DashboardHandler =
    Future<AppResult<AppDashboardDto>> Function(String projectRoot);
typedef GetConfigHandler =
    Future<AppResult<AppConfigDto>> Function(String projectRoot);
typedef UpdateConfigHandler =
    Future<AppResult<ConfigUpdateDto>> Function(
      String projectRoot, {
      required AppConfigDto config,
    });
typedef ActivateHandler =
    Future<AppResult<TaskActivationDto>> Function(
      String projectRoot, {
      String? id,
      String? title,
    });
typedef DeactivateHandler =
    Future<AppResult<TaskDeactivationDto>> Function(
      String projectRoot, {
      bool keepReview,
    });
typedef ReviewDecisionHandler =
    Future<AppResult<ReviewDecisionDto>> Function(
      String projectRoot, {
      String? note,
    });
typedef ReviewClearHandler =
    Future<AppResult<ReviewClearDto>> Function(
      String projectRoot, {
      String? note,
    });
typedef DoneHandler =
    Future<AppResult<TaskDoneDto>> Function(String projectRoot);
typedef BlockHandler =
    Future<AppResult<TaskBlockedDto>> Function(
      String projectRoot, {
      String? reason,
    });
typedef CreateTaskHandler =
    Future<AppResult<TaskCreateDto>> Function(
      String projectRoot, {
      required String title,
      required AppTaskPriority priority,
      required AppTaskCategory category,
      String? section,
    });
typedef UpdatePriorityHandler =
    Future<AppResult<TaskPriorityUpdateDto>> Function(
      String projectRoot, {
      String? id,
      String? title,
      required AppTaskPriority priority,
    });
typedef MoveSectionHandler =
    Future<AppResult<TaskMoveSectionDto>> Function(
      String projectRoot, {
      String? id,
      String? title,
      required String section,
    });
typedef DeleteTaskHandler =
    Future<AppResult<TaskDeleteDto>> Function(
      String projectRoot, {
      String? id,
      String? title,
    });
typedef RefineTaskHandler =
    Future<AppResult<TaskRefinementDto>> Function(
      String projectRoot, {
      required String title,
      bool overwrite,
    });
typedef CycleHandler =
    Future<AppResult<CycleTickDto>> Function(String projectRoot);
typedef RunCycleHandler =
    Future<AppResult<TaskCycleExecutionDto>> Function(
      String projectRoot, {
      required String prompt,
      String? testSummary,
      bool overwrite,
    });
typedef SpecInitHandler =
    Future<AppResult<SpecInitializationDto>> Function(
      String projectRoot, {
      bool overwrite,
    });

class FakeGenaisysApi implements GenaisysApi {
  InitProjectHandler? initializeProjectHandler;
  // Captures the last fromSource / staticMode values passed to initializeProject
  // so tests can assert on them without needing to update the handler typedef.
  String? lastInitFromSource;
  bool lastInitStaticMode = false;
  StatusHandler? getStatusHandler;
  ListTasksHandler? listTasksHandler;
  NextTaskHandler? getNextTaskHandler;
  ReviewStatusHandler? getReviewStatusHandler;
  DashboardHandler? getDashboardHandler;
  GetConfigHandler? getConfigHandler;
  UpdateConfigHandler? updateConfigHandler;
  ActivateHandler? activateTaskHandler;
  DeactivateHandler? deactivateTaskHandler;
  ReviewDecisionHandler? approveReviewHandler;
  ReviewDecisionHandler? rejectReviewHandler;
  ReviewClearHandler? clearReviewHandler;
  DoneHandler? markTaskDoneHandler;
  BlockHandler? blockTaskHandler;
  CreateTaskHandler? createTaskHandler;
  UpdatePriorityHandler? updateTaskPriorityHandler;
  MoveSectionHandler? moveTaskSectionHandler;
  DeleteTaskHandler? deleteTaskHandler;
  RefineTaskHandler? refineTaskHandler;
  CycleHandler? cycleHandler;
  RunCycleHandler? runTaskCycleHandler;
  SpecInitHandler? initializePlanHandler;
  SpecInitHandler? initializeSpecHandler;
  SpecInitHandler? initializeSubtasksHandler;
  Future<AppResult<HitlGateDto>> Function(String projectRoot)? getHitlGateHandler;
  Future<AppResult<void>> Function(
    String projectRoot, {
    required String decision,
    String? note,
  })? submitHitlDecisionHandler;

  @override
  Future<AppResult<ProjectInitializationDto>> initializeProject(
    String projectRoot, {
    bool overwrite = false,
    String? fromSource,
    bool staticMode = false,
    int? sprintSize,
  }) {
    lastInitFromSource = fromSource;
    lastInitStaticMode = staticMode;
    final handler = initializeProjectHandler;
    if (handler == null) {
      throw UnimplementedError('initializeProjectHandler not configured');
    }
    return handler(projectRoot, overwrite: overwrite);
  }

  @override
  Future<AppResult<AppStatusSnapshotDto>> getStatus(String projectRoot) {
    final handler = getStatusHandler;
    if (handler == null) {
      throw UnimplementedError('getStatusHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<AppTaskListDto>> listTasks(
    String projectRoot, {
    TaskListQuery query = const TaskListQuery(),
  }) {
    final handler = listTasksHandler;
    if (handler == null) {
      throw UnimplementedError('listTasksHandler not configured');
    }
    return handler(projectRoot, query: query);
  }

  @override
  Future<AppResult<AppTaskDto?>> getNextTask(
    String projectRoot, {
    String? sectionFilter,
  }) {
    final handler = getNextTaskHandler;
    if (handler == null) {
      throw UnimplementedError('getNextTaskHandler not configured');
    }
    return handler(projectRoot, sectionFilter: sectionFilter);
  }

  @override
  Future<AppResult<AppReviewStatusDto>> getReviewStatus(String projectRoot) {
    final handler = getReviewStatusHandler;
    if (handler == null) {
      throw UnimplementedError('getReviewStatusHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<AppDashboardDto>> getDashboard(String projectRoot) {
    final handler = getDashboardHandler;
    if (handler == null) {
      throw UnimplementedError('getDashboardHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<AppConfigDto>> getConfig(String projectRoot) {
    final handler = getConfigHandler;
    if (handler == null) {
      throw UnimplementedError('getConfigHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<ConfigUpdateDto>> updateConfig(
    String projectRoot, {
    required AppConfigDto config,
  }) {
    final handler = updateConfigHandler;
    if (handler == null) {
      throw UnimplementedError('updateConfigHandler not configured');
    }
    return handler(projectRoot, config: config);
  }

  @override
  Future<AppResult<TaskActivationDto>> activateTask(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    final handler = activateTaskHandler;
    if (handler == null) {
      throw UnimplementedError('activateTaskHandler not configured');
    }
    return handler(projectRoot, id: id, title: title);
  }

  @override
  Future<AppResult<TaskDeactivationDto>> deactivateTask(
    String projectRoot, {
    bool keepReview = false,
  }) {
    final handler = deactivateTaskHandler;
    if (handler == null) {
      throw UnimplementedError('deactivateTaskHandler not configured');
    }
    return handler(projectRoot, keepReview: keepReview);
  }

  @override
  Future<AppResult<ReviewDecisionDto>> approveReview(
    String projectRoot, {
    String? note,
  }) {
    final handler = approveReviewHandler;
    if (handler == null) {
      throw UnimplementedError('approveReviewHandler not configured');
    }
    return handler(projectRoot, note: note);
  }

  @override
  Future<AppResult<ReviewDecisionDto>> rejectReview(
    String projectRoot, {
    String? note,
  }) {
    final handler = rejectReviewHandler;
    if (handler == null) {
      throw UnimplementedError('rejectReviewHandler not configured');
    }
    return handler(projectRoot, note: note);
  }

  @override
  Future<AppResult<ReviewClearDto>> clearReview(
    String projectRoot, {
    String? note,
  }) {
    final handler = clearReviewHandler;
    if (handler == null) {
      throw UnimplementedError('clearReviewHandler not configured');
    }
    return handler(projectRoot, note: note);
  }

  @override
  Future<AppResult<TaskDoneDto>> markTaskDone(
    String projectRoot, {
    bool force = false,
  }) {
    final handler = markTaskDoneHandler;
    if (handler == null) {
      throw UnimplementedError('markTaskDoneHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<TaskBlockedDto>> blockTask(
    String projectRoot, {
    String? reason,
  }) {
    final handler = blockTaskHandler;
    if (handler == null) {
      throw UnimplementedError('blockTaskHandler not configured');
    }
    return handler(projectRoot, reason: reason);
  }

  @override
  Future<AppResult<TaskCreateDto>> createTask(
    String projectRoot, {
    required String title,
    required AppTaskPriority priority,
    required AppTaskCategory category,
    String? section,
  }) {
    final handler = createTaskHandler;
    if (handler == null) {
      throw UnimplementedError('createTaskHandler not configured');
    }
    return handler(
      projectRoot,
      title: title,
      priority: priority,
      category: category,
      section: section,
    );
  }

  @override
  Future<AppResult<TaskPriorityUpdateDto>> updateTaskPriority(
    String projectRoot, {
    String? id,
    String? title,
    required AppTaskPriority priority,
  }) {
    final handler = updateTaskPriorityHandler;
    if (handler == null) {
      throw UnimplementedError('updateTaskPriorityHandler not configured');
    }
    return handler(projectRoot, id: id, title: title, priority: priority);
  }

  @override
  Future<AppResult<TaskMoveSectionDto>> moveTaskSection(
    String projectRoot, {
    String? id,
    String? title,
    required String section,
  }) {
    final handler = moveTaskSectionHandler;
    if (handler == null) {
      throw UnimplementedError('moveTaskSectionHandler not configured');
    }
    return handler(projectRoot, id: id, title: title, section: section);
  }

  @override
  Future<AppResult<TaskDeleteDto>> deleteTask(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    final handler = deleteTaskHandler;
    if (handler == null) {
      throw UnimplementedError('deleteTaskHandler not configured');
    }
    return handler(projectRoot, id: id, title: title);
  }

  @override
  Future<AppResult<TaskRefinementDto>> refineTask(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  }) {
    final handler = refineTaskHandler;
    if (handler == null) {
      throw UnimplementedError('refineTaskHandler not configured');
    }
    return handler(projectRoot, title: title, overwrite: overwrite);
  }

  @override
  Future<AppResult<CycleTickDto>> cycle(String projectRoot) {
    final handler = cycleHandler;
    if (handler == null) {
      throw UnimplementedError('cycleHandler not configured');
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<TaskCycleExecutionDto>> runTaskCycle(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    final handler = runTaskCycleHandler;
    if (handler == null) {
      throw UnimplementedError('runTaskCycleHandler not configured');
    }
    return handler(
      projectRoot,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
    );
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializePlan(
    String projectRoot, {
    bool overwrite = false,
  }) {
    final handler = initializePlanHandler;
    if (handler == null) {
      throw UnimplementedError('initializePlanHandler not configured');
    }
    return handler(projectRoot, overwrite: overwrite);
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializeSpec(
    String projectRoot, {
    bool overwrite = false,
  }) {
    final handler = initializeSpecHandler;
    if (handler == null) {
      throw UnimplementedError('initializeSpecHandler not configured');
    }
    return handler(projectRoot, overwrite: overwrite);
  }

  @override
  Future<AppResult<SpecInitializationDto>> initializeSubtasks(
    String projectRoot, {
    bool overwrite = false,
  }) {
    final handler = initializeSubtasksHandler;
    if (handler == null) {
      throw UnimplementedError('initializeSubtasksHandler not configured');
    }
    return handler(projectRoot, overwrite: overwrite);
  }

  @override
  Future<AppResult<HitlGateDto>> getHitlGate(String projectRoot) {
    final handler = getHitlGateHandler;
    if (handler == null) {
      return Future.value(
        AppResult.success(const HitlGateDto(pending: false)),
      );
    }
    return handler(projectRoot);
  }

  @override
  Future<AppResult<void>> submitHitlDecision(
    String projectRoot, {
    required String decision,
    String? note,
  }) {
    final handler = submitHitlDecisionHandler;
    if (handler == null) {
      throw UnimplementedError('submitHitlDecisionHandler not configured');
    }
    return handler(projectRoot, decision: decision, note: note);
  }
}
