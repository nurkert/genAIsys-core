// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'supervisor_state.freezed.dart';
part 'supervisor_state.g.dart';

@freezed
abstract class SupervisorState with _$SupervisorState {
  const factory SupervisorState({
    @Default(false) @JsonKey(name: 'supervisor_running') bool running,
    @JsonKey(name: 'supervisor_session_id') String? sessionId,
    @JsonKey(name: 'supervisor_pid') int? pid,
    @JsonKey(name: 'supervisor_started_at') String? startedAt,
    @JsonKey(name: 'supervisor_profile') String? profile,
    @JsonKey(name: 'supervisor_start_reason') String? startReason,
    @Default(0)
    @JsonKey(name: 'supervisor_restart_count')
    int restartCount,
    @JsonKey(name: 'supervisor_cooldown_until') String? cooldownUntil,
    @JsonKey(name: 'supervisor_last_halt_reason') String? lastHaltReason,
    @JsonKey(name: 'supervisor_last_resume_action') String? lastResumeAction,
    @JsonKey(name: 'supervisor_last_exit_code') int? lastExitCode,
    @Default(0)
    @JsonKey(name: 'supervisor_low_signal_streak')
    int lowSignalStreak,
    @JsonKey(name: 'supervisor_throughput_window_started_at')
    String? throughputWindowStartedAt,
    @Default(0)
    @JsonKey(name: 'supervisor_throughput_steps')
    int throughputSteps,
    @Default(0)
    @JsonKey(name: 'supervisor_throughput_rejects')
    int throughputRejects,
    @Default(0)
    @JsonKey(name: 'supervisor_throughput_high_retries')
    int throughputHighRetries,
    @Default(0)
    @JsonKey(name: 'supervisor_reflection_count')
    int reflectionCount,
    @JsonKey(name: 'supervisor_last_reflection_at') String? lastReflectionAt,
  }) = _SupervisorState;

  factory SupervisorState.fromJson(Map<String, dynamic> json) =>
      _$SupervisorStateFromJson(json);
}
