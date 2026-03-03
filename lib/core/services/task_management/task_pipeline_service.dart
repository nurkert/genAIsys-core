// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_runner.dart';
import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../ids/task_slugger.dart';
import '../../models/project_state.dart';
import '../../models/review_bundle.dart';
import '../../models/task.dart';
import '../../policy/diff_budget_policy.dart';
import '../../policy/safe_write_policy.dart';
import '../agents/coding_agent_service.dart';
import '../agents/review_agent_service.dart';
import '../review_bundle_service.dart';
import '../agents/spec_agent_service.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../../project_layout.dart';
import 'active_task_resolver.dart';
import '../agent_context_service.dart';
import '../observability/architecture_health_service.dart';
import '../build_test_runner_service.dart';
import '../pipeline_prompt_assembler.dart';
import '../required_files_enforcer.dart';
import '../spec_service.dart';

part 'pipeline_stages.dart';

class TaskPipelineResult {
  TaskPipelineResult({
    required this.plan,
    required this.spec,
    required this.subtasks,
    required this.coding,
    required this.review,
  });

  final SpecAgentResult plan;
  final SpecAgentResult spec;
  final SpecAgentResult subtasks;
  final CodingAgentResult coding;
  final ReviewAgentResult? review;
}

// ---------------------------------------------------------------------------
// Pipeline stage infrastructure
// ---------------------------------------------------------------------------

/// Mutable context threaded through pipeline stages.
class PipelineContext {
  PipelineContext({
    required this.projectRoot,
    required this.layout,
    required this.state,
    required this.config,
    required this.resolvedCategory,
    required this.plan,
    required this.spec,
    required this.subtasks,
    required this.coding,
    required this.requiredFiles,
    required this.requiredFilesMode,
    required this.testSummary,
    required this.reviewPersona,
    required this.contractNotes,
  });

  final String projectRoot;
  final ProjectLayout layout;
  final ProjectState state;
  final ProjectConfig config;
  final TaskCategory resolvedCategory;
  final SpecAgentResult plan;
  final SpecAgentResult spec;
  final SpecAgentResult subtasks;
  final CodingAgentResult coding;
  final List<String> requiredFiles;
  final RequiredFilesMode requiredFilesMode;
  final String? testSummary;
  final ReviewPersona reviewPersona;
  final List<String> contractNotes;

  // Mutable pipeline state — accumulated by stages:
  List<String> changedPaths = [];
  ReviewBundle? reviewBundle;
  String? mergedTestSummary;
}

sealed class PipelineStageOutcome {}

class StageContinue extends PipelineStageOutcome {}

class StageEarlyReturn extends PipelineStageOutcome {}

class StageReject extends PipelineStageOutcome {
  StageReject(this.review);
  final ReviewAgentResult review;
}

class StageReviewComplete extends PipelineStageOutcome {
  StageReviewComplete(this.review);
  final ReviewAgentResult review;
}

abstract class PipelineStage {
  String get name;
  FutureOr<PipelineStageOutcome> execute(PipelineContext ctx);
}

// ---------------------------------------------------------------------------
// TaskPipelineService
// ---------------------------------------------------------------------------

class TaskPipelineService {
  TaskPipelineService({
    SpecAgentService? specAgentService,
    CodingAgentService? codingAgentService,
    ReviewAgentService? reviewAgentService,
    ReviewBundleService? reviewBundleService,
    BuildTestRunnerService? buildTestRunnerService,
    AgentContextService? contextService,
    ActiveTaskResolver? activeTaskResolver,
    GitService? gitService,
    ArchitectureHealthService? architectureHealthService,
    PipelinePromptAssembler? promptAssembler,
    RequiredFilesEnforcer? requiredFilesEnforcer,
  }) : _specAgentService = specAgentService ?? SpecAgentService(),
       _codingAgentService = codingAgentService ?? CodingAgentService(),
       _reviewAgentService = reviewAgentService ?? ReviewAgentService(),
       _reviewBundleService = reviewBundleService ?? ReviewBundleService(),
       _buildTestRunnerService =
           buildTestRunnerService ?? BuildTestRunnerService(),
       _contextService = contextService ?? AgentContextService(),
       _activeTaskResolver = activeTaskResolver ?? ActiveTaskResolver(),
       _gitService = gitService ?? GitService(),
       _architectureHealthService =
           architectureHealthService ?? ArchitectureHealthService(),
       _promptAssembler = promptAssembler ?? PipelinePromptAssembler(),
       _requiredFilesEnforcer =
           requiredFilesEnforcer ?? RequiredFilesEnforcer();

  final SpecAgentService _specAgentService;
  final CodingAgentService _codingAgentService;
  final ReviewAgentService _reviewAgentService;
  final ReviewBundleService _reviewBundleService;
  final BuildTestRunnerService _buildTestRunnerService;
  final AgentContextService _contextService;
  final ActiveTaskResolver _activeTaskResolver;
  final ArchitectureHealthService _architectureHealthService;
  final GitService _gitService;
  final PipelinePromptAssembler _promptAssembler;
  final RequiredFilesEnforcer _requiredFilesEnforcer;

  Future<TaskPipelineResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    ReviewPersona reviewPersona = ReviewPersona.general,
    TaskCategory? taskCategory,
    List<String> contractNotes = const [],
    int retryCount = 0,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();

    // Read forensic guidance early — it informs spec generation when present.
    final specGuidance = state.forensicGuidance?.trim();
    final hasSpecGuidance = specGuidance != null && specGuidance.isNotEmpty;

    final plan = await _specAgentService.generate(
      projectRoot,
      kind: SpecKind.plan,
      overwrite: overwriteArtifacts,
      guidanceContext: hasSpecGuidance ? specGuidance : null,
    );
    final spec = await _specAgentService.generate(
      projectRoot,
      kind: SpecKind.spec,
      overwrite: overwriteArtifacts,
      guidanceContext: hasSpecGuidance ? specGuidance : null,
    );
    final subtasks = await _specAgentService.generate(
      projectRoot,
      kind: SpecKind.subtasks,
      overwrite: overwriteArtifacts,
      guidanceContext: hasSpecGuidance ? specGuidance : null,
    );

    final specText = _loadActiveSpec(layout, state.activeTaskTitle);
    final inSubtaskMode = state.currentSubtask?.trim().isNotEmpty == true;
    final subtaskRequiredFiles = inSubtaskMode
        ? (_requiredFilesEnforcer.requiredFilesFromSubtask(state.currentSubtask)
            ?? const <String>[])
        : const <String>[];
    final requiredFilesMode =
        (inSubtaskMode && subtaskRequiredFiles.isNotEmpty)
        ? RequiredFilesMode.allOf
        : RequiredFilesMode.anyOf;
    // If we are in subtask mode but the subtask does not include explicit file
    // targets, do NOT fall back to spec-level required files.
    final requiredFiles = inSubtaskMode
        ? subtaskRequiredFiles
        : _requiredFilesEnforcer.requiredFilesFromSpec(specText);

    final config = ProjectConfig.load(projectRoot);
    final resolvedCategory =
        taskCategory ?? _resolveActiveTaskCategory(projectRoot);

    // Build list of completed subtask titles from recent commit messages.
    final completedSubtaskTitles = <String>[];
    if (state.activeTaskTitle != null) {
      final taskSlug = state.activeTaskId != null
          ? state.activeTaskId!.split('-').take(10).join('-')
          : '';
      final recentMessages = _gitService.recentCommitMessages(
        projectRoot,
        count: 10,
      );
      for (final msg in recentMessages) {
        // Per-subtask commits use format: "feat(<taskSlug>): <subtaskTitle>"
        // We extract everything after the first ): prefix.
        if (taskSlug.isNotEmpty) {
          final prefixPattern = RegExp('^[0-9a-f]+ feat\\($taskSlug\\): ');
          if (prefixPattern.hasMatch(msg)) {
            final subject = msg.replaceFirst(prefixPattern, '').trim();
            if (subject.isNotEmpty) {
              completedSubtaskTitles.add(subject);
            }
          }
        }
      }
    }

    final finalPrompt = await _promptAssembler.assemble(
      codingPrompt,
      projectRoot: projectRoot,
      config: config,
      resolvedCategory: resolvedCategory,
      layout: layout,
      forensicGuidance: state.forensicGuidance,
      reviewStatus: state.reviewStatus,
      lastError: state.lastError,
      activeTaskTitle: state.activeTaskTitle,
      requiredFiles: requiredFiles,
      requiredFilesMode: requiredFilesMode,
      retryCount: retryCount,
      completedSubtaskTitles: completedSubtaskTitles,
    );

    final systemPrompt = _resolveCodingSystemPrompt(
      projectRoot,
      resolvedCategory,
    );

    final coding = await _codingAgentService.run(
      projectRoot,
      prompt: finalPrompt,
      systemPrompt: systemPrompt,
      taskCategory: resolvedCategory,
    );

    // --- Post-diff stage pipeline ---
    if (coding.response.ok) {
      final ctx = PipelineContext(
        projectRoot: projectRoot,
        layout: layout,
        state: state,
        config: config,
        resolvedCategory: resolvedCategory,
        plan: plan,
        spec: spec,
        subtasks: subtasks,
        coding: coding,
        requiredFiles: requiredFiles,
        requiredFilesMode: requiredFilesMode,
        testSummary: testSummary,
        reviewPersona: reviewPersona,
        contractNotes: contractNotes,
      );
      ctx.changedPaths = _gitService.changedPaths(projectRoot);

      final stages = <PipelineStage>[
        _NoDiffCheckStage(),
        _SafeWriteStage(this),
        _AutoFormatStage(_buildTestRunnerService, _gitService),
        _PostFormatNoDiffCheckStage(),
        _TestDeltaGateStage(),
        _DiffBudgetStage(this),
        _BuildReviewBundleStage(_reviewBundleService),
        _RequiredFilesStage(this),
        _QualityGateStage(this),
        _ArchitectureGateStage(this),
        _AcSelfCheckStage(this),
        _ReviewAgentStage(this),
      ];

      for (final stage in stages) {
        final outcome = await stage.execute(ctx);
        switch (outcome) {
          case StageContinue():
            continue;
          case StageEarlyReturn():
            return TaskPipelineResult(
              plan: plan,
              spec: spec,
              subtasks: subtasks,
              coding: coding,
              review: null,
            );
          case StageReject(:final review):
            return TaskPipelineResult(
              plan: plan,
              spec: spec,
              subtasks: subtasks,
              coding: coding,
              review: review,
            );
          case StageReviewComplete(:final review):
            return TaskPipelineResult(
              plan: plan,
              spec: spec,
              subtasks: subtasks,
              coding: coding,
              review: review,
            );
        }
      }
    }

    return TaskPipelineResult(
      plan: plan,
      spec: spec,
      subtasks: subtasks,
      coding: coding,
      review: null,
    );
  }

  TaskCategory _resolveActiveTaskCategory(String projectRoot) {
    final activeTask = _activeTaskResolver.resolve(projectRoot);
    return activeTask?.category ?? TaskCategory.unknown;
  }

  String? _resolveCodingSystemPrompt(
    String projectRoot,
    TaskCategory category,
  ) {
    final key = _agentKeyForCategory(category);
    final prompt = _contextService.loadCodingPersona(projectRoot, key);
    if (prompt != null) {
      return prompt;
    }
    if (key == 'core') {
      return null;
    }
    return _contextService.loadCodingPersona(projectRoot, 'core');
  }

  String _agentKeyForCategory(TaskCategory category) {
    switch (category) {
      case TaskCategory.ui:
        return 'ui';
      case TaskCategory.security:
        return 'security';
      case TaskCategory.docs:
        return 'docs';
      case TaskCategory.architecture:
        return 'architecture';
      case TaskCategory.refactor:
        return 'refactor';
      case TaskCategory.core:
      case TaskCategory.qa:
      case TaskCategory.agent:
      case TaskCategory.unknown:
        return 'core';
    }
  }

  /// Executes [policyCheck] and, on any [StateError], rolls back working
  /// changes (checkout + clean) so the worktree remains clean. The violation
  /// event is logged, then the error is rethrown.
  void _enforcePolicyOrRollback(
    String projectRoot,
    void Function() policyCheck,
  ) {
    try {
      policyCheck();
    } on StateError catch (e) {
      final layout = ProjectLayout(projectRoot);
      try {
        _gitService.discardWorkingChanges(projectRoot);
      } catch (rollbackError) {
        RunLogStore(layout.runLogPath).append(
          event: 'policy_rollback_failed',
          message: 'Failed to rollback worktree after policy violation',
          data: {
            'root': projectRoot,
            'error_class': 'policy',
            'error_kind': 'rollback_failed',
            'violation': e.message,
            'rollback_error': rollbackError.toString(),
          },
        );
        // Escalation: hard reset + clean as last resort.
        try {
          _gitService.hardReset(projectRoot);
          _gitService.cleanUntracked(projectRoot);
        } catch (escalationError) {
          RunLogStore(layout.runLogPath).append(
            event: 'policy_rollback_escalation_failed',
            message: 'Hard-reset escalation also failed',
            data: {
              'root': projectRoot,
              'error_class': 'policy',
              'error_kind': 'rollback_escalation_failed',
              'violation': e.message,
              'escalation_error': escalationError.toString(),
            },
          );
          rethrow;
        }
      }
      // Verify worktree is actually clean after discard/escalation.
      if (_gitService.isGitRepo(projectRoot) &&
          !_gitService.isClean(projectRoot)) {
        RunLogStore(layout.runLogPath).append(
          event: 'policy_rollback_incomplete',
          message: 'Worktree still dirty after policy rollback',
          data: {
            'root': projectRoot,
            'error_class': 'policy',
            'error_kind': 'rollback_incomplete',
            'violation': e.message,
          },
        );
        throw StateError(
          'Worktree still dirty after policy violation rollback: ${e.message}',
        );
      }
      RunLogStore(layout.runLogPath).append(
        event: 'policy_violation_rollback',
        message: 'Rolled back worktree after policy violation',
        data: {
          'root': projectRoot,
          'error_class': 'policy',
          'error_kind': 'policy_violation_rollback',
          'violation': e.message,
        },
      );
      rethrow;
    }
  }

  void _enforceSafeWrite(
    String projectRoot, {
    required TaskCategory taskCategory,
  }) {
    final config = ProjectConfig.load(projectRoot);
    if (!config.safeWriteEnabled) {
      return;
    }
    final effectiveRoots = _effectiveSafeWriteRoots(
      taskCategory: taskCategory,
      configRoots: config.safeWriteRoots,
    );
    final policy = SafeWritePolicy(
      projectRoot: projectRoot,
      allowedRoots: effectiveRoots,
      enabled: config.safeWriteEnabled,
    );
    final changed = _gitService.changedPaths(projectRoot);
    for (final path in changed) {
      final violation = policy.violationForPath(path);
      if (violation == null) {
        continue;
      }
      final roots = effectiveRoots.isEmpty
          ? '(none configured)'
          : effectiveRoots.join(', ');
      final violationPrefix = taskCategory == TaskCategory.docs
          ? 'Policy violation: safe_write_scope blocked'
          : 'Policy violation: safe_write blocked';
      throw StateError(
        '$violationPrefix "$path" '
        '(category: ${violation.category}). ${violation.message} '
        'Allowed roots: $roots.',
      );
    }
  }

  List<String> _effectiveSafeWriteRoots({
    required TaskCategory taskCategory,
    required List<String> configRoots,
  }) {
    if (taskCategory == TaskCategory.docs) {
      return const [
        'docs',
        'README.md',
        'AGENTS.md',
        'GEMINI.md',
        '.genaisys/TASKS.md',
      ];
    }
    return configRoots;
  }

  String? _loadActiveSpec(ProjectLayout layout, String? taskTitle) {
    final title = taskTitle?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }
    final slug = TaskSlugger.slug(title);
    final path = _join(layout.taskSpecsDir, '$slug.md');
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }

  ReviewAgentResult _buildSpecRequiredFilesReject({
    required List<String> missingRequired,
    required List<String> requiredFiles,
    required RequiredFilesMode mode,
  }) {
    final modeMessage = mode == RequiredFilesMode.allOf
        ? 'All required targets must be present in the diff.'
        : 'At least one required target must be present in the diff.';
    final message =
        'REJECT\n'
        'Spec-required files are missing from the diff.\n'
        '$modeMessage\n'
        'Required:\n'
        '${requiredFiles.map((path) => '- $path').join('\n')}\n\n'
        'Missing:\n'
        '${missingRequired.map((path) => '- $path').join('\n')}\n\n'
        'Please update the required files and do not invent alternate paths.';
    return ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(exitCode: 0, stdout: message, stderr: ''),
      usedFallback: false,
    );
  }

  ReviewAgentResult _buildSpecRequiredFilesDeletedReject({
    required List<String> deletedFiles,
    required List<String> requiredFiles,
  }) {
    final message =
        'REJECT\n'
        'Spec-required files were deleted instead of modified/added.\n'
        'Required files must not be deleted — modify or add them instead.\n'
        'Required:\n'
        '${requiredFiles.map((path) => '- $path').join('\n')}\n\n'
        'Deleted:\n'
        '${deletedFiles.map((path) => '- $path').join('\n')}\n\n'
        'Please restore the deleted files and apply the required changes.';
    return ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(exitCode: 0, stdout: message, stderr: ''),
      usedFallback: false,
    );
  }

  void _enforceDiffBudget(String projectRoot) {
    final config = ProjectConfig.load(projectRoot);
    final budget = DiffBudget(
      maxFiles: config.diffBudgetMaxFiles,
      maxAdditions: config.diffBudgetMaxAdditions,
      maxDeletions: config.diffBudgetMaxDeletions,
    );
    final stats = _gitService.diffStats(projectRoot);
    final policy = DiffBudgetPolicy(budget: budget);
    if (policy.allows(stats)) {
      return;
    }
    throw StateError(
      'Policy violation: diff_budget exceeded '
      '(files ${stats.filesChanged}/${budget.maxFiles}, '
      'additions ${stats.additions}/${budget.maxAdditions}, '
      'deletions ${stats.deletions}/${budget.maxDeletions}). '
      'Split the task or raise policies.diff_budget in .genaisys/config.yml.',
    );
  }

  String? _mergeTestSummaries(String? left, String? right) {
    final leftTrimmed = left?.trim();
    final rightTrimmed = right?.trim();
    if ((leftTrimmed == null || leftTrimmed.isEmpty) &&
        (rightTrimmed == null || rightTrimmed.isEmpty)) {
      return null;
    }
    if (leftTrimmed == null || leftTrimmed.isEmpty) {
      return rightTrimmed;
    }
    if (rightTrimmed == null || rightTrimmed.isEmpty) {
      return leftTrimmed;
    }
    return '$leftTrimmed\n\n$rightTrimmed';
  }

  String _requireTestSummaryForReview(String? summary) {
    final trimmed = summary?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      throw StateError(
        'Policy violation: review bundle requires test results. '
        'Enable policies.quality_gate or provide a non-empty test summary.',
      );
    }
    return trimmed;
  }

  bool _isRetryableQualityGateFailure(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('quality_gate command failed') ||
        normalized.contains('quality_gate command timed out') ||
        normalized.contains('quality_gate dependency bootstrap failed') ||
        normalized.contains('quality_gate dependency bootstrap timed out');
  }

  ReviewAgentResult _buildQualityGateReject(String message) {
    return ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(
        exitCode: 0,
        stdout: 'REJECT\nQuality gate failed before review.\n$message',
        stderr: '',
      ),
      usedFallback: false,
    );
  }

  ReviewAgentResult _buildAcSelfCheckReject(String reason) {
    return ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(
        exitCode: 0,
        stdout: 'REJECT\nAC self-check failed before review.\n$reason',
        stderr: '',
      ),
      usedFallback: false,
    );
  }

  ReviewAgentResult? _enforceArchitectureGate(
    String projectRoot, {
    required ProjectConfig config,
    required ProjectLayout layout,
    required dynamic state,
  }) {
    if (!config.pipelineArchitectureGateEnabled) {
      return null;
    }
    ArchitectureHealthReport report;
    try {
      report = _architectureHealthService.check(projectRoot);
    } catch (_) {
      // Architecture gate is non-critical — if the check itself fails
      // (e.g. no lib/ directory), let the pipeline continue to review.
      return null;
    }
    if (report.passed) {
      return null;
    }
    // Critical violations found — rollback and reject.
    final violationMessages = report.violations
        .map((v) => '- ${v.file} imports ${v.importedFile}: ${v.message}')
        .join('\n');
    RunLogStore(layout.runLogPath).append(
      event: 'architecture_gate_reject',
      message: 'Architecture gate rejected the step before review',
      data: {
        'root': projectRoot,
        'task': (state.activeTaskTitle as String?) ?? '',
        'task_id': (state.activeTaskId as String?) ?? '',
        'error_class': 'architecture',
        'error_kind': 'architecture_violation',
        'violation_count': report.violations.length,
        'score': report.score,
      },
    );
    try {
      _gitService.discardWorkingChanges(projectRoot);
    } catch (discardError) {
      RunLogStore(layout.runLogPath).append(
        event: 'architecture_gate_discard_failed',
        message:
            'Failed to discard working changes after architecture gate reject',
        data: {
          'root': projectRoot,
          'task': (state.activeTaskTitle as String?) ?? '',
          'task_id': (state.activeTaskId as String?) ?? '',
          'error_class': 'architecture',
          'error_kind': 'discard_failed',
          'error': discardError.toString(),
        },
      );
      rethrow;
    }
    return ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(
        exitCode: 0,
        stdout:
            'REJECT\n'
            'Architecture gate failed before review.\n'
            'Critical layer violations detected (score: '
            '${report.score.toStringAsFixed(2)}):\n'
            '$violationMessages\n\n'
            'Fix the layer violations so that core does not import from '
            'higher layers (ui, app, desktop).',
        stderr: '',
      ),
      usedFallback: false,
    );
  }

  String? _collectArchitectureWarnings(String projectRoot) {
    try {
      final report = _architectureHealthService.check(projectRoot);
      if (report.warnings.isEmpty) {
        return null;
      }
      final warningMessages = report.warnings
          .map((w) => '- ${w.file}: ${w.message}')
          .join('\n');
      return '### ARCHITECTURE WARNINGS\n$warningMessages';
    } catch (_) {
      return null;
    }
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
