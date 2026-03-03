// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_run_service.dart';

extension _OrchestratorRunTelemetry on OrchestratorRunService {
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

  void _seedPlanningAuditCadence(
    String projectRoot, {
    required int stepIndex,
    required ProjectConfig config,
    required String stepId,
  }) {
    try {
      final result = _planningAuditCadenceService.seedForStep(
        projectRoot,
        stepIndex: stepIndex,
        config: config,
      );
      if (!result.due && result.created == 0) {
        return;
      }
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_planning_audit',
        message: 'Planning/audit cadence evaluated',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'due': result.due,
          'created': result.created,
          'skipped': result.skipped,
        },
      );
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_planning_audit_failed',
        message: 'Planning/audit cadence failed',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error': error.toString(),
          'error_class': 'state',
          'error_kind': 'planning_audit',
        },
      );
    }
  }

  AutopilotStepSummary? _readLastStepSummary(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.runLogPath);
    if (!file.existsSync()) {
      return null;
    }
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return null;
    }
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          continue;
        }
        final data = decoded['data'];
        if (data is! Map) {
          continue;
        }
        final stepId = _stringOrNull(data['step_id']);
        if (stepId == null || stepId.isEmpty) {
          continue;
        }
        final taskId =
            _stringOrNull(data['task_id']) ??
            _stringOrNull(data['active_task_id']);
        final subtaskId = _stringOrNull(data['subtask_id']);
        final decision =
            _stringOrNull(data['decision']) ??
            _stringOrNull(data['review_decision']);
        return AutopilotStepSummary(
          stepId: stepId,
          taskId: taskId,
          subtaskId: subtaskId,
          decision: decision,
          event: _stringOrNull(decoded['event']),
          timestamp: _stringOrNull(decoded['timestamp']),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  void _markRunStarted(String projectRoot) {
    _updateRuntimeState(projectRoot, (state) {
      final now = DateTime.now().toUtc().toIso8601String();
      return state.copyWith(
        autopilotRun: state.autopilotRun.copyWith(
          running: true,
          currentMode: 'autopilot_run',
          lastLoopAt: now,
          consecutiveFailures: 0,
          lastError: null,
          lastErrorClass: null,
          lastErrorKind: null,
        ),
        lastUpdated: now,
      );
    });
  }

  void _recordLoopStepSuccess(String projectRoot) {
    _updateRuntimeState(projectRoot, (state) {
      final now = DateTime.now().toUtc().toIso8601String();
      return state.copyWith(
        autopilotRun: state.autopilotRun.copyWith(
          running: true,
          currentMode: 'autopilot_run',
          lastLoopAt: now,
          consecutiveFailures: 0,
          lastError: null,
          lastErrorClass: null,
          lastErrorKind: null,
        ),
        lastUpdated: now,
      );
    });
  }

  void _recordLoopStepFailure(
    String projectRoot,
    String errorMessage, {
    String? errorClass,
    String? errorKind,
    String? event,
  }) {
    final reason = FailureReasonMapper.normalize(
      errorClass: errorClass,
      errorKind: errorKind,
      message: errorMessage,
      event: event,
    );
    _updateRuntimeState(projectRoot, (state) {
      final now = DateTime.now().toUtc().toIso8601String();
      return state.copyWith(
        autopilotRun: state.autopilotRun.copyWith(
          running: true,
          currentMode: 'autopilot_run',
          lastLoopAt: now,
          consecutiveFailures: state.autopilotRun.consecutiveFailures + 1,
          lastError: errorMessage,
          lastErrorClass: reason.errorClass,
          lastErrorKind: reason.errorKind,
        ),
        lastUpdated: now,
      );
    });
  }

  void _recordLoopStepPaused(
    String projectRoot,
    String detail, {
    String? errorClass,
    String? errorKind,
    String? event,
  }) {
    final reason = FailureReasonMapper.normalize(
      errorClass: errorClass,
      errorKind: errorKind,
      message: detail,
      event: event,
    );
    _updateRuntimeState(projectRoot, (state) {
      final now = DateTime.now().toUtc().toIso8601String();
      return state.copyWith(
        autopilotRun: state.autopilotRun.copyWith(
          running: true,
          currentMode: 'autopilot_run',
          lastLoopAt: now,
          consecutiveFailures: 0,
          lastError: detail,
          lastErrorClass: reason.errorClass,
          lastErrorKind: reason.errorKind,
        ),
        lastUpdated: now,
      );
    });
  }

  void _markRunStopped(String projectRoot) {
    _updateRuntimeState(projectRoot, (state) {
      final now = DateTime.now().toUtc().toIso8601String();
      return state.copyWith(
        autopilotRun: state.autopilotRun.copyWith(
          running: false,
          currentMode: null,
        ),
        lastUpdated: now,
      );
    });
  }

  void _updateRuntimeState(
    String projectRoot,
    ProjectState Function(ProjectState state) transform,
  ) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    try {
      final store = StateStore(layout.statePath);
      final current = store.read();
      final updated = transform(current);
      store.write(updated);
    } catch (e) {
      // Runtime state persistence should not break loop execution, but
      // silent failures mask counter/state corruption — log to stderr.
      try {
        stderr.writeln(
          '[OrchestratorRunTelemetry] _updateRuntimeState failed '
          '(error_class=state, error_kind=runtime_state_write): $e',
        );
      } catch (_) {}
    }
  }
}
