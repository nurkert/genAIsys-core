// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autopilot_run_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AutopilotRunState _$AutopilotRunStateFromJson(Map<String, dynamic> json) =>
    _AutopilotRunState(
      running: json['autopilot_running'] as bool? ?? false,
      currentMode: json['current_mode'] as String?,
      lastLoopAt: json['last_loop_at'] as String?,
      consecutiveFailures: (json['consecutive_failures'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
      lastErrorClass: json['last_error_class'] as String?,
      lastErrorKind: json['last_error_kind'] as String?,
    );

Map<String, dynamic> _$AutopilotRunStateToJson(_AutopilotRunState instance) =>
    <String, dynamic>{
      'autopilot_running': instance.running,
      'current_mode': instance.currentMode,
      'last_loop_at': instance.lastLoopAt,
      'consecutive_failures': instance.consecutiveFailures,
      'last_error': instance.lastError,
      'last_error_class': instance.lastErrorClass,
      'last_error_kind': instance.lastErrorKind,
    };
