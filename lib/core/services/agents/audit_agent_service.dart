// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../agents/agent_runner.dart';
import '../../policy/language_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../agent_context_service.dart';
import 'agent_service.dart';

enum AuditKind { architecture, security, docs, ui, refactor }

class AuditAgentResult {
  const AuditAgentResult({
    required this.kind,
    required this.response,
    required this.usedFallback,
  });

  final AuditKind kind;
  final AgentResponse response;
  final bool usedFallback;
}

class AuditAgentService {
  AuditAgentService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<AuditAgentResult> run(
    String projectRoot, {
    required AuditKind kind,
  }) async {
    final prompt = _buildPrompt(projectRoot, kind);
    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot, kind),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'audit_completed',
      message: 'Audit completed',
      data: {
        'root': projectRoot,
        'kind': kind.name,
        'used_fallback': result.usedFallback,
        'exit_code': result.response.exitCode,
      },
    );

    return AuditAgentResult(
      kind: kind,
      response: result.response,
      usedFallback: result.usedFallback,
    );
  }

  String _buildPrompt(String projectRoot, AuditKind kind) {
    final layout = ProjectLayout(projectRoot);
    final rules = _readIfExists(layout.rulesPath);
    final vision = _readIfExists(layout.visionPath);

    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln('');
    buffer.writeln('Audit focus: ${kind.name}');
    buffer.writeln('');
    if (vision != null) {
      buffer.writeln('Project Vision:');
      buffer.writeln(vision.trim());
      buffer.writeln('');
    }
    if (rules != null) {
      buffer.writeln('Project Rules:');
      buffer.writeln(rules.trim());
      buffer.writeln('');
    }
    buffer.writeln('Perform a focused repository audit for ${kind.name}.');
    buffer.writeln('Provide:');
    buffer.writeln('- Summary (1-3 bullets)');
    buffer.writeln('- Findings with severity (High/Medium/Low)');
    buffer.writeln('- Recommended next actions');
    buffer.writeln('');
    buffer.writeln('Return only markdown.');
    return buffer.toString();
  }

  String _systemPrompt(String projectRoot, AuditKind kind) {
    final override = _contextService.loadSystemPrompt(
      projectRoot,
      _auditPromptKey(kind),
    );
    if (override != null) {
      return override;
    }
    final fallback = _contextService.loadSystemPrompt(
      projectRoot,
      _kindKey(kind),
    );
    if (fallback != null) {
      return fallback;
    }
    switch (kind) {
      case AuditKind.architecture:
        return 'You are a senior system architect conducting an audit. '
            'Focus on module boundaries, coupling, layering, and '
            'architecture drift. Provide actionable guidance.';
      case AuditKind.security:
        return 'You are a senior security auditor. Focus on vulnerabilities, '
            'unsafe defaults, secret exposure, and policy violations.';
      case AuditKind.docs:
        return 'You are a senior technical writer auditing documentation. '
            'Focus on accuracy, completeness, and operator clarity.';
      case AuditKind.ui:
        return 'You are a senior UI/UX auditor. Focus on consistency, '
            'accessibility, and user workflow clarity.';
      case AuditKind.refactor:
        return 'You are a senior refactoring specialist auditing technical debt. '
            'Focus on duplication, complexity, and maintainability risks.';
    }
  }

  String _auditPromptKey(AuditKind kind) => 'audit_${_kindKey(kind)}';

  String _kindKey(AuditKind kind) {
    switch (kind) {
      case AuditKind.architecture:
        return 'architecture';
      case AuditKind.security:
        return 'security';
      case AuditKind.docs:
        return 'docs';
      case AuditKind.ui:
        return 'ui';
      case AuditKind.refactor:
        return 'refactor';
    }
  }

  String? _readIfExists(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync();
    return content.trim().isEmpty ? null : content;
  }
}
