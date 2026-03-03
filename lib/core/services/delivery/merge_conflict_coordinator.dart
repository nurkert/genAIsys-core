// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../agents/agent_runner.dart';
import '../../git/git_service.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../merge_conflict_resolver_service.dart';

/// Coordinates the merge-or-resolve flow during delivery: attempts a fast merge,
/// and if conflicts arise, drives the agent-based resolution loop with retry,
/// abort, and manual-intervention escalation.
class MergeConflictCoordinator {
  MergeConflictCoordinator({
    GitService? gitService,
    MergeConflictResolverService? mergeConflictResolver,
    int mergeConflictMaxAttempts = 3,
  }) : _gitService = gitService ?? GitService(),
       _mergeConflictResolver =
           mergeConflictResolver ?? MergeConflictResolverService(),
       _mergeConflictMaxAttempts = mergeConflictMaxAttempts < 1
           ? 1
           : mergeConflictMaxAttempts;

  final GitService _gitService;
  final MergeConflictResolverService _mergeConflictResolver;
  final int _mergeConflictMaxAttempts;

  /// Attempts to merge [featureBranch] into the current branch (assumed to be
  /// [baseBranch]).  If conflicts arise, drives agent-based resolution up to
  /// [_mergeConflictMaxAttempts] times before aborting and requesting manual
  /// intervention.
  Future<void> mergeOrResolve(
    String projectRoot,
    String baseBranch,
    String featureBranch,
  ) async {
    final mergeContext = mergeContextFromState(projectRoot);
    try {
      _gitService.merge(projectRoot, featureBranch);
      return;
    } catch (error) {
      if (!_gitService.hasMergeInProgress(projectRoot)) {
        rethrow;
      }
      final conflicts = _gitService.conflictPaths(projectRoot);
      if (conflicts.isEmpty) {
        rethrow;
      }
      appendMergeConflictEvent(
        projectRoot,
        event: 'merge_conflict_detected',
        message: 'Merge conflict detected during delivery merge',
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        conflicts: conflicts,
        data: {
          ...mergeContext,
          'error_class': 'delivery',
          'error_kind': 'merge_conflict_detected',
          'merge_outcome': 'detected',
          'error': error.toString(),
        },
      );
      String? lastFailure;
      for (var attempt = 1; attempt <= _mergeConflictMaxAttempts; attempt++) {
        if (!_gitService.hasMergeInProgress(projectRoot)) {
          throw StateError('Merge aborted during conflict resolution.');
        }
        final currentConflicts = _gitService.conflictPaths(projectRoot);
        if (currentConflicts.isEmpty) {
          appendMergeConflictEvent(
            projectRoot,
            event: 'merge_conflict_resolved',
            message: 'Merge conflicts resolved before next retry attempt',
            baseBranch: baseBranch,
            featureBranch: featureBranch,
            conflicts: const [],
            data: {
              ...mergeContext,
              'attempt': attempt - 1,
              'max_attempts': _mergeConflictMaxAttempts,
              'merge_outcome': 'resolved',
            },
          );
          break;
        }
        appendMergeConflictEvent(
          projectRoot,
          event: 'merge_conflict_resolution_attempt_start',
          message: 'Starting merge conflict resolution attempt',
          baseBranch: baseBranch,
          featureBranch: featureBranch,
          conflicts: currentConflicts,
          data: {
            ...mergeContext,
            'attempt': attempt,
            'max_attempts': _mergeConflictMaxAttempts,
            'merge_outcome': 'attempt_start',
          },
        );
        final resolution = await _mergeConflictResolver.resolve(
          projectRoot,
          baseBranch: baseBranch,
          featureBranch: featureBranch,
          conflictPaths: currentConflicts,
        );
        if (!resolution.response.ok) {
          lastFailure = _mergeAgentFailure(resolution.response);
          appendMergeConflictEvent(
            projectRoot,
            event: 'merge_conflict_resolution_attempt_failed',
            message: 'Merge conflict resolution attempt failed',
            baseBranch: baseBranch,
            featureBranch: featureBranch,
            conflicts: currentConflicts,
            data: {
              ...mergeContext,
              'attempt': attempt,
              'max_attempts': _mergeConflictMaxAttempts,
              'error_class': 'delivery',
              'error_kind': 'merge_conflict_resolution_failed',
              'merge_outcome': 'attempt_failed',
              'last_failure': lastFailure,
              'agent_used_fallback': resolution.usedFallback,
              'agent_exit_code': resolution.response.exitCode,
            },
          );
          if (attempt == _mergeConflictMaxAttempts) {
            abortMergeIfNeeded(
              projectRoot,
              baseBranch: baseBranch,
              featureBranch: featureBranch,
              reason: 'attempt_failed',
              conflicts: currentConflicts,
              mergeContext: mergeContext,
            );
            _manualIntervention(
              projectRoot,
              baseBranch: baseBranch,
              featureBranch: featureBranch,
              reason:
                  'Merge conflict resolution failed after $attempt attempt(s)',
              conflicts: currentConflicts,
              lastFailure: lastFailure,
            );
          }
          continue;
        }

        final remaining = _gitService.conflictPaths(projectRoot);
        if (remaining.isEmpty) {
          appendMergeConflictEvent(
            projectRoot,
            event: 'merge_conflict_resolved',
            message: 'Merge conflicts resolved by recovery playbook',
            baseBranch: baseBranch,
            featureBranch: featureBranch,
            conflicts: const [],
            data: {
              ...mergeContext,
              'attempt': attempt,
              'max_attempts': _mergeConflictMaxAttempts,
              'merge_outcome': 'resolved',
              'agent_used_fallback': resolution.usedFallback,
            },
          );
          break;
        }
        appendMergeConflictEvent(
          projectRoot,
          event: 'merge_conflict_resolution_attempt_unresolved',
          message:
              'Merge conflict resolution attempt finished without progress',
          baseBranch: baseBranch,
          featureBranch: featureBranch,
          conflicts: remaining,
          data: {
            ...mergeContext,
            'attempt': attempt,
            'max_attempts': _mergeConflictMaxAttempts,
            'error_class': 'delivery',
            'error_kind': 'merge_conflict_unresolved',
            'merge_outcome': 'attempt_unresolved',
            'agent_used_fallback': resolution.usedFallback,
            'agent_exit_code': resolution.response.exitCode,
          },
        );
        if (attempt == _mergeConflictMaxAttempts) {
          abortMergeIfNeeded(
            projectRoot,
            baseBranch: baseBranch,
            featureBranch: featureBranch,
            reason: 'attempt_unresolved',
            conflicts: remaining,
            mergeContext: mergeContext,
          );
          _manualIntervention(
            projectRoot,
            baseBranch: baseBranch,
            featureBranch: featureBranch,
            reason: 'Merge conflicts remain after $attempt attempt(s)',
            conflicts: remaining,
          );
        }
      }
    }

    if (!_gitService.hasMergeInProgress(projectRoot)) {
      _manualIntervention(
        projectRoot,
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        reason: 'Merge aborted during conflict resolution',
      );
    }

    final remaining = _gitService.conflictPaths(projectRoot);
    if (remaining.isNotEmpty) {
      abortMergeIfNeeded(
        projectRoot,
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        reason: 'post_resolution_conflicts',
        conflicts: remaining,
        mergeContext: mergeContext,
      );
      _manualIntervention(
        projectRoot,
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        reason: 'Merge conflicts remain after resolution',
        conflicts: remaining,
      );
    }

    _gitService.addAll(projectRoot);
    try {
      _gitService.commit(
        projectRoot,
        mergeCommitMessage(baseBranch, featureBranch),
      );
    } catch (commitError) {
      // Reset the index so a dirty staged state does not corrupt subsequent
      // operations (e.g. next step's preflight or stash).
      try {
        _gitService.resetIndex(projectRoot);
      } catch (_) {
        // Best-effort index reset.
      }
      rethrow;
    }
  }

  /// Aborts an in-progress merge if one exists, with hard-reset fallback.
  void abortMergeIfNeeded(
    String projectRoot, {
    required String baseBranch,
    required String featureBranch,
    required String reason,
    required List<String> conflicts,
    required Map<String, Object?> mergeContext,
  }) {
    if (!_gitService.hasMergeInProgress(projectRoot)) {
      return;
    }
    try {
      _gitService.abortMerge(projectRoot);
      appendMergeConflictEvent(
        projectRoot,
        event: 'merge_conflict_abort',
        message: 'Aborted merge after conflict recovery failure',
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        conflicts: conflicts,
        data: {
          ...mergeContext,
          'error_class': 'delivery',
          'error_kind': 'merge_conflict_abort',
          'merge_outcome': 'aborted',
          'recovery_reason': reason,
        },
      );
    } catch (abortError) {
      // Merge abort itself failed — fall back to hard reset to restore a
      // usable worktree state.
      try {
        _gitService.hardReset(projectRoot);
        _gitService.cleanUntracked(projectRoot);
      } catch (_) {
        // Best-effort hard reset; if this also fails the merge_conflict_abort_failed
        // event below will surface the original error for manual triage.
      }
      appendMergeConflictEvent(
        projectRoot,
        event: 'merge_conflict_abort_failed',
        message:
            'Failed to abort merge — applied hard reset fallback',
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        conflicts: conflicts,
        data: {
          ...mergeContext,
          'error_class': 'delivery',
          'error_kind': 'merge_abort_hard_reset',
          'merge_outcome': 'abort_failed',
          'recovery_reason': reason,
          'original_error': abortError.toString(),
        },
      );
    }
  }

  /// Builds the merge commit message.
  String mergeCommitMessage(String baseBranch, String featureBranch) {
    return 'merge: $featureBranch into $baseBranch';
  }

  /// Extracts task/subtask context from STATE.json for merge event logging.
  Map<String, Object?> mergeContextFromState(String projectRoot) {
    try {
      final state = StateStore(ProjectLayout(projectRoot).statePath).read();
      final context = <String, Object?>{};
      final taskId = state.activeTaskId?.trim();
      if (taskId != null && taskId.isNotEmpty) {
        context['task_id'] = taskId;
      }
      final subtaskId = state.currentSubtask?.trim();
      if (subtaskId != null && subtaskId.isNotEmpty) {
        context['subtask_id'] = subtaskId;
      }
      return context;
    } catch (_) {
      return const {};
    }
  }

  /// Appends a structured merge conflict event to the run log.
  void appendMergeConflictEvent(
    String projectRoot, {
    required String event,
    required String message,
    required String baseBranch,
    required String featureBranch,
    required List<String> conflicts,
    Map<String, Object?>? data,
  }) {
    final payload = <String, Object?>{
      'root': projectRoot,
      'base_branch': baseBranch,
      'feature_branch': featureBranch,
      'conflict_count': conflicts.length,
      'conflicts': conflicts.join(', '),
      ...?data,
    };
    RunLogStore(
      ProjectLayout(projectRoot).runLogPath,
    ).append(event: event, message: message, data: payload);
  }

  String _mergeAgentFailure(AgentResponse response) {
    final stderr = response.stderr.trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    final stdout = response.stdout.trim();
    if (stdout.isNotEmpty) {
      return stdout;
    }
    return 'agent failed';
  }

  Never _manualIntervention(
    String projectRoot, {
    required String baseBranch,
    required String featureBranch,
    required String reason,
    List<String>? conflicts,
    String? lastFailure,
  }) {
    final layout = ProjectLayout(projectRoot);
    final mergeContext = mergeContextFromState(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'merge_conflict_manual',
      message: 'Manual intervention required',
      data: {
        'root': projectRoot,
        ...mergeContext,
        'base_branch': baseBranch,
        'feature_branch': featureBranch,
        'attempt': _mergeConflictMaxAttempts,
        'max_attempts': _mergeConflictMaxAttempts,
        'conflict_count': conflicts?.length ?? 0,
        'error_class': 'delivery',
        'error_kind': 'merge_conflict_manual_required',
        'merge_outcome': 'manual_intervention_required',
        'recovery_reason': reason,
        'reason': reason,
        'conflicts': conflicts?.join(', ') ?? '',
        'last_failure': lastFailure ?? '',
      },
    );
    final conflictDetails = (conflicts == null || conflicts.isEmpty)
        ? ''
        : ' conflicts: ${conflicts.join(', ')}';
    final failureDetails = (lastFailure == null || lastFailure.isEmpty)
        ? ''
        : ' $lastFailure';
    throw StateError(
      'Manual intervention required: merge conflict. $reason.$conflictDetails$failureDetails',
    );
  }
}
