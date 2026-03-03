// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'autopilot_run_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AutopilotRunState {

@JsonKey(name: 'autopilot_running') bool get running;@JsonKey(name: 'current_mode') String? get currentMode;@JsonKey(name: 'last_loop_at') String? get lastLoopAt;@JsonKey(name: 'consecutive_failures') int get consecutiveFailures;@JsonKey(name: 'last_error') String? get lastError;@JsonKey(name: 'last_error_class') String? get lastErrorClass;@JsonKey(name: 'last_error_kind') String? get lastErrorKind;
/// Create a copy of AutopilotRunState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutopilotRunStateCopyWith<AutopilotRunState> get copyWith => _$AutopilotRunStateCopyWithImpl<AutopilotRunState>(this as AutopilotRunState, _$identity);

  /// Serializes this AutopilotRunState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutopilotRunState&&(identical(other.running, running) || other.running == running)&&(identical(other.currentMode, currentMode) || other.currentMode == currentMode)&&(identical(other.lastLoopAt, lastLoopAt) || other.lastLoopAt == lastLoopAt)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastErrorClass, lastErrorClass) || other.lastErrorClass == lastErrorClass)&&(identical(other.lastErrorKind, lastErrorKind) || other.lastErrorKind == lastErrorKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,currentMode,lastLoopAt,consecutiveFailures,lastError,lastErrorClass,lastErrorKind);

@override
String toString() {
  return 'AutopilotRunState(running: $running, currentMode: $currentMode, lastLoopAt: $lastLoopAt, consecutiveFailures: $consecutiveFailures, lastError: $lastError, lastErrorClass: $lastErrorClass, lastErrorKind: $lastErrorKind)';
}


}

/// @nodoc
abstract mixin class $AutopilotRunStateCopyWith<$Res>  {
  factory $AutopilotRunStateCopyWith(AutopilotRunState value, $Res Function(AutopilotRunState) _then) = _$AutopilotRunStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'autopilot_running') bool running,@JsonKey(name: 'current_mode') String? currentMode,@JsonKey(name: 'last_loop_at') String? lastLoopAt,@JsonKey(name: 'consecutive_failures') int consecutiveFailures,@JsonKey(name: 'last_error') String? lastError,@JsonKey(name: 'last_error_class') String? lastErrorClass,@JsonKey(name: 'last_error_kind') String? lastErrorKind
});




}
/// @nodoc
class _$AutopilotRunStateCopyWithImpl<$Res>
    implements $AutopilotRunStateCopyWith<$Res> {
  _$AutopilotRunStateCopyWithImpl(this._self, this._then);

  final AutopilotRunState _self;
  final $Res Function(AutopilotRunState) _then;

/// Create a copy of AutopilotRunState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? running = null,Object? currentMode = freezed,Object? lastLoopAt = freezed,Object? consecutiveFailures = null,Object? lastError = freezed,Object? lastErrorClass = freezed,Object? lastErrorKind = freezed,}) {
  return _then(_self.copyWith(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,currentMode: freezed == currentMode ? _self.currentMode : currentMode // ignore: cast_nullable_to_non_nullable
as String?,lastLoopAt: freezed == lastLoopAt ? _self.lastLoopAt : lastLoopAt // ignore: cast_nullable_to_non_nullable
as String?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,lastErrorClass: freezed == lastErrorClass ? _self.lastErrorClass : lastErrorClass // ignore: cast_nullable_to_non_nullable
as String?,lastErrorKind: freezed == lastErrorKind ? _self.lastErrorKind : lastErrorKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AutopilotRunState].
extension AutopilotRunStatePatterns on AutopilotRunState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutopilotRunState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutopilotRunState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutopilotRunState value)  $default,){
final _that = this;
switch (_that) {
case _AutopilotRunState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutopilotRunState value)?  $default,){
final _that = this;
switch (_that) {
case _AutopilotRunState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'autopilot_running')  bool running, @JsonKey(name: 'current_mode')  String? currentMode, @JsonKey(name: 'last_loop_at')  String? lastLoopAt, @JsonKey(name: 'consecutive_failures')  int consecutiveFailures, @JsonKey(name: 'last_error')  String? lastError, @JsonKey(name: 'last_error_class')  String? lastErrorClass, @JsonKey(name: 'last_error_kind')  String? lastErrorKind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutopilotRunState() when $default != null:
return $default(_that.running,_that.currentMode,_that.lastLoopAt,_that.consecutiveFailures,_that.lastError,_that.lastErrorClass,_that.lastErrorKind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'autopilot_running')  bool running, @JsonKey(name: 'current_mode')  String? currentMode, @JsonKey(name: 'last_loop_at')  String? lastLoopAt, @JsonKey(name: 'consecutive_failures')  int consecutiveFailures, @JsonKey(name: 'last_error')  String? lastError, @JsonKey(name: 'last_error_class')  String? lastErrorClass, @JsonKey(name: 'last_error_kind')  String? lastErrorKind)  $default,) {final _that = this;
switch (_that) {
case _AutopilotRunState():
return $default(_that.running,_that.currentMode,_that.lastLoopAt,_that.consecutiveFailures,_that.lastError,_that.lastErrorClass,_that.lastErrorKind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'autopilot_running')  bool running, @JsonKey(name: 'current_mode')  String? currentMode, @JsonKey(name: 'last_loop_at')  String? lastLoopAt, @JsonKey(name: 'consecutive_failures')  int consecutiveFailures, @JsonKey(name: 'last_error')  String? lastError, @JsonKey(name: 'last_error_class')  String? lastErrorClass, @JsonKey(name: 'last_error_kind')  String? lastErrorKind)?  $default,) {final _that = this;
switch (_that) {
case _AutopilotRunState() when $default != null:
return $default(_that.running,_that.currentMode,_that.lastLoopAt,_that.consecutiveFailures,_that.lastError,_that.lastErrorClass,_that.lastErrorKind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AutopilotRunState implements AutopilotRunState {
  const _AutopilotRunState({@JsonKey(name: 'autopilot_running') this.running = false, @JsonKey(name: 'current_mode') this.currentMode, @JsonKey(name: 'last_loop_at') this.lastLoopAt, @JsonKey(name: 'consecutive_failures') this.consecutiveFailures = 0, @JsonKey(name: 'last_error') this.lastError, @JsonKey(name: 'last_error_class') this.lastErrorClass, @JsonKey(name: 'last_error_kind') this.lastErrorKind});
  factory _AutopilotRunState.fromJson(Map<String, dynamic> json) => _$AutopilotRunStateFromJson(json);

@override@JsonKey(name: 'autopilot_running') final  bool running;
@override@JsonKey(name: 'current_mode') final  String? currentMode;
@override@JsonKey(name: 'last_loop_at') final  String? lastLoopAt;
@override@JsonKey(name: 'consecutive_failures') final  int consecutiveFailures;
@override@JsonKey(name: 'last_error') final  String? lastError;
@override@JsonKey(name: 'last_error_class') final  String? lastErrorClass;
@override@JsonKey(name: 'last_error_kind') final  String? lastErrorKind;

/// Create a copy of AutopilotRunState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutopilotRunStateCopyWith<_AutopilotRunState> get copyWith => __$AutopilotRunStateCopyWithImpl<_AutopilotRunState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AutopilotRunStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutopilotRunState&&(identical(other.running, running) || other.running == running)&&(identical(other.currentMode, currentMode) || other.currentMode == currentMode)&&(identical(other.lastLoopAt, lastLoopAt) || other.lastLoopAt == lastLoopAt)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastErrorClass, lastErrorClass) || other.lastErrorClass == lastErrorClass)&&(identical(other.lastErrorKind, lastErrorKind) || other.lastErrorKind == lastErrorKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,currentMode,lastLoopAt,consecutiveFailures,lastError,lastErrorClass,lastErrorKind);

@override
String toString() {
  return 'AutopilotRunState(running: $running, currentMode: $currentMode, lastLoopAt: $lastLoopAt, consecutiveFailures: $consecutiveFailures, lastError: $lastError, lastErrorClass: $lastErrorClass, lastErrorKind: $lastErrorKind)';
}


}

/// @nodoc
abstract mixin class _$AutopilotRunStateCopyWith<$Res> implements $AutopilotRunStateCopyWith<$Res> {
  factory _$AutopilotRunStateCopyWith(_AutopilotRunState value, $Res Function(_AutopilotRunState) _then) = __$AutopilotRunStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'autopilot_running') bool running,@JsonKey(name: 'current_mode') String? currentMode,@JsonKey(name: 'last_loop_at') String? lastLoopAt,@JsonKey(name: 'consecutive_failures') int consecutiveFailures,@JsonKey(name: 'last_error') String? lastError,@JsonKey(name: 'last_error_class') String? lastErrorClass,@JsonKey(name: 'last_error_kind') String? lastErrorKind
});




}
/// @nodoc
class __$AutopilotRunStateCopyWithImpl<$Res>
    implements _$AutopilotRunStateCopyWith<$Res> {
  __$AutopilotRunStateCopyWithImpl(this._self, this._then);

  final _AutopilotRunState _self;
  final $Res Function(_AutopilotRunState) _then;

/// Create a copy of AutopilotRunState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? running = null,Object? currentMode = freezed,Object? lastLoopAt = freezed,Object? consecutiveFailures = null,Object? lastError = freezed,Object? lastErrorClass = freezed,Object? lastErrorKind = freezed,}) {
  return _then(_AutopilotRunState(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,currentMode: freezed == currentMode ? _self.currentMode : currentMode // ignore: cast_nullable_to_non_nullable
as String?,lastLoopAt: freezed == lastLoopAt ? _self.lastLoopAt : lastLoopAt // ignore: cast_nullable_to_non_nullable
as String?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,lastErrorClass: freezed == lastErrorClass ? _self.lastErrorClass : lastErrorClass // ignore: cast_nullable_to_non_nullable
as String?,lastErrorKind: freezed == lastErrorKind ? _self.lastErrorKind : lastErrorKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
