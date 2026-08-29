// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/config_dto.dart';
import '../dto/config_schema_dto.dart';
import 'in_process_genaisys_api.dart';

class GetConfigUseCase {
  GetConfigUseCase({GenaisysApi? api}) : _api = api ?? InProcessGenaisysApi();

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

/// Reads every registered config key with the metadata needed to render it.
///
/// Prefer this over [GetConfigUseCase] for any surface that should stay
/// complete as config keys are added: it is driven by the config field
/// registry rather than a hand-maintained DTO.
class GetConfigSchemaUseCase {
  GetConfigSchemaUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<ConfigSchemaDto>> run(String projectRoot) {
    return _api.getConfigSchema(projectRoot);
  }
}

/// Writes settings by qualified key. All-or-nothing.
class SetConfigValuesUseCase {
  SetConfigValuesUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<ConfigWriteResultDto>> run(
    String projectRoot, {
    required Map<String, Object?> values,
  }) {
    return _api.setConfigValues(projectRoot, values: values);
  }
}

/// Restores settings to their registered defaults.
class ResetConfigValuesUseCase {
  ResetConfigValuesUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<ConfigWriteResultDto>> run(
    String projectRoot, {
    required List<String> qualifiedKeys,
  }) {
    return _api.resetConfigValues(projectRoot, qualifiedKeys: qualifiedKeys);
  }
}
