// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_error_hints.dart';
import '../../agents/agent_runner.dart';
import '../../models/project_state.dart';
import '../../policy/language_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../../templates/task_spec_templates.dart';
import 'agent_service.dart';
import '../spec_service.dart';

class SpecAgentResult {
  SpecAgentResult({
    required this.path,
    required this.kind,
    required this.wrote,
    required this.usedFallback,
    required this.response,
  });

  final String path;
  final SpecKind kind;
  final bool wrote;
  final bool usedFallback;
  final AgentResponse? response;
}

class FeasibilityCheckResult {
  const FeasibilityCheckResult({
    required this.feasible,
    this.explanation,
    this.regenerated = false,
    this.skipped = false,
  });

  final bool feasible;
  final String? explanation;
  final bool regenerated;
  final bool skipped;
}

class AcSelfCheckResult {
  const AcSelfCheckResult({
    required this.passed,
    this.reason,
    this.skipped = false,
  });

  final bool passed;
  final String? reason;
  final bool skipped;
}

class SpecAgentService {
  SpecAgentService({AgentService? agentService})
    : _agentService = agentService ?? AgentService();

  final AgentService _agentService;

  Future<SpecAgentResult> generate(
    String projectRoot, {
    required SpecKind kind,
    bool overwrite = false,
    String? guidanceContext,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);

    final state = StateStore(layout.statePath).read();
    final activeTitle = state.activeTaskTitle;
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      throw StateError('No active task set. Use: activate');
    }

    final initResult = SpecService().initSpec(
      projectRoot,
      kind: kind,
      overwrite: overwrite,
    );

    if (!initResult.created && !overwrite) {
      return SpecAgentResult(
        path: initResult.path,
        kind: kind,
        wrote: false,
        usedFallback: false,
        response: null,
      );
    }

    var prompt = _buildPrompt(kind, activeTitle);
    // Inject forensic guidance so the spec agent can adjust based on
    // previous failure analysis (e.g., decompose into smaller subtasks).
    final guidance = guidanceContext?.trim();
    if (guidance != null && guidance.isNotEmpty) {
      prompt =
          '$prompt\n\n### FORENSIC GUIDANCE (from automated failure analysis)\n'
          '$guidance\n\n'
          'Apply this guidance when generating the ${_kindLabel(kind)}.';
    }
    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(kind),
      workingDirectory: projectRoot,
    );
    RunLogStore(layout.runLogPath).append(
      event: '${_kindLabel(kind)}_generation_start',
      message: 'Starting ${_kindLabel(kind)} generation via agent',
      data: {'root': projectRoot, 'task': activeTitle, 'file': initResult.path},
    );
    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      if (result.response.exitCode == _timeoutExitCode) {
        throw TimeoutException('${_kindLabel(kind)} agent timed out.');
      }
      final stderr = result.response.stderr.trim();
      final stdout = result.response.stdout.trim();
      final detail = stderr.isNotEmpty ? stderr : stdout;
      final hint = detail.toLowerCase().contains('hint:')
          ? ''
          : AgentErrorHints.hintForExitCode(
              result.response.exitCode,
              detail: detail,
            );
      final message = StringBuffer()
        ..writeln(
          '${_kindLabel(kind)} agent failed with exit_code '
          '${result.response.exitCode}.',
        );
      if (detail.isNotEmpty) {
        message.writeln('Details: ${_truncate(detail, 600)}');
      }
      if (hint.isNotEmpty) {
        message.writeln(hint);
      }
      throw StateError(message.toString().trim());
    }

    LanguagePolicy.enforceEnglish(
      result.response.stdout,
      context: '${_kindLabel(kind)} spec',
    );
    File(initResult.path).writeAsStringSync(result.response.stdout);

    if (kind == SpecKind.subtasks) {
      _updateSubtaskQueue(layout, result.response.stdout);
    }

    RunLogStore(layout.runLogPath).append(
      event: '${_kindLabel(kind)}_generated',
      message: 'Generated ${_kindLabel(kind)} via agent',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'file': initResult.path,
        'used_fallback': result.usedFallback,
        'exit_code': result.response.exitCode,
      },
    );

    return SpecAgentResult(
      path: initResult.path,
      kind: kind,
      wrote: true,
      usedFallback: result.usedFallback,
      response: result.response,
    );
  }

  /// Feature 1a: Proactively assess and split oversized subtasks before coding.
  ///
  /// Calls the agent with a complexity-review prompt. If the agent returns
  /// `REFINED: NO_CHANGES_NEEDED`, marks [refinementDone] and logs a skip.
  /// Otherwise parses the revised list and updates the queue (without clearing
  /// other guards), then marks [refinementDone].
  Future<void> maybeRefineSubtasks(
    String projectRoot, {
    String? stepId,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final store = StateStore(layout.statePath);
    var state = store.read();

    // Guard: already refined this queue.
    if (state.subtaskExecution.refinementDone) {
      RunLogStore(layout.runLogPath).append(
        event: 'subtask_refinement_skipped',
        message: 'Subtask refinement already done for current queue',
        data: {
          'root': projectRoot,
          'step_id': ?stepId,
        },
      );
      return;
    }

    final queue = state.subtaskExecution.queue;
    // Guard: nothing to refine.
    if (queue.isEmpty) {
      RunLogStore(layout.runLogPath).append(
        event: 'subtask_refinement_skipped',
        message: 'Subtask refinement skipped: queue is empty',
        data: {
          'root': projectRoot,
          'step_id': ?stepId,
        },
      );
      return;
    }

    final activeTitle = state.activeTaskTitle ?? '';
    final prompt =
        '${LanguagePolicy.describe()}\n\n'
        '${TaskSpecTemplates.subtaskComplexityReview(activeTitle, queue)}';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(SpecKind.subtaskRefinement),
      workingDirectory: projectRoot,
    );

    RunLogStore(layout.runLogPath).append(
      event: 'subtask_refinement_start',
      message: 'Starting subtask complexity review via agent',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'queue_size': queue.length,
        'step_id': ?stepId,
      },
    );

    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      // Non-fatal: mark done to avoid retry loop, log, and continue.
      _markRefinementDone(store, state);
      RunLogStore(layout.runLogPath).append(
        event: 'subtask_refinement_skipped',
        message: 'Subtask refinement agent failed — skipping',
        data: {
          'root': projectRoot,
          'exit_code': result.response.exitCode,
          'step_id': ?stepId,
        },
      );
      return;
    }

    final output = result.response.stdout.trim();
    if (output.contains('NO_CHANGES_NEEDED')) {
      _markRefinementDone(store, state);
      RunLogStore(layout.runLogPath).append(
        event: 'subtask_refinement_no_changes',
        message: 'Subtask complexity review: all subtasks are well-scoped',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'step_id': ?stepId,
        },
      );
      return;
    }

    // Parse the revised list from the agent response.
    final parsed = _parseSubtasksFromNumberedList(output);
    if (parsed.isEmpty) {
      _markRefinementDone(store, state);
      RunLogStore(layout.runLogPath).append(
        event: 'subtask_refinement_skipped',
        message: 'Subtask refinement: could not parse revised list',
        data: {
          'root': projectRoot,
          'step_id': ?stepId,
        },
      );
      return;
    }

    // Update queue without clearing other guards (refinement/feasibility/split).
    state = store.read();
    store.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          queue: parsed,
          refinementDone: true,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    RunLogStore(layout.runLogPath).append(
      event: 'subtask_refinement_triggered',
      message: 'Subtask queue updated by complexity review',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'old_queue_size': queue.length,
        'new_queue_size': parsed.length,
        'step_id': ?stepId,
      },
    );
  }

  void _markRefinementDone(StateStore store, ProjectState state) {
    store.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          refinementDone: true,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Feature 2: Check whether the proposed subtasks together satisfy the AC.
  ///
  /// Returns [FeasibilityCheckResult.skipped] when the check was already done
  /// or config disabled. Returns [FeasibilityCheckResult.feasible] == true when
  /// the agent confirms the subtasks are sufficient. When NOT_FEASIBLE the
  /// subtasks are regenerated (overwrite) and the result carries
  /// [regenerated: true].
  Future<FeasibilityCheckResult> checkFeasibility(
    String projectRoot, {
    String? stepId,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);
    final store = StateStore(layout.statePath);
    var state = store.read();

    // Guard: already checked.
    if (state.subtaskExecution.feasibilityCheckDone) {
      RunLogStore(layout.runLogPath).append(
        event: 'feasibility_check_skipped',
        message: 'Feasibility check already done for current queue',
        data: {
          'root': projectRoot,
          'step_id': ?stepId,
        },
      );
      return const FeasibilityCheckResult(feasible: true, skipped: true);
    }

    final queue = state.subtaskExecution.queue;
    // Guard: nothing to check when queue is empty.
    if (queue.isEmpty) {
      _markFeasibilityDone(store, state);
      return const FeasibilityCheckResult(feasible: true, skipped: true);
    }

    final activeTitle = state.activeTaskTitle ?? '';

    final prompt =
        '${LanguagePolicy.describe()}\n\n'
        '${TaskSpecTemplates.subtaskFeasibilityCheck(activeTitle, queue)}';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt:
          'You are a senior feasibility reviewer in an automated '
          'orchestration pipeline. Assess whether a set of subtasks will '
          'fully satisfy the given acceptance criteria.\n\n'
          'Constraints:\n'
          '- First line MUST be exactly FEASIBLE or NOT_FEASIBLE.\n'
          '- If NOT_FEASIBLE, add a brief explanation of what is missing.\n'
          '- No commentary beyond the verdict and explanation.',
      workingDirectory: projectRoot,
    );

    RunLogStore(layout.runLogPath).append(
      event: 'feasibility_check_start',
      message: 'Starting subtask feasibility check via agent',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'queue_size': queue.length,
        'step_id': ?stepId,
      },
    );

    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      // Non-fatal: mark done to avoid retry loop.
      _markFeasibilityDone(store, store.read());
      RunLogStore(layout.runLogPath).append(
        event: 'feasibility_check_skipped',
        message: 'Feasibility check agent failed — skipping',
        data: {
          'root': projectRoot,
          'exit_code': result.response.exitCode,
          'step_id': ?stepId,
        },
      );
      return const FeasibilityCheckResult(feasible: true, skipped: true);
    }

    final output = result.response.stdout.trim();
    final firstLine = output.split('\n').first.trim().toUpperCase();

    if (firstLine.startsWith('FEASIBLE') &&
        !firstLine.startsWith('NOT_FEASIBLE')) {
      _markFeasibilityDone(store, store.read());
      RunLogStore(layout.runLogPath).append(
        event: 'feasibility_check_passed',
        message: 'Subtask feasibility check passed',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'step_id': ?stepId,
        },
      );
      return const FeasibilityCheckResult(feasible: true);
    }

    // NOT_FEASIBLE — extract explanation and regenerate subtasks.
    final explanation = output.contains('\n')
        ? output.substring(output.indexOf('\n') + 1).trim()
        : null;

    RunLogStore(layout.runLogPath).append(
      event: 'feasibility_check_failed',
      message: 'Subtask feasibility check failed — regenerating subtasks',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'explanation': ?explanation,
        'step_id': ?stepId,
      },
    );

    // Regenerate subtasks with feasibility guidance.
    try {
      final guidance = explanation != null && explanation.isNotEmpty
          ? 'FEASIBILITY ISSUE: $explanation\n\nEnsure the subtasks together '
              'fully address all acceptance criteria.'
          : 'FEASIBILITY ISSUE: The proposed subtasks do not fully satisfy '
              'the acceptance criteria. Regenerate to cover all requirements.';
      await generate(
        projectRoot,
        kind: SpecKind.subtasks,
        overwrite: true,
        guidanceContext: guidance,
      );
      RunLogStore(layout.runLogPath).append(
        event: 'feasibility_check_regenerated',
        message: 'Subtasks regenerated after feasibility failure',
        data: {
          'root': projectRoot,
          'task': activeTitle,
          'step_id': ?stepId,
        },
      );
    } catch (_) {
      // Non-fatal — continue with existing subtasks.
    }

    // Mark feasibility done to prevent a second call even after regeneration.
    _markFeasibilityDone(store, store.read());

    return FeasibilityCheckResult(
      feasible: false,
      explanation: explanation,
      regenerated: true,
    );
  }

  void _markFeasibilityDone(StateStore store, ProjectState state) {
    store.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          feasibilityCheckDone: true,
        ),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Feature 1b: Split a single rejected subtask into smaller pieces.
  ///
  /// Returns a list of 2-3 replacement subtasks, or `null` if the agent
  /// response could not be parsed.
  Future<List<String>?> splitSubtaskForReject(
    String projectRoot,
    String subtask,
    String rejectNote,
  ) async {
    final layout = ProjectLayout(projectRoot);

    final prompt =
        '${LanguagePolicy.describe()}\n\n'
        '${TaskSpecTemplates.subtaskReactiveSplit(subtask, rejectNote)}';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt:
          'You are a senior scope-control agent in an automated '
          'orchestration pipeline. Split a rejected subtask into '
          'smaller, independently verifiable steps.\n\n'
          'Constraints:\n'
          '- Output ONLY a numbered list of 2-3 subtasks.\n'
          '- Each subtask touches ≤3 files.\n'
          '- Start each with an action verb.\n'
          '- No commentary.',
      workingDirectory: projectRoot,
    );

    RunLogStore(layout.runLogPath).append(
      event: 'subtask_split_on_reject_start',
      message: 'Starting reactive subtask split via agent',
      data: {
        'root': projectRoot,
        'subtask': _truncate(subtask, 120),
        'reject_note': _truncate(rejectNote, 120),
      },
    );

    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      return null;
    }

    final parsed = _parseSubtasksFromNumberedList(result.response.stdout);
    if (parsed.isEmpty || parsed.length > 3) {
      return null;
    }
    return parsed;
  }

  /// Checks whether the current implementation diff satisfies the acceptance
  /// criteria for [requirement].
  ///
  /// Returns [AcSelfCheckResult.skipped] when the agent call fails (non-fatal).
  /// Returns [AcSelfCheckResult.passed] == true when the agent says PASS.
  /// Returns [AcSelfCheckResult.passed] == false with a [reason] when FAIL.
  Future<AcSelfCheckResult> checkImplementationAgainstAc(
    String projectRoot, {
    required String requirement,
    required String diffSummary,
  }) async {
    final layout = ProjectLayout(projectRoot);

    final prompt =
        '${LanguagePolicy.describe()}\n\n'
        '${TaskSpecTemplates.acSelfCheck(requirement, diffSummary)}';

    const systemPrompt =
        'You are a senior code reviewer in an automated orchestration '
        'pipeline. Assess whether the implementation satisfies the '
        'requirement.\n\n'
        'Constraints:\n'
        '- First line MUST be exactly: PASS or FAIL\n'
        '- If FAIL: one sentence explaining what is missing.\n'
        '- No other commentary.';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: systemPrompt,
      workingDirectory: projectRoot,
    );

    RunLogStore(layout.runLogPath).append(
      event: 'ac_self_check_start',
      message: 'Starting AC self-check via agent',
      data: {'root': projectRoot},
    );

    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      RunLogStore(layout.runLogPath).append(
        event: 'ac_self_check_skipped',
        message: 'AC self-check agent failed — skipping',
        data: {
          'root': projectRoot,
          'exit_code': result.response.exitCode,
        },
      );
      return const AcSelfCheckResult(passed: true, skipped: true);
    }

    final output = result.response.stdout.trim();
    final firstLine = output.split('\n').first.trim().toUpperCase();
    final passed = firstLine.startsWith('PASS');
    final String? reason;
    if (!passed && output.contains('\n')) {
      final rest = output.substring(output.indexOf('\n') + 1).trim();
      reason = rest.isNotEmpty ? rest : null;
    } else {
      reason = null;
    }

    RunLogStore(layout.runLogPath).append(
      event: passed ? 'ac_self_check_passed' : 'ac_self_check_failed',
      message: passed ? 'AC self-check passed' : 'AC self-check failed',
      data: {
        'root': projectRoot,
        if (!passed && reason != null) 'reason': reason,
      },
    );

    return AcSelfCheckResult(passed: passed, reason: reason);
  }

  /// Parses a plain numbered list (e.g. `1. Do X`) into clean subtask strings.
  List<String> _parseSubtasksFromNumberedList(String content) {
    final result = <String>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      final match = RegExp(r'^(\d+)[.)]\s+(.+)').firstMatch(trimmed);
      if (match != null) {
        final text = _normalizeSubtaskText(match.group(2)?.trim() ?? '');
        if (_isUsableSubtask(text)) {
          result.add(text);
        }
      }
    }
    return result;
  }

  void _updateSubtaskQueue(ProjectLayout layout, String content) {
    final parsed = _parseSubtasks(content);
    final subtasks = parsed.items;
    if (subtasks.isEmpty) {
      RunLogStore(layout.runLogPath).append(
        event: 'subtasks_queue_empty',
        message: 'Subtask agent produced no parseable subtasks',
        data: {
          'root': layout.projectRoot,
          'error_class': 'pipeline',
          'error_kind': 'empty_subtask_queue',
          'content_length': content.length,
        },
      );
      return;
    }
    final store = StateStore(layout.statePath);
    final state = store.read();
    final now = DateTime.now().toUtc().toIso8601String();
    store.write(
      state.copyWith(
        subtaskExecution: state.subtaskExecution.copyWith(
          queue: subtasks,
          current: null, // Reset current subtask on new queue
          refinementDone: false,
          feasibilityCheckDone: false,
          splitAttempts: const {},
        ),
        lastUpdated: now,
      ),
    );
    RunLogStore(layout.runLogPath).append(
      event: 'subtasks_queue_updated',
      message: 'Updated subtask queue from agent output',
      data: {
        'root': layout.projectRoot,
        'queue_size': subtasks.length,
        'strict_quality_count': parsed.strictQualityCount,
        'dependency_reordered': parsed.dependencyReordered,
      },
    );
  }

  _ParsedSubtasks _parseSubtasks(String content) {
    final drafts = <_SubtaskDraft>[];
    final lines = content.split('\n');
    var insideSubtasks = false;
    var ordinal = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('## Subtasks')) {
        insideSubtasks = true;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        insideSubtasks = false;
        continue;
      }
      if (insideSubtasks) {
        final match = RegExp(r'^(?:(\d+)[.)]|[-*])\s+(.*)').firstMatch(trimmed);
        if (match != null) {
          ordinal += 1;
          final rawNumber = match.group(1);
          final baseDescription = match.group(2)?.trim() ?? '';
          final number = rawNumber == null ? ordinal : int.tryParse(rawNumber);
          final parsed = _extractDependencyHints(baseDescription);
          final normalized = _normalizeSubtaskText(parsed.description);
          if (normalized.isEmpty) {
            continue;
          }
          drafts.add(
            _SubtaskDraft(
              order: ordinal,
              numericId: number,
              description: normalized,
              dependencyRefs: parsed.dependencies,
            ),
          );
        }
      }
    }

    if (drafts.isEmpty) {
      return const _ParsedSubtasks(
        items: [],
        strictQualityCount: 0,
        dependencyReordered: false,
      );
    }

    final ordered = _orderByDependencies(drafts);
    final deduped = _dedupeByNormalizedText(ordered);
    final selected = <String>[];
    var strictCount = 0;
    for (final draft in deduped) {
      if (!_isUsableSubtask(draft.description)) {
        continue;
      }
      selected.add(draft.description);
      if (_isActionVerbFirstWord(draft.description)) {
        strictCount += 1;
      }
      if (selected.length >= 7) {
        break;
      }
    }
    return _ParsedSubtasks(
      items: selected,
      strictQualityCount: strictCount,
      dependencyReordered: !_sameOrder(drafts, ordered),
    );
  }

  _DependencyExtraction _extractDependencyHints(String input) {
    var description = input.trim();
    final refs = <String>{};
    final pattern = RegExp(
      r'[\(\[]\s*(?:depends\s+on|dependency|dependencies|deps?)\s*:\s*([^\)\]]+)[\)\]]',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(description)) {
      final chunk = match.group(1);
      if (chunk == null) {
        continue;
      }
      for (final part in chunk.split(RegExp(r'[,\s]+'))) {
        final key = _normalizeDependencyRef(part);
        if (key != null) {
          refs.add(key);
        }
      }
    }
    description = description.replaceAll(pattern, '').trim();
    return _DependencyExtraction(
      description: description,
      dependencies: refs.toList(growable: false),
    );
  }

  String? _normalizeDependencyRef(String raw) {
    final token = raw.trim().toLowerCase();
    if (token.isEmpty) {
      return null;
    }
    final number = int.tryParse(token);
    if (number != null && number > 0) {
      return '#$number';
    }
    final sNumber = RegExp(r'^s(\d+)$', caseSensitive: false).firstMatch(token);
    if (sNumber != null) {
      final parsed = int.tryParse(sNumber.group(1)!);
      if (parsed != null && parsed > 0) {
        return '#$parsed';
      }
    }
    return null;
  }

  List<_SubtaskDraft> _orderByDependencies(List<_SubtaskDraft> drafts) {
    if (drafts.length < 2) {
      return drafts;
    }
    final idToIndex = <String, int>{};
    for (var i = 0; i < drafts.length; i += 1) {
      final draft = drafts[i];
      if (draft.numericId != null && draft.numericId! > 0) {
        idToIndex['#${draft.numericId}'] = i;
      }
      idToIndex['#${draft.order}'] = i;
    }

    final deps = <int, Set<int>>{};
    final incoming = List<int>.filled(drafts.length, 0);
    for (var i = 0; i < drafts.length; i += 1) {
      final resolved = <int>{};
      for (final ref in drafts[i].dependencyRefs) {
        final refIndex = idToIndex[ref];
        if (refIndex == null || refIndex == i) {
          continue;
        }
        resolved.add(refIndex);
      }
      deps[i] = resolved;
      incoming[i] = resolved.length;
    }

    final outgoing = <int, List<int>>{};
    for (var i = 0; i < drafts.length; i += 1) {
      final dependsOn = deps[i] ?? const <int>{};
      for (final parent in dependsOn) {
        outgoing.putIfAbsent(parent, () => <int>[]).add(i);
      }
    }

    final ready = <int>[];
    for (var i = 0; i < incoming.length; i += 1) {
      if (incoming[i] == 0) {
        ready.add(i);
      }
    }
    ready.sort((a, b) => drafts[a].order.compareTo(drafts[b].order));

    final order = <int>[];
    while (ready.isNotEmpty) {
      ready.sort((a, b) => drafts[a].order.compareTo(drafts[b].order));
      final current = ready.removeAt(0);
      order.add(current);
      final children = outgoing[current] ?? const <int>[];
      for (final child in children) {
        incoming[child] = incoming[child] - 1;
        if (incoming[child] == 0) {
          ready.add(child);
        }
      }
    }

    if (order.length != drafts.length) {
      return drafts;
    }
    return order.map((index) => drafts[index]).toList(growable: false);
  }

  List<_SubtaskDraft> _dedupeByNormalizedText(List<_SubtaskDraft> drafts) {
    final seen = <String>{};
    final output = <_SubtaskDraft>[];
    for (final draft in drafts) {
      final key = _normalizedKey(draft.description);
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      output.add(draft);
    }
    return output;
  }

  bool _sameOrder(List<_SubtaskDraft> left, List<_SubtaskDraft> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i].order != right[i].order) {
        return false;
      }
    }
    return true;
  }

  bool _isUsableSubtask(String value) {
    if (_isPlaceholderSubtask(value)) {
      return false;
    }
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length < 3) {
      return false;
    }
    if (value.length < 14) {
      return false;
    }
    return true;
  }

  bool _isActionVerbFirstWord(String value) {
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return false;
    }
    return _startsWithActionVerb(words.first);
  }

  bool _isPlaceholderSubtask(String value) {
    final lower = value.toLowerCase();
    if (lower == '-' || lower.isEmpty) {
      return true;
    }
    return lower.contains('tbd') ||
        lower.contains('todo') ||
        lower.contains('to do') ||
        lower == 'n/a' ||
        lower.contains('placeholder');
  }

  bool _startsWithActionVerb(String firstWord) {
    final lower = firstWord.toLowerCase();
    return lower == 'add' ||
        lower == 'build' ||
        lower == 'create' ||
        lower == 'define' ||
        lower == 'document' ||
        lower == 'enforce' ||
        lower == 'fix' ||
        lower == 'implement' ||
        lower == 'improve' ||
        lower == 'introduce' ||
        lower == 'migrate' ||
        lower == 'optimize' ||
        lower == 'refactor' ||
        lower == 'remove' ||
        lower == 'run' ||
        lower == 'stabilize' ||
        lower == 'support' ||
        lower == 'test' ||
        lower == 'update' ||
        lower == 'verify' ||
        lower == 'write';
  }

  String _normalizeSubtaskText(String value) {
    return value
        .replaceAll(RegExp(r'^[\-\*\d\.\)\(]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'[.;:,]+$'), '')
        .trim();
  }

  String _normalizedKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _ensureStateFile(ProjectLayout layout) {
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
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
        return '${LanguagePolicy.describe()}\n\n'
            'Write 3-7 subtasks in English for: "$title".\n'
            'Follow this template:\n\n'
            '${TaskSpecTemplates.subtasks(title)}\n'
            'Return only markdown.';
      case SpecKind.subtaskRefinement:
        // Prompt is constructed dynamically from queue in maybeRefineSubtasks.
        return '';
    }
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…';
  }

  String _systemPrompt(SpecKind kind) {
    switch (kind) {
      case SpecKind.plan:
        return 'You are a senior planning agent in an automated orchestration '
            'pipeline. Produce clear, incremental, execution-ready plans.\n\n'
            'Constraints:\n'
            '- Each plan step must be independently verifiable.\n'
            '- Identify risks and mitigations upfront.\n'
            '- Specify dependencies between steps explicitly.\n'
            '- Prefer small, reversible moves over large rewrites.\n'
            '- Output ONLY the plan in the requested markdown template. '
            'No commentary.';
      case SpecKind.spec:
        return 'You are a senior specification agent in an automated '
            'orchestration pipeline. Produce precise, actionable task '
            'specifications.\n\n'
            'Constraints:\n'
            '- Every acceptance criterion must be testable (command, '
            'assertion, or observable outcome).\n'
            '- The ## Files section MUST list every file that needs '
            'creation or modification.\n'
            '- The ## Non-Goals section MUST explicitly exclude adjacent '
            'work to prevent scope creep.\n'
            '- Scope must be achievable in a single coding agent '
            'invocation.\n'
            '- Output ONLY the spec in the requested markdown template. '
            'No commentary.';
      case SpecKind.subtasks:
        return 'You are a senior task decomposition agent in an automated '
            'orchestration pipeline. Break tasks into atomic, '
            'dependency-ordered subtasks.\n\n'
            'Constraints:\n'
            '- Each subtask must be completable in one coding agent '
            'invocation.\n'
            '- Start each subtask with an action verb (Add, Create, Fix, '
            'Implement, etc.).\n'
            '- Order by dependency: foundation first, integration last.\n'
            '- If subtask B depends on A, note it: "B (depends on: 1)".\n'
            '- 3-7 subtasks. Fewer is better if the task is simple.\n'
            '- Output ONLY the subtasks in the requested markdown '
            'template. No commentary.';
      case SpecKind.subtaskRefinement:
        return 'You are a senior scope-control agent in an automated '
            'orchestration pipeline. Your job is to assess subtask '
            'complexity and split oversized ones.\n\n'
            'Constraints:\n'
            '- A well-scoped subtask touches ≤3 files and is completable '
            'in one coding agent invocation.\n'
            '- If ALL subtasks are well-scoped, output ONLY: '
            'REFINED: NO_CHANGES_NEEDED\n'
            '- Otherwise output a revised numbered list. Keep well-scoped '
            'subtasks unchanged.\n'
            '- No commentary outside the list or the sentinel string.';
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

  static const int _timeoutExitCode = 124;
}

class _SubtaskDraft {
  const _SubtaskDraft({
    required this.order,
    required this.numericId,
    required this.description,
    required this.dependencyRefs,
  });

  final int order;
  final int? numericId;
  final String description;
  final List<String> dependencyRefs;
}

class _DependencyExtraction {
  const _DependencyExtraction({
    required this.description,
    required this.dependencies,
  });

  final String description;
  final List<String> dependencies;
}

class _ParsedSubtasks {
  const _ParsedSubtasks({
    required this.items,
    required this.strictQualityCount,
    required this.dependencyReordered,
  });

  final List<String> items;
  final int strictQualityCount;
  final bool dependencyReordered;
}
