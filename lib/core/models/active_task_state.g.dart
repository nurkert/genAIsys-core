// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_task_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActiveTaskState _$ActiveTaskStateFromJson(Map<String, dynamic> json) =>
    _ActiveTaskState(
      id: json['active_task_id'] as String?,
      title: json['active_task_title'] as String?,
      retryKey: json['active_task_retry_key'] as String?,
      reviewStatus: json['review_status'] as String?,
      reviewUpdatedAt: json['review_updated_at'] as String?,
      forensicRecoveryAttempted:
          json['forensic_recovery_attempted'] as bool? ?? false,
      forensicGuidance: json['forensic_guidance'] as String?,
      accumulatedAdvisoryNotes:
          (json['accumulated_advisory_notes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      lastRejectCommitSha: json['last_reject_commit_sha'] as String?,
      mergeInProgress: json['merge_in_progress'] as bool? ?? false,
    );

Map<String, dynamic> _$ActiveTaskStateToJson(_ActiveTaskState instance) =>
    <String, dynamic>{
      'active_task_id': instance.id,
      'active_task_title': instance.title,
      'active_task_retry_key': instance.retryKey,
      'review_status': instance.reviewStatus,
      'review_updated_at': instance.reviewUpdatedAt,
      'forensic_recovery_attempted': instance.forensicRecoveryAttempted,
      'forensic_guidance': instance.forensicGuidance,
      'accumulated_advisory_notes': instance.accumulatedAdvisoryNotes,
      'last_reject_commit_sha': instance.lastRejectCommitSha,
      'merge_in_progress': instance.mergeInProgress,
    };
