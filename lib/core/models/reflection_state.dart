// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'reflection_state.freezed.dart';
part 'reflection_state.g.dart';

@freezed
abstract class ReflectionState with _$ReflectionState {
  const factory ReflectionState({
    @JsonKey(name: 'last_reflection_at') String? lastAt,
    @Default(0) @JsonKey(name: 'reflection_count') int count,
    @Default(0)
    @JsonKey(name: 'reflection_tasks_created')
    int tasksCreated,
  }) = _ReflectionState;

  factory ReflectionState.fromJson(Map<String, dynamic> json) =>
      _$ReflectionStateFromJson(json);
}
