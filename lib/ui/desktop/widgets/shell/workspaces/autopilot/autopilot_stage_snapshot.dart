// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../../../../../core/app/app.dart';
import '../../../../localization/desktop_strings.dart';

/// Data class that parses autopilot status into stage information.
class AutopilotStageSnapshot {
  const AutopilotStageSnapshot({
    required this.label,
    required this.index,
    required this.blocked,
  });

  final String label;
  final int index;
  final bool blocked;

  static AutopilotStageSnapshot fromStatus({
    required DesktopStrings strings,
    required AutopilotStatusDto? status,
    required AppRunLogEventDto? latestEvent,
  }) {
    final String rawEvent =
        (latestEvent?.event ?? status?.lastStepSummary?.event ?? '')
            .trim()
            .toLowerCase();
    final bool running = status?.autopilotRunning ?? false;
    final bool blocked = _isBlocked(status, rawEvent);

    if (!running && rawEvent.isEmpty) {
      return AutopilotStageSnapshot(
        label: strings.autopilotStatusPaused,
        index: 0,
        blocked: false,
      );
    }

    final int index = _indexFromEvent(rawEvent);
    if (blocked) {
      return AutopilotStageSnapshot(
        label: 'Blocked',
        index: index,
        blocked: true,
      );
    }

    final String label = switch (index) {
      0 => 'Preflight',
      1 => strings.autopilotStagePlanning,
      2 => strings.autopilotStageCoding,
      3 => strings.autopilotStageTesting,
      4 => strings.autopilotStageReview,
      _ => strings.autopilotLoopStageLabel,
    };

    return AutopilotStageSnapshot(label: label, index: index, blocked: false);
  }

  static int _indexFromEvent(String event) {
    if (event.contains('preflight')) {
      return 0;
    }
    if (event.contains('planning') ||
        event.contains('planned') ||
        event.contains('subtask_scheduler')) {
      return 1;
    }
    if (event.contains('quality_gate') ||
        event.contains('analyze') ||
        event.contains('test') ||
        event.contains('lint')) {
      return 3;
    }
    if (event.contains('review')) {
      return 4;
    }
    if (event.contains('task_cycle') ||
        event.contains('coding') ||
        event.contains('orchestrator_step') ||
        event.contains('agent') ||
        event.contains('run_step')) {
      return 2;
    }
    return 2;
  }

  static bool _isBlocked(AutopilotStatusDto? status, String rawEvent) {
    final String stallReason = status?.stallReason?.trim() ?? '';
    if (stallReason.isNotEmpty) {
      return true;
    }
    final String lastErrorKind = status?.lastErrorKind?.trim() ?? '';
    if (lastErrorKind.isNotEmpty) {
      return true;
    }
    final String lastError = status?.lastError?.trim() ?? '';
    if (lastError.isNotEmpty) {
      return true;
    }
    if (rawEvent.isEmpty) {
      return false;
    }
    return rawEvent.contains('error') ||
        rawEvent.contains('reject') ||
        rawEvent.contains('blocked') ||
        rawEvent.contains('safety_halt') ||
        rawEvent.contains('preflight_failed') ||
        rawEvent.contains('provider_pause') ||
        rawEvent.contains('stuck');
  }
}
