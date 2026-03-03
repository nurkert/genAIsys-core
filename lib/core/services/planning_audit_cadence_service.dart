// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../models/task.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'task_management/task_write_service.dart';

class PlanningAuditCadenceResult {
  PlanningAuditCadenceResult({
    required this.stepIndex,
    required this.due,
    required this.created,
    required this.skipped,
    required this.createdTitles,
    required this.skippedTitles,
  });

  final int stepIndex;
  final bool due;
  final int created;
  final int skipped;
  final List<String> createdTitles;
  final List<String> skippedTitles;
}

class PlanningAuditCadenceService {
  PlanningAuditCadenceService({
    TaskWriteService? taskWriteService,
    DateTime Function()? now,
  }) : _taskWriteService = taskWriteService ?? TaskWriteService(),
       _now = now ?? DateTime.now;

  final TaskWriteService _taskWriteService;
  final DateTime Function() _now;

  PlanningAuditCadenceResult seedForStep(
    String projectRoot, {
    required int stepIndex,
    required ProjectConfig config,
  }) {
    final normalizedStep = stepIndex < 1 ? 1 : stepIndex;
    final cadence = config.autopilotPlanningAuditCadenceSteps < 1
        ? 1
        : config.autopilotPlanningAuditCadenceSteps;
    final due = normalizedStep % cadence == 0;
    final periodicMaxAdd = config.autopilotPlanningAuditMaxAdd < 1
        ? 1
        : config.autopilotPlanningAuditMaxAdd;

    if (!config.autopilotPlanningAuditEnabled) {
      return PlanningAuditCadenceResult(
        stepIndex: normalizedStep,
        due: false,
        created: 0,
        skipped: 0,
        createdTitles: const [],
        skippedTitles: const [],
      );
    }

    final existingTasks = _readTasks(projectRoot);
    final createdTitles = <String>[];
    final skippedTitles = <String>[];

    // Skip foundation meta-tasks on early steps to let new projects establish
    // their own concrete backlog first. Self-review / refactor / regression
    // tasks are only useful once the project has enough history to audit.
    final skipFoundation = normalizedStep <= cadence;

    if (!skipFoundation) {
      for (final suggestion in _foundationSuggestions) {
        final created = _tryCreate(
          projectRoot,
          title: suggestion.title,
          priority: suggestion.priority,
          category: suggestion.category,
        );
        if (created) {
          createdTitles.add(suggestion.title);
        } else {
          skippedTitles.add(suggestion.title);
        }
      }
    }

    if (due) {
      final openTasks = existingTasks
          .where(
            (task) => task.completion == TaskCompletion.open && !task.blocked,
          )
          .toList(growable: false);
      var periodicCreated = 0;
      for (final suggestion in _periodicSuggestions) {
        if (periodicCreated >= periodicMaxAdd) {
          skippedTitles.add(suggestion.kindLabel);
          continue;
        }
        if (_hasOpenAuditTask(openTasks, suggestion.kindLabel)) {
          skippedTitles.add(suggestion.kindLabel);
          continue;
        }
        final title = _buildPeriodicTitle(suggestion.kindLabel, normalizedStep);
        final created = _tryCreate(
          projectRoot,
          title: title,
          priority: suggestion.priority,
          category: suggestion.category,
        );
        if (created) {
          createdTitles.add(title);
          periodicCreated += 1;
        } else {
          skippedTitles.add(title);
        }
      }
    }

    if (due || createdTitles.isNotEmpty) {
      _appendLog(
        projectRoot,
        event: 'planning_audit_cadence',
        message: due
            ? 'Planning/audit cadence seeding executed'
            : 'Planning/audit foundation tasks ensured',
        data: {
          'step_index': normalizedStep,
          'due': due,
          'cadence_steps': cadence,
          'periodic_max_add': periodicMaxAdd,
          'created': createdTitles.length,
          'skipped': skippedTitles.length,
        },
      );
    }

    return PlanningAuditCadenceResult(
      stepIndex: normalizedStep,
      due: due,
      created: createdTitles.length,
      skipped: skippedTitles.length,
      createdTitles: List<String>.unmodifiable(createdTitles),
      skippedTitles: List<String>.unmodifiable(skippedTitles),
    );
  }

  bool _hasOpenAuditTask(List<Task> openTasks, String kindLabel) {
    final needle = 'run $kindLabel audit sweep';
    for (final task in openTasks) {
      final normalized = _normalize(task.title);
      if (normalized.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String _buildPeriodicTitle(String kindLabel, int stepIndex) {
    final date = _formatDate(_now().toUtc());
    return 'Run $kindLabel audit sweep (cadence step $stepIndex / $date) '
        '| AC: Capture top findings and add concrete follow-up tasks.';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool _tryCreate(
    String projectRoot, {
    required String title,
    required TaskPriority priority,
    required TaskCategory category,
  }) {
    try {
      _taskWriteService.createTask(
        projectRoot,
        title: title,
        priority: priority,
        category: category,
        section: 'Backlog',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Task> _readTasks(String projectRoot) {
    try {
      final layout = ProjectLayout(projectRoot);
      final file = File(layout.tasksPath);
      if (!file.existsSync()) {
        return const [];
      }
      return TaskStore(layout.tasksPath).readTasks();
    } catch (_) {
      return const [];
    }
  }

  String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _appendLog(
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
}

class _FoundationSuggestion {
  const _FoundationSuggestion({
    required this.title,
    required this.priority,
    required this.category,
  });

  final String title;
  final TaskPriority priority;
  final TaskCategory category;
}

class _PeriodicSuggestion {
  const _PeriodicSuggestion({
    required this.kindLabel,
    required this.priority,
    required this.category,
  });

  final String kindLabel;
  final TaskPriority priority;
  final TaskCategory category;
}

const List<_FoundationSuggestion> _foundationSuggestions = [
  _FoundationSuggestion(
    title:
        'Run a full self-review of the current core and CLI architecture before new feature work | AC: Produce prioritized findings and concrete next actions.',
    priority: TaskPriority.p1,
    category: TaskCategory.architecture,
  ),
  _FoundationSuggestion(
    title:
        'Create a concrete refactor backlog from self-review findings with small safe steps | AC: Add at least five incremental refactor tasks with acceptance criteria.',
    priority: TaskPriority.p1,
    category: TaskCategory.refactor,
  ),
  _FoundationSuggestion(
    title:
        'Add focused regression checks for every refactor step to prevent fast-iteration breakage | AC: Every refactor task includes at least one deterministic regression check.',
    priority: TaskPriority.p1,
    category: TaskCategory.qa,
  ),
];

const List<_PeriodicSuggestion> _periodicSuggestions = [
  _PeriodicSuggestion(
    kindLabel: 'architecture',
    priority: TaskPriority.p1,
    category: TaskCategory.architecture,
  ),
  _PeriodicSuggestion(
    kindLabel: 'security',
    priority: TaskPriority.p1,
    category: TaskCategory.security,
  ),
  _PeriodicSuggestion(
    kindLabel: 'docs',
    priority: TaskPriority.p2,
    category: TaskCategory.docs,
  ),
  _PeriodicSuggestion(
    kindLabel: 'ui',
    priority: TaskPriority.p2,
    category: TaskCategory.ui,
  ),
];
