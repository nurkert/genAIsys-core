// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../cli/models/cli_models.dart';
import '../cli/cli_client.dart';
import '../cli/gui_cli_error_mapper.dart';

class GuiDashboardSnapshot {
  const GuiDashboardSnapshot({required this.status, required this.review});

  final CliStatusSnapshot status;
  final CliReviewStatus review;
}

/// Legacy CLI bridge for GUI flows.
///
/// Prefer `GenaisysApi` + `AppResult` (via `InProcessGenaisysApi`) for all
/// new GUI use cases. This adapter remains for backward compatibility with
/// older CLI-driven GUI code paths.
class GuiCliAdapter {
  GuiCliAdapter({CliClient? client}) : _client = client ?? CliClient();

  final CliClient _client;

  Future<CliClientResult<CliInitResponse>> initializeProject(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _client.initJson(projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliStatusSnapshot>> loadStatus(String projectRoot) {
    return _client.status(projectRoot);
  }

  Future<CliClientResult<CliTasksResponse>> loadTasks(
    String projectRoot, {
    List<String> options = const [],
  }) {
    return _client.tasks(projectRoot, options: options);
  }

  Future<CliClientResult<CliTaskItem>> loadNextTask(
    String projectRoot, {
    List<String> options = const [],
  }) {
    return _client.next(projectRoot, options: options);
  }

  Future<CliClientResult<CliReviewStatus>> loadReviewStatus(
    String projectRoot,
  ) {
    return _client.reviewStatus(projectRoot);
  }

  Future<CliClientResult<GuiDashboardSnapshot>> loadDashboard(
    String projectRoot,
  ) async {
    final statusResult = await loadStatus(projectRoot);
    if (!statusResult.ok || statusResult.data == null) {
      return CliClientResult<GuiDashboardSnapshot>(
        status: statusResult.status,
        stdout: statusResult.stdout,
        stderr: statusResult.stderr,
        data: null,
        error: statusResult.error,
      );
    }

    final reviewResult = await loadReviewStatus(projectRoot);
    if (!reviewResult.ok || reviewResult.data == null) {
      return CliClientResult<GuiDashboardSnapshot>(
        status: reviewResult.status,
        stdout: _mergeOutput([statusResult.stdout, reviewResult.stdout]),
        stderr: _mergeOutput([statusResult.stderr, reviewResult.stderr]),
        data: null,
        error: reviewResult.error,
      );
    }

    return CliClientResult<GuiDashboardSnapshot>(
      status: statusResult.status,
      stdout: _mergeOutput([statusResult.stdout, reviewResult.stdout]),
      stderr: _mergeOutput([statusResult.stderr, reviewResult.stderr]),
      data: GuiDashboardSnapshot(
        status: statusResult.data!,
        review: reviewResult.data!,
      ),
      error: null,
    );
  }

  Future<CliClientResult<CliActivateResponse>> activateTask(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    return _client.activateJson(projectRoot, id: id, title: title);
  }

  Future<CliClientResult<CliDeactivateResponse>> deactivateTask(
    String projectRoot, {
    bool keepReview = false,
  }) {
    return _client.deactivateJson(projectRoot, keepReview: keepReview);
  }

  Future<CliClientResult<CliReviewDecisionResponse>> approveReview(
    String projectRoot, {
    String? note,
  }) {
    return _client.reviewApproveJson(projectRoot, note: note);
  }

  Future<CliClientResult<CliReviewDecisionResponse>> rejectReview(
    String projectRoot, {
    String? note,
  }) {
    return _client.reviewRejectJson(projectRoot, note: note);
  }

  Future<CliClientResult<CliReviewClearResponse>> clearReview(
    String projectRoot, {
    String? note,
  }) {
    return _client.reviewClearJson(projectRoot, note: note);
  }

  Future<CliClientResult<CliDoneResponse>> markTaskDone(String projectRoot) {
    return _client.doneJson(projectRoot);
  }

  Future<CliClientResult<CliBlockResponse>> blockTask(
    String projectRoot, {
    String? reason,
  }) {
    return _client.blockJson(projectRoot, reason: reason);
  }

  Future<CliClientResult<CliCycleResponse>> cycleTask(String projectRoot) {
    return _client.cycleJson(projectRoot);
  }

  Future<CliClientResult<CliCycleRunResponse>> runTaskCycle(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    return _client.cycleRunJson(
      projectRoot,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
    );
  }

  Future<CliClientResult<CliPlanInitResponse>> initializePlan(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _client.planInitJson(projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliSpecInitResponse>> initializeSpec(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _client.specInitJson(projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliSubtasksInitResponse>> initializeSubtasks(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _client.subtasksInitJson(projectRoot, overwrite: overwrite);
  }

  GuiCliErrorKind classifyError(CliErrorResponse? error) {
    return mapCliError(error);
  }

  String _mergeOutput(List<String> chunks) {
    final normalized = chunks
        .map((chunk) => chunk.trim())
        .where((chunk) => chunk.isNotEmpty)
        .toList();
    return normalized.join('\n');
  }
}
