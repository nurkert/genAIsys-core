// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../contracts/app_result.dart';
import '../../dto/autopilot_dto.dart';
import '../../../services/branch_hygiene_service.dart';
import 'autopilot_use_case_utils.dart';

class AutopilotBranchCleanupUseCase {
  AutopilotBranchCleanupUseCase({BranchHygieneService? service})
    : _service = service ?? BranchHygieneService();

  final BranchHygieneService _service;

  Future<AppResult<AutopilotBranchCleanupDto>> run(
    String projectRoot, {
    String? baseBranch,
    String? remote,
    bool includeRemote = false,
    bool dryRun = false,
  }) async {
    try {
      final result = _service.cleanupMergedBranches(
        projectRoot,
        baseBranch: baseBranch,
        remote: remote,
        includeRemote: includeRemote,
        dryRun: dryRun,
      );
      return AppResult.success(
        AutopilotBranchCleanupDto(
          baseBranch: result.baseBranch,
          dryRun: result.dryRun,
          deletedLocalBranches: result.deletedLocalBranches,
          deletedRemoteBranches: result.deletedRemoteBranches,
          skippedBranches: result.skippedBranches,
          failures: result.failures,
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(mapAutopilotError(error, stackTrace));
    }
  }
}
