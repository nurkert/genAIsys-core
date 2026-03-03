// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../agents/agent_runner.dart';
import '../../policy/language_policy.dart';
import '../agent_context_service.dart';
import 'agent_service.dart';

class AnalysisAgentService {
  AnalysisAgentService({
    AgentService? agentService,
    AgentContextService? contextService,
  }) : _agentService = agentService ?? AgentService(),
       _contextService = contextService ?? AgentContextService();

  final AgentService _agentService;
  final AgentContextService _contextService;

  Future<String> analyzeFailure(
    String projectRoot, {
    required String taskTitle,
    required String failureContext,
    String? lastAttemptOutput,
  }) async {
    final prompt =
        '''
${LanguagePolicy.describe()}

Task: $taskTitle

The last implementation attempt failed or was rejected.
Context/Feedback:
$failureContext

${lastAttemptOutput != null ? _formatLastAttempt(lastAttemptOutput) : ''}

Analyze the root cause of this failure.
Provide a concise debugging strategy and specific technical steps to fix it.
Do not write code, only provide the analytical strategy.
''';

    final request = AgentRequest(
      prompt: prompt,
      systemPrompt: _systemPrompt(projectRoot),
      workingDirectory: projectRoot,
    );

    final result = await _agentService.run(projectRoot, request);
    return result.response.stdout;
  }

  String _systemPrompt(String projectRoot) {
    final override = _contextService.loadSystemPrompt(projectRoot, 'analysis');
    if (override != null) {
      return override;
    }
    return 'You are a senior debugging expert and systems analyst. '
        'Your goal is to perform root-cause analysis and provide precise, '
        'actionable fix strategies for complex engineering failures.';
  }

  String _formatLastAttempt(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return 'Last Agent Output:\n$trimmed';
  }
}
