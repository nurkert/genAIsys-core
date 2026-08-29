// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/config_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// GUI wrapper for config read/update.
class GuiConfigUseCase {
  GuiConfigUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppConfigDto>> load(String projectRoot) {
    return _api.getConfig(projectRoot);
  }

  Future<AppResult<ConfigUpdateDto>> update(
    String projectRoot, {
    required AppConfigDto config,
  }) {
    return _api.updateConfig(projectRoot, config: config);
  }
}
