// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../contracts/app_result.dart';
import '../contracts/genaisys_api.dart';
import '../dto/dashboard_dto.dart';
import '../dto/status_snapshot_dto.dart';
import 'in_process_genaisys_api.dart';

class GetDashboardUseCase {
  GetDashboardUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppDashboardDto>> run(String projectRoot) {
    return _api.getDashboard(projectRoot);
  }
}

class GetStatusUseCase {
  GetStatusUseCase({GenaisysApi? api})
    : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  Future<AppResult<AppStatusSnapshotDto>> run(String projectRoot) {
    return _api.getStatus(projectRoot);
  }
}
