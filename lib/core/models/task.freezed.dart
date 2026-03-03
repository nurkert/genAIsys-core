// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Task {

 String get title; TaskPriority get priority; TaskCategory get category; TaskCompletion get completion; bool get blocked; String get section; int get lineIndex; List<String> get dependencyRefs;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.title, title) || other.title == title)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.category, category) || other.category == category)&&(identical(other.completion, completion) || other.completion == completion)&&(identical(other.blocked, blocked) || other.blocked == blocked)&&(identical(other.section, section) || other.section == section)&&(identical(other.lineIndex, lineIndex) || other.lineIndex == lineIndex)&&const DeepCollectionEquality().equals(other.dependencyRefs, dependencyRefs));
}


@override
int get hashCode => Object.hash(runtimeType,title,priority,category,completion,blocked,section,lineIndex,const DeepCollectionEquality().hash(dependencyRefs));

@override
String toString() {
  return 'Task(title: $title, priority: $priority, category: $category, completion: $completion, blocked: $blocked, section: $section, lineIndex: $lineIndex, dependencyRefs: $dependencyRefs)';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String title, TaskPriority priority, TaskCategory category, TaskCompletion completion, bool blocked, String section, int lineIndex, List<String> dependencyRefs
});




}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? priority = null,Object? category = null,Object? completion = null,Object? blocked = null,Object? section = null,Object? lineIndex = null,Object? dependencyRefs = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TaskCategory,completion: null == completion ? _self.completion : completion // ignore: cast_nullable_to_non_nullable
as TaskCompletion,blocked: null == blocked ? _self.blocked : blocked // ignore: cast_nullable_to_non_nullable
as bool,section: null == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String,lineIndex: null == lineIndex ? _self.lineIndex : lineIndex // ignore: cast_nullable_to_non_nullable
as int,dependencyRefs: null == dependencyRefs ? _self.dependencyRefs : dependencyRefs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  TaskPriority priority,  TaskCategory category,  TaskCompletion completion,  bool blocked,  String section,  int lineIndex,  List<String> dependencyRefs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.title,_that.priority,_that.category,_that.completion,_that.blocked,_that.section,_that.lineIndex,_that.dependencyRefs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  TaskPriority priority,  TaskCategory category,  TaskCompletion completion,  bool blocked,  String section,  int lineIndex,  List<String> dependencyRefs)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.title,_that.priority,_that.category,_that.completion,_that.blocked,_that.section,_that.lineIndex,_that.dependencyRefs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  TaskPriority priority,  TaskCategory category,  TaskCompletion completion,  bool blocked,  String section,  int lineIndex,  List<String> dependencyRefs)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.title,_that.priority,_that.category,_that.completion,_that.blocked,_that.section,_that.lineIndex,_that.dependencyRefs);case _:
  return null;

}
}

}

/// @nodoc


class _Task extends Task {
  const _Task({required this.title, required this.priority, required this.category, required this.completion, this.blocked = false, required this.section, required this.lineIndex, final  List<String> dependencyRefs = const <String>[]}): _dependencyRefs = dependencyRefs,super._();
  

@override final  String title;
@override final  TaskPriority priority;
@override final  TaskCategory category;
@override final  TaskCompletion completion;
@override@JsonKey() final  bool blocked;
@override final  String section;
@override final  int lineIndex;
 final  List<String> _dependencyRefs;
@override@JsonKey() List<String> get dependencyRefs {
  if (_dependencyRefs is EqualUnmodifiableListView) return _dependencyRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencyRefs);
}


/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.title, title) || other.title == title)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.category, category) || other.category == category)&&(identical(other.completion, completion) || other.completion == completion)&&(identical(other.blocked, blocked) || other.blocked == blocked)&&(identical(other.section, section) || other.section == section)&&(identical(other.lineIndex, lineIndex) || other.lineIndex == lineIndex)&&const DeepCollectionEquality().equals(other._dependencyRefs, _dependencyRefs));
}


@override
int get hashCode => Object.hash(runtimeType,title,priority,category,completion,blocked,section,lineIndex,const DeepCollectionEquality().hash(_dependencyRefs));

@override
String toString() {
  return 'Task(title: $title, priority: $priority, category: $category, completion: $completion, blocked: $blocked, section: $section, lineIndex: $lineIndex, dependencyRefs: $dependencyRefs)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String title, TaskPriority priority, TaskCategory category, TaskCompletion completion, bool blocked, String section, int lineIndex, List<String> dependencyRefs
});




}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? priority = null,Object? category = null,Object? completion = null,Object? blocked = null,Object? section = null,Object? lineIndex = null,Object? dependencyRefs = null,}) {
  return _then(_Task(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TaskCategory,completion: null == completion ? _self.completion : completion // ignore: cast_nullable_to_non_nullable
as TaskCompletion,blocked: null == blocked ? _self.blocked : blocked // ignore: cast_nullable_to_non_nullable
as bool,section: null == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String,lineIndex: null == lineIndex ? _self.lineIndex : lineIndex // ignore: cast_nullable_to_non_nullable
as int,dependencyRefs: null == dependencyRefs ? _self._dependencyRefs : dependencyRefs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
