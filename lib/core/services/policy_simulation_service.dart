// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../git/git_service.dart';
import '../models/task.dart';
import '../models/review_bundle.dart';
import '../policy/diff_budget_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import 'task_management/activate_service.dart';
import 'task_management/active_task_resolver.dart';
import 'agents/review_agent_service.dart';
import 'review_bundle_service.dart';
import 'task_management/subtask_scheduler_service.dart';
import 'task_management/task_pipeline_service.dart';
import 'vision_backlog_planner_service.dart';

class PolicySimulationResult {
  PolicySimulationResult({
    required this.projectRoot,
    required this.workspaceRoot,
    required this.hasTask,
    required this.activatedTask,
    required this.plannedTasksAdded,
    required this.taskTitle,
    required this.taskId,
    required this.subtask,
    required this.reviewDecision,
    required this.diffSummary,
    required this.diffPatch,
    required this.diffStats,
    required this.policyViolation,
    required this.policyMessage,
  });

  final String projectRoot;
  final String? workspaceRoot;
  final bool hasTask;
  final bool activatedTask;
  final int plannedTasksAdded;
  final String? taskTitle;
  final String? taskId;
  final String? subtask;
  final String? reviewDecision;
  final String diffSummary;
  final String diffPatch;
  final DiffStats? diffStats;
  final bool policyViolation;
  final String? policyMessage;
}

class PolicySimulationService {
  PolicySimulationService({
    TaskPipelineService? taskPipelineService,
    VisionBacklogPlannerService? plannerService,
    ActivateService? activateService,
    ActiveTaskResolver? activeTaskResolver,
    ReviewBundleService? reviewBundleService,
    SubtaskSchedulerService? subtaskSchedulerService,
    GitService? gitService,
  }) : _taskPipelineService = taskPipelineService ?? TaskPipelineService(),
       _plannerService = plannerService ?? VisionBacklogPlannerService(),
       _activateService = activateService ?? ActivateService(),
       _activeTaskResolver = activeTaskResolver ?? ActiveTaskResolver(),
       _reviewBundleService = reviewBundleService ?? ReviewBundleService(),
       _subtaskScheduler = subtaskSchedulerService ?? SubtaskSchedulerService(),
       _gitService = gitService ?? GitService();

  final TaskPipelineService _taskPipelineService;
  final VisionBacklogPlannerService _plannerService;
  final ActivateService _activateService;
  final ActiveTaskResolver _activeTaskResolver;
  final ReviewBundleService _reviewBundleService;
  final SubtaskSchedulerService _subtaskScheduler;
  final GitService _gitService;

  Future<PolicySimulationResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    bool keepWorkspace = false,
  }) async {
    Directory? workspaceParent;
    String? workspaceRoot;
    try {
      workspaceParent = Directory.systemTemp.createTempSync('genaisys_sim_');
      workspaceRoot = _createWorkspace(projectRoot, workspaceParent.path);

      final config = _loadConfig(workspaceRoot);
      final resolvedMinOpen = minOpenTasks ?? config.autopilotMinOpenTasks;
      final resolvedMaxPlanAdd = maxPlanAdd ?? config.autopilotMaxPlanAdd;
      final normalizedMinOpen = resolvedMinOpen < 1 ? 1 : resolvedMinOpen;
      final normalizedMaxPlanAdd = resolvedMaxPlanAdd < 1
          ? 1
          : resolvedMaxPlanAdd;

      final planner = await _plannerService.syncBacklogStrategically(
        workspaceRoot,
        minOpenTasks: normalizedMinOpen,
        maxAdd: normalizedMaxPlanAdd,
      );

      final layout = ProjectLayout(workspaceRoot);
      final stateStore = StateStore(layout.statePath);
      var state = stateStore.read();
      var activeTitle = state.activeTaskTitle?.trim();
      var activeTaskId = state.activeTaskId?.trim();
      var activatedTask = false;

      if (activeTitle == null || activeTitle.isEmpty) {
        final activation = _activateService.activate(workspaceRoot);
        if (!activation.hasTask) {
          return PolicySimulationResult(
            projectRoot: projectRoot,
            workspaceRoot: keepWorkspace ? workspaceRoot : null,
            hasTask: false,
            activatedTask: false,
            plannedTasksAdded: planner.added,
            taskTitle: null,
            taskId: null,
            subtask: null,
            reviewDecision: null,
            diffSummary: '',
            diffPatch: '',
            diffStats: null,
            policyViolation: false,
            policyMessage: null,
          );
        }
        activatedTask = true;
        activeTitle = activation.task!.title;
        state = stateStore.read();
        activeTaskId = state.activeTaskId?.trim();
      }

      String promptToUse = codingPrompt;
      String? subtask;
      if (state.currentSubtask != null) {
        subtask = state.currentSubtask;
        promptToUse = 'Implement subtask: $subtask';
      } else if (state.subtaskQueue.isNotEmpty) {
        final selection = _subtaskScheduler.selectNext(
          workspaceRoot,
          activeTaskTitle: activeTitle,
          queue: state.subtaskQueue,
        );
        subtask = selection.selectedSubtask;
        final rest = selection.remainingQueue;
        stateStore.write(
          state.copyWith(
            subtaskExecution: state.subtaskExecution.copyWith(
              current: subtask,
              queue: rest,
            ),
            lastUpdated: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        promptToUse = 'Implement subtask: $subtask';
      }

      final composedPrompt = _composePrompt(promptToUse, activeTitle);
      final category =
          _activeTaskResolver.resolve(workspaceRoot)?.category ??
          TaskCategory.unknown;
      final reviewPersona = _selectReviewPersona(category);

      TaskPipelineResult? pipeline;
      var policyViolation = false;
      String? policyMessage;
      try {
        pipeline = await _taskPipelineService.run(
          workspaceRoot,
          codingPrompt: composedPrompt,
          testSummary: testSummary,
          overwriteArtifacts: overwriteArtifacts,
          reviewPersona: reviewPersona,
          taskCategory: category,
        );
      } on StateError catch (error) {
        final message = error.message.toString();
        if (message.toLowerCase().contains('policy violation')) {
          policyViolation = true;
          policyMessage = message;
        } else {
          rethrow;
        }
      }

      final bundle = _safeReviewBundle(
        workspaceRoot,
        testSummary: testSummary,
        taskTitle: activeTitle,
      );
      final diffStats = _safeDiffStats(workspaceRoot);
      final reviewDecision = pipeline?.review?.decision.name;

      _appendRunLog(
        projectRoot,
        event: 'policy_simulation',
        message: 'Policy simulation completed',
        data: {
          'task': activeTitle,
          'task_id': activeTaskId ?? '',
          'subtask': subtask ?? '',
          'planned_added': planner.added,
          'review_decision': reviewDecision ?? '',
          'policy_violation': policyViolation,
          'policy_message': policyMessage ?? '',
        },
      );

      return PolicySimulationResult(
        projectRoot: projectRoot,
        workspaceRoot: keepWorkspace ? workspaceRoot : null,
        hasTask: true,
        activatedTask: activatedTask,
        plannedTasksAdded: planner.added,
        taskTitle: activeTitle,
        taskId: activeTaskId,
        subtask: subtask,
        reviewDecision: reviewDecision,
        diffSummary: bundle.diffSummary,
        diffPatch: bundle.diffPatch,
        diffStats: diffStats,
        policyViolation: policyViolation,
        policyMessage: policyMessage,
      );
    } finally {
      if (!keepWorkspace && workspaceParent != null) {
        try {
          workspaceParent.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  String _createWorkspace(String projectRoot, String tempRoot) {
    final workspaceRoot = _join(tempRoot, 'workspace');
    if (_gitService.isGitRepo(projectRoot)) {
      final result = Process.runSync('git', [
        'clone',
        '--local',
        projectRoot,
        workspaceRoot,
      ]);
      if (result.exitCode == 0) {
        return workspaceRoot;
      }
    }
    _copyDirectory(Directory(projectRoot), Directory(workspaceRoot));
    return workspaceRoot;
  }

  void _copyDirectory(Directory source, Directory destination) {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    for (final entity in source.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (name.isEmpty) {
        continue;
      }
      final targetPath = _join(destination.path, name);
      if (entity is Directory) {
        _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        entity.copySync(targetPath);
      }
    }
  }

  ProjectConfig _loadConfig(String projectRoot) {
    try {
      return ProjectConfig.load(projectRoot);
    } catch (_) {
      return ProjectConfig.empty();
    }
  }

  String _composePrompt(String basePrompt, String? activeTitle) {
    final task = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : '(unknown)';
    return '''
$basePrompt

Constraints:
- Implement exactly one smallest meaningful step.
- Do not mix multiple features.
- Keep internal artifacts and task outputs in English.
- Current active task: $task
'''
        .trim();
  }

  ReviewPersona _selectReviewPersona(TaskCategory category) {
    switch (category) {
      case TaskCategory.security:
        return ReviewPersona.security;
      case TaskCategory.ui:
        return ReviewPersona.ui;
      case TaskCategory.architecture:
      case TaskCategory.refactor:
        return ReviewPersona.performance;
      case TaskCategory.docs:
      case TaskCategory.qa:
      case TaskCategory.core:
      case TaskCategory.agent:
      case TaskCategory.unknown:
        return ReviewPersona.general;
    }
  }

  DiffStats? _safeDiffStats(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return null;
    }
    try {
      return _gitService.diffStats(projectRoot);
    } catch (_) {
      return null;
    }
  }

  ReviewBundle _safeReviewBundle(
    String projectRoot, {
    String? testSummary,
    String? taskTitle,
  }) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return ReviewBundle(
        diffSummary: '',
        diffPatch: '',
        testSummary: testSummary,
        taskTitle: taskTitle,
        spec: null,
      );
    }
    try {
      return _reviewBundleService.build(projectRoot, testSummary: testSummary);
    } catch (_) {
      return ReviewBundle(
        diffSummary: '',
        diffPatch: '',
        testSummary: testSummary,
        taskTitle: taskTitle,
        spec: null,
      );
    }
  }

  void _appendRunLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: event,
      message: message,
      data: {'root': projectRoot, ...data},
    );
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
