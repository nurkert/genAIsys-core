// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'active_task_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActiveTaskState {

@JsonKey(name: 'active_task_id') String? get id;@JsonKey(name: 'active_task_title') String? get title;@JsonKey(name: 'active_task_retry_key') String? get retryKey;@JsonKey(name: 'review_status') String? get reviewStatus;@JsonKey(name: 'review_updated_at') String? get reviewUpdatedAt;@JsonKey(name: 'forensic_recovery_attempted') bool get forensicRecoveryAttempted;@JsonKey(name: 'forensic_guidance') String? get forensicGuidance;@JsonKey(name: 'accumulated_advisory_notes') List<String> get accumulatedAdvisoryNotes;@JsonKey(name: 'last_reject_commit_sha') String? get lastRejectCommitSha;@JsonKey(name: 'merge_in_progress') bool get mergeInProgress;
/// Create a copy of ActiveTaskState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveTaskStateCopyWith<ActiveTaskState> get copyWith => _$ActiveTaskStateCopyWithImpl<ActiveTaskState>(this as ActiveTaskState, _$identity);

  /// Serializes this ActiveTaskState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveTaskState&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.retryKey, retryKey) || other.retryKey == retryKey)&&(identical(other.reviewStatus, reviewStatus) || other.reviewStatus == reviewStatus)&&(identical(other.reviewUpdatedAt, reviewUpdatedAt) || other.reviewUpdatedAt == reviewUpdatedAt)&&(identical(other.forensicRecoveryAttempted, forensicRecoveryAttempted) || other.forensicRecoveryAttempted == forensicRecoveryAttempted)&&(identical(other.forensicGuidance, forensicGuidance) || other.forensicGuidance == forensicGuidance)&&const DeepCollectionEquality().equals(other.accumulatedAdvisoryNotes, accumulatedAdvisoryNotes)&&(identical(other.lastRejectCommitSha, lastRejectCommitSha) || other.lastRejectCommitSha == lastRejectCommitSha)&&(identical(other.mergeInProgress, mergeInProgress) || other.mergeInProgress == mergeInProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,retryKey,reviewStatus,reviewUpdatedAt,forensicRecoveryAttempted,forensicGuidance,const DeepCollectionEquality().hash(accumulatedAdvisoryNotes),lastRejectCommitSha,mergeInProgress);

@override
String toString() {
  return 'ActiveTaskState(id: $id, title: $title, retryKey: $retryKey, reviewStatus: $reviewStatus, reviewUpdatedAt: $reviewUpdatedAt, forensicRecoveryAttempted: $forensicRecoveryAttempted, forensicGuidance: $forensicGuidance, accumulatedAdvisoryNotes: $accumulatedAdvisoryNotes, lastRejectCommitSha: $lastRejectCommitSha, mergeInProgress: $mergeInProgress)';
}


}

/// @nodoc
abstract mixin class $ActiveTaskStateCopyWith<$Res>  {
  factory $ActiveTaskStateCopyWith(ActiveTaskState value, $Res Function(ActiveTaskState) _then) = _$ActiveTaskStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'active_task_id') String? id,@JsonKey(name: 'active_task_title') String? title,@JsonKey(name: 'active_task_retry_key') String? retryKey,@JsonKey(name: 'review_status') String? reviewStatus,@JsonKey(name: 'review_updated_at') String? reviewUpdatedAt,@JsonKey(name: 'forensic_recovery_attempted') bool forensicRecoveryAttempted,@JsonKey(name: 'forensic_guidance') String? forensicGuidance,@JsonKey(name: 'accumulated_advisory_notes') List<String> accumulatedAdvisoryNotes,@JsonKey(name: 'last_reject_commit_sha') String? lastRejectCommitSha,@JsonKey(name: 'merge_in_progress') bool mergeInProgress
});




}
/// @nodoc
class _$ActiveTaskStateCopyWithImpl<$Res>
    implements $ActiveTaskStateCopyWith<$Res> {
  _$ActiveTaskStateCopyWithImpl(this._self, this._then);

  final ActiveTaskState _self;
  final $Res Function(ActiveTaskState) _then;

/// Create a copy of ActiveTaskState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? title = freezed,Object? retryKey = freezed,Object? reviewStatus = freezed,Object? reviewUpdatedAt = freezed,Object? forensicRecoveryAttempted = null,Object? forensicGuidance = freezed,Object? accumulatedAdvisoryNotes = null,Object? lastRejectCommitSha = freezed,Object? mergeInProgress = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,retryKey: freezed == retryKey ? _self.retryKey : retryKey // ignore: cast_nullable_to_non_nullable
as String?,reviewStatus: freezed == reviewStatus ? _self.reviewStatus : reviewStatus // ignore: cast_nullable_to_non_nullable
as String?,reviewUpdatedAt: freezed == reviewUpdatedAt ? _self.reviewUpdatedAt : reviewUpdatedAt // ignore: cast_nullable_to_non_nullable
as String?,forensicRecoveryAttempted: null == forensicRecoveryAttempted ? _self.forensicRecoveryAttempted : forensicRecoveryAttempted // ignore: cast_nullable_to_non_nullable
as bool,forensicGuidance: freezed == forensicGuidance ? _self.forensicGuidance : forensicGuidance // ignore: cast_nullable_to_non_nullable
as String?,accumulatedAdvisoryNotes: null == accumulatedAdvisoryNotes ? _self.accumulatedAdvisoryNotes : accumulatedAdvisoryNotes // ignore: cast_nullable_to_non_nullable
as List<String>,lastRejectCommitSha: freezed == lastRejectCommitSha ? _self.lastRejectCommitSha : lastRejectCommitSha // ignore: cast_nullable_to_non_nullable
as String?,mergeInProgress: null == mergeInProgress ? _self.mergeInProgress : mergeInProgress // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ActiveTaskState].
extension ActiveTaskStatePatterns on ActiveTaskState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActiveTaskState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActiveTaskState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActiveTaskState value)  $default,){
final _that = this;
switch (_that) {
case _ActiveTaskState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActiveTaskState value)?  $default,){
final _that = this;
switch (_that) {
case _ActiveTaskState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'active_task_id')  String? id, @JsonKey(name: 'active_task_title')  String? title, @JsonKey(name: 'active_task_retry_key')  String? retryKey, @JsonKey(name: 'review_status')  String? reviewStatus, @JsonKey(name: 'review_updated_at')  String? reviewUpdatedAt, @JsonKey(name: 'forensic_recovery_attempted')  bool forensicRecoveryAttempted, @JsonKey(name: 'forensic_guidance')  String? forensicGuidance, @JsonKey(name: 'accumulated_advisory_notes')  List<String> accumulatedAdvisoryNotes, @JsonKey(name: 'last_reject_commit_sha')  String? lastRejectCommitSha, @JsonKey(name: 'merge_in_progress')  bool mergeInProgress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActiveTaskState() when $default != null:
return $default(_that.id,_that.title,_that.retryKey,_that.reviewStatus,_that.reviewUpdatedAt,_that.forensicRecoveryAttempted,_that.forensicGuidance,_that.accumulatedAdvisoryNotes,_that.lastRejectCommitSha,_that.mergeInProgress);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'active_task_id')  String? id, @JsonKey(name: 'active_task_title')  String? title, @JsonKey(name: 'active_task_retry_key')  String? retryKey, @JsonKey(name: 'review_status')  String? reviewStatus, @JsonKey(name: 'review_updated_at')  String? reviewUpdatedAt, @JsonKey(name: 'forensic_recovery_attempted')  bool forensicRecoveryAttempted, @JsonKey(name: 'forensic_guidance')  String? forensicGuidance, @JsonKey(name: 'accumulated_advisory_notes')  List<String> accumulatedAdvisoryNotes, @JsonKey(name: 'last_reject_commit_sha')  String? lastRejectCommitSha, @JsonKey(name: 'merge_in_progress')  bool mergeInProgress)  $default,) {final _that = this;
switch (_that) {
case _ActiveTaskState():
return $default(_that.id,_that.title,_that.retryKey,_that.reviewStatus,_that.reviewUpdatedAt,_that.forensicRecoveryAttempted,_that.forensicGuidance,_that.accumulatedAdvisoryNotes,_that.lastRejectCommitSha,_that.mergeInProgress);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'active_task_id')  String? id, @JsonKey(name: 'active_task_title')  String? title, @JsonKey(name: 'active_task_retry_key')  String? retryKey, @JsonKey(name: 'review_status')  String? reviewStatus, @JsonKey(name: 'review_updated_at')  String? reviewUpdatedAt, @JsonKey(name: 'forensic_recovery_attempted')  bool forensicRecoveryAttempted, @JsonKey(name: 'forensic_guidance')  String? forensicGuidance, @JsonKey(name: 'accumulated_advisory_notes')  List<String> accumulatedAdvisoryNotes, @JsonKey(name: 'last_reject_commit_sha')  String? lastRejectCommitSha, @JsonKey(name: 'merge_in_progress')  bool mergeInProgress)?  $default,) {final _that = this;
switch (_that) {
case _ActiveTaskState() when $default != null:
return $default(_that.id,_that.title,_that.retryKey,_that.reviewStatus,_that.reviewUpdatedAt,_that.forensicRecoveryAttempted,_that.forensicGuidance,_that.accumulatedAdvisoryNotes,_that.lastRejectCommitSha,_that.mergeInProgress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActiveTaskState implements ActiveTaskState {
  const _ActiveTaskState({@JsonKey(name: 'active_task_id') this.id, @JsonKey(name: 'active_task_title') this.title, @JsonKey(name: 'active_task_retry_key') this.retryKey, @JsonKey(name: 'review_status') this.reviewStatus, @JsonKey(name: 'review_updated_at') this.reviewUpdatedAt, @JsonKey(name: 'forensic_recovery_attempted') this.forensicRecoveryAttempted = false, @JsonKey(name: 'forensic_guidance') this.forensicGuidance, @JsonKey(name: 'accumulated_advisory_notes') final  List<String> accumulatedAdvisoryNotes = const <String>[], @JsonKey(name: 'last_reject_commit_sha') this.lastRejectCommitSha, @JsonKey(name: 'merge_in_progress') this.mergeInProgress = false}): _accumulatedAdvisoryNotes = accumulatedAdvisoryNotes;
  factory _ActiveTaskState.fromJson(Map<String, dynamic> json) => _$ActiveTaskStateFromJson(json);

@override@JsonKey(name: 'active_task_id') final  String? id;
@override@JsonKey(name: 'active_task_title') final  String? title;
@override@JsonKey(name: 'active_task_retry_key') final  String? retryKey;
@override@JsonKey(name: 'review_status') final  String? reviewStatus;
@override@JsonKey(name: 'review_updated_at') final  String? reviewUpdatedAt;
@override@JsonKey(name: 'forensic_recovery_attempted') final  bool forensicRecoveryAttempted;
@override@JsonKey(name: 'forensic_guidance') final  String? forensicGuidance;
 final  List<String> _accumulatedAdvisoryNotes;
@override@JsonKey(name: 'accumulated_advisory_notes') List<String> get accumulatedAdvisoryNotes {
  if (_accumulatedAdvisoryNotes is EqualUnmodifiableListView) return _accumulatedAdvisoryNotes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accumulatedAdvisoryNotes);
}

@override@JsonKey(name: 'last_reject_commit_sha') final  String? lastRejectCommitSha;
@override@JsonKey(name: 'merge_in_progress') final  bool mergeInProgress;

/// Create a copy of ActiveTaskState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveTaskStateCopyWith<_ActiveTaskState> get copyWith => __$ActiveTaskStateCopyWithImpl<_ActiveTaskState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveTaskStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveTaskState&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.retryKey, retryKey) || other.retryKey == retryKey)&&(identical(other.reviewStatus, reviewStatus) || other.reviewStatus == reviewStatus)&&(identical(other.reviewUpdatedAt, reviewUpdatedAt) || other.reviewUpdatedAt == reviewUpdatedAt)&&(identical(other.forensicRecoveryAttempted, forensicRecoveryAttempted) || other.forensicRecoveryAttempted == forensicRecoveryAttempted)&&(identical(other.forensicGuidance, forensicGuidance) || other.forensicGuidance == forensicGuidance)&&const DeepCollectionEquality().equals(other._accumulatedAdvisoryNotes, _accumulatedAdvisoryNotes)&&(identical(other.lastRejectCommitSha, lastRejectCommitSha) || other.lastRejectCommitSha == lastRejectCommitSha)&&(identical(other.mergeInProgress, mergeInProgress) || other.mergeInProgress == mergeInProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,retryKey,reviewStatus,reviewUpdatedAt,forensicRecoveryAttempted,forensicGuidance,const DeepCollectionEquality().hash(_accumulatedAdvisoryNotes),lastRejectCommitSha,mergeInProgress);

@override
String toString() {
  return 'ActiveTaskState(id: $id, title: $title, retryKey: $retryKey, reviewStatus: $reviewStatus, reviewUpdatedAt: $reviewUpdatedAt, forensicRecoveryAttempted: $forensicRecoveryAttempted, forensicGuidance: $forensicGuidance, accumulatedAdvisoryNotes: $accumulatedAdvisoryNotes, lastRejectCommitSha: $lastRejectCommitSha, mergeInProgress: $mergeInProgress)';
}


}

/// @nodoc
abstract mixin class _$ActiveTaskStateCopyWith<$Res> implements $ActiveTaskStateCopyWith<$Res> {
  factory _$ActiveTaskStateCopyWith(_ActiveTaskState value, $Res Function(_ActiveTaskState) _then) = __$ActiveTaskStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'active_task_id') String? id,@JsonKey(name: 'active_task_title') String? title,@JsonKey(name: 'active_task_retry_key') String? retryKey,@JsonKey(name: 'review_status') String? reviewStatus,@JsonKey(name: 'review_updated_at') String? reviewUpdatedAt,@JsonKey(name: 'forensic_recovery_attempted') bool forensicRecoveryAttempted,@JsonKey(name: 'forensic_guidance') String? forensicGuidance,@JsonKey(name: 'accumulated_advisory_notes') List<String> accumulatedAdvisoryNotes,@JsonKey(name: 'last_reject_commit_sha') String? lastRejectCommitSha,@JsonKey(name: 'merge_in_progress') bool mergeInProgress
});




}
/// @nodoc
class __$ActiveTaskStateCopyWithImpl<$Res>
    implements _$ActiveTaskStateCopyWith<$Res> {
  __$ActiveTaskStateCopyWithImpl(this._self, this._then);

  final _ActiveTaskState _self;
  final $Res Function(_ActiveTaskState) _then;

/// Create a copy of ActiveTaskState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? title = freezed,Object? retryKey = freezed,Object? reviewStatus = freezed,Object? reviewUpdatedAt = freezed,Object? forensicRecoveryAttempted = null,Object? forensicGuidance = freezed,Object? accumulatedAdvisoryNotes = null,Object? lastRejectCommitSha = freezed,Object? mergeInProgress = null,}) {
  return _then(_ActiveTaskState(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,retryKey: freezed == retryKey ? _self.retryKey : retryKey // ignore: cast_nullable_to_non_nullable
as String?,reviewStatus: freezed == reviewStatus ? _self.reviewStatus : reviewStatus // ignore: cast_nullable_to_non_nullable
as String?,reviewUpdatedAt: freezed == reviewUpdatedAt ? _self.reviewUpdatedAt : reviewUpdatedAt // ignore: cast_nullable_to_non_nullable
as String?,forensicRecoveryAttempted: null == forensicRecoveryAttempted ? _self.forensicRecoveryAttempted : forensicRecoveryAttempted // ignore: cast_nullable_to_non_nullable
as bool,forensicGuidance: freezed == forensicGuidance ? _self.forensicGuidance : forensicGuidance // ignore: cast_nullable_to_non_nullable
as String?,accumulatedAdvisoryNotes: null == accumulatedAdvisoryNotes ? _self._accumulatedAdvisoryNotes : accumulatedAdvisoryNotes // ignore: cast_nullable_to_non_nullable
as List<String>,lastRejectCommitSha: freezed == lastRejectCommitSha ? _self.lastRejectCommitSha : lastRejectCommitSha // ignore: cast_nullable_to_non_nullable
as String?,mergeInProgress: null == mergeInProgress ? _self.mergeInProgress : mergeInProgress // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
