// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';

/// Aggregated result from a background workspace refresh.
///
/// All fields are composed of primitives, enums, and nested DTOs — they are
/// safe to send across [Isolate] boundaries without custom serialisation.
class WorkspaceRefreshResult {
  const WorkspaceRefreshResult({
    this.dashboard,
    this.dashboardError,
    this.taskList,
    this.nextTask,
    this.taskError,
    this.reviewStatus,
    this.reviewError,
    this.config,
    this.configError,
  });

  final AppDashboardDto? dashboard;
  final String? dashboardError;
  final AppTaskListDto? taskList;
  final AppTaskDto? nextTask;
  final String? taskError;
  final AppReviewStatusDto? reviewStatus;
  final String? reviewError;
  final AppConfigDto? config;
  final String? configError;
}

/// Aggregated result from a background autopilot status fetch.
class AutopilotStatusRefreshResult {
  const AutopilotStatusRefreshResult({this.status, this.error});

  final AutopilotStatusDto? status;
  final String? error;
}

// ---------------------------------------------------------------------------
// Top-level async functions executed inside a background isolate.
//
// CRITICAL DESIGN DECISIONS:
//
//   1. These MUST remain top-level (not instance methods, not closures that
//      capture `this`) so that the Dart runtime can send them across isolate
//      boundaries without capturing unsendable widget/controller state.
//
//   2. A fresh [InProcessGenaisysApi] (or [AutopilotStatusUseCase]) is
//      created INSIDE the isolate.  The default constructors wire up all
//      internal dependencies (services, stores, git) automatically.
//
//   3. [Isolate.run] accepts `FutureOr<R>`, so async functions work.  The
//      isolate spins its own event loop until the async computation completes.
//
//   4. All returned DTOs are composed of primitives, enums, Lists, and Maps
//      — all Dart-native sendable types.  Verified by static analysis of
//      every DTO in `lib/core/app/dto/`.
// ---------------------------------------------------------------------------

/// Runs all read-only workspace API calls in a background isolate.
///
/// Creates a fresh [InProcessGenaisysApi] inside the isolate and calls:
///   • getDashboard (status + review)
///   • listTasks + getNextTask
///   • getReviewStatus
///   • optionally getConfig
Future<WorkspaceRefreshResult> _refreshWorkspaceInIsolate(
  (String rootPath, bool includeConfig) args,
) async {
  final String rootPath = args.$1;
  final bool includeConfig = args.$2;
  final InProcessGenaisysApi api = InProcessGenaisysApi();

  // --- Dashboard (status + review in one call) ---
  AppDashboardDto? dashboard;
  String? dashboardError;
  final AppResult<AppDashboardDto> dashResult = await api.getDashboard(
    rootPath,
  );
  if (dashResult.ok && dashResult.data != null) {
    dashboard = dashResult.data;
  } else {
    dashboardError = dashResult.error?.message ?? 'Failed to load dashboard.';
  }

  // --- Tasks ---
  AppTaskListDto? taskList;
  AppTaskDto? nextTask;
  String? taskError;
  final AppResult<AppTaskListDto> tasksResult = await api.listTasks(
    rootPath,
    query: const TaskListQuery(sortByPriority: true),
  );
  if (tasksResult.ok && tasksResult.data != null) {
    taskList = tasksResult.data;
  } else {
    taskError = tasksResult.error?.message ?? 'Failed to load tasks.';
  }
  final AppResult<AppTaskDto?> nextTaskResult = await api.getNextTask(rootPath);
  if (nextTaskResult.ok) {
    nextTask = nextTaskResult.data;
  } else {
    taskError ??= nextTaskResult.error?.message ?? 'Failed to load next task.';
  }

  // --- Review (standalone, in case dashboard failed) ---
  AppReviewStatusDto? reviewStatus;
  String? reviewError;
  if (dashboard != null) {
    reviewStatus = dashboard.review;
  } else {
    final AppResult<AppReviewStatusDto> reviewResult = await api
        .getReviewStatus(rootPath);
    if (reviewResult.ok && reviewResult.data != null) {
      reviewStatus = reviewResult.data;
    } else {
      reviewError =
          reviewResult.error?.message ?? 'Failed to load review status.';
    }
  }

  // --- Config (optional) ---
  AppConfigDto? config;
  String? configError;
  if (includeConfig) {
    final AppResult<AppConfigDto> configResult = await api.getConfig(rootPath);
    if (configResult.ok && configResult.data != null) {
      config = configResult.data;
    } else {
      configError = configResult.error?.message ?? 'Failed to load config.';
    }
  }

  return WorkspaceRefreshResult(
    dashboard: dashboard,
    dashboardError: dashboardError,
    taskList: taskList,
    nextTask: nextTask,
    taskError: taskError,
    reviewStatus: reviewStatus,
    reviewError: reviewError,
    config: config,
    configError: configError,
  );
}

/// Fetches autopilot status in a background isolate.
///
/// Creates a fresh [AutopilotStatusUseCase] inside the isolate.
Future<AutopilotStatusRefreshResult> _refreshAutopilotStatusInIsolate(
  String rootPath,
) async {
  final AutopilotStatusUseCase useCase = AutopilotStatusUseCase();
  final AppResult<AutopilotStatusDto> result = await useCase.load(rootPath);
  if (result.ok && result.data != null) {
    return AutopilotStatusRefreshResult(status: result.data);
  }
  return AutopilotStatusRefreshResult(
    error: result.error?.message ?? 'Unknown autopilot status error.',
  );
}

// ---------------------------------------------------------------------------
// Public API — call these from the main-thread controllers.
// ---------------------------------------------------------------------------

/// Runs a full workspace refresh in a background [Isolate].
///
/// If the isolate spawn fails (e.g. hot-reload artefact, release-mode sandbox
/// restriction) the method returns an **empty** [WorkspaceRefreshResult] with
/// a descriptive [WorkspaceRefreshResult.dashboardError].  It does **not**
/// fall back to running the blocking API calls on the main thread because
/// those calls use [Process.runSync] and synchronous file I/O that would
/// freeze the UI event-loop for 150-450 ms — enough to deadlock window
/// initialization in release builds.
Future<WorkspaceRefreshResult> runWorkspaceRefreshInBackground({
  required String projectRootPath,
  required bool includeConfig,
}) async {
  try {
    return await Isolate.run<WorkspaceRefreshResult>(
      () => _refreshWorkspaceInIsolate((projectRootPath, includeConfig)),
    );
  } catch (error, stackTrace) {
    // Always log — the previous kDebugMode guard silenced failures in release
    // builds, making the resulting freeze impossible to diagnose.
    debugPrint(
      '[BackgroundApiRunner] Isolate spawn failed — returning empty result '
      'to keep the UI thread free.  Error: $error\n$stackTrace',
    );
    // Return an empty result so callers can render a placeholder UI and the
    // next poll cycle will retry.  Never call _refreshWorkspaceInIsolate on
    // the main thread.
    return WorkspaceRefreshResult(
      dashboardError: 'Background refresh unavailable: $error',
    );
  }
}

/// Runs an autopilot status refresh in a background [Isolate].
///
/// Returns an empty [AutopilotStatusRefreshResult] with an error string if
/// the isolate spawn fails — see [runWorkspaceRefreshInBackground] for the
/// rationale.
Future<AutopilotStatusRefreshResult> runAutopilotStatusInBackground({
  required String projectRootPath,
}) async {
  try {
    return await Isolate.run<AutopilotStatusRefreshResult>(
      () => _refreshAutopilotStatusInIsolate(projectRootPath),
    );
  } catch (error, stackTrace) {
    debugPrint(
      '[BackgroundApiRunner] Autopilot isolate spawn failed — returning '
      'empty result.  Error: $error\n$stackTrace',
    );
    return AutopilotStatusRefreshResult(
      error: 'Background autopilot refresh unavailable: $error',
    );
  }
}
