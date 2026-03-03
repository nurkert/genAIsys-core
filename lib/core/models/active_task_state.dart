// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'active_task_state.freezed.dart';
part 'active_task_state.g.dart';

@freezed
abstract class ActiveTaskState with _$ActiveTaskState {
  const factory ActiveTaskState({
    @JsonKey(name: 'active_task_id') String? id,
    @JsonKey(name: 'active_task_title') String? title,
    @JsonKey(name: 'active_task_retry_key') String? retryKey,
    @JsonKey(name: 'review_status') String? reviewStatus,
    @JsonKey(name: 'review_updated_at') String? reviewUpdatedAt,
    @Default(false)
    @JsonKey(name: 'forensic_recovery_attempted')
    bool forensicRecoveryAttempted,
    @JsonKey(name: 'forensic_guidance') String? forensicGuidance,
    @Default(<String>[])
    @JsonKey(name: 'accumulated_advisory_notes')
    List<String> accumulatedAdvisoryNotes,
    @JsonKey(name: 'last_reject_commit_sha') String? lastRejectCommitSha,
    @Default(false)
    @JsonKey(name: 'merge_in_progress')
    bool mergeInProgress,
  }) = _ActiveTaskState;

  factory ActiveTaskState.fromJson(Map<String, dynamic> json) =>
      _$ActiveTaskStateFromJson(json);
}
