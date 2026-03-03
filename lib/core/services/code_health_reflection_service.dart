// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../config/project_config.dart';
import '../models/code_health_models.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

/// Layer 3: LLM-powered root cause analysis for code health.
///
/// Triggered only when Layer 2 (deja-vu) detects behavioral patterns.
/// Reads affected source files (truncated to token budget) and asks the
/// LLM to identify architectural root causes behind recurring signals.
class CodeHealthReflectionService {
  CodeHealthReflectionService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  /// Analyze hotspot modules for root causes using LLM.
  ///
  /// [triggeringSignals] should contain Layer 1+2 signals that triggered
  /// this reflection. Returns structured refactoring suggestions as
  /// [CodeHealthSignal] objects with layer [HealthSignalLayer.architectureReflection].
  Future<List<CodeHealthSignal>> reflect(
    String projectRoot, {
    required List<CodeHealthSignal> triggeringSignals,
    required ProjectConfig config,
  }) async {
    if (triggeringSignals.isEmpty) return const [];

    final prompt = _assemblePrompt(
      projectRoot,
      signals: triggeringSignals,
      budgetTokens: config.codeHealthLlmBudgetTokens,
    );

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    if (!result.response.ok) return const [];

    return _parseResponse(result.response.stdout);
  }

  String _assemblePrompt(
    String projectRoot, {
    required List<CodeHealthSignal> signals,
    required int budgetTokens,
  }) {
    final buffer = StringBuffer();

    // Section 1: Triggering signals.
    buffer.writeln('## Code Health Signals Detected');
    buffer.writeln();
    for (final signal in signals) {
      buffer.writeln(
        '- [${signal.layer.name}] (confidence: '
        '${signal.confidence.toStringAsFixed(2)}): ${signal.finding}',
      );
      if (signal.affectedFiles.isNotEmpty) {
        buffer.writeln('  Files: ${signal.affectedFiles.join(', ')}');
      }
    }
    buffer.writeln();

    // Section 2: Affected file contents (truncated to budget).
    final affectedFiles = <String>{};
    for (final signal in signals) {
      affectedFiles.addAll(signal.affectedFiles);
    }

    // Reserve ~30% of budget for prompt structure and response.
    final contentBudgetChars = (budgetTokens * 4 * 0.7).toInt();
    var usedChars = 0;

    buffer.writeln('## Affected Source Files');
    buffer.writeln();

    for (final filePath in affectedFiles) {
      if (usedChars >= contentBudgetChars) {
        buffer.writeln('(remaining files omitted due to token budget)');
        break;
      }

      final fullPath = '$projectRoot${Platform.pathSeparator}$filePath';
      final file = File(fullPath);
      if (!file.existsSync()) continue;

      String content;
      try {
        content = file.readAsStringSync();
      } catch (_) {
        continue;
      }

      final remaining = contentBudgetChars - usedChars;
      if (content.length > remaining) {
        content = '${content.substring(0, remaining)}\n... (truncated)';
      }

      buffer.writeln('### $filePath');
      buffer.writeln('```dart');
      buffer.writeln(content);
      buffer.writeln('```');
      buffer.writeln();

      usedChars += content.length;
    }

    // Section 3: Instructions.
    buffer.writeln('## Instructions');
    buffer.writeln();
    buffer.writeln(
      'Identify the root causes behind these recurring patterns.',
    );
    buffer.writeln(
      'For each root cause found, output a structured finding block:',
    );
    buffer.writeln();
    buffer.writeln(
      'FINDING: <concise description of the architectural issue>',
    );
    buffer.writeln('FILES: <comma-separated affected file paths>');
    buffer.writeln('ACTION: <specific refactoring suggestion>');
    buffer.writeln('CONFIDENCE: <0.0-1.0>');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(
      'Only report findings you are confident about. '
      'Do not invent issues not supported by the signals above.',
    );

    return buffer.toString();
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(
      projectRoot,
      'code_health_reflection',
    );
    if (override != null) return override;

    return 'You are a senior software architect specializing in code health '
        'and refactoring analysis. You analyze code patterns, identify root '
        'causes of recurring issues, and suggest targeted architectural '
        'improvements. Be precise and evidence-based — only report issues '
        'directly supported by the provided signals and code.';
  }

  /// Parse structured findings from the LLM response.
  List<CodeHealthSignal> _parseResponse(String response) {
    final signals = <CodeHealthSignal>[];
    final blocks = response.split('---');

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final finding = _extractField(trimmed, 'FINDING');
      if (finding == null) continue;

      final filesRaw = _extractField(trimmed, 'FILES');
      final action = _extractField(trimmed, 'ACTION');
      final confidenceRaw = _extractField(trimmed, 'CONFIDENCE');

      final files = filesRaw
              ?.split(',')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList() ??
          const <String>[];

      var confidence = 0.7; // default if not specified
      if (confidenceRaw != null) {
        final parsed = double.tryParse(confidenceRaw);
        if (parsed != null) {
          confidence = parsed.clamp(0.0, 1.0);
        }
      }

      signals.add(CodeHealthSignal(
        layer: HealthSignalLayer.architectureReflection,
        confidence: confidence,
        finding: finding,
        affectedFiles: files,
        suggestedAction: action,
      ));
    }

    return signals;
  }

  String? _extractField(String block, String fieldName) {
    final pattern = RegExp(
      '^$fieldName:\\s*(.+)',
      multiLine: true,
      caseSensitive: false,
    );
    final match = pattern.firstMatch(block);
    return match?.group(1)?.trim();
  }
}
