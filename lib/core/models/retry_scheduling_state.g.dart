// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retry_scheduling_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RetrySchedulingState _$RetrySchedulingStateFromJson(
  Map<String, dynamic> json,
) => _RetrySchedulingState(
  retryCounts:
      (json['task_retry_counts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  cooldownUntil:
      (json['task_cooldown_until'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$RetrySchedulingStateToJson(
  _RetrySchedulingState instance,
) => <String, dynamic>{
  'task_retry_counts': instance.retryCounts,
  'task_cooldown_until': instance.cooldownUntil,
};
