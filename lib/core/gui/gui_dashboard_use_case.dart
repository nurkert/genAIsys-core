// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/dashboard_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// Thin use-case wrapper for dashboard data loading.
///
/// Keeps GUI layers dependent on a use-case entrypoint instead of directly
/// coupling widgets to the adapter implementation.
class GuiDashboardUseCase {
  GuiDashboardUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppDashboardDto>> load(String projectRoot) {
    return _api.getDashboard(projectRoot);
  }
}
