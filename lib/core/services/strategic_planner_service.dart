// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../policy/language_policy.dart';
import '../models/task.dart';
import '../models/task_draft.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

class StrategicPlannerService {
  StrategicPlannerService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<List<TaskDraft>> suggestTasks(
    String projectRoot, {
    int count = 5,
  }) async {
    final layout = ProjectLayout(projectRoot);
    if (!File(layout.visionPath).existsSync()) {
      return const [];
    }

    final visionContent = File(layout.visionPath).readAsStringSync();
    final taskStore = TaskStore(layout.tasksPath);
    final existingTasks = taskStore.readTasks();
    final taskList = existingTasks.map((t) => '- ${t.title}').join('\n');

    final prompt =
        '''
${LanguagePolicy.describe()}

Project Vision:
$visionContent

Current Backlog:
$taskList

Based on the vision and current backlog, suggest exactly $count next meaningful engineering tasks.
Focus on architectural stability, core features, and safety.

Requirements:
- Each task must be concrete, actionable, and small enough to complete in one cycle.
- Use this exact format per line:
  - [P1|P2|P3] [CORE|UI|SEC|DOCS|ARCH|QA|AGENT|REF] <task title> | AC: <acceptance criteria>
- Task titles must start with a verb and be 6-16 words.
- Acceptance criteria must be specific and testable (what must be true to accept).
- Do not repeat tasks already in the backlog.

Return ONLY the tasks as a bulleted list.
''';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final suggestions = _parseSuggestions(
      result.response.stdout,
      defaults: _defaultHints(visionContent),
    );

    RunLogStore(layout.runLogPath).append(
      event: 'strategic_planning_suggestions',
      message: 'Generated strategic task suggestions',
      data: {
        'root': projectRoot,
        'count': suggestions.length,
        'used_fallback': result.usedFallback,
      },
    );

    return suggestions;
  }

  /// Generates a complete initial backlog from VISION.md and optionally
  /// ARCHITECTURE.md. Used when TASKS.md is empty (no existing tasks).
  Future<List<TaskDraft>> generateInitialBacklog(
    String projectRoot, {
    int maxTasks = 20,
  }) async {
    final layout = ProjectLayout(projectRoot);
    if (!File(layout.visionPath).existsSync()) {
      return const [];
    }

    final visionContent = File(layout.visionPath).readAsStringSync();
    final architectureContent = _loadOptionalFile(layout.architecturePath);

    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln();
    buffer.writeln('## Project Vision');
    buffer.writeln(visionContent);

    if (architectureContent != null) {
      buffer.writeln();
      buffer.writeln('## Technical Architecture');
      buffer.writeln(architectureContent);
    }

    buffer.writeln();
    buffer.writeln('''
## Task

Create a complete, prioritized engineering backlog for this project from scratch.
There are no existing tasks — this is the initial planning phase.

Requirements:
- Generate up to $maxTasks tasks covering the full scope of the vision.
- Group tasks by phase: P1 CORE/SEC tasks first, then P2 features, then P3 polish.
- Each task must be concrete, actionable, and small enough to complete in one cycle.
- Use this exact format per line:
  - [P1|P2|P3] [CORE|UI|SEC|DOCS|ARCH|QA|AGENT|REF] <task title> | AC: <acceptance criteria>
- Task titles must start with a verb and be 6-16 words.
- Acceptance criteria must be specific and testable.
- Respect architectural module boundaries and dependency direction.

Return ONLY the tasks as a bulleted list.
''');

    final request = AgentRequest(
      prompt: buffer.toString(),
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final suggestions = _parseSuggestions(
      result.response.stdout,
      defaults: _defaultHints(visionContent),
    );

    RunLogStore(layout.runLogPath).append(
      event: 'initial_backlog_generated',
      message: 'Generated initial backlog from vision',
      data: {
        'root': projectRoot,
        'count': suggestions.length,
        'max_tasks': maxTasks,
        'has_architecture': architectureContent != null,
        'used_fallback': result.usedFallback,
      },
    );

    return suggestions;
  }

  String? _loadOptionalFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync().trim();
    return content.isEmpty ? null : content;
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(projectRoot, 'strategy');
    if (override != null) {
      return override;
    }
    return 'You are a senior product strategist and software architect. '
        'Your goal is to transform a high-level vision into concrete, '
        'incremental, and well-structured engineering tasks.';
  }

  List<TaskDraft> _parseSuggestions(
    String output, {
    required _PlannerDefaults defaults,
  }) {
    final lines = output.split('\n');
    final results = <TaskDraft>[];
    final seen = <String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          final draft = TaskDraft.parseLine(
            content,
            defaultPriority: defaults.priority,
            defaultCategory: defaults.category,
          );
          if (draft == null) {
            continue;
          }
          final normalized = draft.normalizedKey();
          if (normalized.isEmpty || seen.contains(normalized)) {
            continue;
          }
          seen.add(normalized);
          final withAcceptance = draft.acceptanceCriteria.trim().isEmpty
              ? draft.copyWith(
                  acceptanceCriteria: _defaultAcceptance(draft.title),
                )
              : draft;
          if (!_passesQuality(withAcceptance)) {
            continue;
          }
          results.add(withAcceptance.copyWith(source: 'strategic_planner'));
        }
      }
    }
    return results;
  }

  bool _passesQuality(TaskDraft draft) {
    final words = draft.title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final wordCount = words.length;
    if (wordCount < 3) {
      return false;
    }
    if (draft.title.length < 12) {
      return false;
    }
    if (draft.acceptanceCriteria.trim().length < 12) {
      return false;
    }
    return true;
  }

  String _defaultAcceptance(String title) {
    return 'The change for "$title" is implemented and verified by tests or manual check.';
  }

  _PlannerDefaults _defaultHints(String visionContent) {
    final lower = visionContent.toLowerCase();
    if (lower.contains('ui') || lower.contains('frontend')) {
      return _PlannerDefaults(
        priority: TaskPriority.p2,
        category: TaskCategory.ui,
      );
    }
    if (lower.contains('security') || lower.contains('auth')) {
      return _PlannerDefaults(
        priority: TaskPriority.p1,
        category: TaskCategory.security,
      );
    }
    return const _PlannerDefaults(
      priority: TaskPriority.p2,
      category: TaskCategory.core,
    );
  }
}

class _PlannerDefaults {
  const _PlannerDefaults({required this.priority, required this.category});

  final TaskPriority priority;
  final TaskCategory category;
}
