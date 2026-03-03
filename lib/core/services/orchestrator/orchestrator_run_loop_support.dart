// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_run_service.dart';

extension _OrchestratorRunLoopSupport on OrchestratorRunService {
  String? _classifyErrorKind(String? message) {
    final reason = FailureReasonMapper.normalize(message: message);
    if (reason.errorKind == FailureReason.unknown.errorKind) {
      return null;
    }
    return reason.errorKind;
  }

  _StepContext _readStepContext(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    try {
      final store = StateStore(layout.statePath);
      final state = store.read();
      final taskId = state.activeTaskId?.trim();
      final subtaskId = state.currentSubtask?.trim();
      return _StepContext(
        taskId: taskId?.isNotEmpty == true ? taskId : null,
        subtaskId: subtaskId?.isNotEmpty == true ? subtaskId : null,
      );
    } catch (_) {
      return const _StepContext();
    }
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
    if (result.didArchitecturePlanning) {
      return true;
    }
    if (result.visionFulfilled != null) {
      return true;
    }
    final decision = result.reviewDecision?.trim().toLowerCase();
    if (decision == 'approve') {
      return true;
    }
    return false;
  }

  bool _isBenignIdleStep({
    required bool stepWasIdle,
    required int consecutiveFailures,
  }) {
    return stepWasIdle && consecutiveFailures == 0;
  }

  String? _stepIssueKind(OrchestratorStepResult result) {
    if (!result.executedCycle) {
      return null;
    }
    if (result.blockedTask) {
      return null;
    }
    final decision = result.reviewDecision?.trim().toLowerCase();
    if (decision == 'reject') {
      return 'review_rejected';
    }
    if (decision == null || decision.isEmpty) {
      return 'no_diff';
    }
    return null;
  }

  Duration _progressFailureCooldown({
    required Duration failedCooldown,
    required Duration fallbackSleep,
  }) {
    if (failedCooldown.inMicroseconds > 0) {
      return failedCooldown;
    }
    if (fallbackSleep.inMicroseconds > 0) {
      return fallbackSleep;
    }
    return Duration.zero;
  }

  bool _releaseFailedActiveTaskForCooldown(
    String projectRoot, {
    required OrchestratorStepResult stepResult,
    required String stepId,
    required int stepIndex,
    required String stepIssueKind,
    required bool unattendedMode,
    required bool reactivateFailed,
  }) {
    if (!unattendedMode) {
      return false;
    }
    if (stepResult.blockedTask || stepResult.deactivatedTask) {
      return false;
    }
    final taskId = stepResult.activeTaskId?.trim() ?? '';
    final taskTitle = stepResult.activeTaskTitle?.trim() ?? '';
    if (taskId.isEmpty && taskTitle.isEmpty) {
      return false;
    }
    try {
      ActivateService().deactivate(projectRoot, keepReview: true);

      // Write per-task cooldown timestamp into STATE.json so the task
      // is not re-selected until the cooldown expires.
      final layout = ProjectLayout(projectRoot);
      final config = ProjectConfig.load(projectRoot);
      final cooldown = _progressFailureCooldown(
        failedCooldown: config.autopilotFailedCooldown,
        fallbackSleep: config.autopilotStepSleep,
      );
      final stateStore = StateStore(layout.statePath);
      final state = stateStore.read();
      // Subtask queue belongs to the previously active task context. Once the
      // task is released for cooldown, clear transient subtask pointers to
      // prevent cross-task carry-over on the next activation.
      final updatedCooldowns = Map<String, String>.from(
        state.taskCooldownUntil,
      );
      if (cooldown.inSeconds > 0) {
        final key = taskId.isNotEmpty ? 'id:$taskId' : 'title:$taskTitle';
        final expiresAt = DateTime.now().toUtc().add(cooldown);
        updatedCooldowns[key] = expiresAt.toIso8601String();
      }
      stateStore.write(
        state.copyWith(
          retryScheduling: state.retryScheduling.copyWith(
            cooldownUntil: updatedCooldowns,
          ),
          subtaskExecution: state.subtaskExecution.copyWith(
            current: null,
            queue: const <String>[],
          ),
        ),
      );

      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_progress_failure_release',
        message: 'Released failed active task for cooldown scheduling',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_kind': stepIssueKind,
          'reactivate_failed': reactivateFailed,
          'cooldown_seconds': cooldown.inSeconds,
          if (taskId.isNotEmpty) 'task_id': taskId,
          if (taskTitle.isNotEmpty) 'task_title': taskTitle,
        },
      );
      return true;
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_progress_failure_release_failed',
        message: 'Failed to release active task after progress failure',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_kind': stepIssueKind,
          'error': error.toString(),
          if (taskId.isNotEmpty) 'task_id': taskId,
          if (taskTitle.isNotEmpty) 'task_title': taskTitle,
        },
      );
      return false;
    }
  }

  /// Tries to block the currently active task and release it for cooldown,
  /// allowing the run loop to continue with a different task.
  ///
  /// Returns `true` if a task was successfully blocked and released, `false`
  /// if no active task exists or the operation fails.
  bool _tryBlockAndReleaseActiveTask(
    String projectRoot, {
    required String stepId,
    required int stepIndex,
    required String? errorKind,
    required String errorMessage,
  }) {
    final layout = ProjectLayout(projectRoot);
    try {
      final stateStore = StateStore(layout.statePath);
      final state = stateStore.read();
      final taskId = state.activeTaskId?.trim() ?? '';
      final taskTitle = state.activeTaskTitle?.trim() ?? '';
      if (taskId.isEmpty && taskTitle.isEmpty) {
        return false;
      }

      ActivateService().deactivate(projectRoot, keepReview: true);

      final config = ProjectConfig.load(projectRoot);
      final cooldown = _progressFailureCooldown(
        failedCooldown: config.autopilotFailedCooldown,
        fallbackSleep: config.autopilotStepSleep,
      );
      final updatedState = stateStore.read();
      final updatedCooldowns = Map<String, String>.from(
        updatedState.taskCooldownUntil,
      );
      if (cooldown.inSeconds > 0) {
        final key = taskId.isNotEmpty ? 'id:$taskId' : 'title:$taskTitle';
        final expiresAt = DateTime.now().toUtc().add(cooldown);
        updatedCooldowns[key] = expiresAt.toIso8601String();
      }
      stateStore.write(
        updatedState.copyWith(
          retryScheduling: updatedState.retryScheduling.copyWith(
            cooldownUntil: updatedCooldowns,
          ),
          subtaskExecution: updatedState.subtaskExecution.copyWith(
            current: null,
            queue: const <String>[],
          ),
        ),
      );

      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_task_blocked_continue',
        message: 'Blocked failing task and continuing run loop',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_kind': errorKind,
          'error_message': errorMessage,
          'cooldown_seconds': cooldown.inSeconds,
          if (taskId.isNotEmpty) 'task_id': taskId,
          if (taskTitle.isNotEmpty) 'task_title': taskTitle,
        },
      );
      return true;
    } catch (releaseError) {
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_task_block_failed',
        message: 'Failed to block active task after error',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_kind': errorKind,
          'release_error': releaseError.toString(),
        },
      );
      return false;
    }
  }

  String _stepIssueMessage(OrchestratorStepResult result) {
    final decision = result.reviewDecision?.trim().toLowerCase();
    final retryCount = result.retryCount;
    final task = result.activeTaskTitle?.trim();
    final subtask = result.currentSubtask?.trim();
    if (decision == 'reject') {
      return 'Step ended with review reject (retry_count=$retryCount)'
          '${task == null || task.isEmpty ? '' : ' for task "$task"'}'
          '${subtask == null || subtask.isEmpty ? '' : ', subtask "$subtask"'}.';
    }
    return 'Step produced no diff (retry_count=$retryCount)'
        '${task == null || task.isEmpty ? '' : ' for task "$task"'}'
        '${subtask == null || subtask.isEmpty ? '' : ', subtask "$subtask"'}.';
  }

  bool _approveBudgetExceeded(int approvals, int budget) {
    if (budget <= 0) {
      return false;
    }
    // budget=5 allows exactly 5 approvals; halt on the 6th.
    return approvals > budget;
  }

  bool _scopeBudgetExceeded({
    required int filesChanged,
    required int additions,
    required int deletions,
    required int maxFiles,
    required int maxAdditions,
    required int maxDeletions,
  }) {
    // maxFiles=100 allows exactly 100 changed files; halt on the 101st.
    final filesExceeded = maxFiles > 0 && filesChanged > maxFiles;
    final additionsExceeded = maxAdditions > 0 && additions > maxAdditions;
    final deletionsExceeded = maxDeletions > 0 && deletions > maxDeletions;
    return filesExceeded || additionsExceeded || deletionsExceeded;
  }

  String _buildRunStepId(String runId, int stepIndex) {
    final normalized = runId.replaceAll(':', '').replaceAll('.', '');
    return 'run-$normalized-$stepIndex';
  }

  Duration _errorBackoff({
    required int failures,
    required Duration baseSleep,
    required String? errorKind,
    Duration? idleSleep,
  }) {
    if (errorKind == 'policy_violation' ||
        errorKind == 'diff_budget' ||
        errorKind == 'git_dirty' ||
        errorKind == 'merge_conflict') {
      return Duration.zero;
    }

    var baseSeconds = baseSleep.inSeconds;
    if (baseSeconds < 1) {
      baseSeconds = 1;
    }
    var maxSeconds = 60;

    switch (errorKind) {
      case 'agent_unavailable':
        if (baseSeconds < 10) {
          baseSeconds = 10;
        }
        maxSeconds = 120;
        break;
      case 'timeout':
        if (baseSeconds < 5) {
          baseSeconds = 5;
        }
        maxSeconds = 120;
        break;
      case 'lock_held':
        final idleSeconds = idleSleep?.inSeconds ?? baseSeconds;
        if (baseSeconds < idleSeconds) {
          baseSeconds = idleSeconds;
        }
        maxSeconds = 90;
        break;
      case 'not_found':
        if (baseSeconds < 8) {
          baseSeconds = 8;
        }
        maxSeconds = 60;
        break;
      case 'provider_quota':
        if (baseSeconds < 30) {
          baseSeconds = 30;
        }
        maxSeconds = 900;
        break;
    }

    var exponent = failures;
    if (exponent < 1) {
      exponent = 1;
    }
    if (exponent > 6) {
      exponent = 6;
    }
    var seconds = baseSeconds * (1 << (exponent - 1));
    if (seconds > maxSeconds) {
      seconds = maxSeconds;
    }
    return Duration(seconds: seconds);
  }

  Duration _preflightBackoff({
    required int failures,
    required Duration idleSleep,
  }) {
    var baseSeconds = idleSleep.inSeconds;
    if (baseSeconds < 5) {
      baseSeconds = 5;
    }
    var exponent = failures;
    if (exponent < 1) {
      exponent = 1;
    }
    if (exponent > 6) {
      exponent = 6;
    }
    var seconds = baseSeconds * (1 << (exponent - 1));
    if (seconds > 900) {
      seconds = 900;
    }
    return Duration(seconds: seconds);
  }

  ProjectConfig _loadConfig(String projectRoot) {
    try {
      return ProjectConfig.load(projectRoot);
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'config_load_failed',
        message: 'Failed to load config; falling back to empty defaults',
        data: {
          'error_class': 'config',
          'error_kind': 'config_parse_error',
          'error': error.toString(),
        },
      );
      return ProjectConfig.empty();
    }
  }

  /// Runs a HITL gate if enabled and the relevant config flag is true.
  ///
  /// Returns [RunLoopTransition.terminate] with reason `'hitl_rejected'` if the
  /// human rejects, or `null` to continue the run loop.
  Future<RunLoopTransition?> _runHitlGate(
    RunLoopContext ctx,
    _AutopilotRunLock lockHandle, {
    required HitlGateEvent event,
    required bool gateFlag,
    String? taskId,
    String? taskTitle,
    int? sprintNumber,
  }) async {
    if (!ctx.params.config.hitlEnabled || !gateFlag) return null;
    ctx.hitlGatePending = true;
    final decision = await _hitlGateService.waitForDecision(
      ctx.params.projectRoot,
      gate: HitlGateInfo(
        event: event,
        stepId: ctx.stepId,
        taskId: taskId,
        taskTitle: taskTitle,
        sprintNumber: sprintNumber,
        createdAt: DateTime.now().toUtc(),
        expiresAt: _hitlExpiry(ctx.params.config),
      ),
      heartbeat: () => _trackedHeartbeatRaw(ctx, lockHandle),
      pollInterval: const Duration(seconds: 5),
      timeout: ctx.params.config.hitl.timeout,
    );
    ctx.hitlGatePending = false;
    if (!decision.approved) {
      _trackedHeartbeat(ctx, lockHandle);
      return const RunLoopTransition.terminate(reason: 'hitl_rejected');
    }
    return null;
  }

  /// Returns the expiry [DateTime] for a HITL gate based on [config.hitl.timeout],
  /// or `null` if the timeout is infinite (i.e. `timeout_minutes == 0`).
  DateTime? _hitlExpiry(ProjectConfig config) {
    final timeout = config.hitl.timeout;
    if (timeout == null) return null;
    return DateTime.now().toUtc().add(timeout);
  }

  int _reflectionThreshold(ProjectConfig config) {
    switch (config.reflectionTriggerMode) {
      case 'task_count':
        return config.reflectionTriggerTaskCount;
      case 'time':
        return config.reflectionTriggerHours;
      case 'loop_count':
      default:
        return config.reflectionTriggerLoopCount;
    }
  }

  void _updateReflectionState(
    String projectRoot,
    ProductivityReflectionResult result,
  ) {
    final layout = ProjectLayout(projectRoot);
    try {
      final store = StateStore(layout.statePath);
      final state = store.read();
      store.write(
        state.copyWith(
          reflection: state.reflection.copyWith(
            lastAt: DateTime.now().toUtc().toIso8601String(),
            count: state.reflection.count + 1,
            tasksCreated:
                state.reflection.tasksCreated + result.optimizationTasksCreated,
          ),
        ),
      );
    } catch (_) {
      // State update is best-effort; do not block the run loop.
    }
    _appendRunLog(
      projectRoot,
      event: 'reflection_complete',
      message: 'Productivity reflection completed',
      data: {
        'triggered': result.triggered,
        'optimization_tasks_created': result.optimizationTasksCreated,
        'patterns': result.patterns,
        if (result.healthReport != null)
          'health_score': result.healthReport!.overallScore,
        if (result.trend != null)
          'trend_direction': result.trend!.overallDirection.name,
      },
    );
  }

  Future<T> _runWithHeartbeat<T>(
    _AutopilotRunLock lockHandle,
    Future<T> Function() action, {
    Duration? lockTtl,
  }) async {
    final effectiveInterval = _heartbeatInterval(lockTtl);
    final abortCompleter = Completer<Never>();
    Timer? timer;
    try {
      lockHandle.heartbeat();
      timer = Timer.periodic(effectiveInterval, (_) {
        try {
          lockHandle.verifyOwnership();
          lockHandle.heartbeat();
        } catch (e) {
          timer?.cancel();
          if (!abortCompleter.isCompleted) {
            abortCompleter.completeError(e);
          }
        }
      });
      // Race the action against a lock-stolen abort signal.
      return await Future.any<T>([
        action(),
        abortCompleter.future,
      ]);
    } finally {
      timer?.cancel();
      if (!abortCompleter.isCompleted) {
        // Prevent the completer from leaking as an unhandled future error.
        abortCompleter.future.ignore();
      }
      try {
        lockHandle.heartbeat();
      } catch (_) {
        // Lock may already be stolen; ignore heartbeat failure on cleanup.
      }
    }
  }

  /// Computes heartbeat interval as `min(lockTtl ~/ 4, 5s)`.
  /// Falls back to 5 seconds when TTL is null or non-positive.
  Duration _heartbeatInterval(Duration? lockTtl) {
    const maxInterval = Duration(seconds: 5);
    if (lockTtl == null || lockTtl.inSeconds < 1) {
      return maxInterval;
    }
    final quarter = Duration(
      milliseconds: lockTtl.inMilliseconds ~/ 4,
    );
    return quarter < maxInterval ? quarter : maxInterval;
  }
}

class _StepContext {
  const _StepContext({this.taskId, this.subtaskId});

  final String? taskId;
  final String? subtaskId;
}
