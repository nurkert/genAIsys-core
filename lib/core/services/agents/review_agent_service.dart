// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_error_hints.dart';
import '../../agents/agent_runner.dart';
import '../../config/project_config.dart';
import '../../models/review_bundle.dart';
import '../../policy/language_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../agent_context_service.dart';
import 'agent_service.dart';

enum ReviewDecision { approve, reject }

enum ReviewPersona { general, security, ui, performance }

class ReviewAgentResult {
  const ReviewAgentResult({
    required this.decision,
    required this.response,
    required this.usedFallback,
    this.advisoryNotes = const [],
  });

  final ReviewDecision decision;
  final AgentResponse response;
  final bool usedFallback;

  /// Non-blocking advisory notes extracted from verification reviews.
  /// These are new non-critical findings that do not affect the approval
  /// decision but should be tracked as follow-up QA tasks.
  final List<String> advisoryNotes;
}

class ReviewAgentService {
  ReviewAgentService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<ReviewAgentResult> review(
    String projectRoot, {
    required String diffSummary,
    String? testSummary,
    ReviewPersona persona = ReviewPersona.general,
    String strictness = 'standard',
  }) async {
    final bundle = ReviewBundle(
      diffSummary: diffSummary,
      diffPatch: '',
      testSummary: testSummary,
      taskTitle: null,
      spec: null,
    );
    return reviewBundle(
      projectRoot,
      bundle: bundle,
      persona: persona,
      strictness: strictness,
    );
  }

  Future<ReviewAgentResult> reviewBundle(
    String projectRoot, {
    required ReviewBundle bundle,
    ReviewPersona persona = ReviewPersona.general,
    String strictness = 'standard',
    List<String> contractNotes = const [],
  }) async {
    final config = ProjectConfig.load(projectRoot);
    final priorContext = config.reviewFreshContext
        ? null
        : _loadPriorCycleContext(projectRoot);
    final prompt = contractNotes.isNotEmpty
        ? _buildVerificationPrompt(bundle, contractNotes: contractNotes)
        : _buildPrompt(bundle, priorContext: priorContext);
    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot, persona, strictness),
      workingDirectory: projectRoot,
    );
    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) {
      if (result.response.exitCode == _timeoutExitCode) {
        throw TimeoutException('Review agent timed out.');
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
          'Review agent failed with exit_code ${result.response.exitCode}.',
        );
      if (detail.isNotEmpty) {
        message.writeln('Details: ${_truncate(detail, 600)}');
      }
      if (hint.isNotEmpty) {
        message.writeln(hint);
      }
      throw StateError(message.toString().trim());
    }
    // Validate that the response contains a recognizable decision keyword.
    // If neither APPROVE nor REJECT (nor positive-pattern fallbacks) is found,
    // treat as a malformed response and emit a structured run-log event.
    final malformedDecision = _detectMalformedResponse(
      projectRoot,
      stdout: result.response.stdout,
    );
    if (malformedDecision != null) {
      return ReviewAgentResult(
        decision: malformedDecision,
        response: result.response,
        usedFallback: result.usedFallback,
      );
    }

    final decision = _parseDecision(result.response.stdout);
    _enforceEnglishNote(result.response.stdout);

    if (decision == ReviewDecision.approve) {
      if (config.reviewRequireEvidence) {
        final evidenceDecision = _validateReviewEvidence(
          projectRoot,
          response: result.response.stdout,
          bundle: bundle,
          evidenceMinLength: config.reviewEvidenceMinLength,
        );
        if (evidenceDecision != null) {
          return ReviewAgentResult(
            decision: evidenceDecision,
            response: result.response,
            usedFallback: result.usedFallback,
          );
        }
      }
    }

    final advisoryNotes = contractNotes.isNotEmpty
        ? _extractAdvisoryNotes(result.response.stdout)
        : const <String>[];
    return ReviewAgentResult(
      decision: decision,
      response: result.response,
      usedFallback: result.usedFallback,
      advisoryNotes: advisoryNotes,
    );
  }

  String _buildPrompt(ReviewBundle bundle, {String? priorContext}) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln('');

    // Subtask-aware review scoping: when reviewing a subtask delivery,
    // the review agent must evaluate ONLY the subtask's scope, not reject
    // because the full task acceptance criteria are not yet met.
    final subtask = bundle.subtaskDescription?.trim();
    final isSubtaskReview = subtask != null && subtask.isNotEmpty;
    if (isSubtaskReview) {
      buffer.writeln('## Review Scope: SUBTASK DELIVERY (not full task)');
      buffer.writeln('');
      buffer.writeln('Current subtask: $subtask');
      buffer.writeln('');
      buffer.writeln(
        'Evaluate ONLY whether this subtask\'s described scope was delivered. '
        'Do NOT reject because the full task acceptance criteria are not yet '
        'met — remaining subtasks will address those.',
      );
      buffer.writeln('');
    }

    if (bundle.taskTitle != null) {
      final taskLabel = isSubtaskReview ? 'Full Task (Context)' : 'Task';
      buffer.writeln('$taskLabel: ${bundle.taskTitle}');
      buffer.writeln('');
    }
    if (bundle.spec != null) {
      final specLabel = isSubtaskReview ? 'Full Task Spec (Context)' : 'Spec';
      buffer.writeln('$specLabel:');
      buffer.writeln(bundle.spec!.trim());
      buffer.writeln('');
    }
    if (priorContext != null && priorContext.trim().isNotEmpty) {
      buffer.writeln('Prior cycle context:');
      buffer.writeln(priorContext.trim());
      buffer.writeln('');
    }
    buffer.writeln('Review the following changes.');
    buffer.writeln('');
    buffer.writeln('Diff Summary:');
    buffer.writeln(bundle.diffSummary.trim());
    buffer.writeln('');
    buffer.writeln('Diff Patch:');
    final patch = bundle.diffPatch.trim();
    buffer.writeln(patch.isEmpty ? '(none)' : patch);
    // Provide changed file paths so the reviewer can reference them,
    // enabling evidence validation to match file references.
    final changedPaths = _extractPathsFromDiff(bundle.diffSummary);
    if (changedPaths.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Changed files:');
      for (final p in changedPaths) {
        buffer.writeln('- $p');
      }
    }
    if (bundle.testSummary != null && bundle.testSummary!.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Test Summary:');
      buffer.writeln(bundle.testSummary!.trim());
    }
    buffer.writeln('');
    buffer.writeln('Review gates:');
    buffer.writeln('- Correctness and regression risk');
    buffer.writeln('- Test coverage and evidence quality');
    buffer.writeln('- Maintainability and readability');
    buffer.writeln('- Security and policy compliance');
    buffer.writeln('');
    buffer.writeln('Answer with APPROVE or REJECT on the first line.');
    buffer.writeln('Provide a short reason after the first line.');
    return buffer.toString();
  }

  /// Builds a verification-review prompt that locks the review scope to the
  /// previous rejection notes (the "contract"). The reviewer must only verify
  /// whether those items were resolved. New non-critical findings are reported
  /// as ADVISORY notes and do not block approval.
  String _buildVerificationPrompt(
    ReviewBundle bundle, {
    required List<String> contractNotes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln('');
    buffer.writeln('## VERIFICATION REVIEW');
    buffer.writeln('');
    buffer.writeln(
      'This is NOT a fresh review. The previous review(s) raised specific '
      'issues (listed below as the "Review Contract"). Your sole task:',
    );
    buffer.writeln('');
    buffer.writeln(
      '1. For EACH contract item: is it resolved? (YES/NO + brief evidence)',
    );
    buffer.writeln(
      '2. NEW critical findings ONLY: security vulnerabilities or broken '
      'functionality that would cause data loss or crashes. '
      'Report these after "CRITICAL:".',
    );
    buffer.writeln(
      '3. NEW non-critical observations: report after "ADVISORY:" — these '
      'will be tracked separately and do NOT affect your decision.',
    );
    buffer.writeln('');
    buffer.writeln('### Decision Rule');
    buffer.writeln(
      '- APPROVE if ALL contract items are resolved AND no new CRITICAL '
      'findings.',
    );
    buffer.writeln(
      '- REJECT if any contract item is NOT resolved, or if a new CRITICAL '
      'finding exists. List ONLY the unresolved/critical items.',
    );
    buffer.writeln('');
    buffer.writeln('### Review Contract');
    for (final note in contractNotes) {
      buffer.writeln('- [ ] $note');
    }
    buffer.writeln('');
    if (bundle.taskTitle != null) {
      buffer.writeln('Task: ${bundle.taskTitle}');
      buffer.writeln('');
    }
    buffer.writeln('### Current Diff');
    buffer.writeln(bundle.diffSummary.trim());
    buffer.writeln('');
    final patch = bundle.diffPatch.trim();
    buffer.writeln(patch.isEmpty ? '(none)' : patch);
    if (bundle.testSummary != null && bundle.testSummary!.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('### Test Summary');
      buffer.writeln(bundle.testSummary!.trim());
    }
    buffer.writeln('');
    buffer.writeln('Answer with APPROVE or REJECT on the first line.');
    return buffer.toString();
  }

  /// Extracts advisory notes from a review response.
  ///
  /// Looks for lines starting with "ADVISORY:" and collects the text after
  /// the marker. Returns an empty list if no advisory notes are found.
  List<String> _extractAdvisoryNotes(String stdout) {
    final notes = <String>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      final upper = trimmed.toUpperCase();
      if (upper.startsWith('ADVISORY:')) {
        final note = trimmed.substring('ADVISORY:'.length).trim();
        if (note.isNotEmpty) {
          notes.add(note);
        }
      }
    }
    return notes;
  }

  String _systemPrompt(
    String projectRoot,
    ReviewPersona persona,
    String strictness,
  ) {
    final override = _contextService.loadSystemPrompt(
      projectRoot,
      _reviewPromptKey(persona),
    );
    if (override != null) {
      return override;
    }
    final base = switch (persona) {
      ReviewPersona.security =>
        'You are a senior security auditor reviewing code in an automated CI pipeline. '
            'Evaluate ONLY the diff provided — do not speculate about code not shown.\n\n'
            'Classify each finding by severity:\n'
            '- BLOCKING: Security vulnerabilities, data exposure, policy bypasses. Must fix before merge.\n'
            '- IMPORTANT: Missing validation, weak error handling, incomplete sanitization. Should fix.\n'
            '- ADVISORY: Style improvements, minor hardening opportunities. Note but do not block.\n\n'
            'Analyze the diff first, reason about risks, then state your verdict. '
            'Never approve changes that introduce vulnerabilities or bypass safety gates.',
      ReviewPersona.ui =>
        'You are a senior UI/UX engineer reviewing code in an automated CI pipeline. '
            'Evaluate ONLY the diff provided — do not speculate about code not shown.\n\n'
            'Classify each finding by severity:\n'
            '- BLOCKING: Broken interactions, inaccessible UI, layout crashes. Must fix.\n'
            '- IMPORTANT: Missing keyboard support, inconsistent patterns, poor error states. Should fix.\n'
            '- ADVISORY: Visual polish, minor spacing, style preferences. Note but do not block.\n\n'
            'Analyze the diff first, then state your verdict. '
            'Focus on desktop-first usability, accessibility, and design system adherence.',
      ReviewPersona.performance =>
        'You are a senior performance engineer reviewing code in an automated CI pipeline. '
            'Evaluate ONLY the diff provided — do not speculate about code not shown.\n\n'
            'Classify each finding by severity:\n'
            '- BLOCKING: Unbounded loops, memory leaks, missing timeouts in critical paths. Must fix.\n'
            '- IMPORTANT: Excessive allocations, repeated parsing, unnecessary I/O. Should fix.\n'
            '- ADVISORY: Minor optimizations, style-level efficiency. Note but do not block.\n\n'
            'Analyze the diff first, then state your verdict. '
            'Focus on bounded work, deterministic behavior, and resource efficiency.',
      ReviewPersona.general =>
        'You are an independent senior code reviewer in an automated CI pipeline. '
            'You have no implementation bias — evaluate ONLY the diff provided.\n\n'
            'Classify each finding by severity:\n'
            '- BLOCKING: Correctness bugs, security issues, missing tests for changed behavior. Must fix before merge.\n'
            '- IMPORTANT: Poor maintainability, unclear naming, incomplete error handling. Should fix.\n'
            '- ADVISORY: Style preferences, minor improvements. Note but do not block.\n\n'
            'Analyze the diff first, reason about risks, then state your verdict. '
            'Be concise — focus on what matters, skip bikeshedding.',
    };
    final strictnessDirective = _strictnessDirective(strictness);
    if (strictnessDirective.isEmpty) {
      return base;
    }
    return '$base\n\n$strictnessDirective';
  }

  String _strictnessDirective(String strictness) {
    switch (strictness) {
      case 'strict':
        return 'STRICTNESS: STRICT\n'
            'Rejection threshold: ANY finding rated BLOCKING or IMPORTANT.\n'
            'ADVISORY notes alone do not block, but every changed line must '
            'be justified and covered by tests. '
            'Zero tolerance for technical debt introduction.';
      case 'lenient':
        return 'STRICTNESS: LENIENT\n'
            'Rejection threshold: BLOCKING findings only.\n'
            'IMPORTANT findings should be noted as follow-ups but do not '
            'block merge. Accept if core functionality is correct and '
            'no security issues exist.';
      case 'standard':
      default:
        return '';
    }
  }

  String _reviewPromptKey(ReviewPersona persona) {
    switch (persona) {
      case ReviewPersona.security:
        return 'review_security';
      case ReviewPersona.ui:
        return 'review_ui';
      case ReviewPersona.performance:
        return 'review_performance';
      case ReviewPersona.general:
        return 'review';
    }
  }

  /// Detects responses that contain neither APPROVE/REJECT nor any
  /// recognized positive-pattern fallback. Returns [ReviewDecision.reject]
  /// for malformed responses, or `null` if a valid decision is present.
  ReviewDecision? _detectMalformedResponse(
    String projectRoot, {
    required String stdout,
  }) {
    final trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      // Empty responses are already handled by _parseDecision as reject;
      // still log them as malformed for observability.
      _logMalformedResponse(projectRoot, trimmed);
      return ReviewDecision.reject;
    }

    final upper = trimmed.toUpperCase();
    if (upper.contains('APPROVE') || upper.contains('REJECT')) {
      return null;
    }

    // Check positive-pattern fallbacks (same list as _parseDecision).
    const positivePatterns = <String>[
      'READY TO MERGE',
      'SHIP IT',
      'LGTM',
      'LOOKS GOOD TO ME',
      'NO ISSUES FOUND',
    ];
    for (final pattern in positivePatterns) {
      if (upper.contains(pattern)) {
        return null;
      }
    }

    // Neither a decision keyword nor a positive pattern was found.
    _logMalformedResponse(projectRoot, trimmed);
    return ReviewDecision.reject;
  }

  /// Emits a `review_malformed_response` run-log event.
  void _logMalformedResponse(String projectRoot, String response) {
    final layout = ProjectLayout(projectRoot);
    _logEvidenceEvent(
      layout,
      event: 'review_malformed_response',
      message: 'Review response contains neither APPROVE nor REJECT',
      data: {
        'root': projectRoot,
        'error_class': 'review',
        'error_kind': 'review_malformed_response',
        'response_length': response.length,
        'response_preview': _truncate(response, 200),
      },
    );
  }

  /// Returns [ReviewDecision.reject] if the review evidence is too weak,
  /// or `null` if the review passes the evidence check.
  ReviewDecision? _validateReviewEvidence(
    String projectRoot, {
    required String response,
    required ReviewBundle bundle,
    int evidenceMinLength = ProjectConfig.defaultReviewEvidenceMinLength,
  }) {
    final trimmed = response.trim();
    final layout = ProjectLayout(projectRoot);

    // Suspiciously short responses lack substantive analysis.
    if (trimmed.length < evidenceMinLength) {
      _logEvidenceEvent(
        layout,
        event: 'review_evidence_weak',
        message: 'Review response too short for meaningful evidence',
        data: {
          'root': projectRoot,
          'error_class': 'review',
          'error_kind': 'review_evidence_too_short',
          'response_length': trimmed.length,
        },
      );
      return ReviewDecision.reject;
    }

    // Check if the review references at least one file path from the diff.
    // Multi-tier matching: full path, basename, or last two path segments.
    final diffPaths = _extractPathsFromDiff(bundle.diffSummary);
    if (diffPaths.isNotEmpty) {
      final referencesFile = diffPaths.any((path) {
        // Tier 1: exact full path reference.
        if (trimmed.contains(path)) return true;
        // Tier 2: basename match (e.g., "card.dart").
        final basename = path.split('/').last;
        if (basename.isNotEmpty && trimmed.contains(basename)) return true;
        // Tier 3: last two segments (e.g., "models/card.dart").
        final segments = path.split('/');
        if (segments.length >= 2) {
          final partial = segments.sublist(segments.length - 2).join('/');
          if (trimmed.contains(partial)) return true;
        }
        return false;
      });
      if (!referencesFile) {
        // Tier 4: substantive technical content — external reviewers may
        // discuss code behavior without citing file paths.
        if (!_isSubstantiveReview(trimmed)) {
          _logEvidenceEvent(
            layout,
            event: 'review_evidence_weak',
            message: 'Review does not reference any changed file',
            data: {
              'root': projectRoot,
              'error_class': 'review',
              'error_kind': 'review_evidence_no_file_reference',
              'diff_paths_count': diffPaths.length,
            },
          );
          return ReviewDecision.reject;
        }
      }
    }

    return null;
  }

  /// Best-effort evidence event logging. Creates the run-log directory
  /// if missing so evidence validation works even in minimal project layouts.
  void _logEvidenceEvent(
    ProjectLayout layout, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    try {
      final logFile = File(layout.runLogPath);
      if (!logFile.parent.existsSync()) {
        logFile.parent.createSync(recursive: true);
      }
      RunLogStore(
        layout.runLogPath,
      ).append(event: event, message: message, data: data);
    } catch (_) {
      // Evidence logging is observability — never block the review decision.
    }
  }

  /// Returns `true` when the review text is long enough and contains at least
  /// two technical terms. External LLM reviewers often discuss code behavior
  /// without citing exact file paths, so substantive technical analysis is
  /// accepted as sufficient evidence.
  bool _isSubstantiveReview(String text) {
    if (text.length < 200) return false;
    const terms = [
      'function', 'method', 'class', 'test', 'error', 'return',
      'parameter', 'argument', 'implementation', 'logic', 'import',
      'variable', 'type', 'interface', 'constructor', 'coverage',
      'regression', 'refactor', 'behavior', 'contract',
    ];
    final lower = text.toLowerCase();
    var matchCount = 0;
    for (final term in terms) {
      if (lower.contains(term)) {
        matchCount++;
        if (matchCount >= 2) return true;
      }
    }
    return false;
  }

  /// Extracts file path segments from a diff summary.
  List<String> _extractPathsFromDiff(String diffSummary) {
    final paths = <String>[];
    // Match common diff output path patterns: a/path or b/path or just path.
    final pathPattern = RegExp(
      r'(?:^|\s)(?:[ab]/)?(\S+\.\w+)',
      multiLine: true,
    );
    for (final match in pathPattern.allMatches(diffSummary)) {
      final path = match.group(1);
      if (path != null && path.contains('.')) {
        paths.add(path);
      }
    }
    return paths.toSet().toList();
  }

  ReviewDecision _parseDecision(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) return ReviewDecision.reject;

    // 1) Check the first non-empty line for an explicit keyword.
    //    This is the strongest signal because the prompt requests it.
    final firstLine = trimmed
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .toUpperCase();
    if (firstLine.contains('REJECT')) return ReviewDecision.reject;
    if (firstLine.contains('APPROVE')) return ReviewDecision.approve;

    // 2) Scan the full text for explicit keywords.
    //    REJECT takes precedence over APPROVE to stay fail-safe,
    //    but only when the keyword appears as an intentional verdict
    //    (not in phrases like "no reason to reject").
    final upper = trimmed.toUpperCase();
    if (upper.contains('REJECT') && !upper.contains('APPROVE')) {
      return ReviewDecision.reject;
    }
    if (upper.contains('APPROVE')) {
      return ReviewDecision.approve;
    }

    // 3) Recognize common positive-review patterns as fallback approval.
    //    These are weaker signals that only apply when neither keyword is
    //    present, and the text clearly indicates a merge-ready verdict.
    const positivePatterns = <String>[
      'READY TO MERGE',
      'SHIP IT',
      'LGTM',
      'LOOKS GOOD TO ME',
      'NO ISSUES FOUND',
    ];
    for (final pattern in positivePatterns) {
      if (upper.contains(pattern)) {
        return ReviewDecision.approve;
      }
    }

    // 4) Fail-safe: if the decision is ambiguous, reject.
    return ReviewDecision.reject;
  }

  void _enforceEnglishNote(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final lines = trimmed.split('\n');
    if (lines.length == 1) {
      return;
    }
    final note = lines.skip(1).join('\n').trim();
    if (note.isEmpty) {
      return;
    }
    LanguagePolicy.enforceEnglish(note, context: 'review note');
  }

  /// Loads prior cycle context from project state for non-fresh reviews.
  ///
  /// When [ProjectConfig.reviewFreshContext] is `false`, this method
  /// assembles a summary of the previous cycle's failure signals
  /// (last error, forensic guidance) so the review agent can evaluate
  /// whether the current diff addresses known issues.
  String? _loadPriorCycleContext(String projectRoot) {
    try {
      final layout = ProjectLayout(projectRoot);
      final state = StateStore(layout.statePath).read();
      final parts = <String>[];
      final lastError = state.lastError?.trim();
      if (lastError != null && lastError.isNotEmpty) {
        parts.add('Last error: $lastError');
      }
      final guidance = state.forensicGuidance?.trim();
      if (guidance != null && guidance.isNotEmpty) {
        parts.add('Forensic guidance: $guidance');
      }
      if (parts.isEmpty) {
        return null;
      }
      return parts.join('\n');
    } catch (_) {
      return null;
    }
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…';
  }

  static const int _timeoutExitCode = 124;
}
