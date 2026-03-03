// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'telemetry_dto.dart';

class AppStatusSnapshotDto {
  const AppStatusSnapshotDto({
    required this.projectRoot,
    required this.tasksTotal,
    required this.tasksOpen,
    required this.tasksDone,
    required this.tasksBlocked,
    required this.activeTaskTitle,
    required this.activeTaskId,
    required this.reviewStatus,
    required this.reviewUpdatedAt,
    required this.cycleCount,
    required this.lastUpdated,
    this.lastError,
    this.lastErrorClass,
    this.lastErrorKind,
    required this.workflowStage,
    required this.health,
    required this.telemetry,
  });

  final String projectRoot;
  final int tasksTotal;
  final int tasksOpen;
  final int tasksDone;
  final int tasksBlocked;
  final String? activeTaskTitle;
  final String? activeTaskId;
  final String? reviewStatus;
  final String? reviewUpdatedAt;
  final int cycleCount;
  final String? lastUpdated;
  final String? lastError;
  final String? lastErrorClass;
  final String? lastErrorKind;
  final String workflowStage;
  final AppHealthSnapshotDto health;
  final AppRunTelemetryDto telemetry;
}
