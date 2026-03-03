// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../ids/task_slugger.dart';
import '../models/workflow_stage.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';
import '../templates/task_spec_templates.dart';
import 'workflow_service.dart';

enum SpecKind { plan, spec, subtasks, subtaskRefinement }

class SpecInitResult {
  SpecInitResult({
    required this.path,
    required this.kind,
    required this.created,
  });

  final String path;
  final SpecKind kind;
  final bool created;
}

class SpecService {
  SpecInitResult initSpec(
    String projectRoot, {
    required SpecKind kind,
    bool overwrite = false,
  }) {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);

    final state = StateStore(layout.statePath).read();
    final activeTitle = state.activeTaskTitle;
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      throw StateError('No active task set. Use: activate');
    }

    Directory(layout.taskSpecsDir).createSync(recursive: true);
    final slug = TaskSlugger.slug(activeTitle);
    final filename = _filenameFor(kind, slug);
    final pathOut = _join(layout.taskSpecsDir, filename);
    final file = File(pathOut);
    if (file.existsSync() && !overwrite) {
      return SpecInitResult(path: pathOut, kind: kind, created: false);
    }

    final content = _templateFor(kind, activeTitle);
    file.writeAsStringSync(content);

    RunLogStore(layout.runLogPath).append(
      event: '${_kindLabel(kind)}_init',
      message: 'Initialized ${_kindLabel(kind)} file',
      data: {'root': projectRoot, 'task': activeTitle, 'file': pathOut},
    );

    _advanceWorkflowIfNeeded(projectRoot, kind: kind);

    return SpecInitResult(path: pathOut, kind: kind, created: true);
  }

  void _ensureStateFile(ProjectLayout layout) {
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
  }

  String _kindLabel(SpecKind kind) {
    switch (kind) {
      case SpecKind.plan:
        return 'plan';
      case SpecKind.spec:
        return 'spec';
      case SpecKind.subtasks:
        return 'subtasks';
      case SpecKind.subtaskRefinement:
        return 'subtask_refinement';
    }
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }

  void _advanceWorkflowIfNeeded(String projectRoot, {required SpecKind kind}) {
    if (kind == SpecKind.plan || kind == SpecKind.subtaskRefinement) {
      return;
    }
    final workflow = WorkflowService();
    final current = workflow.getStage(projectRoot);
    if (current == WorkflowStage.planning) {
      workflow.transition(projectRoot, WorkflowStage.execution);
    }
  }

  String _filenameFor(SpecKind kind, String slug) {
    switch (kind) {
      case SpecKind.plan:
        return '$slug-plan.md';
      case SpecKind.spec:
        return '$slug.md';
      case SpecKind.subtasks:
      case SpecKind.subtaskRefinement:
        return '$slug-subtasks.md';
    }
  }

  String _templateFor(SpecKind kind, String title) {
    switch (kind) {
      case SpecKind.plan:
        return TaskSpecTemplates.plan(title);
      case SpecKind.spec:
        return TaskSpecTemplates.spec(title);
      case SpecKind.subtasks:
      case SpecKind.subtaskRefinement:
        return TaskSpecTemplates.subtasks(title);
    }
  }
}
