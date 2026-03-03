// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'task_pipeline_service.dart';

// ---------------------------------------------------------------------------
// Pipeline stages (private, same library for access to service internals)
// ---------------------------------------------------------------------------

class _NoDiffCheckStage implements PipelineStage {
  @override
  String get name => 'no_diff_check';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    if (ctx.changedPaths.isEmpty) {
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'task_cycle_no_diff',
        message: 'No diff produced by coding agent (short-circuit)',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'review',
          'error_kind': 'no_diff',
        },
      );
      return StageEarlyReturn();
    }
    return StageContinue();
  }
}

class _SafeWriteStage implements PipelineStage {
  _SafeWriteStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'safe_write';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    _pipeline._enforcePolicyOrRollback(
      ctx.projectRoot,
      () => _pipeline._enforceSafeWrite(
        ctx.projectRoot,
        taskCategory: ctx.resolvedCategory,
      ),
    );
    return StageContinue();
  }
}

class _AutoFormatStage implements PipelineStage {
  _AutoFormatStage(this._buildTestRunnerService, this._gitService);
  final BuildTestRunnerService _buildTestRunnerService;
  final GitService _gitService;

  @override
  String get name => 'auto_format';

  @override
  Future<PipelineStageOutcome> execute(PipelineContext ctx) async {
    await _buildTestRunnerService.autoFormatChangedDartFiles(
      ctx.projectRoot,
      changedPaths: ctx.changedPaths,
    );
    // Re-capture changed paths after auto-format so post-format file
    // changes are included in the diff budget calculation and downstream
    // spec-required-files checks.
    ctx.changedPaths = _gitService.changedPaths(ctx.projectRoot);
    return StageContinue();
  }
}

class _PostFormatNoDiffCheckStage implements PipelineStage {
  @override
  String get name => 'post_format_no_diff_check';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    if (ctx.changedPaths.isEmpty) {
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'task_cycle_no_diff',
        message:
            'No diff after auto-format (all changes were formatting-only)',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'review',
          'error_kind': 'no_diff',
        },
      );
      return StageEarlyReturn();
    }
    return StageContinue();
  }
}

class _TestDeltaGateStage implements PipelineStage {
  @override
  String get name => 'test_delta_gate';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    if (!ctx.config.pipelineTestDeltaGateEnabled) return StageContinue();

    final enforcedCategories = ctx.config.pipelineTestDeltaGateCategories;
    if (!enforcedCategories.contains(ctx.resolvedCategory.name)) {
      return StageContinue();
    }

    final hasTestFile = ctx.changedPaths.any((p) => p.endsWith('_test.dart'));
    if (hasTestFile) return StageContinue();

    RunLogStore(ctx.layout.runLogPath).append(
      event: 'test_delta_gate_reject',
      message: 'No test files modified — test delta gate rejected',
      data: {
        'root': ctx.projectRoot,
        'task': ctx.state.activeTaskTitle ?? '',
        'task_id': ctx.state.activeTaskId ?? '',
        'category': ctx.resolvedCategory.name,
        'error_class': 'review',
        'error_kind': 'test_delta_missing',
      },
    );
    return StageReject(ReviewAgentResult(
      decision: ReviewDecision.reject,
      response: AgentResponse(
        exitCode: -1,
        stdout:
            'REJECT\nNo test files modified. Category '
            '${ctx.resolvedCategory.name.toUpperCase()} requires test coverage.\n'
            'Add or update a *_test.dart file alongside your implementation.',
        stderr: '',
      ),
      usedFallback: false,
    ));
  }
}

class _DiffBudgetStage implements PipelineStage {
  _DiffBudgetStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'diff_budget';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    _pipeline._enforcePolicyOrRollback(
      ctx.projectRoot,
      () => _pipeline._enforceDiffBudget(ctx.projectRoot),
    );
    return StageContinue();
  }
}

class _BuildReviewBundleStage implements PipelineStage {
  _BuildReviewBundleStage(this._reviewBundleService);
  final ReviewBundleService _reviewBundleService;

  @override
  String get name => 'build_review_bundle';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    final sinceCommitSha = ctx.config.reviewDiffDeltaEnabled
        ? ctx.state.activeTask.lastRejectCommitSha
        : null;
    final bundle = _reviewBundleService.build(
      ctx.projectRoot,
      testSummary: ctx.testSummary,
      sinceCommitSha: sinceCommitSha,
    );
    final hasDiff =
        bundle.diffSummary.trim().isNotEmpty ||
        bundle.diffPatch.trim().isNotEmpty;
    if (!hasDiff) {
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'task_cycle_no_diff',
        message: 'No diff produced by coding agent; contract notes preserved for next retry.',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'review',
          'error_kind': 'no_diff',
          if (ctx.contractNotes.isNotEmpty)
            'contract_notes': ctx.contractNotes,
        },
      );
      return StageEarlyReturn();
    }
    ctx.reviewBundle = bundle;
    return StageContinue();
  }
}

class _RequiredFilesStage implements PipelineStage {
  _RequiredFilesStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'required_files';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    // Detect spec-required files that were deleted (status D).
    final deletedRequired = _pipeline._requiredFilesEnforcer
        .deletedRequiredFiles(
      ctx.projectRoot,
      ctx.requiredFiles,
      ctx.changedPaths,
    );
    if (deletedRequired.isNotEmpty) {
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'policy_error',
        message: 'Spec-required files were deleted',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'policy',
          'error_kind': 'spec_required_files_deleted',
          'required_files': ctx.requiredFiles,
          'deleted_files': deletedRequired,
          'changed_paths': ctx.changedPaths,
        },
      );
      return StageReject(
        _pipeline._buildSpecRequiredFilesDeletedReject(
          deletedFiles: deletedRequired,
          requiredFiles: ctx.requiredFiles,
        ),
      );
    }

    var requiredOk = ctx.requiredFiles.isEmpty
        ? true
        : (ctx.requiredFilesMode == RequiredFilesMode.allOf
              ? _pipeline._requiredFilesEnforcer
                  .missingRequiredFiles(ctx.requiredFiles, ctx.changedPaths)
                  .isEmpty
              : _pipeline._requiredFilesEnforcer
                  .hasAnyRequiredFile(ctx.requiredFiles, ctx.changedPaths));
    // Disk fallback: if required files all exist on disk but are not in
    // the diff (they don't need changes), consider the check passed.
    if (!requiredOk &&
        _pipeline._requiredFilesEnforcer.allRequiredFilesExistOnDisk(
          ctx.projectRoot, ctx.requiredFiles,
        )) {
      requiredOk = true;
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'spec_required_files_disk_fallback',
        message: 'Required files exist on disk but not in diff — passing',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'required_files': ctx.requiredFiles,
        },
      );
    }
    if (!requiredOk) {
      final missingRequired =
          ctx.requiredFilesMode == RequiredFilesMode.allOf
          ? _pipeline._requiredFilesEnforcer
              .missingRequiredFiles(ctx.requiredFiles, ctx.changedPaths)
          // For any-of, "missing" is the full list: none were touched.
          : ctx.requiredFiles;
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'policy_error',
        message: 'Spec-required files missing from diff',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'policy',
          'error_kind': 'spec_required_files_missing',
          'required_mode': ctx.requiredFilesMode.name,
          'required_files': ctx.requiredFiles,
          'missing_files': missingRequired,
          'changed_paths': ctx.changedPaths,
        },
      );
      return StageReject(
        _pipeline._buildSpecRequiredFilesReject(
          missingRequired: missingRequired,
          requiredFiles: ctx.requiredFiles,
          mode: ctx.requiredFilesMode,
        ),
      );
    }
    return StageContinue();
  }
}

class _QualityGateStage implements PipelineStage {
  _QualityGateStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'quality_gate';

  @override
  Future<PipelineStageOutcome> execute(PipelineContext ctx) async {
    ctx.mergedTestSummary = ctx.reviewBundle!.testSummary;
    try {
      final quality = await _pipeline._buildTestRunnerService.run(
        ctx.projectRoot,
        changedPaths: ctx.changedPaths,
      );
      ctx.mergedTestSummary = _pipeline._mergeTestSummaries(
        ctx.reviewBundle!.testSummary,
        quality.summary,
      );
    } on StateError catch (error) {
      final message = error.message.toString().trim();
      if (_pipeline._isRetryableQualityGateFailure(message)) {
        RunLogStore(ctx.layout.runLogPath).append(
          event: 'quality_gate_reject',
          message: 'Quality gate rejected the step before review',
          data: {
            'root': ctx.projectRoot,
            'task': ctx.state.activeTaskTitle ?? '',
            'task_id': ctx.state.activeTaskId ?? '',
            'error_class': 'quality_gate',
            'error_kind': 'quality_gate_failed',
          },
        );
        return StageReject(_pipeline._buildQualityGateReject(message));
      }
      rethrow;
    }
    return StageContinue();
  }
}

class _ArchitectureGateStage implements PipelineStage {
  _ArchitectureGateStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'architecture_gate';

  @override
  PipelineStageOutcome execute(PipelineContext ctx) {
    final archGateReview = _pipeline._enforceArchitectureGate(
      ctx.projectRoot,
      config: ctx.config,
      layout: ctx.layout,
      state: ctx.state,
    );
    if (archGateReview != null) {
      return StageReject(archGateReview);
    }
    return StageContinue();
  }
}

class _AcSelfCheckStage implements PipelineStage {
  _AcSelfCheckStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'ac_self_check';

  @override
  Future<PipelineStageOutcome> execute(PipelineContext ctx) async {
    if (!ctx.config.pipelineAcSelfCheckEnabled) {
      return StageContinue();
    }
    final bundle = ctx.reviewBundle!;
    final requirement = bundle.subtaskDescription ?? bundle.spec ?? '';
    final diffSummary = bundle.diffSummary;
    if (requirement.trim().isEmpty || diffSummary.trim().isEmpty) {
      return StageContinue();
    }
    AcSelfCheckResult result;
    try {
      result = await _pipeline._specAgentService.checkImplementationAgainstAc(
        ctx.projectRoot,
        requirement: requirement,
        diffSummary: diffSummary,
      );
    } catch (_) {
      // Non-fatal: skip on unexpected error.
      return StageContinue();
    }
    if (result.skipped || result.passed) {
      return StageContinue();
    }
    final reason =
        result.reason ??
        'Implementation does not satisfy the requirement.';
    RunLogStore(ctx.layout.runLogPath).append(
      event: 'ac_self_check_reject',
      message: 'AC self-check rejected before review agent',
      data: {
        'root': ctx.projectRoot,
        'task': ctx.state.activeTaskTitle ?? '',
        'task_id': ctx.state.activeTaskId ?? '',
        'reason': reason,
        'error_class': 'review',
        'error_kind': 'ac_self_check_failed',
      },
    );
    return StageReject(_pipeline._buildAcSelfCheckReject(reason));
  }
}

class _ReviewAgentStage implements PipelineStage {
  _ReviewAgentStage(this._pipeline);
  final TaskPipelineService _pipeline;

  @override
  String get name => 'review_agent';

  @override
  Future<PipelineStageOutcome> execute(PipelineContext ctx) async {
    final requiredTestSummary = _pipeline._requireTestSummaryForReview(
      ctx.mergedTestSummary,
    );
    String? archWarnings;
    if (ctx.config.pipelineArchitectureGateEnabled) {
      archWarnings = _pipeline._collectArchitectureWarnings(ctx.projectRoot);
    }
    final baseBundle = ctx.reviewBundle!;
    final reviewBundle =
        requiredTestSummary == baseBundle.testSummary && archWarnings == null
        ? baseBundle
        : ReviewBundle(
            diffSummary: baseBundle.diffSummary,
            diffPatch: baseBundle.diffPatch,
            testSummary: archWarnings != null
                ? '$requiredTestSummary\n\n$archWarnings'
                : requiredTestSummary,
            taskTitle: baseBundle.taskTitle,
            spec: baseBundle.spec,
            subtaskDescription: baseBundle.subtaskDescription,
          );
    try {
      final review = await _pipeline._reviewAgentService.reviewBundle(
        ctx.projectRoot,
        bundle: reviewBundle,
        persona: ctx.reviewPersona,
        strictness: ctx.config.reviewStrictness,
        contractNotes: ctx.contractNotes,
      );
      return StageReviewComplete(review);
    } catch (reviewError) {
      // Review agent crash resilience: if the agent CLI crashes
      // (exit code != 0, unparseable output), treat as a synthetic
      // reject so the orchestrator retries instead of halting.
      RunLogStore(ctx.layout.runLogPath).append(
        event: 'review_agent_crash',
        message: 'Review agent crashed — treating as reject',
        data: {
          'root': ctx.projectRoot,
          'task': ctx.state.activeTaskTitle ?? '',
          'task_id': ctx.state.activeTaskId ?? '',
          'error_class': 'review',
          'error_kind': 'review_agent_crash',
          'error': reviewError.toString(),
        },
      );
      return StageReviewComplete(ReviewAgentResult(
        decision: ReviewDecision.reject,
        response: AgentResponse(
          exitCode: -1,
          stdout:
              'REJECT\nReview agent crashed. '
              'This is a synthetic reject to allow retry.\n'
              'Error: $reviewError',
          stderr: '',
        ),
        usedFallback: false,
      ));
    }
  }
}
