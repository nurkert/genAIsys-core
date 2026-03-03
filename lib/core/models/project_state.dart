// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'active_task_state.dart';
import 'autopilot_run_state.dart';
import 'reflection_state.dart';
import 'retry_scheduling_state.dart';
import 'subtask_execution_state.dart';
import 'supervisor_state.dart';
import 'workflow_stage.dart';

part 'project_state.freezed.dart';

@Freezed(toJson: false, fromJson: false)
abstract class ProjectState with _$ProjectState {
  const ProjectState._();

  const factory ProjectState({
    // Top-level fields (remain at root).
    @Default(1) int version,
    required String lastUpdated,
    @Default(0) int cycleCount,
    @Default(WorkflowStage.idle) WorkflowStage workflowStage,
    // Sub-model partitions.
    @Default(ActiveTaskState()) ActiveTaskState activeTask,
    @Default(RetrySchedulingState()) RetrySchedulingState retryScheduling,
    @Default(SubtaskExecutionState()) SubtaskExecutionState subtaskExecution,
    @Default(AutopilotRunState()) AutopilotRunState autopilotRun,
    @Default(SupervisorState()) SupervisorState supervisor,
    @Default(ReflectionState()) ReflectionState reflection,
  }) = _ProjectState;

  factory ProjectState.fromJson(Map<String, dynamic> json) {
    return ProjectState(
      version: json['version'] as int? ?? 1,
      lastUpdated: json['last_updated'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      cycleCount: json['cycle_count'] as int? ?? 0,
      workflowStage: _parseWorkflowStage(json['workflow_stage']),
      activeTask: ActiveTaskState.fromJson(json),
      retryScheduling: RetrySchedulingState.fromJson(json),
      subtaskExecution: SubtaskExecutionState.fromJson(json),
      autopilotRun: AutopilotRunState.fromJson(json),
      supervisor: SupervisorState.fromJson(json),
      reflection: ReflectionState.fromJson(json),
    );
  }

  factory ProjectState.initial() =>
      ProjectState(lastUpdated: DateTime.now().toUtc().toIso8601String());

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'last_updated': lastUpdated,
      'cycle_count': cycleCount,
      'workflow_stage': workflowStage.name,
      ...activeTask.toJson(),
      ...retryScheduling.toJson(),
      ...subtaskExecution.toJson(),
      ...autopilotRun.toJson(),
      ...supervisor.toJson(),
      ...reflection.toJson(),
    };
  }

  // ---------------------------------------------------------------------------
  // Convenience getters — backward-compatible read access
  // ---------------------------------------------------------------------------

  // ActiveTaskState
  String? get activeTaskId => activeTask.id;
  String? get activeTaskTitle => activeTask.title;
  String? get activeTaskRetryKey => activeTask.retryKey;
  String? get reviewStatus => activeTask.reviewStatus;
  String? get reviewUpdatedAt => activeTask.reviewUpdatedAt;
  bool get forensicRecoveryAttempted => activeTask.forensicRecoveryAttempted;
  String? get forensicGuidance => activeTask.forensicGuidance;

  // RetrySchedulingState
  Map<String, int> get taskRetryCounts => retryScheduling.retryCounts;
  Map<String, String> get taskCooldownUntil => retryScheduling.cooldownUntil;

  // SubtaskExecutionState
  List<String> get subtaskQueue => subtaskExecution.queue;
  String? get currentSubtask => subtaskExecution.current;

  // AutopilotRunState
  bool get autopilotRunning => autopilotRun.running;
  String? get currentMode => autopilotRun.currentMode;
  String? get lastLoopAt => autopilotRun.lastLoopAt;
  int get consecutiveFailures => autopilotRun.consecutiveFailures;
  String? get lastError => autopilotRun.lastError;
  String? get lastErrorClass => autopilotRun.lastErrorClass;
  String? get lastErrorKind => autopilotRun.lastErrorKind;

  // SupervisorState
  bool get supervisorRunning => supervisor.running;
  String? get supervisorSessionId => supervisor.sessionId;
  int? get supervisorPid => supervisor.pid;
  String? get supervisorStartedAt => supervisor.startedAt;
  String? get supervisorProfile => supervisor.profile;
  String? get supervisorStartReason => supervisor.startReason;
  int get supervisorRestartCount => supervisor.restartCount;
  String? get supervisorCooldownUntil => supervisor.cooldownUntil;
  String? get supervisorLastHaltReason => supervisor.lastHaltReason;
  String? get supervisorLastResumeAction => supervisor.lastResumeAction;
  int? get supervisorLastExitCode => supervisor.lastExitCode;
  int get supervisorLowSignalStreak => supervisor.lowSignalStreak;
  String? get supervisorThroughputWindowStartedAt =>
      supervisor.throughputWindowStartedAt;
  int get supervisorThroughputSteps => supervisor.throughputSteps;
  int get supervisorThroughputRejects => supervisor.throughputRejects;
  int get supervisorThroughputHighRetries => supervisor.throughputHighRetries;
  int get supervisorReflectionCount => supervisor.reflectionCount;
  String? get supervisorLastReflectionAt => supervisor.lastReflectionAt;

  // ReflectionState
  String? get lastReflectionAt => reflection.lastAt;
  int get reflectionCount => reflection.count;
  int get reflectionTasksCreated => reflection.tasksCreated;
}

WorkflowStage _parseWorkflowStage(dynamic value) {
  if (value == null) return WorkflowStage.idle;
  final name = value.toString();
  for (final stage in WorkflowStage.values) {
    if (stage.name == name) return stage;
  }
  return WorkflowStage.idle;
}
