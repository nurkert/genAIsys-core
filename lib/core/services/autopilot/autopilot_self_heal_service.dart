// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../errors/failure_reason_mapper.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../error_pattern_registry_service.dart';
import '../orchestrator_step_service.dart';

/// Standalone service responsible for self-heal fallback attempts during
/// autopilot error recovery.
///
/// Extracted from the `_OrchestratorRunLoopSupport` extension on
/// `OrchestratorRunService` to reduce god-class complexity.
class AutopilotSelfHealService {
  AutopilotSelfHealService({
    OrchestratorStepService? stepService,
    ErrorPatternRegistryService? errorPatternRegistry,
  }) : _stepService = stepService ?? OrchestratorStepService(),
       _errorPatternRegistry =
           errorPatternRegistry ?? ErrorPatternRegistryService();

  final OrchestratorStepService _stepService;
  final ErrorPatternRegistryService _errorPatternRegistry;

  /// Whether a self-heal attempt can be made given the current state.
  bool canAttemptSelfHeal({
    required bool enabled,
    required int attemptsUsed,
    required int maxAttempts,
    required String? errorKind,
    required bool unattendedMode,
  }) {
    if (!enabled) return false;
    if (maxAttempts < 1) return false;
    if (attemptsUsed >= maxAttempts) return false;
    if (unattendedMode &&
        (errorKind == 'review_rejected' ||
            errorKind == 'no_diff' ||
            errorKind == 'timeout')) {
      return false;
    }
    return isSelfHealEligibleErrorKind(errorKind);
  }

  /// Whether the given error kind is eligible for self-heal recovery.
  bool isSelfHealEligibleErrorKind(String? errorKind) {
    if (errorKind == null || errorKind.isEmpty) return false;
    return errorKind == 'policy_violation' ||
        errorKind == 'quality_gate_failed' ||
        errorKind == 'analyze_failed' ||
        errorKind == 'test_failed' ||
        errorKind == 'timeout' ||
        errorKind == 'review_rejected' ||
        errorKind == 'no_diff' ||
        errorKind == 'diff_budget' ||
        errorKind == 'merge_conflict' ||
        errorKind == 'git_dirty' ||
        errorKind == 'not_found' ||
        errorKind == 'no_active_task' ||
        errorKind == 'agent_unavailable';
  }

  /// Attempts a self-heal fallback step. Returns `true` if the recovery
  /// step made progress, `false` otherwise.
  Future<bool> attemptSelfHealFallback(
    String projectRoot, {
    required String codingPrompt,
    required String? testSummary,
    required bool overwriteArtifacts,
    required int minOpenTasks,
    required int maxPlanAdd,
    required String stepId,
    required int stepIndex,
    required String? errorKind,
    required String errorMessage,
    required int attempt,
    required int maxAttempts,
    required int maxTaskRetries,
  }) async {
    final context = _readStepContext(projectRoot);
    final reviewNote = errorKind == 'review_rejected'
        ? _readLastReviewRejectNote(projectRoot)
        : null;
    final recoveryPrompt = buildSelfHealPrompt(
      projectRoot: projectRoot,
      codingPrompt: codingPrompt,
      errorKind: errorKind,
      errorMessage: errorMessage,
      reviewNote: reviewNote,
    );
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_self_heal_attempt',
      message: 'Autopilot self-heal fallback triggered',
      data: {
        'step_id': stepId,
        'step_index': stepIndex,
        'attempt': attempt,
        'max_attempts': maxAttempts,
        'error_kind': errorKind,
        'error': errorMessage,
        if (context.taskId != null) 'task_id': context.taskId,
        if (context.subtaskId != null) 'subtask_id': context.subtaskId,
      },
    );

    try {
      final result = await _stepService.run(
        projectRoot,
        codingPrompt: recoveryPrompt,
        testSummary: testSummary,
        overwriteArtifacts: overwriteArtifacts,
        minOpenTasks: minOpenTasks,
        maxPlanAdd: maxPlanAdd,
        maxTaskRetries: maxTaskRetries,
      );
      final progressed =
          _didProgress(result) && result.retryCount <= maxTaskRetries;
      _appendRunLog(
        projectRoot,
        event: progressed
            ? 'orchestrator_run_self_heal_success'
            : 'orchestrator_run_self_heal_no_progress',
        message: progressed
            ? 'Autopilot self-heal fallback succeeded'
            : 'Autopilot self-heal fallback made no useful progress',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'attempt': attempt,
          'error_kind': errorKind,
          'review_decision': result.reviewDecision ?? '',
          'retry_count': result.retryCount,
          'executed_cycle': result.executedCycle,
          'planned_tasks_added': result.plannedTasksAdded,
          if (result.activeTaskId != null && result.activeTaskId!.isNotEmpty)
            'task_id': result.activeTaskId,
          if (result.currentSubtask != null &&
              result.currentSubtask!.isNotEmpty)
            'subtask_id': result.currentSubtask,
        },
      );
      return progressed;
    } catch (error) {
      final errorText = error.toString();
      _appendRunLog(
        projectRoot,
        event: 'orchestrator_run_self_heal_failed',
        message: 'Autopilot self-heal fallback failed',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'attempt': attempt,
          'error_kind': _classifyErrorKind(errorText) ?? errorKind,
          'error': errorText,
          if (context.taskId != null) 'task_id': context.taskId,
          if (context.subtaskId != null) 'subtask_id': context.subtaskId,
        },
      );
      return false;
    }
  }

  /// Builds the self-heal prompt with error context and recovery guidance.
  String buildSelfHealPrompt({
    required String projectRoot,
    required String codingPrompt,
    required String? errorKind,
    required String errorMessage,
    String? reviewNote,
  }) {
    final trimmedReview = reviewNote?.trim();
    final reviewBlock = trimmedReview == null || trimmedReview.isEmpty
        ? ''
        : '\nLatest review note:\n${_truncateNote(trimmedReview, 1200)}\n';
    final noDiffBlock = errorKind == 'no_diff'
        ? '''

No-diff guidance (required):
1. You MUST produce at least one concrete file change under the allowed safe-write roots.
2. Do not claim "updated/created" unless `git status --porcelain` shows actual changes.
3. If you truly believe no change is needed, output `BLOCK: no_diff_no_op` with a short reason and propose a next safe action (e.g. adjust spec/subtasks) instead of narrating changes.
'''
        : '';
    final timeoutBlock = errorKind == 'timeout'
        ? '''

Timeout guidance (required):
1. Produce the smallest meaningful diff and finish quickly.
2. Avoid broad scans/refactors and do not touch unrelated files.
3. If a safe minimal diff is not possible in this step, output `BLOCK: timeout_scope_too_large` and propose the next smallest split.
'''
        : '';

    var knownStrategyBlock = '';
    if (errorKind != null && errorKind.isNotEmpty) {
      try {
        final strategy = _errorPatternRegistry.knownResolutionFor(
          projectRoot,
          errorKind,
        );
        if (strategy != null && strategy.trim().isNotEmpty) {
          knownStrategyBlock = '''

Known resolution strategy for '$errorKind':
${_truncateNote(strategy.trim(), 600)}
''';
        }
      } catch (_) {
        // Registry lookup is best-effort observability.
      }
    }

    return '''
$codingPrompt

### AUTOPILOT SELF-HEAL MODE
The previous attempt failed and blocked autonomous progress.

Error kind: ${errorKind ?? 'unknown'}
Error message: $errorMessage
$reviewBlock
$noDiffBlock
$timeoutBlock
$knownStrategyBlock

Goal:
1. Resolve the blocking issue with the smallest safe change set.
2. Keep tests/analyze green and respect all policies.
3. Do not bypass quality gates, do not disable tests, do not weaken policies.
4. If code cannot be changed safely, update specs/subtasks so the next loop can proceed safely.
''';
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  String _truncateNote(String text, int maxChars) {
    if (maxChars <= 0 || text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  }

  bool _didProgress(OrchestratorStepResult result) {
    if (result.autoMarkedDone) return true;
    if (result.plannedTasksAdded > 0) return true;
    if (result.activatedTask) return true;
    if (result.didArchitecturePlanning) return true;
    if (result.visionFulfilled != null) return true;
    final decision = result.reviewDecision?.trim().toLowerCase();
    if (decision == 'approve') return true;
    return false;
  }

  String? _classifyErrorKind(String? message) {
    final reason = FailureReasonMapper.normalize(message: message);
    if (reason.errorKind == FailureReason.unknown.errorKind) return null;
    return reason.errorKind;
  }

  _SelfHealStepContext _readStepContext(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    try {
      final store = StateStore(layout.statePath);
      final state = store.read();
      final taskId = state.activeTaskId?.trim();
      final subtaskId = state.currentSubtask?.trim();
      return _SelfHealStepContext(
        taskId: taskId?.isNotEmpty == true ? taskId : null,
        subtaskId: subtaskId?.isNotEmpty == true ? subtaskId : null,
      );
    } catch (_) {
      return const _SelfHealStepContext();
    }
  }

  String? _readLastReviewRejectNote(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.runLogPath);
    if (!file.existsSync()) return null;
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return null;
    }
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final event = decoded['event']?.toString() ?? '';
        if (event != 'review_reject') continue;
        final data = decoded['data'];
        if (data is Map) {
          final note = data['note']?.toString();
          if (note != null && note.trim().isNotEmpty) return note;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  void _appendRunLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) return;
    RunLogStore(layout.runLogPath).append(
      event: event,
      message: message,
      data: {'root': projectRoot, ...data},
    );
  }
}

class _SelfHealStepContext {
  const _SelfHealStepContext({this.taskId, this.subtaskId});
  final String? taskId;
  final String? subtaskId;
}
