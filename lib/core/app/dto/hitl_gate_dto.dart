// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// DTO for the currently pending HITL gate, or an empty (no-gate) state.
class HitlGateDto {
  const HitlGateDto({
    required this.pending,
    this.event,
    this.taskId,
    this.taskTitle,
    this.sprintNumber,
    this.expiresAt,
  });

  /// `true` when a gate file is present and awaiting a decision.
  final bool pending;

  /// Event type: `'after_task_done'`, `'before_sprint'`, or `'before_halt'`.
  final String? event;

  final String? taskId;
  final String? taskTitle;
  final int? sprintNumber;

  /// ISO-8601 expiry timestamp, or `null` if the gate has no timeout.
  final String? expiresAt;
}
