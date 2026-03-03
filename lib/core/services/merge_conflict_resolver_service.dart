// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../agents/agent_runner.dart';
import '../policy/language_policy.dart';
import 'agent_context_service.dart';
import 'agents/agent_service.dart';

class MergeConflictResolutionResult {
  const MergeConflictResolutionResult({
    required this.response,
    required this.usedFallback,
  });

  final AgentResponse response;
  final bool usedFallback;
}

class MergeConflictResolverService {
  MergeConflictResolverService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<MergeConflictResolutionResult> resolve(
    String projectRoot, {
    required String baseBranch,
    required String featureBranch,
    required List<String> conflictPaths,
  }) async {
    final request = AgentRequest(
      prompt: _buildPrompt(
        baseBranch: baseBranch,
        featureBranch: featureBranch,
        conflictPaths: conflictPaths,
      ),
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    return MergeConflictResolutionResult(
      response: result.response,
      usedFallback: result.usedFallback,
    );
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(projectRoot, 'merge');
    if (override != null) {
      return override;
    }
    final core = _contextService.loadSystemPrompt(projectRoot, 'core');
    if (core != null) {
      return core;
    }
    return 'You are a senior engineer. Resolve merge conflicts carefully, '
        'keeping behavior correct and changes minimal.';
  }

  String _buildPrompt({
    required String baseBranch,
    required String featureBranch,
    required List<String> conflictPaths,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(LanguagePolicy.describe());
    buffer.writeln('');
    buffer.writeln('Resolve git merge conflicts and update the files on disk.');
    buffer.writeln('Base branch: $baseBranch');
    buffer.writeln('Feature branch: $featureBranch');
    buffer.writeln('');
    buffer.writeln('Conflicted files:');
    for (final path in conflictPaths) {
      buffer.writeln('- $path');
    }
    buffer.writeln('');
    buffer.writeln('Instructions:');
    buffer.writeln(
      '- Only resolve conflicts. Do not refactor or add new features.',
    );
    buffer.writeln('- Remove conflict markers (<<<<<<<, =======, >>>>>>>).');
    buffer.writeln('- Preserve intent from both branches when possible.');
    buffer.writeln(
      '- Keep changes minimal and consistent with existing style.',
    );
    buffer.writeln('- Do not run tests unless needed to resolve ambiguity.');
    buffer.writeln('- Do not commit; only update the working tree.');
    return buffer.toString();
  }
}
