// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subtask_execution_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SubtaskExecutionState {

@JsonKey(name: 'subtask_queue') List<String> get queue;@JsonKey(name: 'current_subtask') String? get current;@JsonKey(name: 'subtask_refinement_done') bool get refinementDone;@JsonKey(name: 'feasibility_check_done') bool get feasibilityCheckDone;@JsonKey(name: 'subtask_split_attempts') Map<String, int> get splitAttempts;
/// Create a copy of SubtaskExecutionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubtaskExecutionStateCopyWith<SubtaskExecutionState> get copyWith => _$SubtaskExecutionStateCopyWithImpl<SubtaskExecutionState>(this as SubtaskExecutionState, _$identity);

  /// Serializes this SubtaskExecutionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubtaskExecutionState&&const DeepCollectionEquality().equals(other.queue, queue)&&(identical(other.current, current) || other.current == current)&&(identical(other.refinementDone, refinementDone) || other.refinementDone == refinementDone)&&(identical(other.feasibilityCheckDone, feasibilityCheckDone) || other.feasibilityCheckDone == feasibilityCheckDone)&&const DeepCollectionEquality().equals(other.splitAttempts, splitAttempts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(queue),current,refinementDone,feasibilityCheckDone,const DeepCollectionEquality().hash(splitAttempts));

@override
String toString() {
  return 'SubtaskExecutionState(queue: $queue, current: $current, refinementDone: $refinementDone, feasibilityCheckDone: $feasibilityCheckDone, splitAttempts: $splitAttempts)';
}


}

/// @nodoc
abstract mixin class $SubtaskExecutionStateCopyWith<$Res>  {
  factory $SubtaskExecutionStateCopyWith(SubtaskExecutionState value, $Res Function(SubtaskExecutionState) _then) = _$SubtaskExecutionStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'subtask_queue') List<String> queue,@JsonKey(name: 'current_subtask') String? current,@JsonKey(name: 'subtask_refinement_done') bool refinementDone,@JsonKey(name: 'feasibility_check_done') bool feasibilityCheckDone,@JsonKey(name: 'subtask_split_attempts') Map<String, int> splitAttempts
});




}
/// @nodoc
class _$SubtaskExecutionStateCopyWithImpl<$Res>
    implements $SubtaskExecutionStateCopyWith<$Res> {
  _$SubtaskExecutionStateCopyWithImpl(this._self, this._then);

  final SubtaskExecutionState _self;
  final $Res Function(SubtaskExecutionState) _then;

/// Create a copy of SubtaskExecutionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? queue = null,Object? current = freezed,Object? refinementDone = null,Object? feasibilityCheckDone = null,Object? splitAttempts = null,}) {
  return _then(_self.copyWith(
queue: null == queue ? _self.queue : queue // ignore: cast_nullable_to_non_nullable
as List<String>,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,refinementDone: null == refinementDone ? _self.refinementDone : refinementDone // ignore: cast_nullable_to_non_nullable
as bool,feasibilityCheckDone: null == feasibilityCheckDone ? _self.feasibilityCheckDone : feasibilityCheckDone // ignore: cast_nullable_to_non_nullable
as bool,splitAttempts: null == splitAttempts ? _self.splitAttempts : splitAttempts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [SubtaskExecutionState].
extension SubtaskExecutionStatePatterns on SubtaskExecutionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubtaskExecutionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubtaskExecutionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubtaskExecutionState value)  $default,){
final _that = this;
switch (_that) {
case _SubtaskExecutionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubtaskExecutionState value)?  $default,){
final _that = this;
switch (_that) {
case _SubtaskExecutionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'subtask_queue')  List<String> queue, @JsonKey(name: 'current_subtask')  String? current, @JsonKey(name: 'subtask_refinement_done')  bool refinementDone, @JsonKey(name: 'feasibility_check_done')  bool feasibilityCheckDone, @JsonKey(name: 'subtask_split_attempts')  Map<String, int> splitAttempts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubtaskExecutionState() when $default != null:
return $default(_that.queue,_that.current,_that.refinementDone,_that.feasibilityCheckDone,_that.splitAttempts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'subtask_queue')  List<String> queue, @JsonKey(name: 'current_subtask')  String? current, @JsonKey(name: 'subtask_refinement_done')  bool refinementDone, @JsonKey(name: 'feasibility_check_done')  bool feasibilityCheckDone, @JsonKey(name: 'subtask_split_attempts')  Map<String, int> splitAttempts)  $default,) {final _that = this;
switch (_that) {
case _SubtaskExecutionState():
return $default(_that.queue,_that.current,_that.refinementDone,_that.feasibilityCheckDone,_that.splitAttempts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'subtask_queue')  List<String> queue, @JsonKey(name: 'current_subtask')  String? current, @JsonKey(name: 'subtask_refinement_done')  bool refinementDone, @JsonKey(name: 'feasibility_check_done')  bool feasibilityCheckDone, @JsonKey(name: 'subtask_split_attempts')  Map<String, int> splitAttempts)?  $default,) {final _that = this;
switch (_that) {
case _SubtaskExecutionState() when $default != null:
return $default(_that.queue,_that.current,_that.refinementDone,_that.feasibilityCheckDone,_that.splitAttempts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubtaskExecutionState implements SubtaskExecutionState {
  const _SubtaskExecutionState({@JsonKey(name: 'subtask_queue') final  List<String> queue = const [], @JsonKey(name: 'current_subtask') this.current, @JsonKey(name: 'subtask_refinement_done') this.refinementDone = false, @JsonKey(name: 'feasibility_check_done') this.feasibilityCheckDone = false, @JsonKey(name: 'subtask_split_attempts') final  Map<String, int> splitAttempts = const {}}): _queue = queue,_splitAttempts = splitAttempts;
  factory _SubtaskExecutionState.fromJson(Map<String, dynamic> json) => _$SubtaskExecutionStateFromJson(json);

 final  List<String> _queue;
@override@JsonKey(name: 'subtask_queue') List<String> get queue {
  if (_queue is EqualUnmodifiableListView) return _queue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_queue);
}

@override@JsonKey(name: 'current_subtask') final  String? current;
@override@JsonKey(name: 'subtask_refinement_done') final  bool refinementDone;
@override@JsonKey(name: 'feasibility_check_done') final  bool feasibilityCheckDone;
 final  Map<String, int> _splitAttempts;
@override@JsonKey(name: 'subtask_split_attempts') Map<String, int> get splitAttempts {
  if (_splitAttempts is EqualUnmodifiableMapView) return _splitAttempts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_splitAttempts);
}


/// Create a copy of SubtaskExecutionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubtaskExecutionStateCopyWith<_SubtaskExecutionState> get copyWith => __$SubtaskExecutionStateCopyWithImpl<_SubtaskExecutionState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubtaskExecutionStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubtaskExecutionState&&const DeepCollectionEquality().equals(other._queue, _queue)&&(identical(other.current, current) || other.current == current)&&(identical(other.refinementDone, refinementDone) || other.refinementDone == refinementDone)&&(identical(other.feasibilityCheckDone, feasibilityCheckDone) || other.feasibilityCheckDone == feasibilityCheckDone)&&const DeepCollectionEquality().equals(other._splitAttempts, _splitAttempts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_queue),current,refinementDone,feasibilityCheckDone,const DeepCollectionEquality().hash(_splitAttempts));

@override
String toString() {
  return 'SubtaskExecutionState(queue: $queue, current: $current, refinementDone: $refinementDone, feasibilityCheckDone: $feasibilityCheckDone, splitAttempts: $splitAttempts)';
}


}

/// @nodoc
abstract mixin class _$SubtaskExecutionStateCopyWith<$Res> implements $SubtaskExecutionStateCopyWith<$Res> {
  factory _$SubtaskExecutionStateCopyWith(_SubtaskExecutionState value, $Res Function(_SubtaskExecutionState) _then) = __$SubtaskExecutionStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'subtask_queue') List<String> queue,@JsonKey(name: 'current_subtask') String? current,@JsonKey(name: 'subtask_refinement_done') bool refinementDone,@JsonKey(name: 'feasibility_check_done') bool feasibilityCheckDone,@JsonKey(name: 'subtask_split_attempts') Map<String, int> splitAttempts
});




}
/// @nodoc
class __$SubtaskExecutionStateCopyWithImpl<$Res>
    implements _$SubtaskExecutionStateCopyWith<$Res> {
  __$SubtaskExecutionStateCopyWithImpl(this._self, this._then);

  final _SubtaskExecutionState _self;
  final $Res Function(_SubtaskExecutionState) _then;

/// Create a copy of SubtaskExecutionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? queue = null,Object? current = freezed,Object? refinementDone = null,Object? feasibilityCheckDone = null,Object? splitAttempts = null,}) {
  return _then(_SubtaskExecutionState(
queue: null == queue ? _self._queue : queue // ignore: cast_nullable_to_non_nullable
as List<String>,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,refinementDone: null == refinementDone ? _self.refinementDone : refinementDone // ignore: cast_nullable_to_non_nullable
as bool,feasibilityCheckDone: null == feasibilityCheckDone ? _self.feasibilityCheckDone : feasibilityCheckDone // ignore: cast_nullable_to_non_nullable
as bool,splitAttempts: null == splitAttempts ? _self._splitAttempts : splitAttempts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}

// dart format on
