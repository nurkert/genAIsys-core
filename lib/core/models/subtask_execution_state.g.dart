// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask_execution_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubtaskExecutionState _$SubtaskExecutionStateFromJson(
  Map<String, dynamic> json,
) => _SubtaskExecutionState(
  queue:
      (json['subtask_queue'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  current: json['current_subtask'] as String?,
  refinementDone: json['subtask_refinement_done'] as bool? ?? false,
  feasibilityCheckDone: json['feasibility_check_done'] as bool? ?? false,
  splitAttempts:
      (json['subtask_split_attempts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
);

Map<String, dynamic> _$SubtaskExecutionStateToJson(
  _SubtaskExecutionState instance,
) => <String, dynamic>{
  'subtask_queue': instance.queue,
  'current_subtask': instance.current,
  'subtask_refinement_done': instance.refinementDone,
  'feasibility_check_done': instance.feasibilityCheckDone,
  'subtask_split_attempts': instance.splitAttempts,
};
