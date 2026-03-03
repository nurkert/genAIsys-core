// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../config/project_config.dart';
import '../errors/operation_errors.dart';
import '../git/git_service.dart';
import '../ids/task_slugger.dart';
import '../models/project_state.dart';
import '../models/task.dart';
import '../policy/diff_budget_policy.dart';
import '../project_layout.dart';
import 'agents/coding_agent_service.dart';
import 'agents/review_agent_service.dart';
import '../services/review_service.dart';
import 'agents/spec_agent_service.dart';
import '../services/spec_service.dart';
import '../services/error_pattern_registry_service.dart';
import '../services/review_escalation_service.dart';
import 'task_management/task_forensics_service.dart';
import 'task_management/task_pipeline_service.dart';
import 'task_management/done_service.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import '../storage/task_store.dart';
import 'task_management/active_task_resolver.dart';

part 'task_cycle/task_cycle_stages.dart';

class TaskCycleResult {
  TaskCycleResult({
    required this.pipeline,
    required this.reviewRecorded,
    required this.reviewDecision,
    required this.retryCount,
    required this.taskBlocked,
    required this.autoMarkedDone,
    required this.approvedDiffStats,
  });

  final TaskPipelineResult pipeline;
  final bool reviewRecorded;
  final ReviewDecision? reviewDecision;
  final int retryCount;
  final bool taskBlocked;
  final bool autoMarkedDone;
  final DiffStats? approvedDiffStats;
}

class TaskCycleService {
  TaskCycleService({
    TaskPipelineService? taskPipelineService,
    ReviewService? reviewService,
    GitService? gitService,
    DoneService? doneService,
    ActiveTaskResolver? activeTaskResolver,
    ErrorPatternRegistryService? errorPatternRegistryService,
    TaskForensicsService? taskForensicsService,
    SpecAgentService? specAgentService,
    int maxReviewRetries = 3,
  }) : _taskPipelineService = taskPipelineService ?? TaskPipelineService(),
       _reviewService = reviewService ?? ReviewService(),
       _gitService = gitService ?? GitService(),
       _doneService = doneService ?? DoneService(),
       _activeTaskResolver = activeTaskResolver ?? ActiveTaskResolver(),
       _errorPatternRegistryService =
           errorPatternRegistryService ?? ErrorPatternRegistryService(),
       _taskForensicsService = taskForensicsService ?? TaskForensicsService(),
       _specAgentService = specAgentService ?? SpecAgentService(),
       _maxReviewRetries = maxReviewRetries < 1 ? 1 : maxReviewRetries;

  final TaskPipelineService _taskPipelineService;
  final ReviewService _reviewService;
  final GitService _gitService;
  final DoneService _doneService;
  final ActiveTaskResolver _activeTaskResolver;
  final ErrorPatternRegistryService _errorPatternRegistryService;
  final TaskForensicsService _taskForensicsService;
  final SpecAgentService _specAgentService;
  final int _maxReviewRetries;

  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    try {
      final stageContext = _buildStageContext(
        projectRoot: projectRoot,
        codingPrompt: codingPrompt,
        testSummary: testSummary,
        overwriteArtifacts: overwriteArtifacts,
        isSubtask: isSubtask,
        subtaskDescription: subtaskDescription,
        maxReviewRetries: maxReviewRetries,
      );

      _appendRunLog(
        projectRoot,
        event: 'task_cycle_start',
        message: 'Task cycle started',
        data: stageContext.toRunLogStartData(),
      );

      final resumed = await _resumeApprovedDeliveryIfPending(
        projectRoot,
        isSubtask: stageContext.isSubtask,
        subtaskDescription: stageContext.subtaskDescription,
      );
      if (resumed != null) {
        return resumed;
      }

      final pipelineStage = await _runPipelineStage(
        projectRoot,
        stageContext: stageContext,
      );
      final reviewStage = await _applyReviewStage(
        projectRoot,
        stageContext: stageContext,
        pipelineStage: pipelineStage,
      );

      _appendRunLog(
        projectRoot,
        event: 'task_cycle_end',
        message: 'Task cycle completed',
        data: {
          'root': projectRoot,
          'review_recorded': reviewStage.reviewRecorded,
          'review_decision': pipelineStage.review?.decision.name ?? '',
          'auto_marked_done': reviewStage.autoMarkedDone,
          'retry_count': reviewStage.retryCount,
          'task_blocked': reviewStage.taskBlocked,
          if (stageContext.subtaskDescription != null &&
              stageContext.subtaskDescription!.trim().isNotEmpty)
            'subtask': stageContext.subtaskDescription!.trim(),
        },
      );

      return TaskCycleResult(
        pipeline: pipelineStage.pipeline,
        reviewRecorded: reviewStage.reviewRecorded,
        reviewDecision: pipelineStage.review?.decision,
        retryCount: reviewStage.retryCount,
        taskBlocked: reviewStage.taskBlocked,
        autoMarkedDone: reviewStage.autoMarkedDone,
        approvedDiffStats: reviewStage.approvedDiffStats,
      );
    } catch (error, stackTrace) {
      throw classifyOperationError(error, stackTrace);
    }
  }

  TaskCategory _resolveTaskCategory(String projectRoot) {
    final activeTask = _activeTaskResolver.resolve(projectRoot);
    return activeTask?.category ?? TaskCategory.unknown;
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

  String? _extractNote(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lines = trimmed.split('\n');
    if (lines.length == 1) {
      return lines.first.trim();
    }
    final remainder = lines.skip(1).join('\n').trim();
    return remainder.isEmpty ? null : remainder;
  }

  void _commitAndPush(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) {
      throw StateError('Not a git repository: $projectRoot');
    }
    if (_gitService.hasChanges(projectRoot)) {
      _gitService.addAll(projectRoot);
      _gitService.commit(projectRoot, _commitMessage(projectRoot));
    }

    final remote = _gitService.defaultRemote(projectRoot);
    if (remote == null) {
      return;
    }
    final branch = _gitService.currentBranch(projectRoot);
    try {
      _gitService.push(projectRoot, remote, branch);
    } catch (e) {
      // Do not rethrow: the commit is local, review state stays "approved",
      // and _resumeApprovedDeliveryIfPending will retry push on next cycle.
      _appendRunLog(
        projectRoot,
        event: 'push_failed',
        message:
            'Git push failed after commit — delivery will retry on next cycle',
        data: {
          'root': projectRoot,
          'remote': remote,
          'branch': branch,
          'error': e.toString(),
          'error_class': 'delivery',
          'error_kind': 'push_failed',
        },
      );
    }
  }

  DiffStats? _captureDiffStats(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return null;
    }
    try {
      return _gitService.diffStats(projectRoot);
    } catch (_) {
      // Best-effort: diff stats are optional for commit messages.
      return null;
    }
  }

  String _commitMessage(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final title = state.activeTaskTitle?.trim();
    if (title == null || title.isEmpty) {
      return 'chore: task update';
    }
    return 'task: $title';
  }

  int _incrementRetry(String projectRoot, {String? subtaskDescription}) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();

    // For subtask-level retry keys, always compute fresh (they are granular
    // diagnostics and do not need locking).  For task-level keys (no
    // subtaskDescription), use the persisted activeTaskRetryKey if available
    // so the key stays stable even if the active task context changes mid-cycle.
    String? key;
    if (subtaskDescription == null) {
      final persisted = state.activeTaskRetryKey;
      if (persisted != null && persisted.isNotEmpty) {
        key = persisted;
      }
    }

    key ??= _retryKey(
      state.activeTaskId,
      state.activeTaskTitle,
      subtaskDescription: subtaskDescription,
    );

    if (key == null) {
      key = 'unknown:fallback';
      RunLogStore(layout.runLogPath).append(
        event: 'retry_key_fallback',
        message: 'All retry key inputs null/empty, using fallback key',
        data: {
          'root': projectRoot,
          'active_task_id': state.activeTaskId ?? '',
          'active_task_title': state.activeTaskTitle ?? '',
          'subtask_description': subtaskDescription ?? '',
          'error_class': 'pipeline',
          'error_kind': 'retry_key_null',
        },
      );
    }

    // Persist the retry key on first task-level increment so it remains
    // stable across cycles even if activeTaskId / activeTaskTitle change.
    final freshState = store.read();
    final needsPersist = subtaskDescription == null &&
        (freshState.activeTaskRetryKey == null ||
            freshState.activeTaskRetryKey!.isEmpty);

    final counts = Map<String, int>.from(freshState.taskRetryCounts);
    final nextCount = (counts[key] ?? 0) + 1;
    counts[key] = nextCount;
    store.write(
      freshState.copyWith(
        retryScheduling: freshState.retryScheduling.copyWith(
          retryCounts: Map.unmodifiable(counts),
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
        activeTask: needsPersist
            ? freshState.activeTask.copyWith(retryKey: key)
            : freshState.activeTask,
      ),
    );
    return nextCount;
  }

  void _clearRetry(String projectRoot, {String? subtaskDescription}) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();

    // For task-level clears (no subtask), prefer the persisted key set at
    // activation time.  This ensures the correct counter is cleared even if
    // activeTaskId/activeTaskTitle changed or were nulled mid-cycle.
    String? key;
    if (subtaskDescription == null) {
      final persisted = state.activeTaskRetryKey;
      if (persisted != null && persisted.isNotEmpty) {
        key = persisted;
      }
    }
    key ??= _retryKey(
          state.activeTaskId,
          state.activeTaskTitle,
          subtaskDescription: subtaskDescription,
        ) ??
        'unknown:fallback';

    if (!state.taskRetryCounts.containsKey(key)) {
      return;
    }
    final counts = Map<String, int>.from(state.taskRetryCounts);
    counts.remove(key);
    store.write(
      state.copyWith(
        retryScheduling: state.retryScheduling.copyWith(
          retryCounts: Map.unmodifiable(counts),
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  void _clearActiveTask(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();
    store.write(
      state.copyWith(
        activeTask: state.activeTask.copyWith(
          id: null,
          title: null,
          retryKey: null,
          forensicRecoveryAttempted: false,
          forensicGuidance: null,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  void _clearSubtasks(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();
    if (state.subtaskQueue.isEmpty && state.currentSubtask == null) {
      return;
    }
    store.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          queue: const [],
          current: null,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Commits any post-done state changes to maintain the clean-end invariant.
  ///
  /// After `markDone()` commits TASKS.md + STATE.json, subsequent operations
  /// (audit trail recording, `_clearSubtasks()`, `_clearTaskCooldown()`) dirty
  /// the worktree.  This method persists those changes so the next step can
  /// checkout cleanly.
  void _persistStateCleanupAfterDone(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) return;
    if (!_gitService.hasChanges(projectRoot)) return;
    try {
      _gitService.addAll(projectRoot);
      _gitService.commit(
        projectRoot,
        'meta(state): finalize task completion',
      );
    } catch (commitError) {
      try {
        _gitService.stashPush(
          projectRoot,
          message:
              'genaisys:done-cleanup-fallback:${DateTime.now().toUtc().microsecondsSinceEpoch}',
          includeUntracked: true,
        );
      } catch (_) {
        // Best-effort: stash failed, try hard discard to maintain clean-end invariant.
        try {
          _gitService.discardWorkingChanges(projectRoot);
        } catch (_) {
          // Best-effort: hard discard is last resort.
        }
        _appendRunLog(
          projectRoot,
          event: 'done_state_discard_fallback',
          message:
              'Post-done stash failed, discarded working changes as last resort',
          data: {
            'root': projectRoot,
            'error_class': 'delivery',
            'error_kind': 'done_cleanup_discard',
          },
        );
      }
      _appendRunLog(
        projectRoot,
        event: 'done_state_cleanup_commit_failed',
        message: 'Post-done state commit failed, stashed as fallback',
        data: {
          'root': projectRoot,
          'error': commitError.toString(),
          'error_class': 'delivery',
          'error_kind': 'done_cleanup_commit_failed',
        },
      );
    }
  }

  /// Commits any post-block STATE.json changes to maintain the clean-end
  /// invariant.  After `blockActive()` commits TASKS.md + STATE.json, the
  /// subsequent `_clearActiveTask()` / `_clearSubtasks()` calls dirty
  /// STATE.json again.  This method persists those changes via git commit
  /// (or falls back to stash if commit fails).
  void _persistStateCleanupAfterBlock(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) return;
    if (!_gitService.hasChanges(projectRoot)) return;
    try {
      _gitService.addAll(projectRoot);
      _gitService.commit(
        projectRoot,
        'meta(state): clear active task after block',
      );
    } catch (commitError) {
      // Fallback: stash to maintain clean-end invariant.
      try {
        _gitService.stashPush(
          projectRoot,
          message:
              'genaisys:block-cleanup-fallback:${DateTime.now().toUtc().microsecondsSinceEpoch}',
          includeUntracked: true,
        );
      } catch (_) {
        // Best-effort: stash failed, try hard discard to maintain clean-end invariant.
        try {
          _gitService.discardWorkingChanges(projectRoot);
        } catch (_) {
          // Best-effort: hard discard is last resort.
        }
        _appendRunLog(
          projectRoot,
          event: 'block_state_discard_fallback',
          message:
              'Post-block stash failed, discarded working changes as last resort',
          data: {
            'root': projectRoot,
            'error_class': 'delivery',
            'error_kind': 'block_cleanup_discard',
          },
        );
      }
      _appendRunLog(
        projectRoot,
        event: 'block_state_cleanup_commit_failed',
        message: 'Post-block STATE.json commit failed, stashed as fallback',
        data: {
          'root': projectRoot,
          'error': commitError.toString(),
          'error_class': 'delivery',
          'error_kind': 'block_cleanup_commit_failed',
        },
      );
    }
  }

  String? _retryKey(
    String? taskId,
    String? taskTitle, {
    String? subtaskDescription,
  }) {
    final normalizedSubtask = subtaskDescription?.trim();
    final normalizedId = taskId?.trim();
    if (normalizedId != null && normalizedId.isNotEmpty) {
      if (normalizedSubtask != null && normalizedSubtask.isNotEmpty) {
        return 'subtask:id:$normalizedId:${normalizedSubtask.toLowerCase()}';
      }
      return 'id:$normalizedId';
    }
    final normalizedTitle = taskTitle?.trim().toLowerCase();
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      if (normalizedSubtask != null && normalizedSubtask.isNotEmpty) {
        return 'subtask:title:$normalizedTitle:${normalizedSubtask.toLowerCase()}';
      }
      return 'title:$normalizedTitle';
    }
    if (normalizedSubtask != null && normalizedSubtask.isNotEmpty) {
      return 'subtask:${normalizedSubtask.toLowerCase()}';
    }
    return null;
  }

  /// Appends a `[P3] [QA]` follow-up task to TASKS.md for advisory notes
  /// discovered during a verification review.
  void _appendFollowUpQaTask(
    String projectRoot,
    List<String> advisoryNotes,
  ) {
    if (advisoryNotes.isEmpty) return;
    try {
      final layout = ProjectLayout(projectRoot);
      final state = StateStore(layout.statePath).read();
      final taskTitle = state.activeTaskTitle ?? 'unknown task';
      final escalation = ReviewEscalationService();
      final line = escalation.buildFollowUpTaskLine(taskTitle, advisoryNotes);
      if (line == null) return;
      final tasksFile = File(layout.tasksPath);
      if (!tasksFile.existsSync()) return;
      final content = tasksFile.readAsStringSync();
      tasksFile.writeAsStringSync('$content\n$line\n');
      _appendRunLog(
        projectRoot,
        event: 'review_advisory_followup_created',
        message: 'Created follow-up QA task for ${advisoryNotes.length} '
            'advisory note(s)',
        data: {
          'root': projectRoot,
          'task': taskTitle,
          'advisory_count': advisoryNotes.length,
        },
      );
    } catch (_) {
      // Non-critical: do not block pipeline if follow-up task creation fails.
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
    RunLogStore(
      layout.runLogPath,
    ).append(event: event, message: message, data: data);
  }

  /// Returns `true` when the orchestrator is running in unattended (autopilot)
  /// mode.  Checks for `autopilot.lock`, `autopilotRunning` flag, or
  /// `currentMode` starting with `autopilot_`.
  bool _isUnattendedMode(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    if (File(layout.autopilotLockPath).existsSync()) return true;
    final state = StateStore(layout.statePath).read();
    if (state.autopilotRunning) return true;
    final mode = state.currentMode;
    if (mode != null && mode.startsWith('autopilot_')) return true;
    return false;
  }

  Future<TaskCycleResult?> _resumeApprovedDeliveryIfPending(
    String projectRoot, {
    required bool isSubtask,
    required String? subtaskDescription,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final reviewApproved =
        state.reviewStatus?.trim().toLowerCase() == 'approved';
    final hasActiveTask =
        (state.activeTaskId?.trim().isNotEmpty ?? false) ||
        (state.activeTaskTitle?.trim().isNotEmpty ?? false);
    if (!reviewApproved || !hasActiveTask) {
      return null;
    }

    final taskId = state.activeTaskId?.trim();
    final taskTitle = state.activeTaskTitle?.trim();
    final retrySubtask = subtaskDescription ?? state.currentSubtask;
    _appendRunLog(
      projectRoot,
      event: 'task_cycle_delivery_resume_start',
      message: 'Resuming approved delivery before running a new coding cycle',
      data: {
        'root': projectRoot,
        'is_subtask': isSubtask,
        if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
        if (taskTitle != null && taskTitle.isNotEmpty) 'task': taskTitle,
        if (retrySubtask != null && retrySubtask.trim().isNotEmpty)
          'subtask_id': retrySubtask.trim(),
      },
    );

    _commitAndPush(projectRoot);
    if (isSubtask) {
      _clearRetry(projectRoot, subtaskDescription: retrySubtask);
      // Also clear task-level retry key on subtask approve.
      _clearRetry(projectRoot);
      _reviewService.clear(
        projectRoot,
        note: 'Cleared approved review after subtask delivery resume.',
      );
    } else {
      _clearRetry(projectRoot);
      await _doneService.markDone(projectRoot);
      _persistStateCleanupAfterDone(projectRoot);
    }

    _appendRunLog(
      projectRoot,
      event: 'task_cycle_delivery_resume_end',
      message: 'Approved delivery resumed successfully',
      data: {
        'root': projectRoot,
        'auto_marked_done': !isSubtask,
        if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
        if (taskTitle != null && taskTitle.isNotEmpty) 'task': taskTitle,
        if (retrySubtask != null && retrySubtask.trim().isNotEmpty)
          'subtask_id': retrySubtask.trim(),
      },
    );

    return TaskCycleResult(
      pipeline: _noopPipelineResult(),
      reviewRecorded: false,
      reviewDecision: ReviewDecision.approve,
      retryCount: 0,
      taskBlocked: false,
      autoMarkedDone: !isSubtask,
      approvedDiffStats: _captureDiffStats(projectRoot),
    );
  }

  TaskPipelineResult _noopPipelineResult() {
    const response = AgentResponse(exitCode: 0, stdout: '', stderr: '');
    return TaskPipelineResult(
      plan: SpecAgentResult(
        path: '(delivery-resume)',
        kind: SpecKind.plan,
        wrote: false,
        usedFallback: false,
        response: response,
      ),
      spec: SpecAgentResult(
        path: '(delivery-resume)',
        kind: SpecKind.spec,
        wrote: false,
        usedFallback: false,
        response: response,
      ),
      subtasks: SpecAgentResult(
        path: '(delivery-resume)',
        kind: SpecKind.subtasks,
        wrote: false,
        usedFallback: false,
        response: response,
      ),
      coding: CodingAgentResult(
        path: '(delivery-resume)',
        usedFallback: false,
        response: response,
      ),
      review: null,
    );
  }
}
