// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';
import '../models/workspace_models.dart';
import 'autopilot_controller.dart';
import 'background_api_runner.dart';
import 'project_config_controller.dart';
import 'review_controller.dart';
import 'task_controller.dart';

/// Editable subset of project-level config values exposed in the workspace UI.
@immutable
class ProjectSettingsDraft {
  ProjectSettingsDraft({
    required this.gitBaseBranch,
    required this.gitFeaturePrefix,
    required this.gitAutoStash,
    required this.safeWriteEnabled,
    required List<String> safeWriteRoots,
    required List<String> shellAllowlist,
    required this.shellAllowlistProfile,
    required this.diffBudgetMaxFiles,
    required this.diffBudgetMaxAdditions,
    required this.diffBudgetMaxDeletions,
    required this.autopilotMinOpenTasks,
    required this.autopilotMaxPlanAdd,
    required this.autopilotStepSleepSeconds,
    required this.autopilotIdleSleepSeconds,
    required this.autopilotMaxSteps,
    required this.autopilotMaxFailures,
    required this.autopilotMaxTaskRetries,
    required this.autopilotSelectionMode,
    required this.autopilotFairnessWindow,
    required this.autopilotPriorityWeightP1,
    required this.autopilotPriorityWeightP2,
    required this.autopilotPriorityWeightP3,
    required this.autopilotReactivateBlocked,
    required this.autopilotReactivateFailed,
    required this.autopilotBlockedCooldownSeconds,
    required this.autopilotFailedCooldownSeconds,
    required this.autopilotLockTtlSeconds,
    required this.autopilotNoProgressThreshold,
    required this.autopilotStuckCooldownSeconds,
    required this.autopilotSelfRestart,
    required this.autopilotScopeMaxFiles,
    required this.autopilotScopeMaxAdditions,
    required this.autopilotScopeMaxDeletions,
    required this.autopilotApproveBudget,
    required this.autopilotManualOverride,
    required this.autopilotOvernightUnattendedEnabled,
    required this.autopilotSelfTuneEnabled,
    required this.autopilotSelfTuneWindow,
    required this.autopilotSelfTuneMinSamples,
    required this.autopilotSelfTuneSuccessPercent,
  }) : safeWriteRoots = List<String>.unmodifiable(safeWriteRoots),
       shellAllowlist = List<String>.unmodifiable(shellAllowlist);

  factory ProjectSettingsDraft.fromConfig(AppConfigDto config) {
    return ProjectSettingsDraft(
      gitBaseBranch: config.gitBaseBranch,
      gitFeaturePrefix: config.gitFeaturePrefix,
      gitAutoStash: config.gitAutoStash,
      safeWriteEnabled: config.safeWriteEnabled,
      safeWriteRoots: config.safeWriteRoots,
      shellAllowlist: config.shellAllowlist,
      shellAllowlistProfile: config.shellAllowlistProfile,
      diffBudgetMaxFiles: config.diffBudgetMaxFiles,
      diffBudgetMaxAdditions: config.diffBudgetMaxAdditions,
      diffBudgetMaxDeletions: config.diffBudgetMaxDeletions,
      autopilotMinOpenTasks: config.autopilotMinOpenTasks,
      autopilotMaxPlanAdd: config.autopilotMaxPlanAdd,
      autopilotStepSleepSeconds: config.autopilotStepSleepSeconds,
      autopilotIdleSleepSeconds: config.autopilotIdleSleepSeconds,
      autopilotMaxSteps: config.autopilotMaxSteps,
      autopilotMaxFailures: config.autopilotMaxFailures,
      autopilotMaxTaskRetries: config.autopilotMaxTaskRetries,
      autopilotSelectionMode: config.autopilotSelectionMode,
      autopilotFairnessWindow: config.autopilotFairnessWindow,
      autopilotPriorityWeightP1: config.autopilotPriorityWeightP1,
      autopilotPriorityWeightP2: config.autopilotPriorityWeightP2,
      autopilotPriorityWeightP3: config.autopilotPriorityWeightP3,
      autopilotReactivateBlocked: config.autopilotReactivateBlocked,
      autopilotReactivateFailed: config.autopilotReactivateFailed,
      autopilotBlockedCooldownSeconds: config.autopilotBlockedCooldownSeconds,
      autopilotFailedCooldownSeconds: config.autopilotFailedCooldownSeconds,
      autopilotLockTtlSeconds: config.autopilotLockTtlSeconds,
      autopilotNoProgressThreshold: config.autopilotNoProgressThreshold,
      autopilotStuckCooldownSeconds: config.autopilotStuckCooldownSeconds,
      autopilotSelfRestart: config.autopilotSelfRestart,
      autopilotScopeMaxFiles: config.autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions: config.autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions: config.autopilotScopeMaxDeletions,
      autopilotApproveBudget: config.autopilotApproveBudget,
      autopilotManualOverride: config.autopilotManualOverride,
      autopilotOvernightUnattendedEnabled:
          config.autopilotOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled: config.autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow: config.autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples: config.autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent: config.autopilotSelfTuneSuccessPercent,
    );
  }

  AppConfigDto toConfig() {
    return AppConfigDto(
      gitBaseBranch: gitBaseBranch.trim(),
      gitFeaturePrefix: gitFeaturePrefix.trim(),
      gitAutoStash: gitAutoStash,
      safeWriteEnabled: safeWriteEnabled,
      safeWriteRoots: safeWriteRoots,
      shellAllowlist: shellAllowlist,
      shellAllowlistProfile: shellAllowlistProfile.trim(),
      diffBudgetMaxFiles: diffBudgetMaxFiles,
      diffBudgetMaxAdditions: diffBudgetMaxAdditions,
      diffBudgetMaxDeletions: diffBudgetMaxDeletions,
      autopilotMinOpenTasks: autopilotMinOpenTasks,
      autopilotMaxPlanAdd: autopilotMaxPlanAdd,
      autopilotStepSleepSeconds: autopilotStepSleepSeconds,
      autopilotIdleSleepSeconds: autopilotIdleSleepSeconds,
      autopilotMaxSteps: autopilotMaxSteps,
      autopilotMaxFailures: autopilotMaxFailures,
      autopilotMaxTaskRetries: autopilotMaxTaskRetries,
      autopilotSelectionMode: autopilotSelectionMode.trim(),
      autopilotFairnessWindow: autopilotFairnessWindow,
      autopilotPriorityWeightP1: autopilotPriorityWeightP1,
      autopilotPriorityWeightP2: autopilotPriorityWeightP2,
      autopilotPriorityWeightP3: autopilotPriorityWeightP3,
      autopilotReactivateBlocked: autopilotReactivateBlocked,
      autopilotReactivateFailed: autopilotReactivateFailed,
      autopilotBlockedCooldownSeconds: autopilotBlockedCooldownSeconds,
      autopilotFailedCooldownSeconds: autopilotFailedCooldownSeconds,
      autopilotLockTtlSeconds: autopilotLockTtlSeconds,
      autopilotNoProgressThreshold: autopilotNoProgressThreshold,
      autopilotStuckCooldownSeconds: autopilotStuckCooldownSeconds,
      autopilotSelfRestart: autopilotSelfRestart,
      autopilotScopeMaxFiles: autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions: autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions: autopilotScopeMaxDeletions,
      autopilotApproveBudget: autopilotApproveBudget,
      autopilotManualOverride: autopilotManualOverride,
      autopilotOvernightUnattendedEnabled: autopilotOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled: autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow: autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples: autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent: autopilotSelfTuneSuccessPercent,
    );
  }

  final String gitBaseBranch;
  final String gitFeaturePrefix;
  final bool gitAutoStash;
  final bool safeWriteEnabled;
  final List<String> safeWriteRoots;
  final List<String> shellAllowlist;
  final String shellAllowlistProfile;
  final int diffBudgetMaxFiles;
  final int diffBudgetMaxAdditions;
  final int diffBudgetMaxDeletions;
  final int autopilotMinOpenTasks;
  final int autopilotMaxPlanAdd;
  final int autopilotStepSleepSeconds;
  final int autopilotIdleSleepSeconds;
  final int? autopilotMaxSteps;
  final int autopilotMaxFailures;
  final int autopilotMaxTaskRetries;
  final String autopilotSelectionMode;
  final int autopilotFairnessWindow;
  final int autopilotPriorityWeightP1;
  final int autopilotPriorityWeightP2;
  final int autopilotPriorityWeightP3;
  final bool autopilotReactivateBlocked;
  final bool autopilotReactivateFailed;
  final int autopilotBlockedCooldownSeconds;
  final int autopilotFailedCooldownSeconds;
  final int autopilotLockTtlSeconds;
  final int autopilotNoProgressThreshold;
  final int autopilotStuckCooldownSeconds;
  final bool autopilotSelfRestart;
  final int autopilotScopeMaxFiles;
  final int autopilotScopeMaxAdditions;
  final int autopilotScopeMaxDeletions;
  final int autopilotApproveBudget;
  final bool autopilotManualOverride;
  final bool autopilotOvernightUnattendedEnabled;
  final bool autopilotSelfTuneEnabled;
  final int autopilotSelfTuneWindow;
  final int autopilotSelfTuneMinSamples;
  final int autopilotSelfTuneSuccessPercent;
}

/// Coordinator controller for project workspace tabs.
///
/// Delegates domain logic to focused sub-controllers ([AutopilotController],
/// [TaskController], [ReviewController], [ProjectConfigController]) while
/// keeping a stable public API for view consumption.
class ProjectWorkspaceController extends ChangeNotifier {
  ProjectWorkspaceController({
    required String projectRootPath,
    GenaisysApi? api,
    AutopilotStatusUseCase? autopilotStatusUseCase,
    AutopilotStopUseCase? autopilotStopUseCase,
    AutopilotStepUseCase? autopilotStepUseCase,
    Duration autopilotPollIntervalRunning =
        _defaultAutopilotPollIntervalRunning,
    Duration autopilotPollIntervalIdle = _defaultAutopilotPollIntervalIdle,
  }) : _projectRootPath = projectRootPath.trim(),
       _api = api ?? InProcessGenaisysApi(),
       _useIsolate = api == null {
    _autopilot = AutopilotController(
      projectRootPath: _projectRootPath,
      autopilotStatusUseCase: autopilotStatusUseCase,
      autopilotStopUseCase: autopilotStopUseCase,
      autopilotStepUseCase: autopilotStepUseCase,
      pollIntervalRunning: autopilotPollIntervalRunning,
      pollIntervalIdle: autopilotPollIntervalIdle,
    );
    _tasks = TaskController(projectRootPath: _projectRootPath, api: _api);
    _review = ReviewController(projectRootPath: _projectRootPath, api: _api);
    _config = ProjectConfigController(
      projectRootPath: _projectRootPath,
      api: _api,
    );
  }

  static const Duration _defaultAutopilotPollIntervalRunning = Duration(
    seconds: 1,
  );
  static const Duration _defaultAutopilotPollIntervalIdle = Duration(
    seconds: 3,
  );
  static const Duration _backgroundDashboardPollInterval = Duration(
    seconds: 30,
  );

  final String _projectRootPath;
  final GenaisysApi _api;

  /// When true, blocking API calls run in a background [Isolate] to keep the
  /// UI thread free.  Disabled when a custom [GenaisysApi] was injected
  /// (tests) because mock instances cannot be recreated inside an isolate.
  final bool _useIsolate;

  // ---- Sub-controllers ----
  late final AutopilotController _autopilot;
  late final TaskController _tasks;
  late final ReviewController _review;
  late final ProjectConfigController _config;

  /// Exposes the autopilot sub-controller for direct access when needed.
  AutopilotController get autopilot => _autopilot;

  /// Exposes the task sub-controller for direct access when needed.
  TaskController get tasks => _tasks;

  /// Exposes the review sub-controller for direct access when needed.
  ReviewController get review => _review;

  /// Exposes the config sub-controller for direct access when needed.
  ProjectConfigController get configController => _config;

  // ---- Coordinator state ----
  bool _loading = false;
  bool _actionInProgress = false;
  bool _disposed = false;
  bool _initializing = false;
  bool _refreshing = false;
  bool _pollingPaused = false;
  Timer? _dashboardPollTimer;
  String? _errorMessage;
  String? _infoMessage;
  DateTime? _lastSyncedAt;
  AppDashboardDto? _dashboard;

  // ---- Focused ValueNotifiers for scoped rebuilds ----
  final ValueNotifier<bool> actionInProgressNotifier = ValueNotifier<bool>(
    false,
  );

  ValueNotifier<AutopilotStatusDto?> get autopilotStatusNotifier =>
      _autopilot.statusNotifier;

  final ValueNotifier<AppDashboardDto?> dashboardNotifier =
      ValueNotifier<AppDashboardDto?>(null);

  ValueNotifier<AppTaskListDto> get taskListNotifier => _tasks.taskListNotifier;

  final ValueNotifier<({String? error, String? info})> feedbackNotifier =
      ValueNotifier<({String? error, String? info})>((error: null, info: null));
  final ValueNotifier<int> backlogComposerFocusRequestNotifier =
      ValueNotifier<int>(0);
  int _backlogComposerFocusRequestSerial = 0;
  int _backlogComposerFocusHandledSerial = 0;

  // ---- Public getters (stable API) ----
  bool get hasProjectRoot => _projectRootPath.isNotEmpty;
  String get projectRootPath => _projectRootPath;
  bool get isLoading => _loading;
  bool get isActionInProgress => _actionInProgress;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  AppDashboardDto? get dashboard => _dashboard;
  AppStatusSnapshotDto? get status => _dashboard?.status;
  AppReviewStatusDto? get reviewStatus =>
      _review.reviewStatus ?? _dashboard?.review;
  AppTaskListDto get taskList => _tasks.taskList;
  AppTaskDto? get nextTask => _tasks.nextTask;
  AppConfigDto? get projectConfig => _config.config;
  AutopilotStatusDto? get autopilotStatus => _autopilot.status;
  bool get autopilotRunning => _autopilot.isRunning;

  List<BacklogTask> get backlogTasks {
    return _tasks.backlogTasks(activeTaskId: status?.activeTaskId);
  }

  List<BacklogTask> backlogTasksByStatus(BacklogTaskStatus status) {
    return _tasks.backlogTasksByStatus(
      status,
      activeTaskId: this.status?.activeTaskId,
    );
  }

  BacklogTask? backlogTaskById(String taskId) {
    return _tasks.backlogTaskById(taskId, activeTaskId: status?.activeTaskId);
  }

  ProjectSettingsDraft? get settingsDraft => _config.settingsDraft;

  // ---- Lifecycle ----

  Future<void> initialize() async {
    if (_initializing || _disposed) {
      return;
    }
    if (!hasProjectRoot) {
      _errorMessage = 'No project root configured for this workspace.';
      notifyListeners();
      return;
    }
    _initializing = true;
    try {
      await refresh(includeConfig: true);
      _startPolling();
    } finally {
      _initializing = false;
    }
  }

  Future<void> refresh({
    bool includeConfig = false,
    bool silent = false,
  }) async {
    if (!hasProjectRoot) {
      _errorMessage = 'No project root configured for this workspace.';
      notifyListeners();
      return;
    }

    // Guard against overlapping refreshes.
    if (_refreshing) {
      return;
    }
    _refreshing = true;

    try {
      if (!silent) {
        _loading = true;
        notifyListeners();
      }
      _errorMessage = null;
      _infoMessage = null;

      if (_useIsolate) {
        // Production path: run all blocking API calls (Process.runSync,
        // readAsStringSync, etc.) in a background isolate so the UI thread
        // stays free for frame rendering.
        await _refreshViaIsolate(includeConfig: includeConfig);
      } else {
        // Test path: a custom GenaisysApi was injected — run directly on
        // the main thread to honour mock overrides.
        await _refreshDirect(includeConfig: includeConfig);
      }

      // Autopilot status (also uses health check with git subprocesses).
      await refreshAutopilotStatus(silent: true);

      _lastSyncedAt = DateTime.now();
      _syncFeedbackNotifier();

      if (!silent) {
        _loading = false;
      }
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  /// Runs all read-only API calls in a background [Isolate] via
  /// [runWorkspaceRefreshInBackground].  Results are applied to coordinator
  /// state on the main thread after the isolate completes.
  Future<void> _refreshViaIsolate({required bool includeConfig}) async {
    final WorkspaceRefreshResult result = await runWorkspaceRefreshInBackground(
      projectRootPath: _projectRootPath,
      includeConfig: includeConfig || _config.config == null,
    );

    // --- Apply results to coordinator state (main thread) ---

    // Dashboard
    if (result.dashboard != null) {
      _dashboard = result.dashboard;
      dashboardNotifier.value = result.dashboard;
    } else if (result.dashboardError != null) {
      _errorMessage ??= result.dashboardError;
    }

    // Tasks
    if (result.taskList != null) {
      _tasks.applyRefreshResult(
        taskList: result.taskList!,
        nextTask: result.nextTask,
      );
    } else if (result.taskError != null) {
      _errorMessage ??= result.taskError;
    }

    // Review
    if (result.dashboard != null) {
      _review.updateFromDashboard(result.dashboard!.review);
    } else if (result.reviewStatus != null) {
      _review.updateFromDashboard(result.reviewStatus);
    } else if (result.reviewError != null) {
      _errorMessage ??= result.reviewError;
    }

    // Config
    if (result.config != null) {
      _config.applyConfig(result.config!);
    } else if (result.configError != null) {
      _errorMessage ??= result.configError;
    }
  }

  /// Runs all read-only API calls on the main thread via [Future.wait].
  ///
  /// Used when a custom [GenaisysApi] was injected (tests).
  Future<void> _refreshDirect({required bool includeConfig}) async {
    // Run independent API calls in parallel.
    final List<Object?> results = await Future.wait(<Future<Object?>>[
      _api.getDashboard(_projectRootPath),
      _tasks.refresh(),
      _review.refresh(),
    ]);

    // Dashboard
    final AppResult<AppDashboardDto> dashboardResult =
        results[0]! as AppResult<AppDashboardDto>;
    if (dashboardResult.ok && dashboardResult.data != null) {
      _dashboard = dashboardResult.data;
      dashboardNotifier.value = dashboardResult.data;
    } else {
      _errorMessage ??=
          dashboardResult.error?.message ?? 'Failed to load dashboard.';
    }

    // Tasks
    final String? taskError = results[1] as String?;
    if (taskError != null) {
      _errorMessage ??= taskError;
    }

    // Review
    final String? reviewError = results[2] as String?;
    if (reviewError != null) {
      _errorMessage ??= reviewError;
    }
    _review.updateFromDashboard(_dashboard?.review);

    // Config
    if (includeConfig || _config.config == null) {
      final String? configError = await _config.refresh();
      if (configError != null) {
        _errorMessage ??= configError;
      }
    }
  }

  Future<void> refreshAutopilotStatus({bool silent = false}) async {
    if (_disposed || !hasProjectRoot) {
      return;
    }
    final String? error = await _autopilot.refreshStatus(
      isActionInProgress: () => _actionInProgress,
    );
    if (error != null && !silent) {
      _errorMessage = error;
      _syncFeedbackNotifier();
      notifyListeners();
    }
  }

  // ---- Autopilot delegation ----

  void attachAutopilotLiveSync() => _autopilot.attachLiveSync();
  void detachAutopilotLiveSync() => _autopilot.detachLiveSync();

  Future<void> runAutopilotStep({String? prompt}) async {
    await _runMutation<AutopilotStepDto>(
      operation: () => _autopilot.runStep(prompt: prompt),
      successMessage: 'Autopilot step executed.',
    );
  }

  Future<void> stopAutopilot() async {
    await _runMutation<AutopilotStopDto>(
      operation: () => _autopilot.stop(),
      successMessage: 'Autopilot stop requested.',
    );
  }

  // ---- Task delegation ----

  Future<void> runTaskCycle({
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) async {
    final String normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      _errorMessage = 'Prompt must not be empty.';
      _infoMessage = null;
      notifyListeners();
      return;
    }

    await _runMutation<TaskCycleExecutionDto>(
      operation: () => _api.runTaskCycle(
        _projectRootPath,
        prompt: normalizedPrompt,
        testSummary: testSummary,
        overwrite: overwrite,
      ),
      successMessage: 'Task cycle executed.',
    );
  }

  Future<void> runCycleTick() async {
    await _runMutation<CycleTickDto>(
      operation: () => _api.cycle(_projectRootPath),
      successMessage: 'Cycle counter updated.',
    );
  }

  Future<void> activateNextTask() async {
    await _runMutation<TaskActivationDto>(
      operation: () => _tasks.activateNextTask(),
      successMessage: 'Next task activated.',
    );
  }

  Future<void> markActiveTaskDone() async {
    await _runMutation<TaskDoneDto>(
      operation: () => _tasks.markActiveTaskDone(),
      successMessage: 'Active task marked done.',
    );
  }

  Future<void> createTask({
    required String title,
    required BacklogTaskPriority priority,
    AppTaskCategory category = AppTaskCategory.core,
    String section = 'Backlog',
  }) async {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      _errorMessage = 'Task title must not be empty.';
      _infoMessage = null;
      notifyListeners();
      return;
    }

    await _runMutation<TaskCreateDto>(
      operation: () => _tasks.createTask(
        title: normalizedTitle,
        priority: _toAppPriority(priority),
        category: category,
        section: section,
      ),
      successMessage: 'Task created.',
    );
  }

  Future<void> updateTaskPriority({
    required String taskId,
    required BacklogTaskPriority priority,
  }) async {
    await _runMutation<TaskPriorityUpdateDto>(
      operation: () => _tasks.updateTaskPriority(
        taskId: taskId,
        priority: _toAppPriority(priority),
      ),
      successMessage: 'Task priority updated.',
    );
  }

  Future<void> refineTask({
    required String title,
    bool overwrite = false,
  }) async {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      _errorMessage = 'Task title must not be empty.';
      _infoMessage = null;
      notifyListeners();
      return;
    }
    await _runMutation<TaskRefinementDto>(
      operation: () =>
          _tasks.refineTask(title: normalizedTitle, overwrite: overwrite),
      successMessage: 'Task refinement artifacts generated.',
    );
  }

  Future<void> deleteTask({required String taskId}) async {
    await _runMutation<TaskDeleteDto>(
      operation: () => _tasks.deleteTask(taskId: taskId),
      successMessage: 'Task deleted.',
    );
  }

  Future<void> moveTaskBetweenColumns({
    required String taskId,
    required BacklogTaskStatus destination,
  }) async {
    if (_actionInProgress) {
      return;
    }

    final BacklogTask? current = backlogTaskById(taskId);
    if (current != null && current.status == destination) {
      return;
    }

    _actionInProgress = true;
    _errorMessage = null;
    _infoMessage = null;
    _syncActionInProgressNotifier();
    _syncFeedbackNotifier();
    notifyListeners();

    try {
      AppError? error;
      switch (destination) {
        case BacklogTaskStatus.blocked:
          final String? activeTaskId = status?.activeTaskId;
          if (activeTaskId != taskId) {
            final AppResult<TaskActivationDto> activation = await _tasks
                .activateNextTask(id: taskId);
            error = _extractError(activation);
            if (error != null) {
              break;
            }
          }
          final AppResult<TaskBlockedDto> blockedResult = await _tasks
              .blockActiveTask(reason: 'Moved to blocked column.');
          error = _extractError(blockedResult);
          break;
        case BacklogTaskStatus.todo:
          final String? activeTaskId = status?.activeTaskId;
          if (activeTaskId == taskId) {
            final AppResult<TaskDeactivationDto> result = await _tasks
                .deactivateActiveTask(keepReview: true);
            error = _extractError(result);
          } else {
            final AppResult<TaskMoveSectionDto> result = await _tasks
                .moveTaskSection(taskId: taskId, section: 'Backlog');
            error = _extractError(result);
          }
          break;
        case BacklogTaskStatus.working:
          final AppResult<TaskActivationDto> result = await _tasks
              .activateNextTask(id: taskId);
          error = _extractError(result);
          break;
        case BacklogTaskStatus.done:
          final String? activeTaskId = status?.activeTaskId;
          if (activeTaskId != taskId) {
            final AppResult<TaskActivationDto> activation = await _tasks
                .activateNextTask(id: taskId);
            error = _extractError(activation);
            if (error != null) {
              break;
            }
          }
          final AppResult<TaskDoneDto> doneResult = await _tasks
              .markActiveTaskDone();
          error = _extractError(doneResult);
          break;
      }

      if (error != null) {
        _errorMessage = _formatError(error);
      } else {
        _infoMessage = 'Task moved.';
      }
      _syncFeedbackNotifier();
      await refresh(silent: true);
    } finally {
      _actionInProgress = false;
      _syncActionInProgressNotifier();
      notifyListeners();
    }
  }

  void requestBacklogComposerFocus() {
    _backlogComposerFocusRequestSerial += 1;
    backlogComposerFocusRequestNotifier.value =
        _backlogComposerFocusRequestSerial;
  }

  bool consumeBacklogComposerFocusRequest() {
    if (_backlogComposerFocusHandledSerial >=
        _backlogComposerFocusRequestSerial) {
      return false;
    }
    _backlogComposerFocusHandledSerial = _backlogComposerFocusRequestSerial;
    return true;
  }

  Future<void> blockActiveTask({String? reason}) async {
    await _runMutation<TaskBlockedDto>(
      operation: () => _tasks.blockActiveTask(reason: reason),
      successMessage: 'Active task blocked.',
    );
  }

  Future<void> deactivateActiveTask({bool keepReview = true}) async {
    await _runMutation<TaskDeactivationDto>(
      operation: () => _tasks.deactivateActiveTask(keepReview: keepReview),
      successMessage: 'Active task deactivated.',
    );
  }

  // ---- Review delegation ----

  Future<void> approveReview({String? note}) async {
    await _runMutation<ReviewDecisionDto>(
      operation: () => _review.approve(note: note),
      successMessage: 'Review approved.',
    );
  }

  Future<void> rejectReview({String? note}) async {
    await _runMutation<ReviewDecisionDto>(
      operation: () => _review.reject(note: note),
      successMessage: 'Review rejected.',
    );
  }

  Future<void> clearReview({String? note}) async {
    await _runMutation<ReviewClearDto>(
      operation: () => _review.clear(note: note),
      successMessage: 'Review status cleared.',
    );
  }

  // ---- Config delegation ----

  Future<void> saveSettings(ProjectSettingsDraft draft) async {
    if (_config.config == null) {
      _errorMessage = 'Project config is not loaded yet.';
      _infoMessage = null;
      notifyListeners();
      return;
    }

    await _runMutation<ConfigUpdateDto>(
      operation: () => _config.save(draft),
      successMessage: 'Project settings saved.',
      includeConfig: true,
    );
  }

  // ---- Project artifact initialization (stays on coordinator) ----

  Future<void> initializeProjectArtifacts({bool overwrite = false}) async {
    await _runMutation<ProjectInitializationDto>(
      operation: () =>
          _api.initializeProject(_projectRootPath, overwrite: overwrite),
      successMessage: 'Project scaffold initialized.',
    );
  }

  Future<void> initializePlanArtifacts({bool overwrite = false}) async {
    await _runMutation<SpecInitializationDto>(
      operation: () =>
          _api.initializePlan(_projectRootPath, overwrite: overwrite),
      successMessage: 'Plan artifact initialized.',
    );
  }

  Future<void> initializeSpecArtifacts({bool overwrite = false}) async {
    await _runMutation<SpecInitializationDto>(
      operation: () =>
          _api.initializeSpec(_projectRootPath, overwrite: overwrite),
      successMessage: 'Spec artifact initialized.',
    );
  }

  Future<void> initializeSubtasksArtifacts({bool overwrite = false}) async {
    await _runMutation<SpecInitializationDto>(
      operation: () =>
          _api.initializeSubtasks(_projectRootPath, overwrite: overwrite),
      successMessage: 'Subtasks artifact initialized.',
    );
  }

  // ---- Polling ----

  bool get isPollingPaused => _pollingPaused;

  void pausePolling() {
    if (_pollingPaused) {
      return;
    }
    _pollingPaused = true;
    _stopPolling();
  }

  void resumePolling() {
    if (!_pollingPaused) {
      return;
    }
    _pollingPaused = false;
    _startPolling();
  }

  // ---- Feedback ----

  void clearFeedback() {
    if (_errorMessage == null && _infoMessage == null) {
      return;
    }
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  // ---- Private helpers ----

  Future<void> _runMutation<T>({
    required Future<AppResult<T>> Function() operation,
    required String successMessage,
    bool includeConfig = false,
  }) async {
    if (_actionInProgress) {
      return;
    }

    _actionInProgress = true;
    _errorMessage = null;
    _infoMessage = null;
    _syncActionInProgressNotifier();
    _syncFeedbackNotifier();
    notifyListeners();

    try {
      final AppResult<T> result = await operation();
      final AppError? error = _extractError(result);
      if (error != null) {
        _errorMessage = _formatError(error);
        _syncFeedbackNotifier();
        return;
      }
      _infoMessage = successMessage;
      _syncFeedbackNotifier();
      await refresh(includeConfig: includeConfig, silent: true);
    } finally {
      _actionInProgress = false;
      _syncActionInProgressNotifier();
      notifyListeners();
    }
  }

  void _syncFeedbackNotifier() {
    final ({String? error, String? info}) current = (
      error: _errorMessage,
      info: _infoMessage,
    );
    if (feedbackNotifier.value != current) {
      feedbackNotifier.value = current;
    }
  }

  void _syncActionInProgressNotifier() {
    if (actionInProgressNotifier.value != _actionInProgress) {
      actionInProgressNotifier.value = _actionInProgress;
    }
  }

  AppError? _extractError<T>(AppResult<T> result) {
    if (result.ok && result.data != null) {
      return null;
    }
    return result.error ?? AppError.unknown('Operation failed unexpectedly.');
  }

  String _formatError(AppError? error) {
    if (error == null) {
      return 'Unknown operation error.';
    }
    return error.message;
  }

  AppTaskPriority _toAppPriority(BacklogTaskPriority priority) {
    switch (priority) {
      case BacklogTaskPriority.p1:
        return AppTaskPriority.p1;
      case BacklogTaskPriority.p2:
        return AppTaskPriority.p2;
      case BacklogTaskPriority.p3:
        return AppTaskPriority.p3;
    }
  }

  void _startPolling() {
    if (_disposed || _pollingPaused || !hasProjectRoot) {
      return;
    }
    _stopPolling();
    // Autopilot status polling is handled by AutopilotController's own
    // live-sync mechanism (1-5s + jitter).  Dashboard is polled here on a
    // longer interval.  Both paths use background isolates in production
    // to keep the UI thread free.
    _dashboardPollTimer = Timer.periodic(_backgroundDashboardPollInterval, (_) {
      if (!_disposed && !_pollingPaused && !_actionInProgress && !_refreshing) {
        unawaited(refresh(silent: true));
      }
    });
  }

  void _stopPolling() {
    _dashboardPollTimer?.cancel();
    _dashboardPollTimer = null;
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _stopPolling();
    _autopilot.dispose();
    _tasks.dispose();
    _review.dispose();
    _config.dispose();
    actionInProgressNotifier.dispose();
    dashboardNotifier.dispose();
    feedbackNotifier.dispose();
    backlogComposerFocusRequestNotifier.dispose();
    super.dispose();
  }
}
