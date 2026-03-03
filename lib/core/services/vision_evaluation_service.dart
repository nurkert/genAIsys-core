// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../policy/language_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

class VisionEvaluationResult {
  const VisionEvaluationResult({
    required this.visionFulfilled,
    required this.completionEstimate,
    required this.coveredGoals,
    required this.uncoveredGoals,
    required this.suggestedNextSteps,
    required this.reasoning,
    required this.usedFallback,
  });

  final bool visionFulfilled;
  final double completionEstimate;
  final List<String> coveredGoals;
  final List<String> uncoveredGoals;
  final List<String> suggestedNextSteps;
  final String reasoning;
  final bool usedFallback;
}

class VisionEvaluationService {
  VisionEvaluationService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  /// Evaluates how well the current project state fulfills the vision.
  ///
  /// Returns null if VISION.md does not exist.
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    final layout = ProjectLayout(projectRoot);
    final visionFile = File(layout.visionPath);
    if (!visionFile.existsSync()) {
      return null;
    }
    final visionContent = visionFile.readAsStringSync().trim();
    if (visionContent.isEmpty) {
      return null;
    }

    final architectureContent = _loadOptionalFile(layout.architecturePath);
    final rulesContent = _loadOptionalFile(layout.rulesPath);
    final taskStore = TaskStore(layout.tasksPath);
    final tasks = taskStore.readTasks();
    final doneTasks = tasks
        .where((t) => t.completion.name == 'done')
        .map((t) => '- [x] ${t.title}')
        .join('\n');
    final openTasks = tasks
        .where((t) => t.completion.name == 'open')
        .map((t) => '- [ ] ${t.title}')
        .join('\n');

    final prompt = _buildPrompt(
      visionContent: visionContent,
      architectureContent: architectureContent,
      rulesContent: rulesContent,
      doneTasks: doneTasks,
      openTasks: openTasks,
    );

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final output = result.response.stdout.trim();

    if (output.isEmpty) {
      return null;
    }

    final parsed = _parseEvaluation(output);

    RunLogStore(layout.runLogPath).append(
      event: parsed.visionFulfilled
          ? 'vision_complete'
          : 'vision_evaluation_completed',
      message: parsed.visionFulfilled
          ? 'Vision evaluation: project is feature-complete'
          : 'Vision evaluation: gaps remain',
      data: {
        'root': projectRoot,
        'vision_fulfilled': parsed.visionFulfilled,
        'completion_estimate': parsed.completionEstimate,
        'covered_goals': parsed.coveredGoals.length,
        'uncovered_goals': parsed.uncoveredGoals.length,
        'suggested_next_steps': parsed.suggestedNextSteps.length,
        'used_fallback': result.usedFallback,
      },
    );

    return VisionEvaluationResult(
      visionFulfilled: parsed.visionFulfilled,
      completionEstimate: parsed.completionEstimate,
      coveredGoals: parsed.coveredGoals,
      uncoveredGoals: parsed.uncoveredGoals,
      suggestedNextSteps: parsed.suggestedNextSteps,
      reasoning: parsed.reasoning,
      usedFallback: result.usedFallback,
    );
  }

  String _buildPrompt({
    required String visionContent,
    String? architectureContent,
    String? rulesContent,
    required String doneTasks,
    required String openTasks,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln();
    buffer.writeln('## Project Vision');
    buffer.writeln(visionContent);

    if (architectureContent != null) {
      buffer.writeln();
      buffer.writeln('## Architecture');
      buffer.writeln(architectureContent);
    }

    if (rulesContent != null) {
      buffer.writeln();
      buffer.writeln('## Rules & Quality Standards');
      buffer.writeln(rulesContent);
    }

    buffer.writeln();
    buffer.writeln('## Completed Tasks');
    buffer.writeln(doneTasks.isEmpty ? '(none)' : doneTasks);
    buffer.writeln();
    buffer.writeln('## Open Tasks');
    buffer.writeln(openTasks.isEmpty ? '(none)' : openTasks);

    buffer.writeln();
    buffer.writeln('''
## Evaluation Task

Evaluate whether the project vision is fulfilled based on the completed and open tasks above.

Respond in this exact format:

FULFILLED: yes|no
COMPLETION: <0.0-1.0>
REASONING: <1-2 sentences explaining your assessment>

COVERED_GOALS:
- <goal that is covered by completed tasks>

UNCOVERED_GOALS:
- <goal from the vision that is NOT yet covered>

NEXT_STEPS:
- <concrete task suggestion if vision is not yet fulfilled>
''');

    return buffer.toString();
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadCodingPersona(
      projectRoot,
      'strategy',
    );
    if (override != null) {
      return override;
    }
    return 'You are a senior product evaluator. '
        'Assess project completion against its vision objectively. '
        'Be precise about what is covered and what gaps remain.';
  }

  VisionEvaluationResult _parseEvaluation(String output) {
    final lines = output.split('\n');
    var fulfilled = false;
    var completion = 0.0;
    var reasoning = '';
    final covered = <String>[];
    final uncovered = <String>[];
    final nextSteps = <String>[];

    var currentSection = '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('FULFILLED:')) {
        final value = trimmed.substring('FULFILLED:'.length).trim().toLowerCase();
        fulfilled = value == 'yes' || value == 'true';
      } else if (trimmed.startsWith('COMPLETION:')) {
        final value = trimmed.substring('COMPLETION:'.length).trim();
        completion = double.tryParse(value) ?? 0.0;
        if (completion < 0.0) completion = 0.0;
        if (completion > 1.0) completion = 1.0;
      } else if (trimmed.startsWith('REASONING:')) {
        reasoning = trimmed.substring('REASONING:'.length).trim();
      } else if (trimmed == 'COVERED_GOALS:') {
        currentSection = 'covered';
      } else if (trimmed == 'UNCOVERED_GOALS:') {
        currentSection = 'uncovered';
      } else if (trimmed == 'NEXT_STEPS:') {
        currentSection = 'next';
      } else if (trimmed.startsWith('- ')) {
        final item = trimmed.substring(2).trim();
        if (item.isNotEmpty) {
          switch (currentSection) {
            case 'covered':
              covered.add(item);
            case 'uncovered':
              uncovered.add(item);
            case 'next':
              nextSteps.add(item);
          }
        }
      }
    }

    return VisionEvaluationResult(
      visionFulfilled: fulfilled,
      completionEstimate: completion,
      coveredGoals: List.unmodifiable(covered),
      uncoveredGoals: List.unmodifiable(uncovered),
      suggestedNextSteps: List.unmodifiable(nextSteps),
      reasoning: reasoning,
      usedFallback: false,
    );
  }

  String? _loadOptionalFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync().trim();
    return content.isEmpty ? null : content;
  }
}
