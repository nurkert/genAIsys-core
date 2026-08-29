// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/action_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// Thin use-case wrapper for block action in GUI flows.
class GuiBlockTaskUseCase {
  GuiBlockTaskUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<TaskBlockedDto>> run(String projectRoot, {String? reason}) {
    return _api.blockTask(projectRoot, reason: reason);
  }
}
