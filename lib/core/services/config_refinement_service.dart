// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../agents/agent_runner.dart';
import '../config/project_type.dart';
import '../policy/language_policy.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

class ConfigRefinementResult {
  const ConfigRefinementResult({
    required this.configContent,
    required this.usedFallback,
  });

  final String configContent;
  final bool usedFallback;
}

/// Refines `config.yml` using project intent and architecture context.
class ConfigRefinementService {
  ConfigRefinementService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<ConfigRefinementResult?> refineConfig(
    String projectRoot, {
    required String visionContent,
    required String architectureContent,
    required ProjectType projectType,
    required String currentConfig,
  }) async {
    final normalizedVision = visionContent.trim();
    final normalizedArchitecture = architectureContent.trim();
    final normalizedConfig = currentConfig.trim();
    if (normalizedVision.isEmpty) {
      throw StateError('Config refinement requires non-empty vision content.');
    }
    if (normalizedArchitecture.isEmpty) {
      throw StateError(
        'Config refinement requires non-empty architecture content.',
      );
    }
    if (normalizedConfig.isEmpty) {
      throw StateError('Config refinement requires non-empty config content.');
    }

    final prompt = _buildPrompt(
      visionContent: normalizedVision,
      architectureContent: normalizedArchitecture,
      projectType: projectType,
      currentConfig: normalizedConfig,
    );

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final agentResult = await _agentService.run(projectRoot, request);
    final refinedConfig = agentResult.response.stdout.trim();
    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);
    if (refinedConfig.isEmpty) {
      runLog.append(
        event: 'config_refinement_empty',
        message: 'Config refinement agent returned empty output',
        data: {
          'root': projectRoot,
          'project_type': projectType.configKey,
          'error_class': 'planning',
          'error_kind': 'config_refinement_empty_output',
          'used_fallback': agentResult.usedFallback,
        },
      );
      return null;
    }

    runLog.append(
      event: 'config_refinement_completed',
      message: 'Config refinement completed',
      data: {
        'root': projectRoot,
        'project_type': projectType.configKey,
        'used_fallback': agentResult.usedFallback,
      },
    );

    return ConfigRefinementResult(
      configContent: refinedConfig,
      usedFallback: agentResult.usedFallback,
    );
  }

  String _buildPrompt({
    required String visionContent,
    required String architectureContent,
    required ProjectType projectType,
    required String currentConfig,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln();
    buffer.writeln('## Project Type');
    buffer.writeln(projectType.configKey);
    buffer.writeln();
    buffer.writeln('## Vision');
    buffer.writeln(visionContent);
    buffer.writeln();
    buffer.writeln('## Architecture');
    buffer.writeln(architectureContent);
    buffer.writeln();
    buffer.writeln('## Current Config');
    buffer.writeln('```yaml');
    buffer.writeln(currentConfig);
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('## Task');
    buffer.writeln('''
Refine the config.yml for this project.

Requirements:
- Keep output strictly as raw YAML for config.yml (no prose, no markdown fences).
- Align quality gates and policy strictness with the project type and architecture.
- Preserve existing keys unless a change is needed for correctness or better defaults.
- Keep settings deterministic and automation-friendly.
- Do not weaken review, safe-write, or shell allowlist safety guarantees.
''');
    return buffer.toString();
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(projectRoot, 'strategy');
    if (override != null) {
      return override;
    }
    return 'You are a senior configuration engineer. '
        'Produce safe, deterministic, and maintainable automation config.';
  }
}
