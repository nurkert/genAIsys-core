// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supervisor_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupervisorState _$SupervisorStateFromJson(
  Map<String, dynamic> json,
) => _SupervisorState(
  running: json['supervisor_running'] as bool? ?? false,
  sessionId: json['supervisor_session_id'] as String?,
  pid: (json['supervisor_pid'] as num?)?.toInt(),
  startedAt: json['supervisor_started_at'] as String?,
  profile: json['supervisor_profile'] as String?,
  startReason: json['supervisor_start_reason'] as String?,
  restartCount: (json['supervisor_restart_count'] as num?)?.toInt() ?? 0,
  cooldownUntil: json['supervisor_cooldown_until'] as String?,
  lastHaltReason: json['supervisor_last_halt_reason'] as String?,
  lastResumeAction: json['supervisor_last_resume_action'] as String?,
  lastExitCode: (json['supervisor_last_exit_code'] as num?)?.toInt(),
  lowSignalStreak: (json['supervisor_low_signal_streak'] as num?)?.toInt() ?? 0,
  throughputWindowStartedAt:
      json['supervisor_throughput_window_started_at'] as String?,
  throughputSteps: (json['supervisor_throughput_steps'] as num?)?.toInt() ?? 0,
  throughputRejects:
      (json['supervisor_throughput_rejects'] as num?)?.toInt() ?? 0,
  throughputHighRetries:
      (json['supervisor_throughput_high_retries'] as num?)?.toInt() ?? 0,
  reflectionCount: (json['supervisor_reflection_count'] as num?)?.toInt() ?? 0,
  lastReflectionAt: json['supervisor_last_reflection_at'] as String?,
);

Map<String, dynamic> _$SupervisorStateToJson(
  _SupervisorState instance,
) => <String, dynamic>{
  'supervisor_running': instance.running,
  'supervisor_session_id': instance.sessionId,
  'supervisor_pid': instance.pid,
  'supervisor_started_at': instance.startedAt,
  'supervisor_profile': instance.profile,
  'supervisor_start_reason': instance.startReason,
  'supervisor_restart_count': instance.restartCount,
  'supervisor_cooldown_until': instance.cooldownUntil,
  'supervisor_last_halt_reason': instance.lastHaltReason,
  'supervisor_last_resume_action': instance.lastResumeAction,
  'supervisor_last_exit_code': instance.lastExitCode,
  'supervisor_low_signal_streak': instance.lowSignalStreak,
  'supervisor_throughput_window_started_at': instance.throughputWindowStartedAt,
  'supervisor_throughput_steps': instance.throughputSteps,
  'supervisor_throughput_rejects': instance.throughputRejects,
  'supervisor_throughput_high_retries': instance.throughputHighRetries,
  'supervisor_reflection_count': instance.reflectionCount,
  'supervisor_last_reflection_at': instance.lastReflectionAt,
};
