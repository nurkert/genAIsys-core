// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../models/task_draft.dart';
import '../project_layout.dart';
import '../storage/atomic_file_write.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'strategic_planner_service.dart';
import 'task_management/task_write_service.dart';
import 'vision_evaluation_service.dart';

class SprintPlanResult {
  const SprintPlanResult({
    required this.sprintStarted,
    required this.visionFulfilled,
    required this.maxSprintsReached,
    required this.sprintNumber,
    required this.tasksAdded,
  });

  final bool sprintStarted;
  final bool visionFulfilled;
  final bool maxSprintsReached;
  final int sprintNumber;
  final int tasksAdded;

  static const noAction = SprintPlanResult(
    sprintStarted: false,
    visionFulfilled: false,
    maxSprintsReached: false,
    sprintNumber: 0,
    tasksAdded: 0,
  );
}

class SprintPlannerService {
  SprintPlannerService({
    StrategicPlannerService? strategicPlanner,
    VisionEvaluationService? visionEvaluationService,
    TaskWriteService? taskWriteService,
  }) : _strategicPlanner = strategicPlanner ?? StrategicPlannerService(),
       _visionEvaluationService =
           visionEvaluationService ?? VisionEvaluationService(),
       _taskWriteService = taskWriteService ?? TaskWriteService();

  final StrategicPlannerService _strategicPlanner;
  final VisionEvaluationService _visionEvaluationService;
  final TaskWriteService _taskWriteService;

  static final RegExp _sprintHeaderPattern = RegExp(
    r'^## Sprint (\d+)',
    multiLine: true,
  );

  /// Returns the highest sprint number found in TASKS.md (0 if none).
  int detectCurrentSprint(String tasksPath) {
    final file = File(tasksPath);
    if (!file.existsSync()) return 0;
    final content = file.readAsStringSync();
    int maxSprint = 0;
    for (final match in _sprintHeaderPattern.allMatches(content)) {
      final n = int.tryParse(match.group(1) ?? '');
      if (n != null && n > maxSprint) maxSprint = n;
    }
    return maxSprint;
  }

  /// Checks whether a new sprint should be started and, if so, generates it.
  ///
  /// Returns [SprintPlanResult.noAction] immediately when there are still open
  /// tasks (nothing to do yet).
  Future<SprintPlanResult> maybeStartNextSprint(
    String projectRoot, {
    required ProjectConfig config,
    required String stepId,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);
    final taskStore = TaskStore(layout.tasksPath);
    final openTasks = taskStore
        .readTasks()
        .where((t) => t.completion.name == 'open')
        .toList();

    if (openTasks.isNotEmpty) {
      return SprintPlanResult.noAction;
    }

    final currentSprint = detectCurrentSprint(layout.tasksPath);

    runLog.append(
      event: 'sprint_planning_started',
      message: 'Sprint planning triggered: all tasks complete',
      data: {
        'step_id': stepId,
        'current_sprint': currentSprint,
        'open_tasks': 0,
        'error_class': 'pipeline',
      },
    );

    // Check max sprints gate.
    if (config.autopilotMaxSprints > 0 &&
        currentSprint >= config.autopilotMaxSprints) {
      runLog.append(
        event: 'sprint_max_reached',
        message: 'Max sprint limit reached — stopping',
        data: {
          'step_id': stepId,
          'max_sprints': config.autopilotMaxSprints,
          'current_sprint': currentSprint,
          'error_class': 'pipeline',
          'error_kind': 'max_sprints_reached',
        },
      );
      return SprintPlanResult(
        sprintStarted: false,
        visionFulfilled: false,
        maxSprintsReached: true,
        sprintNumber: currentSprint,
        tasksAdded: 0,
      );
    }

    // Check vision fulfillment.
    final evalResult = await _visionEvaluationService.evaluate(projectRoot);
    if (evalResult != null && evalResult.visionFulfilled) {
      runLog.append(
        event: 'sprint_vision_fulfilled',
        message: 'Vision fulfilled — stopping sprint planning',
        data: {
          'step_id': stepId,
          'sprint_number': currentSprint,
          'completion_estimate': evalResult.completionEstimate,
          'covered_goals': evalResult.coveredGoals,
          'error_class': 'pipeline',
          'error_kind': 'vision_fulfilled',
        },
      );
      return SprintPlanResult(
        sprintStarted: false,
        visionFulfilled: true,
        maxSprintsReached: false,
        sprintNumber: currentSprint,
        tasksAdded: 0,
      );
    }

    // Generate next sprint.
    final nextSprint = currentSprint + 1;
    final drafts = await _strategicPlanner.suggestTasks(
      projectRoot,
      count: config.autopilotSprintSize,
    );

    _appendSprintHeader(layout.tasksPath, nextSprint);

    final sectionName = 'Sprint $nextSprint';
    var tasksAdded = 0;
    final titles = <String>[];
    for (final draft in drafts) {
      try {
        _taskWriteService.createTask(
          projectRoot,
          title: draft.title,
          priority: draft.priority,
          category: draft.category,
          section: sectionName,
        );
        tasksAdded += 1;
        titles.add(draft.title);
      } catch (_) {
        // Skip duplicate or invalid tasks silently.
      }
    }

    runLog.append(
      event: 'sprint_planning_complete',
      message: 'Sprint $nextSprint planned with $tasksAdded tasks',
      data: {
        'step_id': stepId,
        'sprint_number': nextSprint,
        'tasks_added': tasksAdded,
        'titles': titles,
        'error_class': 'pipeline',
      },
    );

    return SprintPlanResult(
      sprintStarted: true,
      visionFulfilled: false,
      maxSprintsReached: false,
      sprintNumber: nextSprint,
      tasksAdded: tasksAdded,
    );
  }

  /// Appends a `## Sprint N` section header to TASKS.md atomically.
  void _appendSprintHeader(String tasksPath, int sprintNumber) {
    final file = File(tasksPath);
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    final header = '\n## Sprint $sprintNumber\n';
    final updated =
        existing.trimRight().isEmpty ? header.trimLeft() : '$existing\n$header';
    AtomicFileWrite.writeStringSync(tasksPath, updated);
  }
}
