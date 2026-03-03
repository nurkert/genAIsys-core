// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'review_status_dto.dart';
import 'status_snapshot_dto.dart';

class AppDashboardDto {
  const AppDashboardDto({required this.status, required this.review});

  final AppStatusSnapshotDto status;
  final AppReviewStatusDto review;
}
