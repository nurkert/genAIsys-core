// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'task_management/task_write_service.dart';

class MetaTaskSuggestion {
  MetaTaskSuggestion({
    required this.id,
    required this.title,
    required this.priority,
    required this.category,
    this.section = 'Backlog',
  });

  final String id;
  final String title;
  final TaskPriority priority;
  final TaskCategory category;
  final String section;
}

class MetaTaskResult {
  MetaTaskResult({
    required this.created,
    required this.skipped,
    required this.createdTitles,
    required this.skippedTitles,
  });

  final int created;
  final int skipped;
  final List<String> createdTitles;
  final List<String> skippedTitles;
}

class MetaTaskService {
  MetaTaskService({TaskWriteService? taskWriteService})
    : _taskWriteService = taskWriteService ?? TaskWriteService();

  final TaskWriteService _taskWriteService;

  MetaTaskResult ensureMetaTasks(String projectRoot, {List<String>? focusIds}) {
    final layout = ProjectLayout(projectRoot);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final existing = tasks.map((task) => _normalizeTitle(task.title)).toSet();

    final focusSet = focusIds
        ?.map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();

    final created = <String>[];
    final skipped = <String>[];

    for (final suggestion in _suggestions) {
      if (focusSet != null &&
          focusSet.isNotEmpty &&
          !focusSet.contains(suggestion.id)) {
        continue;
      }
      final normalized = _normalizeTitle(suggestion.title);
      if (existing.contains(normalized)) {
        skipped.add(suggestion.title);
        continue;
      }
      try {
        _taskWriteService.createTask(
          projectRoot,
          title: suggestion.title,
          priority: suggestion.priority,
          category: suggestion.category,
          section: suggestion.section,
        );
        created.add(suggestion.title);
        existing.add(normalized);
      } catch (_) {
        skipped.add(suggestion.title);
      }
    }

    if (layout.genaisysDir.isNotEmpty) {
      RunLogStore(layout.runLogPath).append(
        event: 'meta_tasks_generated',
        message: 'Meta tasks generated',
        data: {
          'root': projectRoot,
          'created': created.length,
          'skipped': skipped.length,
        },
      );
    }

    return MetaTaskResult(
      created: created.length,
      skipped: skipped.length,
      createdTitles: created,
      skippedTitles: skipped,
    );
  }
}

final List<MetaTaskSuggestion> _suggestions = [
  MetaTaskSuggestion(
    id: 'prompts-core',
    title:
        'Refine core agent system prompt | AC: Core prompt has clearer guardrails and examples.',
    priority: TaskPriority.p2,
    category: TaskCategory.agent,
  ),
  MetaTaskSuggestion(
    id: 'policies-safe-write',
    title:
        'Clarify safe-write policy and critical paths | AC: Docs list allowed roots and protected files.',
    priority: TaskPriority.p2,
    category: TaskCategory.security,
  ),
  MetaTaskSuggestion(
    id: 'tests-autopilot-regression',
    title:
        'Add regression test for autopilot no-diff handling | AC: New test fails before fix and passes after.',
    priority: TaskPriority.p1,
    category: TaskCategory.qa,
  ),
];

String _normalizeTitle(String title) {
  return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
