// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'retry_scheduling_state.freezed.dart';
part 'retry_scheduling_state.g.dart';

@freezed
abstract class RetrySchedulingState with _$RetrySchedulingState {
  const factory RetrySchedulingState({
    @JsonKey(name: 'task_retry_counts')
    @Default({})
    Map<String, int> retryCounts,
    @JsonKey(name: 'task_cooldown_until')
    @Default({})
    Map<String, String> cooldownUntil,
  }) = _RetrySchedulingState;

  factory RetrySchedulingState.fromJson(Map<String, dynamic> json) =>
      _$RetrySchedulingStateFromJson(json);
}
