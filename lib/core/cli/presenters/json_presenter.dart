// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../app/app.dart';
import '../../security/redaction_service.dart';
import 'cli_presenter.dart';

class JsonPresenter implements CliPresenter {
  const JsonPresenter();

  static final RedactionService _redactionService = RedactionService.shared;

  void writeError(IOSink out, {required String code, required String message}) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{'error': message, 'code': code}),
    );
  }

  void writeInit(IOSink out, ProjectInitializationDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'initialized': dto.initialized,
        'genaisys_dir': dto.genaisysDir,
      }),
    );
  }

  void writeStatus(IOSink out, AppStatusSnapshotDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'project_root': dto.projectRoot,
        'tasks_total': dto.tasksTotal,
        'tasks_open': dto.tasksOpen,
        'tasks_blocked': dto.tasksBlocked,
        'tasks_done': dto.tasksDone,
        'active_task': _labelOrNone(dto.activeTaskTitle),
        'active_task_id': _labelOrNone(dto.activeTaskId),
        'review_status': _labelOrNone(dto.reviewStatus),
        'review_updated_at': _labelOrNone(dto.reviewUpdatedAt),
        'workflow_stage': dto.workflowStage,
        'cycle_count': dto.cycleCount,
        'last_updated': _labelOrUnknown(dto.lastUpdated),
        'last_error': dto.lastError,
        'last_error_class': dto.lastErrorClass,
        'last_error_kind': dto.lastErrorKind,
        'health': _healthPayload(dto.health),
        'telemetry': _telemetryPayload(dto.telemetry),
      }),
    );
  }

  void writeCycle(IOSink out, CycleTickDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'cycle_updated': dto.cycleUpdated,
        'cycle_count': dto.cycleCount,
      }),
    );
  }

  void writeCycleRun(IOSink out, TaskCycleExecutionDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'task_cycle_completed': dto.taskCycleCompleted,
        'review_recorded': dto.reviewRecorded,
        'review_decision': dto.reviewDecision,
        'coding_ok': dto.codingOk,
      }),
    );
  }

  void writeTasks(IOSink out, AppTaskListDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'tasks': dto.tasks.map(_taskPayload).toList(),
      }),
    );
  }

  void writeTask(IOSink out, AppTaskDto dto) {
    _writeJsonLine(out, jsonEncode(_taskPayload(dto)));
  }

  void writeActivate(IOSink out, TaskActivationDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'activated': dto.activated,
        'task': dto.task == null ? null : _taskPayload(dto.task!),
      }),
    );
  }

  void writeDeactivate(IOSink out, TaskDeactivationDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'deactivated': dto.deactivated,
        'keep_review': dto.keepReview,
        'active_task': dto.activeTaskTitle,
        'active_task_id': dto.activeTaskId,
        'review_status': dto.reviewStatus,
        'review_updated_at': dto.reviewUpdatedAt,
      }),
    );
  }

  void writeSpecInit(IOSink out, SpecInitializationDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{'created': dto.created, 'path': dto.path}),
    );
  }

  void writeDone(IOSink out, TaskDoneDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'done': dto.done,
        'task_title': dto.taskTitle,
      }),
    );
  }

  void writeBlock(IOSink out, TaskBlockedDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'blocked': dto.blocked,
        'task_title': dto.taskTitle,
        'reason': dto.reason,
      }),
    );
  }

  void writeReviewStatus(IOSink out, AppReviewStatusDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'review_status': dto.status,
        'review_updated_at': dto.updatedAt,
      }),
    );
  }

  void writeReviewDecision(IOSink out, ReviewDecisionDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'review_recorded': dto.reviewRecorded,
        'decision': dto.decision,
        'task_title': dto.taskTitle,
        'note': dto.note,
      }),
    );
  }

  void writeReviewClear(IOSink out, ReviewClearDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'review_cleared': dto.reviewCleared,
        'review_status': dto.reviewStatus,
        'review_updated_at': dto.reviewUpdatedAt,
        'note': dto.note,
      }),
    );
  }

  void writeAutopilotStep(IOSink out, AutopilotStepDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_step_completed': true,
        'executed_cycle': dto.executedCycle,
        'activated_task': dto.activatedTask,
        'active_task': dto.activeTaskTitle,
        'planned_tasks_added': dto.plannedTasksAdded,
        'review_decision': dto.reviewDecision,
        'retry_count': dto.retryCount,
        'task_blocked': dto.taskBlocked,
        'deactivated_task': dto.deactivatedTask,
      }),
    );
  }

  void writeAutopilotRun(IOSink out, AutopilotRunDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_run_completed': true,
        'total_steps': dto.totalSteps,
        'successful_steps': dto.successfulSteps,
        'idle_steps': dto.idleSteps,
        'failed_steps': dto.failedSteps,
        'stopped_by_max_steps': dto.stoppedByMaxSteps,
        'stopped_when_idle': dto.stoppedWhenIdle,
        'stopped_by_safety_halt': dto.stoppedBySafetyHalt,
      }),
    );
  }

  void writeAutopilotCandidate(IOSink out, AutopilotCandidateDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_candidate_completed': true,
        'passed': dto.passed,
        'skip_suites': dto.skipSuites,
        'missing_files': dto.missingFiles,
        'missing_done_blockers': dto.missingDoneBlockers,
        'open_critical_p1_lines': dto.openCriticalP1Lines,
        'commands': dto.commands
            .map(
              (entry) => <String, Object?>{
                'command': entry.command,
                'ok': entry.ok,
                'exit_code': entry.exitCode,
                'timed_out': entry.timedOut,
                'duration_ms': entry.durationMs,
                'stdout_excerpt': entry.stdoutExcerpt,
                'stderr_excerpt': entry.stderrExcerpt,
              },
            )
            .toList(growable: false),
      }),
    );
  }

  void writeAutopilotPilot(IOSink out, AutopilotPilotDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_pilot_completed': true,
        'passed': dto.passed,
        'timed_out': dto.timedOut,
        'command_exit_code': dto.commandExitCode,
        'branch': dto.branch,
        'duration_seconds': dto.durationSeconds,
        'max_cycles': dto.maxCycles,
        'report_path': dto.reportPath,
        'run': <String, Object?>{
          'total_steps': dto.totalSteps,
          'successful_steps': dto.successfulSteps,
          'idle_steps': dto.idleSteps,
          'failed_steps': dto.failedSteps,
          'stopped_by_max_steps': dto.stoppedByMaxSteps,
          'stopped_when_idle': dto.stoppedWhenIdle,
          'stopped_by_safety_halt': dto.stoppedBySafetyHalt,
        },
        'error': dto.error,
      }),
    );
  }

  void writeAutopilotBranchCleanup(IOSink out, AutopilotBranchCleanupDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_branch_cleanup_completed': true,
        'base_branch': dto.baseBranch,
        'dry_run': dto.dryRun,
        'deleted_local_branches': dto.deletedLocalBranches,
        'deleted_remote_branches': dto.deletedRemoteBranches,
        'skipped_branches': dto.skippedBranches,
        'failures': dto.failures,
      }),
    );
  }

  void writeAutopilotStatus(IOSink out, AutopilotStatusDto dto) {
    final summary = dto.lastStepSummary;
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_running': dto.autopilotRunning,
        'pid': dto.pid,
        'started_at': dto.startedAt,
        'last_loop_at': dto.lastLoopAt,
        'consecutive_failures': dto.consecutiveFailures,
        'last_error': dto.lastError,
        'last_error_class': dto.lastErrorClass,
        'last_error_kind': dto.lastErrorKind,
        'subtask_queue': dto.subtaskQueue,
        'current_subtask': dto.currentSubtask,
        'stall_reason': dto.stallReason,
        'stall_detail': dto.stallDetail,
        'health': _healthPayload(dto.health),
        'telemetry': _telemetryPayload(
          dto.telemetry,
          includeHealthSummary: false,
        ),
        'health_summary': <String, Object?>{
          'failure_trend': <String, Object?>{
            'direction': dto.healthSummary.failureTrend.direction,
            'recent_failures': dto.healthSummary.failureTrend.recentFailures,
            'previous_failures':
                dto.healthSummary.failureTrend.previousFailures,
            'window_seconds': dto.healthSummary.failureTrend.windowSeconds,
            'sample_size': dto.healthSummary.failureTrend.sampleSize,
            'dominant_error_kind':
                dto.healthSummary.failureTrend.dominantErrorKind,
          },
          'retry_distribution': <String, Object?>{
            'samples': dto.healthSummary.retryDistribution.samples,
            'retry_0': dto.healthSummary.retryDistribution.retry0,
            'retry_1': dto.healthSummary.retryDistribution.retry1,
            'retry_2_plus': dto.healthSummary.retryDistribution.retry2Plus,
            'max_retry': dto.healthSummary.retryDistribution.maxRetry,
          },
          'cooldown': <String, Object?>{
            'active': dto.healthSummary.cooldown.active,
            'total_seconds': dto.healthSummary.cooldown.totalSeconds,
            'remaining_seconds': dto.healthSummary.cooldown.remainingSeconds,
            'until': dto.healthSummary.cooldown.until,
            'source_event': dto.healthSummary.cooldown.sourceEvent,
            'reason': dto.healthSummary.cooldown.reason,
          },
        },
        'hitl_gate_pending': dto.hitlGatePending,
        if (dto.hitlGateEvent != null) 'hitl_gate_event': dto.hitlGateEvent,
        'last_step_summary': summary == null
            ? null
            : <String, Object?>{
                'step_id': summary.stepId,
                'task_id': summary.taskId,
                'subtask_id': summary.subtaskId,
                'decision': summary.decision,
                'event': summary.event,
                'timestamp': summary.timestamp,
              },
      }),
    );
  }

  void writeAutopilotStop(IOSink out, AutopilotStopDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{'autopilot_stopped': dto.autopilotStopped}),
    );
  }

  void writeAutopilotSupervisorStart(
    IOSink out,
    AutopilotSupervisorStartDto dto,
  ) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_supervisor_started': dto.started,
        'session_id': dto.sessionId,
        'profile': dto.profile,
        'supervisor_pid': dto.pid,
        'resume_action': dto.resumeAction,
      }),
    );
  }

  void writeAutopilotSupervisorStop(
    IOSink out,
    AutopilotSupervisorStopDto dto,
  ) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_supervisor_stopped': dto.stopped,
        'was_running': dto.wasRunning,
        'reason': dto.reason,
      }),
    );
  }

  void writeAutopilotSupervisorStatus(
    IOSink out,
    AutopilotSupervisorStatusDto dto,
  ) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_supervisor_running': dto.running,
        'session_id': dto.sessionId,
        'profile': dto.profile,
        'start_reason': dto.startReason,
        'supervisor_pid': dto.workerPid,
        'started_at': dto.startedAt,
        'restart_count': dto.restartCount,
        'cooldown_until': dto.cooldownUntil,
        'last_halt_reason': dto.lastHaltReason,
        'last_resume_action': dto.lastResumeAction,
        'last_exit_code': dto.lastExitCode,
        'low_signal_streak': dto.lowSignalStreak,
        'throughput': <String, Object?>{
          'window_started_at': dto.throughputWindowStartedAt,
          'steps': dto.throughputSteps,
          'rejects': dto.throughputRejects,
          'high_retries': dto.throughputHighRetries,
        },
        'autopilot': <String, Object?>{
          'running': dto.autopilotRunning,
          'pid': dto.autopilotPid,
          'last_loop_at': dto.autopilotLastLoopAt,
          'consecutive_failures': dto.autopilotConsecutiveFailures,
          'last_error': dto.autopilotLastError,
        },
      }),
    );
  }

  void writeAutopilotSmoke(IOSink out, AutopilotSmokeDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_smoke_ok': dto.ok,
        'project_root': dto.projectRoot,
        'task_title': dto.taskTitle,
        'review_decision': dto.reviewDecision,
        'task_done': dto.taskDone,
        'commit_count': dto.commitCount,
        'failures': dto.failures,
      }),
    );
  }

  void writeAutopilotSimulation(IOSink out, AutopilotSimulationDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_simulation_completed': true,
        'project_root': dto.projectRoot,
        'workspace_root': dto.workspaceRoot,
        'has_task': dto.hasTask,
        'activated_task': dto.activatedTask,
        'planned_tasks_added': dto.plannedTasksAdded,
        'task_title': dto.taskTitle,
        'task_id': dto.taskId,
        'subtask': dto.subtask,
        'review_decision': dto.reviewDecision,
        'diff_summary': dto.diffSummary,
        'diff_patch': dto.diffPatch,
        'diff_stats': <String, Object?>{
          'files_changed': dto.filesChanged,
          'additions': dto.additions,
          'deletions': dto.deletions,
        },
        'policy_violation': dto.policyViolation,
        'policy_message': dto.policyMessage,
      }),
    );
  }

  void writeAutopilotImprove(IOSink out, AutopilotImproveDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_improve_completed': true,
        'meta': dto.meta == null
            ? null
            : {
                'created': dto.meta!.created,
                'skipped': dto.meta!.skipped,
                'created_titles': dto.meta!.createdTitles,
                'skipped_titles': dto.meta!.skippedTitles,
              },
        'eval': dto.eval == null
            ? null
            : {
                'run_id': dto.eval!.runId,
                'run_at': dto.eval!.runAt,
                'success_rate': dto.eval!.successRate,
                'passed': dto.eval!.passed,
                'total': dto.eval!.total,
                'output_dir': dto.eval!.outputDir,
                'results': dto.eval!.results
                    .map(
                      (entry) => {
                        'id': entry.id,
                        'title': entry.title,
                        'passed': entry.passed,
                        'reason': entry.reason,
                        'review_decision': entry.reviewDecision,
                        'policy_violation': entry.policyViolation,
                        'policy_message': entry.policyMessage,
                        'diff_stats': {
                          'files_changed': entry.filesChanged,
                          'additions': entry.additions,
                          'deletions': entry.deletions,
                        },
                      },
                    )
                    .toList(),
              },
        'self_tune': dto.selfTune == null
            ? null
            : {
                'applied': dto.selfTune!.applied,
                'reason': dto.selfTune!.reason,
                'success_rate': dto.selfTune!.successRate,
                'samples': dto.selfTune!.samples,
                'before': dto.selfTune!.before,
                'after': dto.selfTune!.after,
              },
      }),
    );
  }

  void writeAutopilotHeal(IOSink out, AutopilotHealDto dto) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'autopilot_heal_completed': true,
        'bundle_path': dto.bundlePath,
        'reason': dto.reason,
        'detail': dto.detail,
        'executed_cycle': dto.executedCycle,
        'recovered': dto.recovered,
        'activated_task': dto.activatedTask,
        'deactivated_task': dto.deactivatedTask,
        'task_blocked': dto.taskBlocked,
        'planned_tasks_added': dto.plannedTasksAdded,
        'retry_count': dto.retryCount,
        'review_decision': dto.reviewDecision,
        'active_task_id': dto.activeTaskId,
        'active_task': dto.activeTaskTitle,
        'subtask_id': dto.subtaskId,
      }),
    );
  }

  Map<String, Object?> _taskPayload(AppTaskDto task) {
    return <String, Object?>{
      'id': task.id,
      'title': task.title,
      'section': task.section,
      'priority': task.priority,
      'category': task.category,
      'status': task.status.name,
    };
  }

  String _labelOrNone(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '(none)';
    }
    return trimmed;
  }

  String _labelOrUnknown(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '(unknown)';
    }
    return trimmed;
  }

  Map<String, Object?> _healthPayload(AppHealthSnapshotDto snapshot) {
    return <String, Object?>{
      'all_ok': snapshot.allOk,
      'agent': _healthCheckPayload(snapshot.agent),
      'allowlist': _healthCheckPayload(snapshot.allowlist),
      'git': _healthCheckPayload(snapshot.git),
      'review': _healthCheckPayload(snapshot.review),
    };
  }

  Map<String, Object?> _healthCheckPayload(AppHealthCheckDto check) {
    return <String, Object?>{'ok': check.ok, 'message': check.message};
  }

  Map<String, Object?> _telemetryPayload(
    AppRunTelemetryDto telemetry, {
    bool includeHealthSummary = true,
  }) {
    return <String, Object?>{
      'error_class': telemetry.errorClass,
      'error_kind': telemetry.errorKind,
      'error_message': telemetry.errorMessage,
      'agent_exit_code': telemetry.agentExitCode,
      'agent_stderr_excerpt': telemetry.agentStderrExcerpt,
      'last_error_event': telemetry.lastErrorEvent,
      if (includeHealthSummary && telemetry.healthSummary != null)
        'health_summary': _healthSummaryPayload(telemetry.healthSummary!),
      'recent_events': telemetry.recentEvents.map(_eventPayload).toList(),
    };
  }

  Map<String, Object?> _healthSummaryPayload(AppRunHealthSummaryDto summary) {
    return <String, Object?>{
      'failure_trend': <String, Object?>{
        'direction': summary.failureTrend.direction,
        'recent_failures': summary.failureTrend.recentFailures,
        'previous_failures': summary.failureTrend.previousFailures,
        'window_seconds': summary.failureTrend.windowSeconds,
        'sample_size': summary.failureTrend.sampleSize,
        'dominant_error_kind': summary.failureTrend.dominantErrorKind,
      },
      'retry_distribution': <String, Object?>{
        'samples': summary.retryDistribution.samples,
        'retry_0': summary.retryDistribution.retry0,
        'retry_1': summary.retryDistribution.retry1,
        'retry_2_plus': summary.retryDistribution.retry2Plus,
        'max_retry': summary.retryDistribution.maxRetry,
      },
      'cooldown': <String, Object?>{
        'active': summary.cooldown.active,
        'total_seconds': summary.cooldown.totalSeconds,
        'remaining_seconds': summary.cooldown.remainingSeconds,
        'until': summary.cooldown.until,
        'source_event': summary.cooldown.sourceEvent,
        'reason': summary.cooldown.reason,
      },
    };
  }

  Map<String, Object?> _eventPayload(AppRunLogEventDto event) {
    return <String, Object?>{
      'timestamp': event.timestamp,
      'event_id': event.eventId,
      'correlation_id': event.correlationId,
      'event': event.event,
      'message': event.message,
      'correlation': event.correlation,
      'data': event.data,
    };
  }

  void writeHitlGate(IOSink out, HitlGateDto gate) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'pending': gate.pending,
        if (gate.event != null) 'event': gate.event,
        if (gate.taskId != null) 'task_id': gate.taskId,
        if (gate.taskTitle != null) 'task_title': gate.taskTitle,
        if (gate.sprintNumber != null) 'sprint_number': gate.sprintNumber,
        if (gate.expiresAt != null) 'expires_at': gate.expiresAt,
      }),
    );
  }

  void writeHitlDecision(IOSink out, String decision, {String? note}) {
    _writeJsonLine(
      out,
      jsonEncode(<String, Object?>{
        'decision': decision,
        if (note != null) 'note': note,
      }),
    );
  }

  void _writeJsonLine(IOSink out, String encodedJson) {
    out.writeln(_redactionService.sanitizeText(encodedJson).value);
  }
}
