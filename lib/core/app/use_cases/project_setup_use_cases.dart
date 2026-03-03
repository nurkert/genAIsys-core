// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/action_dto.dart';
import 'in_process_genaisys_api.dart';

class InitializeProjectUseCase {
  InitializeProjectUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<ProjectInitializationDto>> run(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _api.initializeProject(projectRoot, overwrite: overwrite);
  }
}

class InitializeSpecArtifactsUseCase {
  InitializeSpecArtifactsUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<SpecInitializationDto>> initializePlan(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _api.initializePlan(projectRoot, overwrite: overwrite);
  }

  Future<AppResult<SpecInitializationDto>> initializeSpec(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _api.initializeSpec(projectRoot, overwrite: overwrite);
  }

  Future<AppResult<SpecInitializationDto>> initializeSubtasks(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _api.initializeSubtasks(projectRoot, overwrite: overwrite);
  }
}
