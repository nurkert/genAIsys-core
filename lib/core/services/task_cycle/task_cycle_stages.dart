// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../task_cycle_service.dart';

class _TaskCycleStageContext {
  const _TaskCycleStageContext({
    required this.projectRoot,
    required this.codingPrompt,
    required this.testSummary,
    required this.overwriteArtifacts,
    required this.isSubtask,
    required this.subtaskDescription,
    required this.effectiveMaxReviewRetries,
    required this.category,
    required this.reviewPersona,
  });

  final String projectRoot;
  final String codingPrompt;
  final String? testSummary;
  final bool overwriteArtifacts;
  final bool isSubtask;
  final String? subtaskDescription;
  final int effectiveMaxReviewRetries;
  final TaskCategory category;
  final ReviewPersona reviewPersona;

  Map<String, Object?> toRunLogStartData() {
    return {
      'root': projectRoot,
      'overwrite': overwriteArtifacts,
      'is_subtask': isSubtask,
      if (subtaskDescription != null && subtaskDescription!.trim().isNotEmpty)
        'subtask': subtaskDescription!.trim(),
      'review_persona': reviewPersona.name,
      'has_test_summary': testSummary != null && testSummary!.trim().isNotEmpty,
    };
  }
}

class _TaskCyclePipelineStage {
  const _TaskCyclePipelineStage({
    required this.pipeline,
    required this.review,
    required this.noDiff,
  });

  final TaskPipelineResult pipeline;
  final ReviewAgentResult? review;
  final bool noDiff;
}

class _TaskCycleReviewStage {
  const _TaskCycleReviewStage({
    required this.reviewRecorded,
    required this.autoMarkedDone,
    required this.retryCount,
    required this.taskBlocked,
    required this.approvedDiffStats,
  });

  final bool reviewRecorded;
  final bool autoMarkedDone;
  final int retryCount;
  final bool taskBlocked;
  final DiffStats? approvedDiffStats;
}

extension _TaskCycleStageBoundaries on TaskCycleService {
  _TaskCycleStageContext _buildStageContext({
    required String projectRoot,
    required String codingPrompt,
    required String? testSummary,
    required bool overwriteArtifacts,
    required bool isSubtask,
    required String? subtaskDescription,
    required int? maxReviewRetries,
  }) {
    final effectiveMaxReviewRetries =
        maxReviewRetries != null && maxReviewRetries > 0
        ? maxReviewRetries
        : _maxReviewRetries;
    final category = _resolveTaskCategory(projectRoot);
    final selectedPersona = _selectReviewPersona(category);
    return _TaskCycleStageContext(
      projectRoot: projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary,
      overwriteArtifacts: overwriteArtifacts,
      isSubtask: isSubtask,
      subtaskDescription: subtaskDescription,
      effectiveMaxReviewRetries: effectiveMaxReviewRetries,
      category: category,
      reviewPersona: selectedPersona,
    );
  }

  Future<_TaskCyclePipelineStage> _runPipelineStage(
    String projectRoot, {
    required _TaskCycleStageContext stageContext,
  }) async {
    // Compute review contract lock escalation.
    final config = ProjectConfig.load(projectRoot);
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final retryKey =
        _retryKey(state.activeTaskId, state.activeTaskTitle);
    final currentRetryCount = retryKey != null
        ? (state.taskRetryCounts[retryKey] ?? 0)
        : 0;

    List<String> contractNotes = const [];
    if (config.autopilotReviewContractLockEnabled && currentRetryCount > 0) {
      contractNotes = _taskForensicsService.collectRejectNotes(
        projectRoot,
        taskTitle: state.activeTaskTitle,
      );
    }
    final escalation = ReviewEscalationService().computeReviewMode(
      retryCount: currentRetryCount,
      contractLockEnabled: config.autopilotReviewContractLockEnabled,
      previousRejectNotes: contractNotes,
    );

    if (escalation.mode == ReviewMode.verificationReview) {
      _appendRunLog(
        projectRoot,
        event: 'review_contract_lock',
        message:
            'Review scope locked to ${contractNotes.length} contract items',
        data: {
          'root': projectRoot,
          'retry_count': currentRetryCount,
          'contract_items': contractNotes.length,
        },
      );
    }

    final pipeline = await _taskPipelineService.run(
      projectRoot,
      codingPrompt: stageContext.codingPrompt,
      testSummary: stageContext.testSummary,
      overwriteArtifacts: stageContext.overwriteArtifacts,
      reviewPersona: stageContext.reviewPersona,
      taskCategory: stageContext.category,
      contractNotes: escalation.contractNotes,
      retryCount: currentRetryCount,
    );
    final review = pipeline.review;
    final noDiff = review == null && pipeline.coding.response.ok;
    return _TaskCyclePipelineStage(
      pipeline: pipeline,
      review: review,
      noDiff: noDiff,
    );
  }

  Future<_TaskCycleReviewStage> _applyReviewStage(
    String projectRoot, {
    required _TaskCycleStageContext stageContext,
    required _TaskCyclePipelineStage pipelineStage,
  }) async {
    final review = pipelineStage.review;
    var reviewRecorded = false;
    var autoMarkedDone = false;
    var retryCount = 0;
    var taskBlocked = false;
    DiffStats? approvedDiffStats;

    if (review != null) {
      _reviewService.recordDecision(
        projectRoot,
        decision: review.decision == ReviewDecision.approve
            ? 'approve'
            : 'reject',
        note: _extractNote(review.response.stdout),
        testSummary: stageContext.testSummary,
      );
      reviewRecorded = true;
      if (review.decision == ReviewDecision.approve) {
        // Create follow-up QA task for advisory notes from verification reviews.
        if (review.advisoryNotes.isNotEmpty) {
          _appendFollowUpQaTask(projectRoot, review.advisoryNotes);
        }
        approvedDiffStats = _captureDiffStats(projectRoot);
        // Feature C: accumulate advisory notes for next subtask.
        if (review.advisoryNotes.isNotEmpty) {
          final layout = ProjectLayout(projectRoot);
          final store = StateStore(layout.statePath);
          final state = store.read();
          final existing = state.activeTask.accumulatedAdvisoryNotes;
          final merged = [...existing, ...review.advisoryNotes].take(6).toList();
          store.write(state.copyWith(
            activeTask: state.activeTask.copyWith(
              accumulatedAdvisoryNotes: List.unmodifiable(merged),
              lastRejectCommitSha: null, // Feature D: clear on approve
            ),
            lastUpdated: DateTime.now().toUtc().toIso8601String(),
          ));
        } else {
          // Feature D: clear lastRejectCommitSha on approve even without notes.
          final layout = ProjectLayout(projectRoot);
          final store = StateStore(layout.statePath);
          final state = store.read();
          if (state.activeTask.lastRejectCommitSha != null) {
            store.write(state.copyWith(
              activeTask: state.activeTask.copyWith(lastRejectCommitSha: null),
              lastUpdated: DateTime.now().toUtc().toIso8601String(),
            ));
          }
        }
        // Clear subtask-level retry key if applicable.
        if (stageContext.isSubtask && stageContext.subtaskDescription != null) {
          _clearRetry(
            projectRoot,
            subtaskDescription: stageContext.subtaskDescription,
          );
        }
        // Always clear task-level retry key on approve.
        _clearRetry(projectRoot);
        if (stageContext.isSubtask) {
          _maybeCommitSubtask(projectRoot, stageContext.subtaskDescription);
        } else {
          _commitAndPush(projectRoot);
        }
        if (stageContext.isSubtask) {
          // If commit/push succeeded, subtask delivery is complete and keeping an
          // "approved" review status around can cause later steps to incorrectly
          // resume delivery and skip queued subtasks.
          _reviewService.clear(
            projectRoot,
            note: 'Cleared approved review after successful subtask delivery.',
          );
        }
        if (!stageContext.isSubtask) {
          await _doneService.markDone(projectRoot);
          // Safety net: ensure subtask queue is cleared after task completion.
          // DoneService.markDone already does this (Fix 3), but this is
          // defense-in-depth in case the done path is reached via a different
          // code path.
          _clearSubtasks(projectRoot);
          // Persist post-done state changes (audit files, STATE.json
          // mutations from _clearSubtasks / _clearTaskCooldown) so the
          // worktree is clean before the next step's checkout.
          _persistStateCleanupAfterDone(projectRoot);
          autoMarkedDone = true;
        }
      } else {
        // Feature 1b: Attempt a reactive split when the reviewer signals that
        // the subtask is too large.  This runs BEFORE _incrementRetry so a
        // successful split does not consume a retry budget slot.
        final rejectNote = _extractNote(review.response.stdout) ?? '';
        final didSplit = await _trySplitSubtaskOnReject(
          projectRoot,
          stageContext: stageContext,
          rejectNote: rejectNote,
        );
        if (didSplit) {
          // Normalize reject state, skip retry increment, and return early.
          _reviewService.normalizeAfterReject(
            projectRoot,
            note: rejectNote.isNotEmpty ? rejectNote : null,
          );
          _updateErrorPatternRegistryOnReject(projectRoot, review);
          return _TaskCycleReviewStage(
            reviewRecorded: true,
            autoMarkedDone: false,
            retryCount: 0,
            taskBlocked: false,
            approvedDiffStats: null,
          );
        }

        // Always increment at task level (no subtask) for blocking decisions.
        // This prevents the counter from resetting when subtask descriptions
        // change across replanning cycles after rejection.
        retryCount = _incrementRetry(projectRoot);
        // Also track subtask-level retry for granular diagnostics.
        if (stageContext.isSubtask && stageContext.subtaskDescription != null) {
          _incrementRetry(
            projectRoot,
            subtaskDescription: stageContext.subtaskDescription,
          );
        }
        _reviewService.normalizeAfterReject(
          projectRoot,
          note: _extractNote(review.response.stdout),
        );
        // Update error pattern registry with the reject.
        _updateErrorPatternRegistryOnReject(projectRoot, review);
        // Feature D: save HEAD SHA so next review only shows delta diff.
        if (_gitService.isGitRepo(projectRoot)) {
          try {
            final sha = _gitService.headCommitSha(projectRoot);
            final layout = ProjectLayout(projectRoot);
            final store = StateStore(layout.statePath);
            final state = store.read();
            store.write(state.copyWith(
              activeTask: state.activeTask.copyWith(lastRejectCommitSha: sha),
              lastUpdated: DateTime.now().toUtc().toIso8601String(),
            ));
          } catch (_) {
            // Non-critical: silently skip if HEAD SHA not available.
          }
        }
        if (retryCount >= stageContext.effectiveMaxReviewRetries) {
          taskBlocked = _forensicGatedBlock(
            projectRoot,
            retryCount: retryCount,
            stage: 'review_reject',
          );
        }
      }
    } else if (pipelineStage.noDiff) {
      // Task-level retry for blocking (same rationale as reject handler).
      retryCount = _incrementRetry(projectRoot);
      if (stageContext.isSubtask && stageContext.subtaskDescription != null) {
        _incrementRetry(
          projectRoot,
          subtaskDescription: stageContext.subtaskDescription,
        );
      }
      if (retryCount >= stageContext.effectiveMaxReviewRetries) {
        final reason = 'Auto-cycle: no diff after $retryCount attempt(s)';
        taskBlocked = _blockActiveOrRecoverMissingTask(
          projectRoot,
          reason: reason,
          stage: 'no_diff',
          retryCount: retryCount,
        );
      }
    }

    return _TaskCycleReviewStage(
      reviewRecorded: reviewRecorded,
      autoMarkedDone: autoMarkedDone,
      retryCount: retryCount,
      taskBlocked: taskBlocked,
      approvedDiffStats: approvedDiffStats,
    );
  }

  bool _blockActiveOrRecoverMissingTask(
    String projectRoot, {
    required String reason,
    required String stage,
    required int retryCount,
  }) {
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final diagnostics = <String, Object?>{
      'blocking_stage': stage,
      'retry_count': retryCount,
      'error_class': 'pipeline',
      'error_kind': 'dead_letter',
      if (state.lastError != null && state.lastError!.trim().isNotEmpty)
        'last_error': state.lastError!.trim(),
      if (state.lastErrorClass != null &&
          state.lastErrorClass!.trim().isNotEmpty)
        'last_error_class': state.lastErrorClass!.trim(),
      if (state.lastErrorKind != null && state.lastErrorKind!.trim().isNotEmpty)
        'last_error_kind': state.lastErrorKind!.trim(),
    };
    try {
      _doneService.blockActive(
        projectRoot,
        reason: reason,
        diagnostics: diagnostics,
      );
      _appendRunLog(
        projectRoot,
        event: 'task_dead_letter',
        message: 'Task quarantined after exhausting retries',
        data: {
          'root': projectRoot,
          'task': state.activeTaskTitle ?? '',
          if (state.activeTaskId != null &&
              state.activeTaskId!.trim().isNotEmpty)
            'task_id': state.activeTaskId!.trim(),
          if (state.currentSubtask != null &&
              state.currentSubtask!.trim().isNotEmpty)
            'subtask_id': state.currentSubtask!.trim(),
          ...diagnostics,
          'reason': reason,
        },
      );
      _clearActiveTask(projectRoot);
      _clearSubtasks(projectRoot);
      _persistStateCleanupAfterBlock(projectRoot);
      return true;
    } on StateError catch (error) {
      final message = error.message;
      if (message.contains('Active task not found in TASKS.md')) {
        _appendRunLog(
          projectRoot,
          event: 'task_cycle_stale_active_task_recovered',
          message: 'Recovered stale active task state after retry exhaustion',
          data: {
            'root': projectRoot,
            'stage': stage,
            'retry_count': retryCount,
            'reason': reason,
            'error_class': 'pipeline',
            'error_kind': 'not_found',
          },
        );
        _clearActiveTask(projectRoot);
        _clearSubtasks(projectRoot);
        _persistStateCleanupAfterBlock(projectRoot);
        return true;
      }
      rethrow;
    }
  }

  /// Attempts deterministic queue narrowing when forensic recovery was already
  /// tried and the task is still classified as [specTooLarge].
  ///
  /// Returns `true` when narrowing was applied (task should retry without
  /// blocking). Returns `false` when narrowing cannot help (hard block).
  bool _tryForcedNarrowing(
    String projectRoot, {
    required StateStore store,
    required ProjectState state,
    required int retryCount,
    required String stage,
    required ProjectConfig config,
  }) {
    final maxSize = config.subtaskForcedNarrowingMaxSize;
    if (maxSize <= 0) return false;

    // Re-diagnose with fresh state (cheap heuristic, no LLM call).
    final diagnosis = _taskForensicsService.diagnose(
      projectRoot,
      taskTitle: state.activeTaskTitle,
      retryCount: retryCount,
    );
    if (diagnosis.classification != ForensicClassification.specTooLarge) {
      return false;
    }

    final freshState = store.read();
    final queue = freshState.subtaskExecution.queue;
    if (queue.length <= maxSize) {
      return false; // Already within the allowed size.
    }

    final narrowed = queue.take(maxSize).toList(growable: false);
    store.write(
      freshState.copyWith(
        subtaskExecution: freshState.subtaskExecution.copyWith(
          queue: narrowed,
          current: null,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    _appendRunLog(
      projectRoot,
      event: 'subtask_scope_forced_narrowing',
      message:
          'Deterministic scope narrowing: subtask queue truncated to $maxSize',
      data: {
        'root': projectRoot,
        'task': state.activeTaskTitle ?? '',
        'original_queue_size': queue.length,
        'narrowed_to': maxSize,
        'stage': stage,
        'retry_count': retryCount,
        'error_class': 'pipeline',
        'error_kind': 'forced_narrowing',
      },
    );
    return true;
  }

  /// Performs forensic diagnosis before blocking a task.
  ///
  /// If the diagnosis suggests a recoverable action (redecompose, regenerate
  /// spec, retry with guidance), the task is given one forensic recovery
  /// attempt. On the second failure (or if no recovery is possible), the
  /// task is blocked as usual.
  bool _forensicGatedBlock(
    String projectRoot, {
    required int retryCount,
    required String stage,
  }) {
    final config = ProjectConfig.load(projectRoot);
    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();

    // When forensic recovery is disabled, skip forensic analysis and block.
    if (!config.pipelineForensicRecoveryEnabled) {
      final reason =
          'Auto-cycle: review rejected $retryCount time(s) '
          '(forensic recovery disabled)';
      return _blockActiveOrRecoverMissingTask(
        projectRoot,
        reason: reason,
        stage: stage,
        retryCount: retryCount,
      );
    }

    // If forensic recovery was already attempted, try deterministic narrowing
    // before hard-blocking (Feature 4: 2nd-pass scope narrowing).
    if (state.forensicRecoveryAttempted) {
      if (_tryForcedNarrowing(
        projectRoot,
        store: store,
        state: state,
        retryCount: retryCount,
        stage: stage,
        config: config,
      )) {
        // Narrowing succeeded — allow another retry without blocking.
        return false;
      }
      _appendRunLog(
        projectRoot,
        event: 'forensic_recovery_exhausted',
        message: 'Forensic recovery already attempted — hard blocking task',
        data: {
          'root': projectRoot,
          'task': state.activeTaskTitle ?? '',
          'stage': stage,
          'retry_count': retryCount,
          'error_class': 'pipeline',
          'error_kind': 'forensic_recovery_exhausted',
        },
      );
      final reason =
          'Auto-cycle: review rejected $retryCount time(s) '
          '(forensic recovery exhausted)';
      return _blockActiveOrRecoverMissingTask(
        projectRoot,
        reason: reason,
        stage: stage,
        retryCount: retryCount,
      );
    }

    // Pre-check: if the task is already done in TASKS.md, skip forensics
    // and hard-block immediately to prevent wasting tokens on completed tasks.
    if (_isActiveTaskAlreadyDone(projectRoot, state.activeTaskTitle)) {
      _appendRunLog(
        projectRoot,
        event: 'forensic_skip_already_completed',
        message: 'Task is already marked done — hard-blocking without forensics',
        data: {
          'root': projectRoot,
          'task': state.activeTaskTitle ?? '',
          'stage': stage,
          'retry_count': retryCount,
          'error_class': 'pipeline',
          'error_kind': 'already_completed',
        },
      );
      final reason = 'Auto-cycle: task already completed in TASKS.md';
      return _blockActiveOrRecoverMissingTask(
        projectRoot,
        reason: reason,
        stage: stage,
        retryCount: retryCount,
      );
    }

    // Run forensic diagnosis.
    final diagnosis = _taskForensicsService.diagnose(
      projectRoot,
      taskTitle: state.activeTaskTitle,
      retryCount: retryCount,
    );

    _appendRunLog(
      projectRoot,
      event: 'forensic_diagnosis',
      message: 'Forensic diagnosis completed before blocking decision',
      data: {
        'root': projectRoot,
        'task': state.activeTaskTitle ?? '',
        'classification': diagnosis.classification.name,
        'suggested_action': diagnosis.suggestedAction.name,
        'evidence': diagnosis.evidence,
        if (diagnosis.guidanceText != null)
          'guidance_text': diagnosis.guidanceText,
        'error_class': 'pipeline',
        'error_kind': 'forensic_diagnosis',
      },
    );

    switch (diagnosis.suggestedAction) {
      case ForensicAction.redecompose:
        // Build a specific guidance text for re-decomposition that tells
        // the spec agent to produce smaller subtasks.
        final redecomposeGuidance = _buildRedecomposeGuidance(
          diagnosis,
          state.activeTaskTitle,
        );
        return _attemptForensicRecovery(
          projectRoot,
          store: store,
          state: state,
          diagnosis: diagnosis,
          retryCount: retryCount,
          stage: stage,
          recoveryDescription: 'redecompose',
          overwriteArtifacts: true,
          guidanceOverride: redecomposeGuidance,
        );
      case ForensicAction.regenerateSpec:
        // Build guidance that tells the spec agent why the previous spec
        // was incorrect, using evidence from the forensic diagnosis.
        final regenerateGuidance = _buildRegenerateSpecGuidance(
          diagnosis,
          state.activeTaskTitle,
        );
        return _attemptForensicRecovery(
          projectRoot,
          store: store,
          state: state,
          diagnosis: diagnosis,
          retryCount: retryCount,
          stage: stage,
          recoveryDescription: 'regenerate_spec',
          overwriteArtifacts: true,
          guidanceOverride: regenerateGuidance,
        );
      case ForensicAction.retryWithGuidance:
        // In unattended mode, guidance retries are risky because there is
        // no human to review whether the guidance actually helps.  Skip
        // straight to blocking the task instead.
        if (_isUnattendedMode(projectRoot)) {
          _appendRunLog(
            projectRoot,
            event: 'forensic_retry_guidance_skipped_unattended',
            message:
                'Skipping retryWithGuidance in unattended mode — blocking task',
            data: {
              'root': projectRoot,
              'task': state.activeTaskTitle ?? '',
              'classification': diagnosis.classification.name,
              'retry_count': retryCount,
              'error_class': 'pipeline',
              'error_kind': 'unattended_guidance_skip',
            },
          );
          final reason =
              'Auto-cycle: review rejected $retryCount time(s) '
              '(forensic: ${diagnosis.classification.name}, '
              'guidance skipped in unattended mode)';
          return _blockActiveOrRecoverMissingTask(
            projectRoot,
            reason: reason,
            stage: stage,
            retryCount: retryCount,
          );
        }
        return _attemptForensicRecovery(
          projectRoot,
          store: store,
          state: state,
          diagnosis: diagnosis,
          retryCount: retryCount,
          stage: stage,
          recoveryDescription: 'retry_with_guidance',
          overwriteArtifacts: false,
        );
      case ForensicAction.block:
        final reason =
            'Auto-cycle: review rejected $retryCount time(s) '
            '(forensic: ${diagnosis.classification.name})';
        return _blockActiveOrRecoverMissingTask(
          projectRoot,
          reason: reason,
          stage: stage,
          retryCount: retryCount,
        );
    }
  }

  /// Attempts a forensic recovery by resetting retries, storing guidance,
  /// and marking the recovery as attempted.
  ///
  /// When [guidanceOverride] is provided it takes precedence over
  /// `diagnosis.guidanceText` — this allows callers (redecompose,
  /// regenerate_spec) to supply more specific, action-oriented guidance.
  bool _attemptForensicRecovery(
    String projectRoot, {
    required StateStore store,
    required ProjectState state,
    required ForensicDiagnosis diagnosis,
    required int retryCount,
    required String stage,
    required String recoveryDescription,
    required bool overwriteArtifacts,
    String? guidanceOverride,
  }) {
    // Reset retry counters so the task gets another chance after recovery.
    // Clear both task-level and subtask-level keys.
    final taskKey = _retryKey(state.activeTaskId, state.activeTaskTitle);
    final subtaskKey = _retryKey(
      state.activeTaskId,
      state.activeTaskTitle,
      subtaskDescription: state.currentSubtask,
    );
    final counts = Map<String, int>.from(state.taskRetryCounts);
    if (taskKey != null) {
      counts.remove(taskKey);
    }
    if (subtaskKey != null && subtaskKey != taskKey) {
      counts.remove(subtaskKey);
    }

    // Write forensic state: mark recovery as attempted, set guidance.
    // guidanceOverride (from redecompose/regenerate_spec) takes precedence
    // over the generic diagnosis guidance text.
    final effectiveGuidance = guidanceOverride ?? diagnosis.guidanceText;
    try {
      store.write(
        state.copyWith(
          retryScheduling: state.retryScheduling.copyWith(
            retryCounts: Map.unmodifiable(counts),
          ),
          activeTask: state.activeTask.copyWith(
            forensicRecoveryAttempted: true,
            forensicGuidance: effectiveGuidance,
          ),
          lastUpdated: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e) {
      _appendRunLog(
        projectRoot,
        event: 'forensic_recovery_state_write_failed',
        message:
            'Failed to persist forensic recovery state — blocking task as '
            'fallback',
        data: {
          'root': projectRoot,
          'task': state.activeTaskTitle ?? '',
          'error': e.toString(),
          'error_class': 'state',
          'error_kind': 'forensic_recovery_write',
        },
      );
      // Fail-closed: block the task rather than allow untracked retry.
      return true;
    }

    // Delete spec artifacts to force regeneration if needed.
    if (overwriteArtifacts) {
      _deleteSpecArtifacts(projectRoot, state.activeTaskTitle);
    }

    // Feature G: append a lesson learned entry.
    _appendLessonLearned(
      layout: ProjectLayout(projectRoot),
      classification: diagnosis.classification.name,
      taskTitle: state.activeTaskTitle ?? 'unknown',
      evidence: diagnosis.evidence.isNotEmpty ? diagnosis.evidence.first : '',
    );

    _appendRunLog(
      projectRoot,
      event: 'forensic_recovery_attempt',
      message: 'Forensic recovery triggered — task given another chance',
      data: {
        'root': projectRoot,
        'task': state.activeTaskTitle ?? '',
        'classification': diagnosis.classification.name,
        'recovery': recoveryDescription,
        'overwrite_artifacts': overwriteArtifacts,
        'retry_count_before': retryCount,
        'error_class': 'pipeline',
        'error_kind': 'forensic_recovery',
      },
    );

    // Returning false means the task is NOT blocked — it will be retried.
    return false;
  }

  /// Deletes spec artifacts for a task to force regeneration.
  void _deleteSpecArtifacts(String projectRoot, String? taskTitle) {
    final title = taskTitle?.trim();
    if (title == null || title.isEmpty) return;
    final layout = ProjectLayout(projectRoot);
    final slug = TaskSlugger.slug(title);
    final specDir = layout.taskSpecsDir;
    final specFile = File('$specDir/$slug.md');
    if (specFile.existsSync()) {
      try {
        specFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Builds specific guidance for re-decomposition recovery.
  ///
  /// The returned text instructs the spec agent to produce smaller subtasks,
  /// incorporating evidence from the forensic diagnosis (e.g., the number of
  /// required files that caused the task to be too large).
  String _buildRedecomposeGuidance(
    ForensicDiagnosis diagnosis,
    String? taskTitle,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'REDECOMPOSITION REQUIRED: The previous spec for '
      '"${taskTitle ?? 'this task'}" was too large and failed review '
      'after multiple attempts.',
    );
    buffer.writeln();
    // Include evidence so the spec agent understands why.
    for (final item in diagnosis.evidence) {
      buffer.writeln('- $item');
    }
    buffer.writeln();
    buffer.writeln(
      'Decompose into smaller subtasks that each touch at most 3 files. '
      'Each subtask must be independently verifiable and should not '
      'depend on more than one prior subtask.',
    );
    if (diagnosis.guidanceText != null &&
        diagnosis.guidanceText!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Additional context: ${diagnosis.guidanceText!.trim()}');
    }
    return buffer.toString().trim();
  }

  /// Builds specific guidance for spec regeneration recovery.
  ///
  /// The returned text instructs the spec agent to regenerate with corrected
  /// targets, incorporating the review-reject evidence that identified the
  /// spec as incorrect.
  String _buildRegenerateSpecGuidance(
    ForensicDiagnosis diagnosis,
    String? taskTitle,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'SPEC REGENERATION REQUIRED: The previous spec for '
      '"${taskTitle ?? 'this task'}" was found to be incorrect and '
      'failed review after multiple attempts.',
    );
    buffer.writeln();
    for (final item in diagnosis.evidence) {
      buffer.writeln('- $item');
    }
    buffer.writeln();
    buffer.writeln(
      'Regenerate the spec with corrected required files and accurate '
      'requirements. Pay close attention to the evidence above — the '
      'previous spec targeted wrong files or had incorrect requirements.',
    );
    if (diagnosis.guidanceText != null &&
        diagnosis.guidanceText!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Review feedback: ${diagnosis.guidanceText!.trim()}');
    }
    return buffer.toString().trim();
  }

  /// Checks whether the active task is already marked `[x]` done in TASKS.md.
  bool _isActiveTaskAlreadyDone(String projectRoot, String? taskTitle) {
    final title = taskTitle?.trim();
    if (title == null || title.isEmpty) return false;
    try {
      final layout = ProjectLayout(projectRoot);
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final normalized = title.toLowerCase();
      return tasks.any(
        (t) =>
            t.title.trim().toLowerCase() == normalized &&
            t.completion == TaskCompletion.done,
      );
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature 1b: Reactive subtask split on complexity-related reject
  // ─────────────────────────────────────────────────────────────────────────

  static const _complexityKeywords = [
    'too large',
    'too big',
    'too many changes',
    'too many files',
    'break down',
    'split',
    'decompose',
    'scope',
  ];

  bool _noteContainsComplexityKeyword(String note) {
    final lower = note.toLowerCase();
    return _complexityKeywords.any((kw) => lower.contains(kw));
  }

  String _subtaskSplitKey(String subtask) {
    return subtask
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Attempts to split [stageContext.subtaskDescription] into 2-3 smaller
  /// subtasks when the reviewer note contains complexity keywords.
  ///
  /// Returns `true` if the split was successful and the queue was updated.
  /// Returns `false` if the split was skipped or failed (normal reject flow).
  Future<bool> _trySplitSubtaskOnReject(
    String projectRoot, {
    required _TaskCycleStageContext stageContext,
    required String rejectNote,
  }) async {
    if (!stageContext.isSubtask || stageContext.subtaskDescription == null) {
      return false;
    }

    final config = ProjectConfig.load(projectRoot);
    if (!config.pipelineSubtaskRefinementEnabled) {
      _appendRunLog(
        projectRoot,
        event: 'subtask_split_on_reject_skipped',
        message: 'Reactive subtask split skipped: config disabled',
        data: {'root': projectRoot},
      );
      return false;
    }

    if (!_noteContainsComplexityKeyword(rejectNote)) {
      return false;
    }

    final layout = ProjectLayout(projectRoot);
    final store = StateStore(layout.statePath);
    final state = store.read();
    final subtask = stageContext.subtaskDescription!;
    final splitKey = _subtaskSplitKey(subtask);
    final attempts = state.subtaskExecution.splitAttempts[splitKey] ?? 0;

    if (attempts >= 1) {
      _appendRunLog(
        projectRoot,
        event: 'subtask_split_on_reject_skipped',
        message: 'Reactive subtask split skipped: already split once',
        data: {
          'root': projectRoot,
          'subtask': subtask,
          'split_attempts': attempts,
        },
      );
      return false;
    }

    List<String>? splitParts;
    try {
      splitParts = await _specAgentService.splitSubtaskForReject(
        projectRoot,
        subtask,
        rejectNote,
      );
    } catch (_) {
      return false;
    }

    if (splitParts == null || splitParts.isEmpty) {
      return false;
    }

    // Prepend split parts to the front of the queue and clear currentSubtask.
    final freshState = store.read();
    final updatedAttempts = Map<String, int>.from(
      freshState.subtaskExecution.splitAttempts,
    )..[splitKey] = attempts + 1;
    final updatedQueue = [
      ...splitParts,
      ...freshState.subtaskExecution.queue,
    ];

    store.write(
      freshState.copyWith(
        subtaskExecution: freshState.subtaskExecution.copyWith(
          current: null,
          queue: updatedQueue,
          splitAttempts: Map.unmodifiable(updatedAttempts),
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    _appendRunLog(
      projectRoot,
      event: 'subtask_split_on_reject',
      message: 'Reactive subtask split succeeded',
      data: {
        'root': projectRoot,
        'original_subtask': subtask,
        'split_count': splitParts.length,
        'new_subtasks': splitParts,
      },
    );

    return true;
  }

  /// Commits subtask changes with a subtask-specific message when
  /// [pipelineSubtaskCommitEnabled] is true and the worktree has changes.
  ///
  /// Does NOT push — push happens at task-completion time via [_commitAndPush].
  /// Falls back to [_commitAndPush] when the config flag is disabled so the
  /// existing behaviour is preserved.
  void _maybeCommitSubtask(
    String projectRoot,
    String? subtaskDescription,
  ) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.pipelineSubtaskCommitEnabled) {
      _commitAndPush(projectRoot);
      return;
    }
    if (!_gitService.isGitRepo(projectRoot)) return;
    if (!_gitService.hasChanges(projectRoot)) return;

    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final title = state.activeTaskTitle?.trim() ?? 'task';
    final slug = TaskSlugger.slug(title);
    final subtask = subtaskDescription?.trim() ?? '';
    final truncated =
        subtask.length > 57 ? '${subtask.substring(0, 57)}...' : subtask;
    final message =
        subtask.isEmpty ? 'feat($slug): subtask delivery' : 'feat($slug): $truncated';

    _gitService.addAll(projectRoot);
    _gitService.commit(projectRoot, message);

    _appendRunLog(
      projectRoot,
      event: 'subtask_committed',
      message: 'Committed subtask changes',
      data: {
        'root': projectRoot,
        'task': title,
        'commit_message': message,
      },
    );
  }

  /// Updates the error pattern registry when a review is rejected.
  ///
  /// Extracts the error_kind from the current state (last_error_kind) and
  /// increments its count in the persistent registry. Falls back to
  /// 'review_rejected' when no specific error kind is available.
  ///
  /// Additionally, if the review note is sufficiently detailed (>=50 chars)
  /// and no resolution strategy exists yet for this error kind, the review
  /// note is stored as a resolution strategy so future coding agents can
  /// learn from past review feedback.
  void _updateErrorPatternRegistryOnReject(
    String projectRoot,
    ReviewAgentResult review,
  ) {
    try {
      final layout = ProjectLayout(projectRoot);
      final state = StateStore(layout.statePath).read();
      final errorKind =
          (state.lastErrorKind != null &&
              state.lastErrorKind!.trim().isNotEmpty)
          ? state.lastErrorKind!.trim()
          : 'review_rejected';
      _errorPatternRegistryService.mergeObservations(
        projectRoot,
        errorKindCounts: {errorKind: 1},
      );
      // Learn from review feedback: store the review note as a resolution
      // strategy if it is sufficiently detailed and none exists yet.
      final reviewNote = _extractNote(review.response.stdout);
      if (reviewNote != null && reviewNote.trim().length >= 50) {
        _errorPatternRegistryService.recordResolutionIfNew(
          projectRoot,
          errorKind,
          reviewNote.trim(),
        );
      }
    } catch (_) {
      // Non-critical: do not block pipeline progress if registry update fails.
    }
  }

  /// Appends a single lesson-learned line to `lessons_learned.md` and
  /// rotates the file to keep at most [pipelineLessonsLearnedMaxLines] entries.
  void _appendLessonLearned({
    required ProjectLayout layout,
    required String classification,
    required String taskTitle,
    required String evidence,
  }) {
    try {
      final ts = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final line = '- [$ts] **$taskTitle** — $classification: $evidence\n';
      final file = File(layout.lessonsLearnedPath);
      if (!file.existsSync()) {
        file.writeAsStringSync('# Lessons Learned\n', flush: true);
      }
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);

      // Rotate: keep only the last N lesson-learned lines.
      int maxLines;
      try {
        maxLines = ProjectConfig.load(layout.projectRoot)
            .pipelineLessonsLearnedMaxLines;
      } catch (_) {
        maxLines = ProjectConfig.defaultPipelineLessonsLearnedMaxLines;
      }
      if (maxLines > 0) {
        final allLines = file
            .readAsLinesSync()
            .where((l) => l.isNotEmpty)
            .toList();
        if (allLines.length > maxLines) {
          file.writeAsStringSync(
            '${allLines.skip(allLines.length - maxLines).join('\n')}\n',
            flush: true,
          );
        }
      }
    } catch (_) {
      // Non-critical: do not block pipeline progress.
    }
  }
}
