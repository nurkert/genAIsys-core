// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'retry_scheduling_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RetrySchedulingState {

@JsonKey(name: 'task_retry_counts') Map<String, int> get retryCounts;@JsonKey(name: 'task_cooldown_until') Map<String, String> get cooldownUntil;
/// Create a copy of RetrySchedulingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetrySchedulingStateCopyWith<RetrySchedulingState> get copyWith => _$RetrySchedulingStateCopyWithImpl<RetrySchedulingState>(this as RetrySchedulingState, _$identity);

  /// Serializes this RetrySchedulingState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetrySchedulingState&&const DeepCollectionEquality().equals(other.retryCounts, retryCounts)&&const DeepCollectionEquality().equals(other.cooldownUntil, cooldownUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(retryCounts),const DeepCollectionEquality().hash(cooldownUntil));

@override
String toString() {
  return 'RetrySchedulingState(retryCounts: $retryCounts, cooldownUntil: $cooldownUntil)';
}


}

/// @nodoc
abstract mixin class $RetrySchedulingStateCopyWith<$Res>  {
  factory $RetrySchedulingStateCopyWith(RetrySchedulingState value, $Res Function(RetrySchedulingState) _then) = _$RetrySchedulingStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'task_retry_counts') Map<String, int> retryCounts,@JsonKey(name: 'task_cooldown_until') Map<String, String> cooldownUntil
});




}
/// @nodoc
class _$RetrySchedulingStateCopyWithImpl<$Res>
    implements $RetrySchedulingStateCopyWith<$Res> {
  _$RetrySchedulingStateCopyWithImpl(this._self, this._then);

  final RetrySchedulingState _self;
  final $Res Function(RetrySchedulingState) _then;

/// Create a copy of RetrySchedulingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? retryCounts = null,Object? cooldownUntil = null,}) {
  return _then(_self.copyWith(
retryCounts: null == retryCounts ? _self.retryCounts : retryCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,cooldownUntil: null == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [RetrySchedulingState].
extension RetrySchedulingStatePatterns on RetrySchedulingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RetrySchedulingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RetrySchedulingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RetrySchedulingState value)  $default,){
final _that = this;
switch (_that) {
case _RetrySchedulingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RetrySchedulingState value)?  $default,){
final _that = this;
switch (_that) {
case _RetrySchedulingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'task_retry_counts')  Map<String, int> retryCounts, @JsonKey(name: 'task_cooldown_until')  Map<String, String> cooldownUntil)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RetrySchedulingState() when $default != null:
return $default(_that.retryCounts,_that.cooldownUntil);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'task_retry_counts')  Map<String, int> retryCounts, @JsonKey(name: 'task_cooldown_until')  Map<String, String> cooldownUntil)  $default,) {final _that = this;
switch (_that) {
case _RetrySchedulingState():
return $default(_that.retryCounts,_that.cooldownUntil);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'task_retry_counts')  Map<String, int> retryCounts, @JsonKey(name: 'task_cooldown_until')  Map<String, String> cooldownUntil)?  $default,) {final _that = this;
switch (_that) {
case _RetrySchedulingState() when $default != null:
return $default(_that.retryCounts,_that.cooldownUntil);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RetrySchedulingState implements RetrySchedulingState {
  const _RetrySchedulingState({@JsonKey(name: 'task_retry_counts') final  Map<String, int> retryCounts = const {}, @JsonKey(name: 'task_cooldown_until') final  Map<String, String> cooldownUntil = const {}}): _retryCounts = retryCounts,_cooldownUntil = cooldownUntil;
  factory _RetrySchedulingState.fromJson(Map<String, dynamic> json) => _$RetrySchedulingStateFromJson(json);

 final  Map<String, int> _retryCounts;
@override@JsonKey(name: 'task_retry_counts') Map<String, int> get retryCounts {
  if (_retryCounts is EqualUnmodifiableMapView) return _retryCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_retryCounts);
}

 final  Map<String, String> _cooldownUntil;
@override@JsonKey(name: 'task_cooldown_until') Map<String, String> get cooldownUntil {
  if (_cooldownUntil is EqualUnmodifiableMapView) return _cooldownUntil;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_cooldownUntil);
}


/// Create a copy of RetrySchedulingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetrySchedulingStateCopyWith<_RetrySchedulingState> get copyWith => __$RetrySchedulingStateCopyWithImpl<_RetrySchedulingState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetrySchedulingStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetrySchedulingState&&const DeepCollectionEquality().equals(other._retryCounts, _retryCounts)&&const DeepCollectionEquality().equals(other._cooldownUntil, _cooldownUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_retryCounts),const DeepCollectionEquality().hash(_cooldownUntil));

@override
String toString() {
  return 'RetrySchedulingState(retryCounts: $retryCounts, cooldownUntil: $cooldownUntil)';
}


}

/// @nodoc
abstract mixin class _$RetrySchedulingStateCopyWith<$Res> implements $RetrySchedulingStateCopyWith<$Res> {
  factory _$RetrySchedulingStateCopyWith(_RetrySchedulingState value, $Res Function(_RetrySchedulingState) _then) = __$RetrySchedulingStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'task_retry_counts') Map<String, int> retryCounts,@JsonKey(name: 'task_cooldown_until') Map<String, String> cooldownUntil
});




}
/// @nodoc
class __$RetrySchedulingStateCopyWithImpl<$Res>
    implements _$RetrySchedulingStateCopyWith<$Res> {
  __$RetrySchedulingStateCopyWithImpl(this._self, this._then);

  final _RetrySchedulingState _self;
  final $Res Function(_RetrySchedulingState) _then;

/// Create a copy of RetrySchedulingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? retryCounts = null,Object? cooldownUntil = null,}) {
  return _then(_RetrySchedulingState(
retryCounts: null == retryCounts ? _self._retryCounts : retryCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,cooldownUntil: null == cooldownUntil ? _self._cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
