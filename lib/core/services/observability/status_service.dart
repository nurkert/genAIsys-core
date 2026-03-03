// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../models/health_snapshot.dart';
import '../../models/task.dart';
import '../../models/workflow_stage.dart';
import '../../project_layout.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';
import 'health_check_service.dart';
import 'run_telemetry_service.dart';

class StatusSnapshot {
  StatusSnapshot({
    required this.projectRoot,
    required this.tasksTotal,
    required this.tasksOpen,
    required this.tasksDone,
    required this.tasksBlocked,
    required this.activeTaskTitle,
    required this.activeTaskId,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
    required this.cycleCount,
    required this.lastUpdated,
    required this.lastError,
    required this.lastErrorClass,
    required this.lastErrorKind,
    required this.workflowStage,
    required this.health,
    required this.telemetry,
  });

  final String projectRoot;
  final int tasksTotal;
  final int tasksOpen;
  final int tasksDone;
  final int tasksBlocked;
  final String? activeTaskTitle;
  final String? activeTaskId;
  final String? reviewStatus;
  final String? reviewUpdatedAt;
  final int cycleCount;
  final String? lastUpdated;
  final String? lastError;
  final String? lastErrorClass;
  final String? lastErrorKind;
  final WorkflowStage workflowStage;
  final HealthSnapshot health;
  final RunTelemetrySnapshot telemetry;

  String get activeTaskLabel =>
      (activeTaskTitle?.isNotEmpty ?? false) ? activeTaskTitle! : '(none)';

  String get activeTaskIdLabel =>
      (activeTaskId?.isNotEmpty ?? false) ? activeTaskId! : '(none)';

  String get reviewStatusLabel =>
      (reviewStatus?.isNotEmpty ?? false) ? reviewStatus! : '(none)';

  String get reviewUpdatedAtLabel =>
      (reviewUpdatedAt?.isNotEmpty ?? false) ? reviewUpdatedAt! : '(none)';

  String get workflowStageLabel => workflowStage.name;

  String get lastUpdatedLabel =>
      (lastUpdated?.isNotEmpty ?? false) ? lastUpdated! : '(unknown)';
}

class StatusService {
  StatusService({
    HealthCheckService? healthService,
    RunTelemetryService? telemetryService,
  }) : _healthService = healthService ?? HealthCheckService(),
       _telemetryService = telemetryService ?? RunTelemetryService();

  final HealthCheckService _healthService;
  final RunTelemetryService _telemetryService;

  StatusSnapshot getStatus(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      throw StateError(
        'No .genaisys directory found at: ${layout.genaisysDir}',
      );
    }
    final state = StateStore(layout.statePath).read();
    final tasks = TaskStore(layout.tasksPath).readTasks();

    final tasksTotal = tasks.length;
    final tasksOpen = tasks
        .where((task) => task.completion == TaskCompletion.open)
        .length;
    final tasksDone = tasksTotal - tasksOpen;
    final tasksBlocked = tasks.where((task) => task.blocked).length;

    final health = _healthService.check(projectRoot);
    final telemetry = _telemetryService.load(projectRoot, recentLimit: 5);

    return StatusSnapshot(
      projectRoot: projectRoot,
      tasksTotal: tasksTotal,
      tasksOpen: tasksOpen,
      tasksDone: tasksDone,
      tasksBlocked: tasksBlocked,
      activeTaskTitle: state.activeTaskTitle,
      activeTaskId: state.activeTaskId,
      reviewStatus: state.reviewStatus,
      reviewUpdatedAt: state.reviewUpdatedAt,
      cycleCount: state.cycleCount,
      lastUpdated: state.lastUpdated,
      lastError: state.lastError,
      lastErrorClass: state.lastErrorClass,
      lastErrorKind: state.lastErrorKind,
      workflowStage: state.workflowStage,
      health: health,
      telemetry: telemetry,
    );
  }
}
