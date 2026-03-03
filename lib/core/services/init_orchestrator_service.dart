// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../models/init_orchestration_context.dart';
import '../models/init_orchestration_result.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'agents/agent_service.dart';

part 'init_pipeline_stages.dart';

/// Runs the 6-stage agent-driven init pipeline for a project.
///
/// Stages: Vision → Architecture → Backlog → Config → Rules → Verification.
/// If the Verification stage rejects, the pipeline retries from the beginning
/// up to [_maxRetries] times, incorporating rejection feedback into the next
/// attempt. After a successful pass, all 5 artifacts are written to disk.
class InitOrchestratorService {
  InitOrchestratorService({AgentService? agentService})
    : _agentService = agentService ?? AgentService();

  final AgentService _agentService;

  static const int _maxRetries = 2;

  Future<InitOrchestrationResult> run(
    String projectRoot, {
    required InitOrchestrationContext ctx,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);
    final writtenPaths = <String>[];

    if (ctx.isReinit) {
      _loadExistingArtifacts(ctx, layout);
    }

    // The effective input text may grow with retry preambles.
    var effectiveInputText = ctx.normalizedInputText;
    var retryCount = 0;

    while (true) {
      // Build a fresh working context for this attempt so we don't mutate
      // the (final) normalizedInputText field on the original context.
      final attempt = InitOrchestrationContext(
        projectRoot: ctx.projectRoot,
        normalizedInputText: effectiveInputText,
        inputSourcePayload: ctx.inputSourcePayload,
        isReinit: ctx.isReinit,
        overwrite: ctx.overwrite,
        existingVision: ctx.existingVision,
        existingArchitecture: ctx.existingArchitecture,
        existingTasks: ctx.existingTasks,
        existingConfig: ctx.existingConfig,
        existingRules: ctx.existingRules,
        retryCount: retryCount,
      );

      final stages = _buildStages();
      String? retryReason;

      for (final stage in stages) {
        runLog.append(
          event: 'init_stage_start',
          message: 'Starting init stage: ${stage.name}',
          data: {'stage': stage.name, 'retry_count': retryCount},
        );

        final outcome = await stage.execute(attempt, _agentService, projectRoot);

        if (outcome is InitStageFailed) {
          runLog.append(
            event: 'init_stage_failed',
            message: 'Init stage failed: ${stage.name}',
            data: {
              'stage': stage.name,
              'reason': outcome.reason,
              'retry_count': retryCount,
              'error_class': 'init_pipeline_error',
              'error_kind': 'stage_failed',
            },
          );
          return InitOrchestrationResult(
            projectRoot: projectRoot,
            writtenPaths: List.unmodifiable(writtenPaths),
            retryCount: retryCount,
            isReinit: ctx.isReinit,
          );
        }

        if (outcome is InitStageRetry) {
          retryReason = outcome.reason;
          break;
        }

        // InitStageContinue — log success and move to next stage.
        runLog.append(
          event: 'init_stage_complete',
          message: 'Init stage complete: ${stage.name}',
          data: {'stage': stage.name, 'retry_count': retryCount},
        );
      }

      if (retryReason != null) {
        retryCount += 1;
        if (retryCount > _maxRetries) {
          runLog.append(
            event: 'init_stage_failed',
            message: 'Init pipeline exceeded max retries after verification',
            data: {
              'reason': retryReason,
              'retry_count': retryCount,
              'error_class': 'init_pipeline_error',
              'error_kind': 'max_retries_exceeded',
            },
          );
          return InitOrchestrationResult(
            projectRoot: projectRoot,
            writtenPaths: List.unmodifiable(writtenPaths),
            retryCount: retryCount,
            isReinit: ctx.isReinit,
          );
        }

        runLog.append(
          event: 'init_orchestration_retry',
          message: 'Init pipeline retrying from stage 1',
          data: {'retry_count': retryCount, 'reason': retryReason},
        );

        // Prepend rejection feedback so the next attempt can improve.
        effectiveInputText =
            '## Reviewer Feedback (retry $retryCount)\n'
            '$retryReason\n\n'
            '## Original Input\n'
            '$effectiveInputText';

        continue;
      }

      // All 6 stages succeeded — write artifacts to disk.
      _writeArtifact(layout.visionPath, attempt.vision!, ctx, runLog, writtenPaths);
      _writeArtifact(layout.architecturePath, attempt.architecture!, ctx, runLog, writtenPaths);
      _writeArtifact(layout.tasksPath, attempt.backlog!, ctx, runLog, writtenPaths);
      _writeArtifact(layout.configPath, attempt.config!, ctx, runLog, writtenPaths);
      _writeArtifact(layout.rulesPath, attempt.rules!, ctx, runLog, writtenPaths);

      runLog.append(
        event: 'init_orchestration_complete',
        message: 'Init orchestration completed successfully',
        data: {
          'written_paths': writtenPaths,
          'retry_count': retryCount,
          'is_reinit': ctx.isReinit,
        },
      );

      return InitOrchestrationResult(
        projectRoot: projectRoot,
        writtenPaths: List.unmodifiable(writtenPaths),
        retryCount: retryCount,
        isReinit: ctx.isReinit,
      );
    }
  }

  List<InitPipelineStage> _buildStages() => [
    _VisionStage(),
    _ArchitectureStage(),
    _BacklogStage(),
    _ConfigStage(),
    _RulesStage(),
    _VerificationStage(),
  ];

  void _loadExistingArtifacts(
    InitOrchestrationContext ctx,
    ProjectLayout layout,
  ) {
    ctx.existingVision = _readIfExists(layout.visionPath);
    ctx.existingArchitecture = _readIfExists(layout.architecturePath);
    ctx.existingTasks = _readIfExists(layout.tasksPath);
    ctx.existingConfig = _readIfExists(layout.configPath);
    ctx.existingRules = _readIfExists(layout.rulesPath);
  }

  String? _readIfExists(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  void _writeArtifact(
    String path,
    String content,
    InitOrchestrationContext ctx,
    RunLogStore runLog,
    List<String> writtenPaths,
  ) {
    if (ctx.isReinit && !ctx.overwrite && File(path).existsSync()) {
      return;
    }
    File(path).writeAsStringSync(content);
    writtenPaths.add(path);
    runLog.append(
      event: 'init_artifact_written',
      message: 'Wrote init artifact',
      data: {'path': path},
    );
  }
}
