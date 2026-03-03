// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../git/git_service.dart';
import '../../../models/run_log_event.dart';
import '../../../project_layout.dart';
import '../../../security/redaction_service.dart';
import '../../../services/orchestrator_run_service.dart';
import '../../../services/orchestrator_step_service.dart';
import '../../../services/observability/run_telemetry_service.dart';
import '../../../storage/run_log_store.dart';
import '../../../storage/state_store.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotHealUseCase {
  AutopilotHealUseCase({
    OrchestratorStepService? stepService,
    OrchestratorRunService? runService,
    RunTelemetryService? telemetryService,
    GitService? gitService,
    RedactionService? redactionService,
  }) : _stepService = stepService ?? OrchestratorStepService(),
       _runService = runService ?? OrchestratorRunService(),
       _telemetryService = telemetryService ?? RunTelemetryService(),
       _gitService = gitService ?? GitService(),
       _redactionService = redactionService ?? RedactionService.shared;

  final OrchestratorStepService _stepService;
  final OrchestratorRunService _runService;
  final RunTelemetryService _telemetryService;
  final GitService _gitService;
  final RedactionService _redactionService;

  Future<AppResult<AutopilotHealDto>> run(
    String projectRoot, {
    String reason = 'unknown',
    String? detail,
    String? prompt,
    bool overwrite = false,
    int? minOpen,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    try {
      final normalizedReason = _normalizeReason(reason);
      final normalizedDetail = _normalizeDetail(detail);
      final bundle = _createIncidentBundle(
        projectRoot,
        reason: normalizedReason,
        detail: normalizedDetail,
      );

      _appendRunLog(
        projectRoot,
        event: 'incident_heal_start',
        message: 'Autopilot incident heal started',
        data: {
          'reason': normalizedReason,
          'detail': ?normalizedDetail,
          'bundle_path': bundle.path,
        },
      );

      final resolvedPrompt = _buildIncidentPrompt(
        bundle,
        reason: normalizedReason,
        detail: normalizedDetail,
        overridePrompt: prompt,
      );
      final stepResult = await _stepService.run(
        projectRoot,
        codingPrompt: resolvedPrompt,
        overwriteArtifacts: overwrite,
        minOpenTasks: minOpen,
        maxPlanAdd: maxPlanAdd,
        maxTaskRetries: maxTaskRetries,
      );
      final recovered =
          _didProgress(stepResult) && !_isProgressFailure(stepResult);

      _appendRunLog(
        projectRoot,
        event: 'incident_heal_end',
        message: recovered
            ? 'Autopilot incident heal completed with progress'
            : 'Autopilot incident heal completed without progress',
        data: {
          'reason': normalizedReason,
          'detail': ?normalizedDetail,
          'bundle_path': bundle.path,
          'recovered': recovered,
          'executed_cycle': stepResult.executedCycle,
          'review_decision': stepResult.reviewDecision ?? '',
          'retry_count': stepResult.retryCount,
          'task_blocked': stepResult.blockedTask,
          'activated_task': stepResult.activatedTask,
          'deactivated_task': stepResult.deactivatedTask,
          'planned_tasks_added': stepResult.plannedTasksAdded,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.trim().isNotEmpty)
            'task_id': stepResult.activeTaskId,
          if (stepResult.currentSubtask != null &&
              stepResult.currentSubtask!.trim().isNotEmpty)
            'subtask_id': stepResult.currentSubtask,
        },
      );

      return AppResult.success(
        AutopilotHealDto(
          bundlePath: bundle.path,
          reason: normalizedReason,
          detail: normalizedDetail,
          executedCycle: stepResult.executedCycle,
          recovered: recovered,
          activatedTask: stepResult.activatedTask,
          deactivatedTask: stepResult.deactivatedTask,
          taskBlocked: stepResult.blockedTask,
          plannedTasksAdded: stepResult.plannedTasksAdded,
          retryCount: stepResult.retryCount,
          reviewDecision: stepResult.reviewDecision,
          activeTaskId: stepResult.activeTaskId,
          activeTaskTitle: stepResult.activeTaskTitle,
          subtaskId: stepResult.currentSubtask,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }

  IncidentBundle _createIncidentBundle(
    String projectRoot, {
    required String reason,
    required String? detail,
  }) {
    final layout = ProjectLayout(projectRoot);
    Directory(layout.attemptsDir).createSync(recursive: true);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final safeTimestamp = timestamp.replaceAll(':', '-');
    final bundlePath =
        '${layout.attemptsDir}${Platform.pathSeparator}incident-heal-$safeTimestamp.json';

    final state = _readState(layout.statePath);
    final status = _readStatus(projectRoot);
    final telemetry = _readTelemetry(projectRoot);
    final git = _readGitSnapshot(projectRoot);
    final runLogExcerpt = _readRunLogExcerpt(layout.runLogPath);
    final payload = <String, Object?>{
      'created_at': timestamp,
      'project_root': projectRoot,
      'incident': <String, Object?>{'reason': reason, 'detail': ?detail},
      'state': state,
      'status': status,
      'telemetry': telemetry,
      'git': git,
      'run_log_excerpt': runLogExcerpt,
    };
    final sanitizedPayload = _redactionService.sanitizeObject(payload);
    final bundleMap = (sanitizedPayload.value as Map).cast<String, Object?>();
    if (sanitizedPayload.report.applied) {
      bundleMap['redaction'] = _redactionService.buildMetadata(
        sanitizedPayload.report,
      );
    }

    File(
      bundlePath,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(bundleMap));
    return IncidentBundle(path: bundlePath, runLogExcerpt: runLogExcerpt);
  }

  Map<String, Object?> _readState(String statePath) {
    try {
      final state = StateStore(statePath).read();
      return state.toJson();
    } catch (error) {
      return <String, Object?>{'error': error.toString()};
    }
  }

  Map<String, Object?> _readStatus(String projectRoot) {
    try {
      final status = _runService.getStatus(projectRoot);
      return <String, Object?>{
        'is_running': status.isRunning,
        'pid': status.pid,
        'started_at': status.startedAt,
        'last_loop_at': status.lastLoopAt,
        'consecutive_failures': status.consecutiveFailures,
        'last_error': status.lastError,
        'current_subtask': status.currentSubtask,
        'subtask_queue_size': status.subtaskQueue.length,
        'last_step_summary': status.lastStepSummary == null
            ? null
            : <String, Object?>{
                'step_id': status.lastStepSummary!.stepId,
                'task_id': status.lastStepSummary!.taskId,
                'subtask_id': status.lastStepSummary!.subtaskId,
                'decision': status.lastStepSummary!.decision,
                'event': status.lastStepSummary!.event,
                'timestamp': status.lastStepSummary!.timestamp,
              },
      };
    } catch (error) {
      return <String, Object?>{'error': error.toString()};
    }
  }

  Map<String, Object?> _readTelemetry(String projectRoot) {
    try {
      final snapshot = _telemetryService.load(projectRoot, recentLimit: 12);
      return <String, Object?>{
        'error_class': snapshot.errorClass,
        'error_kind': snapshot.errorKind,
        'error_message': snapshot.errorMessage,
        'agent_exit_code': snapshot.agentExitCode,
        'agent_stderr_excerpt': snapshot.agentStderrExcerpt,
        'last_error_event': snapshot.lastErrorEvent,
        'health_summary': _healthSummaryPayload(snapshot.healthSummary),
        'recent_events': snapshot.recentEvents
            .map(_eventToPayload)
            .toList(growable: false),
      };
    } catch (error) {
      return <String, Object?>{'error': error.toString()};
    }
  }

  Map<String, Object?> _healthSummaryPayload(RunHealthSummarySnapshot summary) {
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

  Map<String, Object?> _eventToPayload(RunLogEvent event) {
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

  Map<String, Object?> _readGitSnapshot(String projectRoot) {
    final snapshot = <String, Object?>{};
    try {
      final isRepo = _gitService.isGitRepo(projectRoot);
      snapshot['is_git_repo'] = isRepo;
      if (!isRepo) {
        return snapshot;
      }
      snapshot['branch'] = _gitService.currentBranch(projectRoot);
      snapshot['is_clean'] = _gitService.isClean(projectRoot);
      snapshot['has_merge_in_progress'] = _gitService.hasMergeInProgress(
        projectRoot,
      );
      final changed = _gitService.changedPaths(projectRoot);
      snapshot['changed_paths'] = changed.take(40).toList(growable: false);
      snapshot['changed_paths_total'] = changed.length;
      return snapshot;
    } catch (error) {
      snapshot['error'] = error.toString();
      return snapshot;
    }
  }

  List<Map<String, Object?>> _readRunLogExcerpt(String runLogPath) {
    final file = File(runLogPath);
    if (!file.existsSync()) {
      return const [];
    }
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return const [];
    }
    final start = lines.length > 120 ? lines.length - 120 : 0;
    final excerpt = <Map<String, Object?>>[];
    for (final raw in lines.sublist(start)) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          continue;
        }
        final data = decoded['data'];
        final correlation = decoded['correlation'];
        excerpt.add(<String, Object?>{
          'timestamp': decoded['timestamp']?.toString(),
          'event_id': decoded['event_id']?.toString(),
          'correlation_id': decoded['correlation_id']?.toString(),
          'event': decoded['event']?.toString(),
          'message': decoded['message']?.toString(),
          if (correlation is Map)
            'correlation': _filterRunLogData(
              correlation,
              correlationOnly: true,
            ),
          if (data is Map) 'data': _filterRunLogData(data),
        });
      } catch (_) {
        // Ignore malformed lines in incident excerpts.
      }
    }
    return excerpt;
  }

  Map<String, Object?> _filterRunLogData(
    Map data, {
    bool correlationOnly = false,
  }) {
    const baseKeys = <String>{
      'step_id',
      'task_id',
      'subtask_id',
      'attempt_id',
      'review_id',
    };
    const detailKeys = <String>{
      'error_class',
      'error_kind',
      'error',
      'reason',
      'decision',
      'review_decision',
      'retry_count',
      'consecutive_failures',
      'no_progress_steps',
      'command',
      'exit_code',
      'timed_out',
      'backoff_seconds',
      'cooldown_seconds',
      'recovery_reason',
      'lock_pid',
      'lock_pid_alive',
      'lock_last_heartbeat',
    };
    final keys = correlationOnly
        ? baseKeys
        : <String>{...baseKeys, ...detailKeys};
    final filtered = <String, Object?>{};
    for (final key in keys) {
      if (!data.containsKey(key)) {
        continue;
      }
      filtered[key] = data[key];
    }
    return filtered;
  }

  String _buildIncidentPrompt(
    IncidentBundle bundle, {
    required String reason,
    required String? detail,
    required String? overridePrompt,
  }) {
    final detailLine = detail ?? '(none)';
    final eventLines = bundle.runLogExcerpt
        .take(10)
        .map((entry) {
          final ts = entry['timestamp']?.toString() ?? '';
          final event = entry['event']?.toString() ?? '';
          final message = entry['message']?.toString() ?? '';
          final parts = <String>[];
          if (ts.isNotEmpty) {
            parts.add(ts);
          }
          if (event.isNotEmpty) {
            parts.add(event);
          }
          final header = parts.isEmpty ? '' : '[${parts.join(' ')}] ';
          return '- $header${message.trim()}'.trimRight();
        })
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final recentEventsBlock = eventLines.isEmpty
        ? '- (no recent events)'
        : eventLines.join('\n');

    final prefix = (overridePrompt == null || overridePrompt.trim().isEmpty)
        ? 'Fix the current autopilot blocker with one minimal, safe change.'
        : overridePrompt.trim();

    return '''
$prefix

### AUTOPILOT INCIDENT HEAL MODE
Incident reason: $reason
Incident detail: $detailLine
Incident bundle path: ${bundle.path}

Recent reliability events:
$recentEventsBlock

Rules:
1. Read the incident bundle file first.
2. Apply the smallest safe fix that removes the current blocker.
3. Keep all policies enforced (safe_write, shell_allowlist, quality_gate, review gate).
4. Do not bypass tests/analyze/format and do not weaken safeguards.
5. Avoid unrelated refactors.
''';
  }

  bool _didProgress(OrchestratorStepResult result) {
    if (result.autoMarkedDone) {
      return true;
    }
    if (result.plannedTasksAdded > 0) {
      return true;
    }
    if (result.activatedTask) {
      return true;
    }
    if (result.blockedTask) {
      return true;
    }
    if (result.deactivatedTask) {
      return true;
    }
    final decision = result.reviewDecision?.trim().toLowerCase();
    return decision == 'approve';
  }

  bool _isProgressFailure(OrchestratorStepResult result) {
    if (!result.executedCycle || result.blockedTask) {
      return false;
    }
    final decision = result.reviewDecision?.trim().toLowerCase();
    if (decision == 'reject') {
      return true;
    }
    return decision == null || decision.isEmpty;
  }

  String _normalizeReason(String reason) {
    final normalized = reason
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '');
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized;
  }

  String? _normalizeDetail(String? detail) {
    final trimmed = detail?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= 600) {
      return trimmed;
    }
    return '${trimmed.substring(0, 600)}...';
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
}
