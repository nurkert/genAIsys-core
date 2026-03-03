// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectState {

// Top-level fields (remain at root).
 int get version; String get lastUpdated; int get cycleCount; WorkflowStage get workflowStage;// Sub-model partitions.
 ActiveTaskState get activeTask; RetrySchedulingState get retryScheduling; SubtaskExecutionState get subtaskExecution; AutopilotRunState get autopilotRun; SupervisorState get supervisor; ReflectionState get reflection;
/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectStateCopyWith<ProjectState> get copyWith => _$ProjectStateCopyWithImpl<ProjectState>(this as ProjectState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectState&&(identical(other.version, version) || other.version == version)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.cycleCount, cycleCount) || other.cycleCount == cycleCount)&&(identical(other.workflowStage, workflowStage) || other.workflowStage == workflowStage)&&(identical(other.activeTask, activeTask) || other.activeTask == activeTask)&&(identical(other.retryScheduling, retryScheduling) || other.retryScheduling == retryScheduling)&&(identical(other.subtaskExecution, subtaskExecution) || other.subtaskExecution == subtaskExecution)&&(identical(other.autopilotRun, autopilotRun) || other.autopilotRun == autopilotRun)&&(identical(other.supervisor, supervisor) || other.supervisor == supervisor)&&(identical(other.reflection, reflection) || other.reflection == reflection));
}


@override
int get hashCode => Object.hash(runtimeType,version,lastUpdated,cycleCount,workflowStage,activeTask,retryScheduling,subtaskExecution,autopilotRun,supervisor,reflection);

@override
String toString() {
  return 'ProjectState(version: $version, lastUpdated: $lastUpdated, cycleCount: $cycleCount, workflowStage: $workflowStage, activeTask: $activeTask, retryScheduling: $retryScheduling, subtaskExecution: $subtaskExecution, autopilotRun: $autopilotRun, supervisor: $supervisor, reflection: $reflection)';
}


}

/// @nodoc
abstract mixin class $ProjectStateCopyWith<$Res>  {
  factory $ProjectStateCopyWith(ProjectState value, $Res Function(ProjectState) _then) = _$ProjectStateCopyWithImpl;
@useResult
$Res call({
 int version, String lastUpdated, int cycleCount, WorkflowStage workflowStage, ActiveTaskState activeTask, RetrySchedulingState retryScheduling, SubtaskExecutionState subtaskExecution, AutopilotRunState autopilotRun, SupervisorState supervisor, ReflectionState reflection
});


$ActiveTaskStateCopyWith<$Res> get activeTask;$RetrySchedulingStateCopyWith<$Res> get retryScheduling;$SubtaskExecutionStateCopyWith<$Res> get subtaskExecution;$AutopilotRunStateCopyWith<$Res> get autopilotRun;$SupervisorStateCopyWith<$Res> get supervisor;$ReflectionStateCopyWith<$Res> get reflection;

}
/// @nodoc
class _$ProjectStateCopyWithImpl<$Res>
    implements $ProjectStateCopyWith<$Res> {
  _$ProjectStateCopyWithImpl(this._self, this._then);

  final ProjectState _self;
  final $Res Function(ProjectState) _then;

/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? lastUpdated = null,Object? cycleCount = null,Object? workflowStage = null,Object? activeTask = null,Object? retryScheduling = null,Object? subtaskExecution = null,Object? autopilotRun = null,Object? supervisor = null,Object? reflection = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as String,cycleCount: null == cycleCount ? _self.cycleCount : cycleCount // ignore: cast_nullable_to_non_nullable
as int,workflowStage: null == workflowStage ? _self.workflowStage : workflowStage // ignore: cast_nullable_to_non_nullable
as WorkflowStage,activeTask: null == activeTask ? _self.activeTask : activeTask // ignore: cast_nullable_to_non_nullable
as ActiveTaskState,retryScheduling: null == retryScheduling ? _self.retryScheduling : retryScheduling // ignore: cast_nullable_to_non_nullable
as RetrySchedulingState,subtaskExecution: null == subtaskExecution ? _self.subtaskExecution : subtaskExecution // ignore: cast_nullable_to_non_nullable
as SubtaskExecutionState,autopilotRun: null == autopilotRun ? _self.autopilotRun : autopilotRun // ignore: cast_nullable_to_non_nullable
as AutopilotRunState,supervisor: null == supervisor ? _self.supervisor : supervisor // ignore: cast_nullable_to_non_nullable
as SupervisorState,reflection: null == reflection ? _self.reflection : reflection // ignore: cast_nullable_to_non_nullable
as ReflectionState,
  ));
}
/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActiveTaskStateCopyWith<$Res> get activeTask {
  
  return $ActiveTaskStateCopyWith<$Res>(_self.activeTask, (value) {
    return _then(_self.copyWith(activeTask: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetrySchedulingStateCopyWith<$Res> get retryScheduling {
  
  return $RetrySchedulingStateCopyWith<$Res>(_self.retryScheduling, (value) {
    return _then(_self.copyWith(retryScheduling: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubtaskExecutionStateCopyWith<$Res> get subtaskExecution {
  
  return $SubtaskExecutionStateCopyWith<$Res>(_self.subtaskExecution, (value) {
    return _then(_self.copyWith(subtaskExecution: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutopilotRunStateCopyWith<$Res> get autopilotRun {
  
  return $AutopilotRunStateCopyWith<$Res>(_self.autopilotRun, (value) {
    return _then(_self.copyWith(autopilotRun: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupervisorStateCopyWith<$Res> get supervisor {
  
  return $SupervisorStateCopyWith<$Res>(_self.supervisor, (value) {
    return _then(_self.copyWith(supervisor: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionStateCopyWith<$Res> get reflection {
  
  return $ReflectionStateCopyWith<$Res>(_self.reflection, (value) {
    return _then(_self.copyWith(reflection: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectState].
extension ProjectStatePatterns on ProjectState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectState value)  $default,){
final _that = this;
switch (_that) {
case _ProjectState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectState value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String lastUpdated,  int cycleCount,  WorkflowStage workflowStage,  ActiveTaskState activeTask,  RetrySchedulingState retryScheduling,  SubtaskExecutionState subtaskExecution,  AutopilotRunState autopilotRun,  SupervisorState supervisor,  ReflectionState reflection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectState() when $default != null:
return $default(_that.version,_that.lastUpdated,_that.cycleCount,_that.workflowStage,_that.activeTask,_that.retryScheduling,_that.subtaskExecution,_that.autopilotRun,_that.supervisor,_that.reflection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String lastUpdated,  int cycleCount,  WorkflowStage workflowStage,  ActiveTaskState activeTask,  RetrySchedulingState retryScheduling,  SubtaskExecutionState subtaskExecution,  AutopilotRunState autopilotRun,  SupervisorState supervisor,  ReflectionState reflection)  $default,) {final _that = this;
switch (_that) {
case _ProjectState():
return $default(_that.version,_that.lastUpdated,_that.cycleCount,_that.workflowStage,_that.activeTask,_that.retryScheduling,_that.subtaskExecution,_that.autopilotRun,_that.supervisor,_that.reflection);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String lastUpdated,  int cycleCount,  WorkflowStage workflowStage,  ActiveTaskState activeTask,  RetrySchedulingState retryScheduling,  SubtaskExecutionState subtaskExecution,  AutopilotRunState autopilotRun,  SupervisorState supervisor,  ReflectionState reflection)?  $default,) {final _that = this;
switch (_that) {
case _ProjectState() when $default != null:
return $default(_that.version,_that.lastUpdated,_that.cycleCount,_that.workflowStage,_that.activeTask,_that.retryScheduling,_that.subtaskExecution,_that.autopilotRun,_that.supervisor,_that.reflection);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectState extends ProjectState {
  const _ProjectState({this.version = 1, required this.lastUpdated, this.cycleCount = 0, this.workflowStage = WorkflowStage.idle, this.activeTask = const ActiveTaskState(), this.retryScheduling = const RetrySchedulingState(), this.subtaskExecution = const SubtaskExecutionState(), this.autopilotRun = const AutopilotRunState(), this.supervisor = const SupervisorState(), this.reflection = const ReflectionState()}): super._();
  

// Top-level fields (remain at root).
@override@JsonKey() final  int version;
@override final  String lastUpdated;
@override@JsonKey() final  int cycleCount;
@override@JsonKey() final  WorkflowStage workflowStage;
// Sub-model partitions.
@override@JsonKey() final  ActiveTaskState activeTask;
@override@JsonKey() final  RetrySchedulingState retryScheduling;
@override@JsonKey() final  SubtaskExecutionState subtaskExecution;
@override@JsonKey() final  AutopilotRunState autopilotRun;
@override@JsonKey() final  SupervisorState supervisor;
@override@JsonKey() final  ReflectionState reflection;

/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectStateCopyWith<_ProjectState> get copyWith => __$ProjectStateCopyWithImpl<_ProjectState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectState&&(identical(other.version, version) || other.version == version)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.cycleCount, cycleCount) || other.cycleCount == cycleCount)&&(identical(other.workflowStage, workflowStage) || other.workflowStage == workflowStage)&&(identical(other.activeTask, activeTask) || other.activeTask == activeTask)&&(identical(other.retryScheduling, retryScheduling) || other.retryScheduling == retryScheduling)&&(identical(other.subtaskExecution, subtaskExecution) || other.subtaskExecution == subtaskExecution)&&(identical(other.autopilotRun, autopilotRun) || other.autopilotRun == autopilotRun)&&(identical(other.supervisor, supervisor) || other.supervisor == supervisor)&&(identical(other.reflection, reflection) || other.reflection == reflection));
}


@override
int get hashCode => Object.hash(runtimeType,version,lastUpdated,cycleCount,workflowStage,activeTask,retryScheduling,subtaskExecution,autopilotRun,supervisor,reflection);

@override
String toString() {
  return 'ProjectState(version: $version, lastUpdated: $lastUpdated, cycleCount: $cycleCount, workflowStage: $workflowStage, activeTask: $activeTask, retryScheduling: $retryScheduling, subtaskExecution: $subtaskExecution, autopilotRun: $autopilotRun, supervisor: $supervisor, reflection: $reflection)';
}


}

/// @nodoc
abstract mixin class _$ProjectStateCopyWith<$Res> implements $ProjectStateCopyWith<$Res> {
  factory _$ProjectStateCopyWith(_ProjectState value, $Res Function(_ProjectState) _then) = __$ProjectStateCopyWithImpl;
@override @useResult
$Res call({
 int version, String lastUpdated, int cycleCount, WorkflowStage workflowStage, ActiveTaskState activeTask, RetrySchedulingState retryScheduling, SubtaskExecutionState subtaskExecution, AutopilotRunState autopilotRun, SupervisorState supervisor, ReflectionState reflection
});


@override $ActiveTaskStateCopyWith<$Res> get activeTask;@override $RetrySchedulingStateCopyWith<$Res> get retryScheduling;@override $SubtaskExecutionStateCopyWith<$Res> get subtaskExecution;@override $AutopilotRunStateCopyWith<$Res> get autopilotRun;@override $SupervisorStateCopyWith<$Res> get supervisor;@override $ReflectionStateCopyWith<$Res> get reflection;

}
/// @nodoc
class __$ProjectStateCopyWithImpl<$Res>
    implements _$ProjectStateCopyWith<$Res> {
  __$ProjectStateCopyWithImpl(this._self, this._then);

  final _ProjectState _self;
  final $Res Function(_ProjectState) _then;

/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? lastUpdated = null,Object? cycleCount = null,Object? workflowStage = null,Object? activeTask = null,Object? retryScheduling = null,Object? subtaskExecution = null,Object? autopilotRun = null,Object? supervisor = null,Object? reflection = null,}) {
  return _then(_ProjectState(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as String,cycleCount: null == cycleCount ? _self.cycleCount : cycleCount // ignore: cast_nullable_to_non_nullable
as int,workflowStage: null == workflowStage ? _self.workflowStage : workflowStage // ignore: cast_nullable_to_non_nullable
as WorkflowStage,activeTask: null == activeTask ? _self.activeTask : activeTask // ignore: cast_nullable_to_non_nullable
as ActiveTaskState,retryScheduling: null == retryScheduling ? _self.retryScheduling : retryScheduling // ignore: cast_nullable_to_non_nullable
as RetrySchedulingState,subtaskExecution: null == subtaskExecution ? _self.subtaskExecution : subtaskExecution // ignore: cast_nullable_to_non_nullable
as SubtaskExecutionState,autopilotRun: null == autopilotRun ? _self.autopilotRun : autopilotRun // ignore: cast_nullable_to_non_nullable
as AutopilotRunState,supervisor: null == supervisor ? _self.supervisor : supervisor // ignore: cast_nullable_to_non_nullable
as SupervisorState,reflection: null == reflection ? _self.reflection : reflection // ignore: cast_nullable_to_non_nullable
as ReflectionState,
  ));
}

/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActiveTaskStateCopyWith<$Res> get activeTask {
  
  return $ActiveTaskStateCopyWith<$Res>(_self.activeTask, (value) {
    return _then(_self.copyWith(activeTask: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetrySchedulingStateCopyWith<$Res> get retryScheduling {
  
  return $RetrySchedulingStateCopyWith<$Res>(_self.retryScheduling, (value) {
    return _then(_self.copyWith(retryScheduling: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubtaskExecutionStateCopyWith<$Res> get subtaskExecution {
  
  return $SubtaskExecutionStateCopyWith<$Res>(_self.subtaskExecution, (value) {
    return _then(_self.copyWith(subtaskExecution: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutopilotRunStateCopyWith<$Res> get autopilotRun {
  
  return $AutopilotRunStateCopyWith<$Res>(_self.autopilotRun, (value) {
    return _then(_self.copyWith(autopilotRun: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupervisorStateCopyWith<$Res> get supervisor {
  
  return $SupervisorStateCopyWith<$Res>(_self.supervisor, (value) {
    return _then(_self.copyWith(supervisor: value));
  });
}/// Create a copy of ProjectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionStateCopyWith<$Res> get reflection {
  
  return $ReflectionStateCopyWith<$Res>(_self.reflection, (value) {
    return _then(_self.copyWith(reflection: value));
  });
}
}

// dart format on
