// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/autopilot/autopilot_release_candidate_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotCandidateUseCase {
  AutopilotCandidateUseCase({AutopilotReleaseCandidateService? service})
    : _service = service ?? AutopilotReleaseCandidateService();

  final AutopilotReleaseCandidateService _service;

  Future<AppResult<AutopilotCandidateDto>> run(
    String projectRoot, {
    bool skipSuites = false,
  }) async {
    try {
      final result = await _service.runCandidate(
        projectRoot,
        skipSuites: skipSuites,
      );
      return AppResult.success(
        AutopilotCandidateDto(
          passed: result.passed,
          skipSuites: result.skipSuites,
          missingFiles: result.missingFiles,
          missingDoneBlockers: result.missingDoneBlockers,
          openCriticalP1Lines: result.openCriticalP1Lines,
          commands: result.commandOutcomes
              .map(
                (entry) => AutopilotCandidateCommandDto(
                  command: entry.command,
                  ok: entry.ok,
                  exitCode: entry.exitCode,
                  timedOut: entry.timedOut,
                  durationMs: entry.durationMs,
                  stdoutExcerpt: entry.stdoutExcerpt,
                  stderrExcerpt: entry.stderrExcerpt,
                ),
              )
              .toList(growable: false),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
