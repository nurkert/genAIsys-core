// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'init_orchestrator_service.dart';

// ── Outcome types ────────────────────────────────────────────────────────────

sealed class InitStageOutcome {}

/// The stage completed successfully; advance to the next stage.
class InitStageContinue extends InitStageOutcome {}

/// The Verification stage rejected the artifacts; restart from stage 1.
class InitStageRetry extends InitStageOutcome {
  InitStageRetry(this.reason);
  final String reason;
}

/// A non-recoverable failure; abort the pipeline.
class InitStageFailed extends InitStageOutcome {
  InitStageFailed(this.reason);
  final String reason;
}

// ── Stage interface ──────────────────────────────────────────────────────────

abstract class InitPipelineStage {
  String get name;

  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

extension _StageHelpers on InitPipelineStage {
  /// Runs the agent and returns (stdout, ok).  Returns [InitStageFailed] if
  /// the response is empty or the exit code is non-zero.
  ///
  /// When [stripFences] is true (default), leading/trailing markdown/yaml/
  /// generic code fences are removed so artifact content is stored clean.
  Future<(String output, InitStageOutcome? failure)> _runAgent(
    AgentService agentService,
    String projectRoot,
    String prompt, {
    bool stripFences = true,
  }) async {
    final AgentServiceResult result;
    try {
      result = await agentService.run(
        projectRoot,
        AgentRequest(prompt: prompt, workingDirectory: projectRoot),
      );
    } catch (e) {
      return ('', InitStageFailed('Agent invocation error in $name: $e'));
    }

    if (!result.response.ok) {
      return (
        '',
        InitStageFailed(
          'Agent returned exit ${result.response.exitCode} in $name: '
          '${result.response.stderr.trim()}',
        ),
      );
    }

    var output = result.response.stdout.trim();
    if (output.isEmpty) {
      return ('', InitStageFailed('Agent produced empty output in $name.'));
    }

    if (stripFences) {
      output = _stripCodeFences(output);
    }

    return (output, null);
  }

  /// Strips a single outermost code fence block from [text] if present.
  ///
  /// Handles ` ```<lang>\n...\n``` ` and bare ` ```\n...\n``` `. Only the
  /// outermost fence is removed; inner fences in the content are preserved.
  String _stripCodeFences(String text) {
    final trimmed = text.trim();
    // Must start with ``` (possibly with a language tag) and have a newline.
    final firstNewline = trimmed.indexOf('\n');
    if (firstNewline < 0) return trimmed;

    final firstLine = trimmed.substring(0, firstNewline).trim();
    if (!firstLine.startsWith('```')) return trimmed;

    // Find the closing fence — last line that is exactly ```.
    final inner = trimmed.substring(firstNewline + 1);
    final lastFenceIndex = inner.lastIndexOf('\n```');
    if (lastFenceIndex < 0) {
      // Closing fence not found — return without stripping to avoid data loss.
      return trimmed;
    }

    // Check nothing (or only whitespace) follows the closing fence.
    final afterFence = inner.substring(lastFenceIndex + 4).trim();
    if (afterFence.isNotEmpty) return trimmed;

    return inner.substring(0, lastFenceIndex).trim();
  }
}

// ── Concrete stages ──────────────────────────────────────────────────────────

class _VisionStage extends InitPipelineStage {
  @override
  String get name => 'vision';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final existing = ctx.existingVision != null
        ? '\n\n## Existing VISION.md (incorporate relevant parts)\n${ctx.existingVision}'
        : '';
    final prompt =
        'You are initializing a software project. Based on the following input '
        'document, write a concise VISION.md that describes the project purpose, '
        'target users, and high-level goals. Output only the Markdown content, '
        'no explanations.'
        '$existing\n\n'
        '## Input Document\n${ctx.normalizedInputText}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.vision = output;
    return InitStageContinue();
  }
}

class _ArchitectureStage extends InitPipelineStage {
  @override
  String get name => 'architecture';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final existing = ctx.existingArchitecture != null
        ? '\n\n## Existing ARCHITECTURE.md (incorporate relevant parts)\n${ctx.existingArchitecture}'
        : '';
    final prompt =
        'You are initializing a software project. Based on the project vision '
        'below, write a concise ARCHITECTURE.md describing the system components, '
        'data flow, and key technical decisions. Output only the Markdown content, '
        'no explanations.'
        '$existing\n\n'
        '## Project Vision\n${ctx.vision}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.architecture = output;
    return InitStageContinue();
  }
}

class _BacklogStage extends InitPipelineStage {
  @override
  String get name => 'backlog';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final existing = ctx.existingTasks != null
        ? '\n\n## Existing TASKS.md (incorporate open items)\n${ctx.existingTasks}'
        : '';
    final sprintSize = ctx.sprintSize.clamp(1, 50);
    final prompt =
        'You are initializing a software project. Based on the vision and '
        'architecture below, write the **first development sprint** (Sprint 1) '
        'for TASKS.md. Include up to $sprintSize focused P1 tasks forming a '
        'coherent MVP foundation. Use the format: '
        '`- [ ] [P1] [CORE] Task title`. '
        '**Start with `## Sprint 1`** as the only section header. '
        'Focus on the most critical core functionality only — later sprints will '
        'handle QA, docs, and secondary features. Output only the Markdown '
        'content, no explanations.'
        '$existing\n\n'
        '## Project Vision\n${ctx.vision}\n\n'
        '## Architecture\n${ctx.architecture}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.backlog = output;
    return InitStageContinue();
  }
}

class _ConfigStage extends InitPipelineStage {
  @override
  String get name => 'config';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final existing = ctx.existingConfig != null
        ? '\n\n## Existing config.yml (preserve valid settings)\n${ctx.existingConfig}'
        : '';
    final prompt =
        'You are initializing a software project. Based on the vision and '
        'architecture below, refine the Genaisys config.yml. Set appropriate '
        'quality_gate, shell_allowlist, safe_write roots, and autopilot settings '
        'for the detected project type. This project uses AI-driven sprint '
        'planning: set `autopilot.sprint_planning_enabled: true` in config.yml. '
        'Output only the YAML content, no explanations.'
        '$existing\n\n'
        '## Project Vision\n${ctx.vision}\n\n'
        '## Architecture\n${ctx.architecture}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.config = output;
    return InitStageContinue();
  }
}

class _RulesStage extends InitPipelineStage {
  @override
  String get name => 'rules';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final existing = ctx.existingRules != null
        ? '\n\n## Existing RULES.md (incorporate relevant guidelines)\n${ctx.existingRules}'
        : '';
    final prompt =
        'You are initializing a software project. Based on the vision and '
        'architecture below, write a RULES.md with agent coding guidelines '
        'specific to this project (conventions, forbidden patterns, mandatory '
        'checks). Output only the Markdown content, no explanations.'
        '$existing\n\n'
        '## Project Vision\n${ctx.vision}\n\n'
        '## Architecture\n${ctx.architecture}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.rules = output;
    return InitStageContinue();
  }
}

class _VerificationStage extends InitPipelineStage {
  @override
  String get name => 'verification';

  @override
  Future<InitStageOutcome> execute(
    InitOrchestrationContext ctx,
    AgentService agentService,
    String projectRoot,
  ) async {
    final prompt =
        'You are reviewing the following 5 project init artifacts for '
        'consistency, completeness, and quality. Output either:\n'
        '  APPROVE\n'
        'or:\n'
        '  REJECT\n'
        '  <reason explaining what needs to improve>\n\n'
        '## VISION.md\n${ctx.vision}\n\n'
        '## ARCHITECTURE.md\n${ctx.architecture}\n\n'
        '## TASKS.md\n${ctx.backlog}\n\n'
        '## config.yml\n${ctx.config}\n\n'
        '## RULES.md\n${ctx.rules}';

    final (output, failure) = await _runAgent(agentService, projectRoot, prompt);
    if (failure != null) return failure;

    ctx.verification = output;

    final upperOutput = output.toUpperCase();
    if (upperOutput.startsWith('APPROVE') || upperOutput.contains('\nAPPROVE')) {
      return InitStageContinue();
    }

    // Extract the rejection reason (everything after the first line or
    // after the REJECT keyword).
    final lines = output.split('\n');
    final rejectLineIndex = lines.indexWhere(
      (l) => l.trim().toUpperCase().startsWith('REJECT'),
    );
    final reason = rejectLineIndex >= 0 && rejectLineIndex + 1 < lines.length
        ? lines.sublist(rejectLineIndex + 1).join('\n').trim()
        : output.trim();

    return InitStageRetry(reason.isNotEmpty ? reason : 'Verification rejected without details.');
  }
}
