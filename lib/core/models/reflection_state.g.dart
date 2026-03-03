// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReflectionState _$ReflectionStateFromJson(Map<String, dynamic> json) =>
    _ReflectionState(
      lastAt: json['last_reflection_at'] as String?,
      count: (json['reflection_count'] as num?)?.toInt() ?? 0,
      tasksCreated: (json['reflection_tasks_created'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ReflectionStateToJson(_ReflectionState instance) =>
    <String, dynamic>{
      'last_reflection_at': instance.lastAt,
      'reflection_count': instance.count,
      'reflection_tasks_created': instance.tasksCreated,
    };
