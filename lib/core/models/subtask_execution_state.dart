// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtask_execution_state.freezed.dart';
part 'subtask_execution_state.g.dart';

@freezed
abstract class SubtaskExecutionState with _$SubtaskExecutionState {
  const factory SubtaskExecutionState({
    @Default([]) @JsonKey(name: 'subtask_queue') List<String> queue,
    @JsonKey(name: 'current_subtask') String? current,
    @Default(false) @JsonKey(name: 'subtask_refinement_done')
    bool refinementDone,
    @Default(false) @JsonKey(name: 'feasibility_check_done')
    bool feasibilityCheckDone,
    @Default({}) @JsonKey(name: 'subtask_split_attempts')
    Map<String, int> splitAttempts,
  }) = _SubtaskExecutionState;

  factory SubtaskExecutionState.fromJson(Map<String, dynamic> json) =>
      _$SubtaskExecutionStateFromJson(json);
}
