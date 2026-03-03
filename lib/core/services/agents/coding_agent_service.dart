// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_error_hints.dart';
import '../../agents/agent_runner.dart';
import '../../config/project_config.dart';
import '../../ids/task_slugger.dart';
import '../../models/task.dart';
import '../../policy/language_policy.dart';
import '../../project_layout.dart';
import '../../security/redaction_service.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import '../agent_context_service.dart';
import 'agent_service.dart';

class CodingAgentResult {
  CodingAgentResult({
    required this.path,
    required this.usedFallback,
    required this.response,
    this.partialOutputAvailable = false,
  });

  final String path;
  final bool usedFallback;
  final AgentResponse response;

  /// Whether the coding agent timed out but produced non-empty stdout output.
  /// Callers can use this to decide whether partial work can be salvaged.
  final bool partialOutputAvailable;
}

class CodingAgentService {
  CodingAgentService({
    AgentService? agentService,
    AgentContextService? contextService,
    RedactionService? redactionService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService(),
       _redactionService = redactionService ?? RedactionService.shared;

  final AgentService _agentService;
  final AgentContextService _contextService;
  final RedactionService _redactionService;

  Future<CodingAgentResult> run(
    String projectRoot, {
    required String prompt,
    String? systemPrompt,
    TaskCategory? taskCategory,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureStateFile(layout);

    final state = StateStore(layout.statePath).read();
    final activeTitle = state.activeTaskTitle;
    if (activeTitle == null || activeTitle.trim().isEmpty) {
      throw StateError('No active task set. Use: activate');
    }

    Directory(layout.attemptsDir).createSync(recursive: true);
    final slug = TaskSlugger.slug(activeTitle);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final attemptPath =
        '${layout.attemptsDir}${Platform.pathSeparator}$slug-$timestamp.txt';

    final config = ProjectConfig.load(projectRoot);
    final resolvedSystemPrompt =
        systemPrompt ?? _resolveDefaultSystemPrompt(projectRoot);
    final environment = <String, String>{};
    final categoryKey = taskCategory?.name ?? '';
    final overrides = List<String>.from(config.codexCliConfigOverrides);
    _ensureCodexSandboxOverride(overrides);
    if (categoryKey.isNotEmpty) {
      final effort = config.reasoningEffortForCategory(categoryKey);
      overrides.add('reasoning_effort=$effort');
    }
    if (overrides.isNotEmpty) {
      // CodexRunner will expand this into `codex exec -c ... -c ... -`.
      environment['GENAISYS_CODEX_CLI_CONFIG_OVERRIDES'] = overrides.join(
        '\n',
      );
    }
    final claudeOverrides = List<String>.from(
      config.claudeCodeCliConfigOverrides,
    );
    _ensureClaudeCodePermissionOverride(claudeOverrides);
    if (claudeOverrides.isNotEmpty) {
      environment['GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES'] =
          claudeOverrides.join('\n');
    }
    final geminiOverrides = List<String>.from(
      config.geminiCliConfigOverrides,
    );
    _ensureGeminiYoloOverride(geminiOverrides);
    if (geminiOverrides.isNotEmpty) {
      environment['GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES'] =
          geminiOverrides.join('\n');
    }
    final vibeOverrides = List<String>.from(
      config.vibeCliConfigOverrides,
    );
    _ensureVibeAutoApproveOverride(vibeOverrides);
    if (vibeOverrides.isNotEmpty) {
      environment['GENAISYS_VIBE_CLI_CONFIG_OVERRIDES'] =
          vibeOverrides.join('\n');
    }
    final ampOverrides = List<String>.from(
      config.ampCliConfigOverrides,
    );
    _ensureAmpPermissionOverride(ampOverrides);
    if (ampOverrides.isNotEmpty) {
      environment['GENAISYS_AMP_CLI_CONFIG_OVERRIDES'] =
          ampOverrides.join('\n');
    }
    Duration? categoryTimeout;
    if (categoryKey.isNotEmpty) {
      categoryTimeout = config.agentTimeoutForCategory(categoryKey);
    }
    final request = AgentRequest(
      prompt: _buildPrompt(prompt, config),
      systemPrompt: resolvedSystemPrompt,
      workingDirectory: projectRoot,
      environment: environment.isEmpty ? null : environment,
      timeout: categoryTimeout,
    );

    final result = await _agentService.run(projectRoot, request);
    final attemptOutput = _formatAttemptOutput(result.response);
    final sanitizedAttempt = _redactionService.sanitizeText(attemptOutput);
    File(attemptPath).writeAsStringSync(sanitizedAttempt.value);

    final isTimeout = result.response.exitCode == _timeoutExitCode;
    final partialOutputAvailable =
        isTimeout && result.response.stdout.trim().isNotEmpty;

    RunLogStore(layout.runLogPath).append(
      event: 'coding_attempt',
      message: 'Captured coding agent output',
      data: {
        'root': projectRoot,
        'task': activeTitle,
        'file': attemptPath,
        'used_fallback': result.usedFallback,
        'exit_code': result.response.exitCode,
        if (result.response.stderr.trim().isNotEmpty)
          'stderr_excerpt': _truncate(result.response.stderr.trim(), 400),
        'redactions_applied': sanitizedAttempt.report.applied,
        'redaction_replacements': sanitizedAttempt.report.replacementCount,
        'redaction_types': sanitizedAttempt.report.types,
        if (isTimeout) 'partial_output_available': partialOutputAvailable,
      },
    );

    _throwIfFailed(result.response, attemptPath);

    return CodingAgentResult(
      path: attemptPath,
      usedFallback: result.usedFallback,
      response: result.response,
      partialOutputAvailable: partialOutputAvailable,
    );
  }

  void _ensureStateFile(ProjectLayout layout) {
    if (!File(layout.statePath).existsSync()) {
      throw StateError('No STATE.json found at: ${layout.statePath}');
    }
  }

  String _buildPrompt(String prompt, ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln();

    buffer.writeln('## Execution Constraints');
    buffer.writeln(
      '- Work as a senior engineer: clean, explicit, maintainable code.',
    );
    buffer.writeln('- Implement ONE smallest meaningful increment only.');
    buffer.writeln('- Do not mix unrelated features or drive-by refactors.');
    buffer.writeln(
      '- You are NOT responsible for git operations (branch/commit/push/merge). Genaisys handles delivery.',
    );
    buffer.writeln(
      '- Prefer explicit naming, simple control flow, and strong typing.',
    );
    buffer.writeln(
      '- Add focused tests when behavior changes. Untested behavior changes will be rejected.',
    );
    buffer.writeln(
      '- Always produce a concrete change (git diff). Do not respond with narration-only output.',
    );
    buffer.writeln(
      '- If you cannot safely proceed, output a short BLOCK reason instead of stalling.',
    );
    buffer.writeln();

    buffer.writeln('## Persistence Directive');
    buffer.writeln(
      '- If your first approach fails, try an alternative before giving up.',
    );
    buffer.writeln(
      '- If a file is missing, search for it. If an API changed, read the source.',
    );
    buffer.writeln(
      '- Only emit BLOCK after exhausting all reasonable alternatives.',
    );

    if (config.safeWriteEnabled) {
      buffer.writeln();
      buffer.writeln('## Safe Write Policy (ENFORCED)');
      buffer.writeln(
        'You may ONLY create or modify files within these roots:',
      );
      for (final root in config.safeWriteRoots) {
        buffer.writeln('  - $root');
      }
      buffer.writeln(
        'Writes outside these roots will be rejected and rolled back automatically.',
      );
    }

    if (config.shellAllowlist.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Shell Allowlist (ENFORCED)');
      buffer.writeln('You may ONLY execute these shell commands:');
      for (final cmd in config.shellAllowlist) {
        buffer.writeln('  - $cmd');
      }
      buffer.writeln(
        'Any other command will be blocked. Do not attempt workarounds.',
      );
    }

    buffer.writeln();
    buffer.writeln(prompt);
    return buffer.toString();
  }

  String _defaultSystemPrompt() {
    return 'You are a senior coding agent embedded in an automated '
        'orchestration pipeline. Your sole purpose: deliver one minimal, '
        'correct, well-tested increment per invocation.\n\n'
        'Behavioral rules:\n'
        '- Never narrate — always produce file changes that result in a git diff.\n'
        '- If your first approach fails, try an alternative before giving up.\n'
        '- If blocked with no alternatives, emit a structured BLOCK reason immediately.\n'
        '- Keep changes atomic: one concern per invocation, no drive-by refactors.';
  }

  String _resolveDefaultSystemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(projectRoot, 'core');
    return override ?? _defaultSystemPrompt();
  }

  String _formatAttemptOutput(AgentResponse response) {
    final stdout = response.stdout;
    final stderr = response.stderr;
    if (stderr.trim().isEmpty) {
      return stdout;
    }
    if (stdout.trim().isEmpty) {
      return 'STDERR:\n$stderr';
    }
    return 'STDOUT:\n$stdout\n\nSTDERR:\n$stderr';
  }

  void _throwIfFailed(AgentResponse response, String attemptPath) {
    if (response.ok) {
      return;
    }
    if (response.exitCode == _timeoutExitCode) {
      final hasPartialOutput = response.stdout.trim().isNotEmpty;
      throw TimeoutException(
        'Coding agent timed out. '
        'partial_output_available=$hasPartialOutput. '
        'Attempt log: $attemptPath',
      );
    }
    final stderr = response.stderr.trim();
    final stdout = response.stdout.trim();
    final detail = stderr.isNotEmpty ? stderr : stdout;
    final hint = _executionHint(response.exitCode, detail);
    final message = StringBuffer()
      ..writeln('Coding agent failed with exit_code ${response.exitCode}.')
      ..writeln('Attempt log: $attemptPath');
    if (detail.isNotEmpty) {
      message.writeln('Details: ${_truncate(detail, 600)}');
    }
    if (hint.isNotEmpty) {
      message.writeln(hint);
    }
    throw StateError(message.toString().trim());
  }

  String _executionHint(int exitCode, String detail) {
    if (detail.toLowerCase().contains('hint:')) {
      return '';
    }
    return AgentErrorHints.hintForExitCode(exitCode, detail: detail);
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…';
  }

  void _ensureCodexSandboxOverride(List<String> overrides) {
    final hasSandboxOverride = overrides.any((entry) {
      final normalized = entry.trim().toLowerCase().replaceAll(' ', '');
      return normalized.startsWith('sandbox_mode=');
    });
    if (!hasSandboxOverride) {
      overrides.add('sandbox_mode="danger-full-access"');
    }
  }

  void _ensureClaudeCodePermissionOverride(List<String> overrides) {
    if (!overrides.any((e) =>
        e.trim().toLowerCase() == '--dangerously-skip-permissions')) {
      overrides.add('--dangerously-skip-permissions');
    }
    if (!overrides.any((e) =>
        e.trim().toLowerCase() == '--no-session-persistence')) {
      overrides.add('--no-session-persistence');
    }
  }

  void _ensureGeminiYoloOverride(List<String> overrides) {
    // GeminiRunner already passes `--approval-mode yolo` by default.
    // Newer Gemini CLI rejects `-y`/`--yolo` when `--approval-mode` is also
    // present, so only inject if the user explicitly cleared the approval mode.
    final hasApprovalMode = overrides.any((entry) {
      final normalized = entry.trim().toLowerCase();
      return normalized == '-y' ||
          normalized == '--yolo' ||
          normalized.startsWith('--approval-mode');
    });
    if (!hasApprovalMode) {
      // Runner default args already include --approval-mode yolo; no-op.
    }
  }

  void _ensureVibeAutoApproveOverride(List<String> overrides) {
    final hasAutoApprove = overrides.any((entry) {
      final normalized = entry.trim().toLowerCase();
      return normalized == '--auto-approve';
    });
    if (!hasAutoApprove) {
      overrides.add('--auto-approve');
    }
  }

  void _ensureAmpPermissionOverride(List<String> overrides) {
    final hasPermission = overrides.any((entry) {
      final normalized = entry.trim().toLowerCase();
      return normalized == '--dangerously-allow-all';
    });
    if (!hasPermission) {
      overrides.add('--dangerously-allow-all');
    }
  }

  static const int _timeoutExitCode = 124;
}
