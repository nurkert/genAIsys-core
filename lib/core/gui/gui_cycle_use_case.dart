// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/action_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// GUI wrapper for cycle actions.
class GuiCycleUseCase {
  GuiCycleUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<CycleTickDto>> tick(String projectRoot) {
    return _api.cycle(projectRoot);
  }

  Future<AppResult<TaskCycleExecutionDto>> run(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    return _api.runTaskCycle(
      projectRoot,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
    );
  }
}
