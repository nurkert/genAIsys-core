// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../agents/agent_runner.dart';
import '../policy/language_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

class ArchitecturePlanningResult {
  const ArchitecturePlanningResult({
    required this.architectureContent,
    required this.suggestedModules,
    required this.suggestedConstraints,
    required this.usedFallback,
  });

  final String architectureContent;
  final List<String> suggestedModules;
  final List<String> suggestedConstraints;
  final bool usedFallback;
}

class ArchitecturePlanningService {
  ArchitecturePlanningService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  /// Plans a technical architecture based on the project's VISION.md.
  ///
  /// Returns null if no VISION.md exists. Scans the project structure
  /// to provide context to the architecture agent.
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    final layout = ProjectLayout(projectRoot);
    final visionFile = File(layout.visionPath);
    if (!visionFile.existsSync()) {
      return null;
    }
    final visionContent = visionFile.readAsStringSync().trim();
    if (visionContent.isEmpty) {
      return null;
    }

    final rulesContent = _loadOptionalFile(layout.rulesPath);
    final projectScan = _scanProjectStructure(projectRoot);

    final prompt = _buildPrompt(
      visionContent: visionContent,
      rulesContent: rulesContent,
      projectScan: projectScan,
    );

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    final content = result.response.stdout.trim();

    if (content.isEmpty) {
      RunLogStore(layout.runLogPath).append(
        event: 'architecture_planning_empty',
        message: 'Architecture agent returned empty output',
        data: {
          'root': projectRoot,
          'used_fallback': result.usedFallback,
          'error_class': 'planning',
          'error_kind': 'architecture_empty_output',
        },
      );
      return null;
    }

    final modules = _extractModules(content);
    final constraints = _extractConstraints(content);

    RunLogStore(layout.runLogPath).append(
      event: 'architecture_planning_completed',
      message: 'Architecture planning completed',
      data: {
        'root': projectRoot,
        'modules_count': modules.length,
        'constraints_count': constraints.length,
        'used_fallback': result.usedFallback,
      },
    );

    return ArchitecturePlanningResult(
      architectureContent: content,
      suggestedModules: modules,
      suggestedConstraints: constraints,
      usedFallback: result.usedFallback,
    );
  }

  String _buildPrompt({
    required String visionContent,
    required String? rulesContent,
    required String projectScan,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln();
    buffer.writeln('## Project Vision');
    buffer.writeln(visionContent);
    buffer.writeln();

    if (rulesContent != null && rulesContent.isNotEmpty) {
      buffer.writeln('## Project Rules & Constraints');
      buffer.writeln(rulesContent);
      buffer.writeln();
    }

    if (projectScan.isNotEmpty) {
      buffer.writeln('## Current Project Structure');
      buffer.writeln(projectScan);
      buffer.writeln();
    }

    buffer.writeln('## Task');
    buffer.writeln('''
Based on the vision above, design a technical architecture document.

Requirements:
- Define the main modules/packages and their responsibilities.
- Specify dependency direction rules (which module may depend on which).
- Identify key interfaces and data flow patterns.
- List technology stack choices with brief justifications.
- Note any constraints, security boundaries, or performance considerations.

Format the output as a Markdown document suitable for ARCHITECTURE.md.
Use these sections:
1. ## Overview
2. ## Modules
3. ## Dependencies & Layer Rules
4. ## Key Interfaces
5. ## Technology Stack
6. ## Constraints & Boundaries

Keep it concise and actionable — this document will guide task planning and coding agents.
''');

    return buffer.toString();
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadCodingPersona(
      projectRoot,
      'architecture',
    );
    if (override != null) {
      return override;
    }
    return 'You are a senior software architect. '
        'Design clear, modular, and maintainable architectures. '
        'Prioritize separation of concerns, testability, and incremental delivery.';
  }

  String _scanProjectStructure(String projectRoot) {
    final entries = <String>[];
    final root = Directory(projectRoot);
    if (!root.existsSync()) {
      return '';
    }

    // Scan top-level files for tech stack hints.
    for (final entity in root.listSync()) {
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .lastOrNull ?? '';
      if (name.startsWith('.') && name != '.genaisys') {
        continue;
      }
      if (entity is File) {
        entries.add('- $name');
      } else if (entity is Directory) {
        final childCount = _safeChildCount(entity);
        entries.add('- $name/ ($childCount items)');
      }
    }

    return entries.join('\n');
  }

  int _safeChildCount(Directory dir) {
    try {
      return dir.listSync().length;
    } catch (_) {
      return 0;
    }
  }

  String? _loadOptionalFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync().trim();
    return content.isEmpty ? null : content;
  }

  List<String> _extractModules(String content) {
    final modules = <String>[];
    final lines = content.split('\n');
    var inModules = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('## modules')) {
        inModules = true;
        continue;
      }
      if (inModules && trimmed.startsWith('## ')) {
        break;
      }
      if (inModules && trimmed.startsWith('- ')) {
        final module = trimmed.substring(2).split(':').first.trim();
        if (module.isNotEmpty) {
          modules.add(module);
        }
      }
    }
    return List.unmodifiable(modules);
  }

  List<String> _extractConstraints(String content) {
    final constraints = <String>[];
    final lines = content.split('\n');
    var inConstraints = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().contains('constraint') &&
          trimmed.startsWith('## ')) {
        inConstraints = true;
        continue;
      }
      if (inConstraints && trimmed.startsWith('## ')) {
        break;
      }
      if (inConstraints && trimmed.startsWith('- ')) {
        final constraint = trimmed.substring(2).trim();
        if (constraint.isNotEmpty) {
          constraints.add(constraint);
        }
      }
    }
    return List.unmodifiable(constraints);
  }
}
