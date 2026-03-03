// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../errors/failure_reason_mapper.dart';
import '../models/project_state.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'task_management/done_service.dart';

/// Encapsulates the deterministic resume policy for the autopilot supervisor.
///
/// Before starting a new coding segment, the supervisor checks whether an
/// approved delivery is pending. If so, `markDone` is called to complete
/// it before continuing.
class SupervisorResumePolicy {
  SupervisorResumePolicy({DoneService? doneService})
    : _doneService = doneService ?? DoneService();

  final DoneService _doneService;

  /// Peek at the resume action without performing any side effects.
  ///
  /// Returns `'approved_delivery'` if there is an approved task waiting for
  /// delivery, otherwise `'continue_safe_step'`.
  String peekResumeAction(ProjectState state) {
    final reviewApproved =
        state.reviewStatus?.trim().toLowerCase() == 'approved';
    final activeTaskPresent =
        (state.activeTaskId?.trim().isNotEmpty ?? false) ||
        (state.activeTaskTitle?.trim().isNotEmpty ?? false);
    if (reviewApproved && activeTaskPresent) {
      return 'approved_delivery';
    }
    return 'continue_safe_step';
  }

  /// Apply the deterministic resume policy.
  ///
  /// If an approved delivery exists, calls [DoneService.markDone] to complete
  /// it. Returns the action taken (`'approved_delivery'` or
  /// `'continue_safe_step'`).
  ///
  /// Throws [StateError] if the delivery resume fails.
  Future<String> apply(
    String projectRoot, {
    required ProjectState state,
    required String sessionId,
  }) async {
    final activeTaskPresent =
        (state.activeTaskId?.trim().isNotEmpty ?? false) ||
        (state.activeTaskTitle?.trim().isNotEmpty ?? false);
    final reviewApproved =
        state.reviewStatus?.trim().toLowerCase() == 'approved';
    if (!reviewApproved || !activeTaskPresent) {
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_resume',
        message: 'No approved delivery to resume; continuing next safe step',
        data: {
          'session_id': sessionId,
          'resume_action': 'continue_safe_step',
        },
      );
      return 'continue_safe_step';
    }

    try {
      final doneTitle = await _doneService.markDone(projectRoot);
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_resume',
        message: 'Resumed approved delivery before next coding step',
        data: {
          'session_id': sessionId,
          'resume_action': 'approved_delivery',
          'task_title': doneTitle,
        },
      );
      return 'approved_delivery';
    } catch (error) {
      final reason = FailureReasonMapper.normalize(
        message: error.toString(),
        event: 'autopilot_supervisor_resume_failed',
      );
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_resume_failed',
        message: 'Failed to resume approved delivery',
        data: {
          'session_id': sessionId,
          'resume_action': 'approved_delivery',
          'error_class': reason.errorClass,
          'error_kind': reason.errorKind,
          'error': error.toString(),
        },
      );
      throw StateError('Approved-delivery resume failed: $error');
    }
  }

  void _appendRunLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    try {
      RunLogStore(layout.runLogPath).append(
        event: event,
        message: message,
        data: {'root': projectRoot, ...data},
      );
    } catch (_) {
      // Run log write must never break the resume flow.
    }
  }
}
