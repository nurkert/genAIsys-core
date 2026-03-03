// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../agents/agent_runner.dart';
import '../../ids/task_slugger.dart';
import '../../policy/language_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../templates/task_spec_templates.dart';
import '../agents/agent_service.dart';
import '../spec_service.dart';

class TaskRefinementArtifactResult {
  TaskRefinementArtifactResult({
    required this.kind,
    required this.path,
    required this.wrote,
    required this.usedFallback,
  });

  final SpecKind kind;
  final String path;
  final bool wrote;
  final bool usedFallback;
}

class TaskRefinementResult {
  TaskRefinementResult({
    required this.title,
    required this.artifacts,
    required this.usedFallback,
  });

  final String title;
  final List<TaskRefinementArtifactResult> artifacts;
  final bool usedFallback;
}

class TaskRefinementService {
  TaskRefinementService({AgentService? agentService})
    : _agentService = agentService ?? AgentService();

  final AgentService _agentService;

  Future<TaskRefinementResult> refine(
    String projectRoot, {
    required String title,
    bool overwrite = false,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Task title must not be empty.');
    }

    final layout = ProjectLayout(projectRoot);
    Directory(layout.taskSpecsDir).createSync(recursive: true);

    final slug = TaskSlugger.slug(normalizedTitle);
    final artifacts = <TaskRefinementArtifactResult>[];
    var usedFallback = false;

    for (final kind in SpecKind.values.where(
      (k) => k != SpecKind.subtaskRefinement,
    )) {
      final result = await _generateArtifact(
        projectRoot,
        layout,
        normalizedTitle,
        slug,
        kind,
        overwrite: overwrite,
      );
      artifacts.add(result);
      if (result.usedFallback) {
        usedFallback = true;
      }
    }

    return TaskRefinementResult(
      title: normalizedTitle,
      artifacts: artifacts,
      usedFallback: usedFallback,
    );
  }

  Future<TaskRefinementArtifactResult> _generateArtifact(
    String projectRoot,
    ProjectLayout layout,
    String title,
    String slug,
    SpecKind kind, {
    required bool overwrite,
  }) async {
    final filename = _filenameFor(kind, slug);
    final pathOut = _join(layout.taskSpecsDir, filename);
    final file = File(pathOut);

    if (file.existsSync() && !overwrite) {
      _appendLog(
        layout,
        event: 'draft_${_kindLabel(kind)}_skipped',
        message: 'Draft ${_kindLabel(kind)} exists',
        data: {'root': projectRoot, 'task': title, 'file': pathOut},
      );
      return TaskRefinementArtifactResult(
        kind: kind,
        path: pathOut,
        wrote: false,
        usedFallback: false,
      );
    }

    final request = AgentRequest(
      prompt: _buildPrompt(kind, title),
      systemPrompt: _systemPrompt(kind),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final output = result.response.stdout.trim();

    if (output.isEmpty) {
      file.writeAsStringSync(_templateFor(kind, title));
    } else {
      LanguagePolicy.enforceEnglish(
        output,
        context: '${_kindLabel(kind)} spec',
      );
      file.writeAsStringSync(output);
    }

    _appendLog(
      layout,
      event: 'draft_${_kindLabel(kind)}_generated',
      message: 'Generated ${_kindLabel(kind)} draft via agent',
      data: {
        'root': projectRoot,
        'task': title,
        'file': pathOut,
        'used_fallback': result.usedFallback,
        'exit_code': result.response.exitCode,
      },
    );

    return TaskRefinementArtifactResult(
      kind: kind,
      path: pathOut,
      wrote: true,
      usedFallback: result.usedFallback,
    );
  }

  String _buildPrompt(SpecKind kind, String title) {
    switch (kind) {
      case SpecKind.plan:
        return '${LanguagePolicy.describe()}\n\n'
            'Write a concise task plan in English for: "$title".\n'
            'Follow this template:\n\n'
            '${TaskSpecTemplates.plan(title)}\n'
            'Return only markdown.';
      case SpecKind.spec:
        return '${LanguagePolicy.describe()}\n\n'
            'Write a task spec in English for: "$title".\n'
            'Follow this template:\n\n'
            '${TaskSpecTemplates.spec(title)}\n'
            'Return only markdown.';
      case SpecKind.subtasks:
      case SpecKind.subtaskRefinement:
        return '${LanguagePolicy.describe()}\n\n'
            'Write 3-7 subtasks in English for: "$title".\n'
            'Follow this template:\n\n'
            '${TaskSpecTemplates.subtasks(title)}\n'
            'Return only markdown.';
    }
  }

  String _systemPrompt(SpecKind kind) {
    switch (kind) {
      case SpecKind.plan:
        return 'You are a senior planning agent. Produce clear, incremental, '
            'execution-ready plans with maintainability in mind.';
      case SpecKind.spec:
        return 'You are a senior specification agent. Be precise, practical, '
            'and explicit about constraints, tests, and acceptance.';
      case SpecKind.subtasks:
      case SpecKind.subtaskRefinement:
        return 'You are a senior task decomposition agent. Keep subtasks '
            'atomic, dependency-aware, and verifiable.';
    }
  }

  String _kindLabel(SpecKind kind) {
    switch (kind) {
      case SpecKind.plan:
        return 'plan';
      case SpecKind.spec:
        return 'spec';
      case SpecKind.subtasks:
      case SpecKind.subtaskRefinement:
        return 'subtasks';
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

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }

  void _appendLog(
    ProjectLayout layout, {
    required String event,
    String? message,
    Map<String, Object?>? data,
  }) {
    RunLogStore(
      layout.runLogPath,
    ).append(event: event, message: message, data: data);
  }
}
