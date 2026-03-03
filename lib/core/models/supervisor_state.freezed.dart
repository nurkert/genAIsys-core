// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supervisor_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SupervisorState {

@JsonKey(name: 'supervisor_running') bool get running;@JsonKey(name: 'supervisor_session_id') String? get sessionId;@JsonKey(name: 'supervisor_pid') int? get pid;@JsonKey(name: 'supervisor_started_at') String? get startedAt;@JsonKey(name: 'supervisor_profile') String? get profile;@JsonKey(name: 'supervisor_start_reason') String? get startReason;@JsonKey(name: 'supervisor_restart_count') int get restartCount;@JsonKey(name: 'supervisor_cooldown_until') String? get cooldownUntil;@JsonKey(name: 'supervisor_last_halt_reason') String? get lastHaltReason;@JsonKey(name: 'supervisor_last_resume_action') String? get lastResumeAction;@JsonKey(name: 'supervisor_last_exit_code') int? get lastExitCode;@JsonKey(name: 'supervisor_low_signal_streak') int get lowSignalStreak;@JsonKey(name: 'supervisor_throughput_window_started_at') String? get throughputWindowStartedAt;@JsonKey(name: 'supervisor_throughput_steps') int get throughputSteps;@JsonKey(name: 'supervisor_throughput_rejects') int get throughputRejects;@JsonKey(name: 'supervisor_throughput_high_retries') int get throughputHighRetries;@JsonKey(name: 'supervisor_reflection_count') int get reflectionCount;@JsonKey(name: 'supervisor_last_reflection_at') String? get lastReflectionAt;
/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupervisorStateCopyWith<SupervisorState> get copyWith => _$SupervisorStateCopyWithImpl<SupervisorState>(this as SupervisorState, _$identity);

  /// Serializes this SupervisorState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupervisorState&&(identical(other.running, running) || other.running == running)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.startReason, startReason) || other.startReason == startReason)&&(identical(other.restartCount, restartCount) || other.restartCount == restartCount)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.lastHaltReason, lastHaltReason) || other.lastHaltReason == lastHaltReason)&&(identical(other.lastResumeAction, lastResumeAction) || other.lastResumeAction == lastResumeAction)&&(identical(other.lastExitCode, lastExitCode) || other.lastExitCode == lastExitCode)&&(identical(other.lowSignalStreak, lowSignalStreak) || other.lowSignalStreak == lowSignalStreak)&&(identical(other.throughputWindowStartedAt, throughputWindowStartedAt) || other.throughputWindowStartedAt == throughputWindowStartedAt)&&(identical(other.throughputSteps, throughputSteps) || other.throughputSteps == throughputSteps)&&(identical(other.throughputRejects, throughputRejects) || other.throughputRejects == throughputRejects)&&(identical(other.throughputHighRetries, throughputHighRetries) || other.throughputHighRetries == throughputHighRetries)&&(identical(other.reflectionCount, reflectionCount) || other.reflectionCount == reflectionCount)&&(identical(other.lastReflectionAt, lastReflectionAt) || other.lastReflectionAt == lastReflectionAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,sessionId,pid,startedAt,profile,startReason,restartCount,cooldownUntil,lastHaltReason,lastResumeAction,lastExitCode,lowSignalStreak,throughputWindowStartedAt,throughputSteps,throughputRejects,throughputHighRetries,reflectionCount,lastReflectionAt);

@override
String toString() {
  return 'SupervisorState(running: $running, sessionId: $sessionId, pid: $pid, startedAt: $startedAt, profile: $profile, startReason: $startReason, restartCount: $restartCount, cooldownUntil: $cooldownUntil, lastHaltReason: $lastHaltReason, lastResumeAction: $lastResumeAction, lastExitCode: $lastExitCode, lowSignalStreak: $lowSignalStreak, throughputWindowStartedAt: $throughputWindowStartedAt, throughputSteps: $throughputSteps, throughputRejects: $throughputRejects, throughputHighRetries: $throughputHighRetries, reflectionCount: $reflectionCount, lastReflectionAt: $lastReflectionAt)';
}


}

/// @nodoc
abstract mixin class $SupervisorStateCopyWith<$Res>  {
  factory $SupervisorStateCopyWith(SupervisorState value, $Res Function(SupervisorState) _then) = _$SupervisorStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'supervisor_running') bool running,@JsonKey(name: 'supervisor_session_id') String? sessionId,@JsonKey(name: 'supervisor_pid') int? pid,@JsonKey(name: 'supervisor_started_at') String? startedAt,@JsonKey(name: 'supervisor_profile') String? profile,@JsonKey(name: 'supervisor_start_reason') String? startReason,@JsonKey(name: 'supervisor_restart_count') int restartCount,@JsonKey(name: 'supervisor_cooldown_until') String? cooldownUntil,@JsonKey(name: 'supervisor_last_halt_reason') String? lastHaltReason,@JsonKey(name: 'supervisor_last_resume_action') String? lastResumeAction,@JsonKey(name: 'supervisor_last_exit_code') int? lastExitCode,@JsonKey(name: 'supervisor_low_signal_streak') int lowSignalStreak,@JsonKey(name: 'supervisor_throughput_window_started_at') String? throughputWindowStartedAt,@JsonKey(name: 'supervisor_throughput_steps') int throughputSteps,@JsonKey(name: 'supervisor_throughput_rejects') int throughputRejects,@JsonKey(name: 'supervisor_throughput_high_retries') int throughputHighRetries,@JsonKey(name: 'supervisor_reflection_count') int reflectionCount,@JsonKey(name: 'supervisor_last_reflection_at') String? lastReflectionAt
});




}
/// @nodoc
class _$SupervisorStateCopyWithImpl<$Res>
    implements $SupervisorStateCopyWith<$Res> {
  _$SupervisorStateCopyWithImpl(this._self, this._then);

  final SupervisorState _self;
  final $Res Function(SupervisorState) _then;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? running = null,Object? sessionId = freezed,Object? pid = freezed,Object? startedAt = freezed,Object? profile = freezed,Object? startReason = freezed,Object? restartCount = null,Object? cooldownUntil = freezed,Object? lastHaltReason = freezed,Object? lastResumeAction = freezed,Object? lastExitCode = freezed,Object? lowSignalStreak = null,Object? throughputWindowStartedAt = freezed,Object? throughputSteps = null,Object? throughputRejects = null,Object? throughputHighRetries = null,Object? reflectionCount = null,Object? lastReflectionAt = freezed,}) {
  return _then(_self.copyWith(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,startReason: freezed == startReason ? _self.startReason : startReason // ignore: cast_nullable_to_non_nullable
as String?,restartCount: null == restartCount ? _self.restartCount : restartCount // ignore: cast_nullable_to_non_nullable
as int,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as String?,lastHaltReason: freezed == lastHaltReason ? _self.lastHaltReason : lastHaltReason // ignore: cast_nullable_to_non_nullable
as String?,lastResumeAction: freezed == lastResumeAction ? _self.lastResumeAction : lastResumeAction // ignore: cast_nullable_to_non_nullable
as String?,lastExitCode: freezed == lastExitCode ? _self.lastExitCode : lastExitCode // ignore: cast_nullable_to_non_nullable
as int?,lowSignalStreak: null == lowSignalStreak ? _self.lowSignalStreak : lowSignalStreak // ignore: cast_nullable_to_non_nullable
as int,throughputWindowStartedAt: freezed == throughputWindowStartedAt ? _self.throughputWindowStartedAt : throughputWindowStartedAt // ignore: cast_nullable_to_non_nullable
as String?,throughputSteps: null == throughputSteps ? _self.throughputSteps : throughputSteps // ignore: cast_nullable_to_non_nullable
as int,throughputRejects: null == throughputRejects ? _self.throughputRejects : throughputRejects // ignore: cast_nullable_to_non_nullable
as int,throughputHighRetries: null == throughputHighRetries ? _self.throughputHighRetries : throughputHighRetries // ignore: cast_nullable_to_non_nullable
as int,reflectionCount: null == reflectionCount ? _self.reflectionCount : reflectionCount // ignore: cast_nullable_to_non_nullable
as int,lastReflectionAt: freezed == lastReflectionAt ? _self.lastReflectionAt : lastReflectionAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupervisorState].
extension SupervisorStatePatterns on SupervisorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupervisorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupervisorState value)  $default,){
final _that = this;
switch (_that) {
case _SupervisorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupervisorState value)?  $default,){
final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'supervisor_running')  bool running, @JsonKey(name: 'supervisor_session_id')  String? sessionId, @JsonKey(name: 'supervisor_pid')  int? pid, @JsonKey(name: 'supervisor_started_at')  String? startedAt, @JsonKey(name: 'supervisor_profile')  String? profile, @JsonKey(name: 'supervisor_start_reason')  String? startReason, @JsonKey(name: 'supervisor_restart_count')  int restartCount, @JsonKey(name: 'supervisor_cooldown_until')  String? cooldownUntil, @JsonKey(name: 'supervisor_last_halt_reason')  String? lastHaltReason, @JsonKey(name: 'supervisor_last_resume_action')  String? lastResumeAction, @JsonKey(name: 'supervisor_last_exit_code')  int? lastExitCode, @JsonKey(name: 'supervisor_low_signal_streak')  int lowSignalStreak, @JsonKey(name: 'supervisor_throughput_window_started_at')  String? throughputWindowStartedAt, @JsonKey(name: 'supervisor_throughput_steps')  int throughputSteps, @JsonKey(name: 'supervisor_throughput_rejects')  int throughputRejects, @JsonKey(name: 'supervisor_throughput_high_retries')  int throughputHighRetries, @JsonKey(name: 'supervisor_reflection_count')  int reflectionCount, @JsonKey(name: 'supervisor_last_reflection_at')  String? lastReflectionAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
return $default(_that.running,_that.sessionId,_that.pid,_that.startedAt,_that.profile,_that.startReason,_that.restartCount,_that.cooldownUntil,_that.lastHaltReason,_that.lastResumeAction,_that.lastExitCode,_that.lowSignalStreak,_that.throughputWindowStartedAt,_that.throughputSteps,_that.throughputRejects,_that.throughputHighRetries,_that.reflectionCount,_that.lastReflectionAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'supervisor_running')  bool running, @JsonKey(name: 'supervisor_session_id')  String? sessionId, @JsonKey(name: 'supervisor_pid')  int? pid, @JsonKey(name: 'supervisor_started_at')  String? startedAt, @JsonKey(name: 'supervisor_profile')  String? profile, @JsonKey(name: 'supervisor_start_reason')  String? startReason, @JsonKey(name: 'supervisor_restart_count')  int restartCount, @JsonKey(name: 'supervisor_cooldown_until')  String? cooldownUntil, @JsonKey(name: 'supervisor_last_halt_reason')  String? lastHaltReason, @JsonKey(name: 'supervisor_last_resume_action')  String? lastResumeAction, @JsonKey(name: 'supervisor_last_exit_code')  int? lastExitCode, @JsonKey(name: 'supervisor_low_signal_streak')  int lowSignalStreak, @JsonKey(name: 'supervisor_throughput_window_started_at')  String? throughputWindowStartedAt, @JsonKey(name: 'supervisor_throughput_steps')  int throughputSteps, @JsonKey(name: 'supervisor_throughput_rejects')  int throughputRejects, @JsonKey(name: 'supervisor_throughput_high_retries')  int throughputHighRetries, @JsonKey(name: 'supervisor_reflection_count')  int reflectionCount, @JsonKey(name: 'supervisor_last_reflection_at')  String? lastReflectionAt)  $default,) {final _that = this;
switch (_that) {
case _SupervisorState():
return $default(_that.running,_that.sessionId,_that.pid,_that.startedAt,_that.profile,_that.startReason,_that.restartCount,_that.cooldownUntil,_that.lastHaltReason,_that.lastResumeAction,_that.lastExitCode,_that.lowSignalStreak,_that.throughputWindowStartedAt,_that.throughputSteps,_that.throughputRejects,_that.throughputHighRetries,_that.reflectionCount,_that.lastReflectionAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'supervisor_running')  bool running, @JsonKey(name: 'supervisor_session_id')  String? sessionId, @JsonKey(name: 'supervisor_pid')  int? pid, @JsonKey(name: 'supervisor_started_at')  String? startedAt, @JsonKey(name: 'supervisor_profile')  String? profile, @JsonKey(name: 'supervisor_start_reason')  String? startReason, @JsonKey(name: 'supervisor_restart_count')  int restartCount, @JsonKey(name: 'supervisor_cooldown_until')  String? cooldownUntil, @JsonKey(name: 'supervisor_last_halt_reason')  String? lastHaltReason, @JsonKey(name: 'supervisor_last_resume_action')  String? lastResumeAction, @JsonKey(name: 'supervisor_last_exit_code')  int? lastExitCode, @JsonKey(name: 'supervisor_low_signal_streak')  int lowSignalStreak, @JsonKey(name: 'supervisor_throughput_window_started_at')  String? throughputWindowStartedAt, @JsonKey(name: 'supervisor_throughput_steps')  int throughputSteps, @JsonKey(name: 'supervisor_throughput_rejects')  int throughputRejects, @JsonKey(name: 'supervisor_throughput_high_retries')  int throughputHighRetries, @JsonKey(name: 'supervisor_reflection_count')  int reflectionCount, @JsonKey(name: 'supervisor_last_reflection_at')  String? lastReflectionAt)?  $default,) {final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
return $default(_that.running,_that.sessionId,_that.pid,_that.startedAt,_that.profile,_that.startReason,_that.restartCount,_that.cooldownUntil,_that.lastHaltReason,_that.lastResumeAction,_that.lastExitCode,_that.lowSignalStreak,_that.throughputWindowStartedAt,_that.throughputSteps,_that.throughputRejects,_that.throughputHighRetries,_that.reflectionCount,_that.lastReflectionAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupervisorState implements SupervisorState {
  const _SupervisorState({@JsonKey(name: 'supervisor_running') this.running = false, @JsonKey(name: 'supervisor_session_id') this.sessionId, @JsonKey(name: 'supervisor_pid') this.pid, @JsonKey(name: 'supervisor_started_at') this.startedAt, @JsonKey(name: 'supervisor_profile') this.profile, @JsonKey(name: 'supervisor_start_reason') this.startReason, @JsonKey(name: 'supervisor_restart_count') this.restartCount = 0, @JsonKey(name: 'supervisor_cooldown_until') this.cooldownUntil, @JsonKey(name: 'supervisor_last_halt_reason') this.lastHaltReason, @JsonKey(name: 'supervisor_last_resume_action') this.lastResumeAction, @JsonKey(name: 'supervisor_last_exit_code') this.lastExitCode, @JsonKey(name: 'supervisor_low_signal_streak') this.lowSignalStreak = 0, @JsonKey(name: 'supervisor_throughput_window_started_at') this.throughputWindowStartedAt, @JsonKey(name: 'supervisor_throughput_steps') this.throughputSteps = 0, @JsonKey(name: 'supervisor_throughput_rejects') this.throughputRejects = 0, @JsonKey(name: 'supervisor_throughput_high_retries') this.throughputHighRetries = 0, @JsonKey(name: 'supervisor_reflection_count') this.reflectionCount = 0, @JsonKey(name: 'supervisor_last_reflection_at') this.lastReflectionAt});
  factory _SupervisorState.fromJson(Map<String, dynamic> json) => _$SupervisorStateFromJson(json);

@override@JsonKey(name: 'supervisor_running') final  bool running;
@override@JsonKey(name: 'supervisor_session_id') final  String? sessionId;
@override@JsonKey(name: 'supervisor_pid') final  int? pid;
@override@JsonKey(name: 'supervisor_started_at') final  String? startedAt;
@override@JsonKey(name: 'supervisor_profile') final  String? profile;
@override@JsonKey(name: 'supervisor_start_reason') final  String? startReason;
@override@JsonKey(name: 'supervisor_restart_count') final  int restartCount;
@override@JsonKey(name: 'supervisor_cooldown_until') final  String? cooldownUntil;
@override@JsonKey(name: 'supervisor_last_halt_reason') final  String? lastHaltReason;
@override@JsonKey(name: 'supervisor_last_resume_action') final  String? lastResumeAction;
@override@JsonKey(name: 'supervisor_last_exit_code') final  int? lastExitCode;
@override@JsonKey(name: 'supervisor_low_signal_streak') final  int lowSignalStreak;
@override@JsonKey(name: 'supervisor_throughput_window_started_at') final  String? throughputWindowStartedAt;
@override@JsonKey(name: 'supervisor_throughput_steps') final  int throughputSteps;
@override@JsonKey(name: 'supervisor_throughput_rejects') final  int throughputRejects;
@override@JsonKey(name: 'supervisor_throughput_high_retries') final  int throughputHighRetries;
@override@JsonKey(name: 'supervisor_reflection_count') final  int reflectionCount;
@override@JsonKey(name: 'supervisor_last_reflection_at') final  String? lastReflectionAt;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupervisorStateCopyWith<_SupervisorState> get copyWith => __$SupervisorStateCopyWithImpl<_SupervisorState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupervisorStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupervisorState&&(identical(other.running, running) || other.running == running)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.startReason, startReason) || other.startReason == startReason)&&(identical(other.restartCount, restartCount) || other.restartCount == restartCount)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.lastHaltReason, lastHaltReason) || other.lastHaltReason == lastHaltReason)&&(identical(other.lastResumeAction, lastResumeAction) || other.lastResumeAction == lastResumeAction)&&(identical(other.lastExitCode, lastExitCode) || other.lastExitCode == lastExitCode)&&(identical(other.lowSignalStreak, lowSignalStreak) || other.lowSignalStreak == lowSignalStreak)&&(identical(other.throughputWindowStartedAt, throughputWindowStartedAt) || other.throughputWindowStartedAt == throughputWindowStartedAt)&&(identical(other.throughputSteps, throughputSteps) || other.throughputSteps == throughputSteps)&&(identical(other.throughputRejects, throughputRejects) || other.throughputRejects == throughputRejects)&&(identical(other.throughputHighRetries, throughputHighRetries) || other.throughputHighRetries == throughputHighRetries)&&(identical(other.reflectionCount, reflectionCount) || other.reflectionCount == reflectionCount)&&(identical(other.lastReflectionAt, lastReflectionAt) || other.lastReflectionAt == lastReflectionAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,sessionId,pid,startedAt,profile,startReason,restartCount,cooldownUntil,lastHaltReason,lastResumeAction,lastExitCode,lowSignalStreak,throughputWindowStartedAt,throughputSteps,throughputRejects,throughputHighRetries,reflectionCount,lastReflectionAt);

@override
String toString() {
  return 'SupervisorState(running: $running, sessionId: $sessionId, pid: $pid, startedAt: $startedAt, profile: $profile, startReason: $startReason, restartCount: $restartCount, cooldownUntil: $cooldownUntil, lastHaltReason: $lastHaltReason, lastResumeAction: $lastResumeAction, lastExitCode: $lastExitCode, lowSignalStreak: $lowSignalStreak, throughputWindowStartedAt: $throughputWindowStartedAt, throughputSteps: $throughputSteps, throughputRejects: $throughputRejects, throughputHighRetries: $throughputHighRetries, reflectionCount: $reflectionCount, lastReflectionAt: $lastReflectionAt)';
}


}

/// @nodoc
abstract mixin class _$SupervisorStateCopyWith<$Res> implements $SupervisorStateCopyWith<$Res> {
  factory _$SupervisorStateCopyWith(_SupervisorState value, $Res Function(_SupervisorState) _then) = __$SupervisorStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'supervisor_running') bool running,@JsonKey(name: 'supervisor_session_id') String? sessionId,@JsonKey(name: 'supervisor_pid') int? pid,@JsonKey(name: 'supervisor_started_at') String? startedAt,@JsonKey(name: 'supervisor_profile') String? profile,@JsonKey(name: 'supervisor_start_reason') String? startReason,@JsonKey(name: 'supervisor_restart_count') int restartCount,@JsonKey(name: 'supervisor_cooldown_until') String? cooldownUntil,@JsonKey(name: 'supervisor_last_halt_reason') String? lastHaltReason,@JsonKey(name: 'supervisor_last_resume_action') String? lastResumeAction,@JsonKey(name: 'supervisor_last_exit_code') int? lastExitCode,@JsonKey(name: 'supervisor_low_signal_streak') int lowSignalStreak,@JsonKey(name: 'supervisor_throughput_window_started_at') String? throughputWindowStartedAt,@JsonKey(name: 'supervisor_throughput_steps') int throughputSteps,@JsonKey(name: 'supervisor_throughput_rejects') int throughputRejects,@JsonKey(name: 'supervisor_throughput_high_retries') int throughputHighRetries,@JsonKey(name: 'supervisor_reflection_count') int reflectionCount,@JsonKey(name: 'supervisor_last_reflection_at') String? lastReflectionAt
});




}
/// @nodoc
class __$SupervisorStateCopyWithImpl<$Res>
    implements _$SupervisorStateCopyWith<$Res> {
  __$SupervisorStateCopyWithImpl(this._self, this._then);

  final _SupervisorState _self;
  final $Res Function(_SupervisorState) _then;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? running = null,Object? sessionId = freezed,Object? pid = freezed,Object? startedAt = freezed,Object? profile = freezed,Object? startReason = freezed,Object? restartCount = null,Object? cooldownUntil = freezed,Object? lastHaltReason = freezed,Object? lastResumeAction = freezed,Object? lastExitCode = freezed,Object? lowSignalStreak = null,Object? throughputWindowStartedAt = freezed,Object? throughputSteps = null,Object? throughputRejects = null,Object? throughputHighRetries = null,Object? reflectionCount = null,Object? lastReflectionAt = freezed,}) {
  return _then(_SupervisorState(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,startReason: freezed == startReason ? _self.startReason : startReason // ignore: cast_nullable_to_non_nullable
as String?,restartCount: null == restartCount ? _self.restartCount : restartCount // ignore: cast_nullable_to_non_nullable
as int,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as String?,lastHaltReason: freezed == lastHaltReason ? _self.lastHaltReason : lastHaltReason // ignore: cast_nullable_to_non_nullable
as String?,lastResumeAction: freezed == lastResumeAction ? _self.lastResumeAction : lastResumeAction // ignore: cast_nullable_to_non_nullable
as String?,lastExitCode: freezed == lastExitCode ? _self.lastExitCode : lastExitCode // ignore: cast_nullable_to_non_nullable
as int?,lowSignalStreak: null == lowSignalStreak ? _self.lowSignalStreak : lowSignalStreak // ignore: cast_nullable_to_non_nullable
as int,throughputWindowStartedAt: freezed == throughputWindowStartedAt ? _self.throughputWindowStartedAt : throughputWindowStartedAt // ignore: cast_nullable_to_non_nullable
as String?,throughputSteps: null == throughputSteps ? _self.throughputSteps : throughputSteps // ignore: cast_nullable_to_non_nullable
as int,throughputRejects: null == throughputRejects ? _self.throughputRejects : throughputRejects // ignore: cast_nullable_to_non_nullable
as int,throughputHighRetries: null == throughputHighRetries ? _self.throughputHighRetries : throughputHighRetries // ignore: cast_nullable_to_non_nullable
as int,reflectionCount: null == reflectionCount ? _self.reflectionCount : reflectionCount // ignore: cast_nullable_to_non_nullable
as int,lastReflectionAt: freezed == lastReflectionAt ? _self.lastReflectionAt : lastReflectionAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
