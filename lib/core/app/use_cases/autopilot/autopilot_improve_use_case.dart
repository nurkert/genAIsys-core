// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/self_improvement_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotImproveUseCase {
  AutopilotImproveUseCase({SelfImprovementService? service})
    : _service = service ?? SelfImprovementService();

  final SelfImprovementService _service;

  Future<AppResult<AutopilotImproveDto>> run(
    String projectRoot, {
    bool runMeta = true,
    bool runEval = true,
    bool runTune = true,
    bool keepWorkspaces = false,
  }) async {
    try {
      final result = await _service.run(
        projectRoot,
        runMeta: runMeta,
        runEval: runEval,
        runTune: runTune,
        keepWorkspaces: keepWorkspaces,
      );
      return AppResult.success(
        AutopilotImproveDto(
          meta: result.meta == null
              ? null
              : AutopilotMetaTasksDto(
                  created: result.meta!.created,
                  skipped: result.meta!.skipped,
                  createdTitles: result.meta!.createdTitles,
                  skippedTitles: result.meta!.skippedTitles,
                ),
          eval: result.eval == null
              ? null
              : AutopilotEvalRunDto(
                  runId: result.eval!.runId,
                  runAt: result.eval!.runAt,
                  successRate: result.eval!.successRate,
                  passed: result.eval!.passed,
                  total: result.eval!.total,
                  outputDir: result.eval!.outputDir,
                  results: result.eval!.results
                      .map(
                        (entry) => AutopilotEvalCaseDto(
                          id: entry.id,
                          title: entry.title,
                          passed: entry.passed,
                          reviewDecision: entry.reviewDecision,
                          filesChanged: entry.diffStats?.filesChanged ?? 0,
                          additions: entry.diffStats?.additions ?? 0,
                          deletions: entry.diffStats?.deletions ?? 0,
                          policyViolation: entry.policyViolation,
                          policyMessage: entry.policyMessage,
                          reason: entry.reason,
                        ),
                      )
                      .toList(growable: false),
                ),
          selfTune: result.tune == null
              ? null
              : AutopilotSelfTuneDto(
                  applied: result.tune!.applied,
                  reason: result.tune!.reason,
                  successRate: result.tune!.successRate,
                  samples: result.tune!.samples,
                  before: result.tune!.before,
                  after: result.tune!.after,
                ),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
