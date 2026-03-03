// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reflection_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReflectionState {

@JsonKey(name: 'last_reflection_at') String? get lastAt;@JsonKey(name: 'reflection_count') int get count;@JsonKey(name: 'reflection_tasks_created') int get tasksCreated;
/// Create a copy of ReflectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReflectionStateCopyWith<ReflectionState> get copyWith => _$ReflectionStateCopyWithImpl<ReflectionState>(this as ReflectionState, _$identity);

  /// Serializes this ReflectionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReflectionState&&(identical(other.lastAt, lastAt) || other.lastAt == lastAt)&&(identical(other.count, count) || other.count == count)&&(identical(other.tasksCreated, tasksCreated) || other.tasksCreated == tasksCreated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastAt,count,tasksCreated);

@override
String toString() {
  return 'ReflectionState(lastAt: $lastAt, count: $count, tasksCreated: $tasksCreated)';
}


}

/// @nodoc
abstract mixin class $ReflectionStateCopyWith<$Res>  {
  factory $ReflectionStateCopyWith(ReflectionState value, $Res Function(ReflectionState) _then) = _$ReflectionStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'last_reflection_at') String? lastAt,@JsonKey(name: 'reflection_count') int count,@JsonKey(name: 'reflection_tasks_created') int tasksCreated
});




}
/// @nodoc
class _$ReflectionStateCopyWithImpl<$Res>
    implements $ReflectionStateCopyWith<$Res> {
  _$ReflectionStateCopyWithImpl(this._self, this._then);

  final ReflectionState _self;
  final $Res Function(ReflectionState) _then;

/// Create a copy of ReflectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastAt = freezed,Object? count = null,Object? tasksCreated = null,}) {
  return _then(_self.copyWith(
lastAt: freezed == lastAt ? _self.lastAt : lastAt // ignore: cast_nullable_to_non_nullable
as String?,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,tasksCreated: null == tasksCreated ? _self.tasksCreated : tasksCreated // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReflectionState].
extension ReflectionStatePatterns on ReflectionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReflectionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReflectionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReflectionState value)  $default,){
final _that = this;
switch (_that) {
case _ReflectionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReflectionState value)?  $default,){
final _that = this;
switch (_that) {
case _ReflectionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_reflection_at')  String? lastAt, @JsonKey(name: 'reflection_count')  int count, @JsonKey(name: 'reflection_tasks_created')  int tasksCreated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReflectionState() when $default != null:
return $default(_that.lastAt,_that.count,_that.tasksCreated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_reflection_at')  String? lastAt, @JsonKey(name: 'reflection_count')  int count, @JsonKey(name: 'reflection_tasks_created')  int tasksCreated)  $default,) {final _that = this;
switch (_that) {
case _ReflectionState():
return $default(_that.lastAt,_that.count,_that.tasksCreated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'last_reflection_at')  String? lastAt, @JsonKey(name: 'reflection_count')  int count, @JsonKey(name: 'reflection_tasks_created')  int tasksCreated)?  $default,) {final _that = this;
switch (_that) {
case _ReflectionState() when $default != null:
return $default(_that.lastAt,_that.count,_that.tasksCreated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReflectionState implements ReflectionState {
  const _ReflectionState({@JsonKey(name: 'last_reflection_at') this.lastAt, @JsonKey(name: 'reflection_count') this.count = 0, @JsonKey(name: 'reflection_tasks_created') this.tasksCreated = 0});
  factory _ReflectionState.fromJson(Map<String, dynamic> json) => _$ReflectionStateFromJson(json);

@override@JsonKey(name: 'last_reflection_at') final  String? lastAt;
@override@JsonKey(name: 'reflection_count') final  int count;
@override@JsonKey(name: 'reflection_tasks_created') final  int tasksCreated;

/// Create a copy of ReflectionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReflectionStateCopyWith<_ReflectionState> get copyWith => __$ReflectionStateCopyWithImpl<_ReflectionState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReflectionStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReflectionState&&(identical(other.lastAt, lastAt) || other.lastAt == lastAt)&&(identical(other.count, count) || other.count == count)&&(identical(other.tasksCreated, tasksCreated) || other.tasksCreated == tasksCreated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastAt,count,tasksCreated);

@override
String toString() {
  return 'ReflectionState(lastAt: $lastAt, count: $count, tasksCreated: $tasksCreated)';
}


}

/// @nodoc
abstract mixin class _$ReflectionStateCopyWith<$Res> implements $ReflectionStateCopyWith<$Res> {
  factory _$ReflectionStateCopyWith(_ReflectionState value, $Res Function(_ReflectionState) _then) = __$ReflectionStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'last_reflection_at') String? lastAt,@JsonKey(name: 'reflection_count') int count,@JsonKey(name: 'reflection_tasks_created') int tasksCreated
});




}
/// @nodoc
class __$ReflectionStateCopyWithImpl<$Res>
    implements _$ReflectionStateCopyWith<$Res> {
  __$ReflectionStateCopyWithImpl(this._self, this._then);

  final _ReflectionState _self;
  final $Res Function(_ReflectionState) _then;

/// Create a copy of ReflectionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastAt = freezed,Object? count = null,Object? tasksCreated = null,}) {
  return _then(_ReflectionState(
lastAt: freezed == lastAt ? _self.lastAt : lastAt // ignore: cast_nullable_to_non_nullable
as String?,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,tasksCreated: null == tasksCreated ? _self.tasksCreated : tasksCreated // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
