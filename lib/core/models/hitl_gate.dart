// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Models for the Human-in-the-Loop (HITL) gate system.
///
/// The orchestrator writes a [HitlGateInfo] to disk when it reaches a
/// configured gate point, then polls for a [HitlDecision] before continuing.

enum HitlGateEvent {
  afterTaskDone,
  beforeSprint,
  beforeHalt;

  String get serialized {
    switch (this) {
      case HitlGateEvent.afterTaskDone:
        return 'after_task_done';
      case HitlGateEvent.beforeSprint:
        return 'before_sprint';
      case HitlGateEvent.beforeHalt:
        return 'before_halt';
    }
  }

  static HitlGateEvent? tryParse(String? value) {
    switch (value) {
      case 'after_task_done':
        return HitlGateEvent.afterTaskDone;
      case 'before_sprint':
        return HitlGateEvent.beforeSprint;
      case 'before_halt':
        return HitlGateEvent.beforeHalt;
      default:
        return null;
    }
  }
}

class HitlGateInfo {
  const HitlGateInfo({
    required this.event,
    this.stepId,
    this.taskId,
    this.taskTitle,
    this.sprintNumber,
    required this.createdAt,
    this.expiresAt,
  });

  final HitlGateEvent event;
  final String? stepId;
  final String? taskId;
  final String? taskTitle;
  final int? sprintNumber;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

enum HitlDecisionType { approve, reject, timeout }

class HitlDecision {
  const HitlDecision({required this.type, this.note});

  final HitlDecisionType type;
  final String? note;

  /// Whether the gate should be passed (continue the action).
  ///
  /// Both [approve] and [timeout] (auto-approve) return true.
  bool get approved => type != HitlDecisionType.reject;
}
