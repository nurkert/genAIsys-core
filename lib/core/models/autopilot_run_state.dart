// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'autopilot_run_state.freezed.dart';
part 'autopilot_run_state.g.dart';

@freezed
abstract class AutopilotRunState with _$AutopilotRunState {
  const factory AutopilotRunState({
    @Default(false) @JsonKey(name: 'autopilot_running') bool running,
    @JsonKey(name: 'current_mode') String? currentMode,
    @JsonKey(name: 'last_loop_at') String? lastLoopAt,
    @Default(0) @JsonKey(name: 'consecutive_failures') int consecutiveFailures,
    @JsonKey(name: 'last_error') String? lastError,
    @JsonKey(name: 'last_error_class') String? lastErrorClass,
    @JsonKey(name: 'last_error_kind') String? lastErrorKind,
  }) = _AutopilotRunState;

  factory AutopilotRunState.fromJson(Map<String, dynamic> json) =>
      _$AutopilotRunStateFromJson(json);
}
