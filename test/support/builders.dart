import 'dart:convert';
import 'dart:io';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';

/// Fluent builder for [Task] instances with sensible defaults.
///
/// Tests only need to specify the fields they care about:
/// ```dart
/// final task = TaskBuilder().withTitle('Add logging').asDone().build();
/// ```
class TaskBuilder {
  String _title = 'Test Task';
  TaskPriority _priority = TaskPriority.p1;
  TaskCategory _category = TaskCategory.core;
  TaskCompletion _completion = TaskCompletion.open;
  bool _blocked = false;
  String _section = 'Backlog';
  int _lineIndex = 0;

  TaskBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  TaskBuilder withPriority(TaskPriority priority) {
    _priority = priority;
    return this;
  }

  TaskBuilder withCategory(TaskCategory category) {
    _category = category;
    return this;
  }

  TaskBuilder asDone() {
    _completion = TaskCompletion.done;
    return this;
  }

  TaskBuilder asOpen() {
    _completion = TaskCompletion.open;
    return this;
  }

  TaskBuilder asBlocked({String? reason}) {
    _blocked = true;
    if (reason != null) {
      _title = '$_title [BLOCKED] (Reason: $reason)';
    }
    return this;
  }

  TaskBuilder inSection(String section) {
    _section = section;
    return this;
  }

  TaskBuilder atLine(int lineIndex) {
    _lineIndex = lineIndex;
    return this;
  }

  Task build() {
    return Task(
      title: _title,
      priority: _priority,
      category: _category,
      completion: _completion,
      blocked: _blocked,
      section: _section,
      lineIndex: _lineIndex,
    );
  }
}

/// Fluent builder for run-log JSON-line entries.
///
/// ```dart
/// final json = RunLogEntryBuilder()
///     .withEvent('review_approve')
///     .withData({'decision': 'approve'})
///     .buildJson();
/// ```
class RunLogEntryBuilder {
  String _event = 'test_event';
  String _timestamp = '2026-01-01T00:00:00Z';
  Map<String, Object?>? _data;

  RunLogEntryBuilder withEvent(String event) {
    _event = event;
    return this;
  }

  RunLogEntryBuilder withTimestamp(String timestamp) {
    _timestamp = timestamp;
    return this;
  }

  RunLogEntryBuilder withData(Map<String, Object?> data) {
    _data = data;
    return this;
  }

  Map<String, Object?> buildMap() {
    final payload = <String, Object?>{'timestamp': _timestamp, 'event': _event};
    if (_data != null) {
      payload['data'] = _data;
    }
    return payload;
  }

  String buildJson() => jsonEncode(buildMap());
}

/// Fluent builder for [ProjectState] instances.
///
/// Wraps [ProjectState.copyWith] with ergonomic helpers:
/// ```dart
/// final state = ProjectStateBuilder()
///     .withActiveTask('task-1', 'Fix bug')
///     .withWorkflowStage(WorkflowStage.execution)
///     .build();
/// ```
class ProjectStateBuilder {
  ProjectState _state = ProjectState(lastUpdated: '2026-01-01T00:00:00Z');

  ProjectStateBuilder withActiveTask(String id, String title) {
    _state = _state.copyWith(
      activeTask: _state.activeTask.copyWith(id: id, title: title),
    );
    return this;
  }

  ProjectStateBuilder withNoActiveTask() {
    _state = _state.copyWith(
      activeTask: _state.activeTask.copyWith(id: null, title: null),
    );
    return this;
  }

  ProjectStateBuilder withWorkflowStage(WorkflowStage stage) {
    _state = _state.copyWith(workflowStage: stage);
    return this;
  }

  ProjectStateBuilder withReview(String status, {String? updatedAt}) {
    _state = _state.copyWith(
      activeTask: _state.activeTask.copyWith(
        reviewStatus: status,
        reviewUpdatedAt: updatedAt ?? '2026-01-01T00:00:00Z',
      ),
    );
    return this;
  }

  ProjectStateBuilder withNoReview() {
    _state = _state.copyWith(
      activeTask: _state.activeTask.copyWith(
        reviewStatus: null,
        reviewUpdatedAt: null,
      ),
    );
    return this;
  }

  ProjectStateBuilder withCycleCount(int count) {
    _state = _state.copyWith(cycleCount: count);
    return this;
  }

  ProjectStateBuilder withRetryCounts(Map<String, int> counts) {
    _state = _state.copyWith(
      retryScheduling: _state.retryScheduling.copyWith(retryCounts: counts),
    );
    return this;
  }

  ProjectStateBuilder withCooldowns(Map<String, String> cooldowns) {
    _state = _state.copyWith(
      retryScheduling: _state.retryScheduling.copyWith(
        cooldownUntil: cooldowns,
      ),
    );
    return this;
  }

  ProjectStateBuilder withForensicState({
    bool attempted = false,
    String? guidance,
  }) {
    _state = _state.copyWith(
      activeTask: _state.activeTask.copyWith(
        forensicRecoveryAttempted: attempted,
        forensicGuidance: guidance,
      ),
    );
    return this;
  }

  ProjectStateBuilder withSubtask(String? current, {List<String>? queue}) {
    _state = _state.copyWith(
      subtaskExecution: _state.subtaskExecution.copyWith(
        current: current,
        queue: queue ?? _state.subtaskQueue,
      ),
    );
    return this;
  }

  ProjectStateBuilder withConsecutiveFailures(int count) {
    _state = _state.copyWith(
      autopilotRun: _state.autopilotRun.copyWith(consecutiveFailures: count),
    );
    return this;
  }

  ProjectStateBuilder withLastError({
    String? error,
    String? errorClass,
    String? errorKind,
  }) {
    _state = _state.copyWith(
      autopilotRun: _state.autopilotRun.copyWith(
        lastError: error,
        lastErrorClass: errorClass,
        lastErrorKind: errorKind,
      ),
    );
    return this;
  }

  ProjectStateBuilder withAutopilotRunning(bool running) {
    _state = _state.copyWith(
      autopilotRun: _state.autopilotRun.copyWith(running: running),
    );
    return this;
  }

  ProjectState build() => _state;
}

/// Fluent builder for [ProjectConfig] instances.
///
/// ```dart
/// final config = ProjectConfigBuilder()
///     .withReviewMaxRounds(1)
///     .withDiffBudget(files: 5, additions: 100, deletions: 50)
///     .build();
/// ```
class ProjectConfigBuilder {
  final Map<String, Object?> _overrides = {};

  ProjectConfigBuilder withGitBaseBranch(String branch) {
    _overrides['gitBaseBranch'] = branch;
    return this;
  }

  ProjectConfigBuilder withDiffBudget({
    int? files,
    int? additions,
    int? deletions,
  }) {
    if (files != null) _overrides['diffBudgetMaxFiles'] = files;
    if (additions != null) _overrides['diffBudgetMaxAdditions'] = additions;
    if (deletions != null) _overrides['diffBudgetMaxDeletions'] = deletions;
    return this;
  }

  ProjectConfigBuilder withReviewMaxRounds(int rounds) {
    _overrides['reviewMaxRounds'] = rounds;
    return this;
  }

  ProjectConfigBuilder withReviewFreshContext(bool fresh) {
    _overrides['reviewFreshContext'] = fresh;
    return this;
  }

  ProjectConfigBuilder withForensicRecoveryEnabled(bool enabled) {
    _overrides['pipelineForensicRecoveryEnabled'] = enabled;
    return this;
  }

  ProjectConfigBuilder withErrorPatternLearningEnabled(bool enabled) {
    _overrides['pipelineErrorPatternLearningEnabled'] = enabled;
    return this;
  }

  ProjectConfigBuilder withAutopilotMaxFailures(int max) {
    _overrides['autopilotMaxFailures'] = max;
    return this;
  }

  ProjectConfigBuilder withAutopilotMaxTaskRetries(int max) {
    _overrides['autopilotMaxTaskRetries'] = max;
    return this;
  }

  ProjectConfigBuilder withWorkflowAutoPush(bool push) {
    _overrides['workflowAutoPush'] = push;
    return this;
  }

  ProjectConfigBuilder withWorkflowAutoMerge(bool merge) {
    _overrides['workflowAutoMerge'] = merge;
    return this;
  }

  /// Build by constructing a [ProjectConfig] with overridden named parameters.
  ///
  /// Since [ProjectConfig] has many fields and no `copyWith`, we generate YAML
  /// and parse it. For tests that only need a few overrides, this is acceptable.
  ProjectConfig build() {
    return ProjectConfig(
      gitBaseBranch: _overrides['gitBaseBranch'] as String? ?? 'main',
      diffBudgetMaxFiles:
          _overrides['diffBudgetMaxFiles'] as int? ??
          ProjectConfig.defaultDiffBudgetMaxFiles,
      diffBudgetMaxAdditions:
          _overrides['diffBudgetMaxAdditions'] as int? ??
          ProjectConfig.defaultDiffBudgetMaxAdditions,
      diffBudgetMaxDeletions:
          _overrides['diffBudgetMaxDeletions'] as int? ??
          ProjectConfig.defaultDiffBudgetMaxDeletions,
      reviewMaxRounds:
          _overrides['reviewMaxRounds'] as int? ??
          ProjectConfig.defaultReviewMaxRounds,
      reviewFreshContext:
          _overrides['reviewFreshContext'] as bool? ??
          ProjectConfig.defaultReviewFreshContext,
      pipelineForensicRecoveryEnabled:
          _overrides['pipelineForensicRecoveryEnabled'] as bool? ??
          ProjectConfig.defaultPipelineForensicRecoveryEnabled,
      pipelineErrorPatternLearningEnabled:
          _overrides['pipelineErrorPatternLearningEnabled'] as bool? ??
          ProjectConfig.defaultPipelineErrorPatternLearningEnabled,
      autopilotMaxFailures:
          _overrides['autopilotMaxFailures'] as int? ??
          ProjectConfig.defaultAutopilotMaxFailures,
      autopilotMaxTaskRetries:
          _overrides['autopilotMaxTaskRetries'] as int? ??
          ProjectConfig.defaultAutopilotMaxTaskRetries,
      workflowAutoPush:
          _overrides['workflowAutoPush'] as bool? ??
          ProjectConfig.defaultWorkflowAutoPush,
      workflowAutoMerge:
          _overrides['workflowAutoMerge'] as bool? ??
          ProjectConfig.defaultWorkflowAutoMerge,
    );
  }
}

/// Creates a review evidence bundle in the audit directory.
///
/// DoneService requires a complete evidence bundle for markDone.
/// This builder creates the necessary file structure:
/// ```dart
/// ReviewEvidenceBundleBuilder(workspace.layout)
///     .withTaskId('task-1')
///     .withDecision('approve')
///     .write();
/// ```
class ReviewEvidenceBundleBuilder {
  ReviewEvidenceBundleBuilder(this._layout);

  final ProjectLayout _layout;
  String _taskId = 'test-task-0';
  String _taskTitle = 'Test Task';
  String? _subtask;
  String _decision = 'approve';
  String _timestamp = '2026-01-01T00:00:00Z';

  ReviewEvidenceBundleBuilder withTaskId(String id) {
    _taskId = id;
    return this;
  }

  ReviewEvidenceBundleBuilder withTaskTitle(String title) {
    _taskTitle = title;
    return this;
  }

  ReviewEvidenceBundleBuilder withSubtask(String? subtask) {
    _subtask = subtask;
    return this;
  }

  ReviewEvidenceBundleBuilder withDecision(String decision) {
    _decision = decision;
    return this;
  }

  ReviewEvidenceBundleBuilder withTimestamp(String timestamp) {
    _timestamp = timestamp;
    return this;
  }

  /// Write the evidence bundle to the audit directory.
  ///
  /// Creates the directory structure expected by DoneService evidence validation:
  /// `{auditDir}/{taskSlug}/{NNN_review}/summary.json`
  void write() {
    final slug = TaskSlugger.slug(_taskTitle);
    final taskAuditDir = Directory('${_layout.auditDir}/$slug');
    if (!taskAuditDir.existsSync()) {
      taskAuditDir.createSync(recursive: true);
    }

    // Find the next review index.
    final existing = taskAuditDir
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.endsWith('_review'))
        .length;
    final index = existing;
    final bundleDir = Directory(
      '${taskAuditDir.path}/${index.toString().padLeft(3, '0')}_review',
    );
    bundleDir.createSync(recursive: true);

    // Write summary.json with all fields required by DoneService validation.
    final summary = <String, Object?>{
      'timestamp': _timestamp,
      'kind': 'review',
      'decision': _decision,
      'task': _taskTitle,
      'task_id': _taskId,
      'subtask': _subtask,
      'test_summary': 'All tests pass (42 passed, 0 failed)',
      'files': {
        'diff_summary': 'diff_summary.txt',
        'diff_patch': 'diff_patch.txt',
      },
      'definition_of_done': {
        'implementation_completed': true,
        'tests_added_or_updated': true,
        'analyze_green': true,
        'relevant_tests_green': true,
        'runlog_status_checked_if_affected': true,
        'docs_updated_if_behavior_changed': true,
        'tasks_updated_same_slice': true,
      },
    };
    File(
      '${bundleDir.path}/summary.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

    // Write diff files.
    File(
      '${bundleDir.path}/diff_summary.txt',
    ).writeAsStringSync(' 1 file changed, 5 insertions(+), 2 deletions(-)');
    File('${bundleDir.path}/diff_patch.txt').writeAsStringSync(
      '--- a/lib/example.dart\n+++ b/lib/example.dart\n@@ -1,2 +1,5 @@\n+// Added\n',
    );
  }
}
