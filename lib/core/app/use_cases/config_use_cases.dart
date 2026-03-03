// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/config_dto.dart';
import 'in_process_genaisys_api.dart';

class GetConfigUseCase {
  GetConfigUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppConfigDto>> run(String projectRoot) {
    return _api.getConfig(projectRoot);
  }
}

class UpdateConfigUseCase {
  UpdateConfigUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<ConfigUpdateDto>> run(
    String projectRoot, {
    required AppConfigDto config,
  }) {
    return _api.updateConfig(projectRoot, config: config);
  }
}
