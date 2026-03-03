import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/config/project_type.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/services/agent_context_service.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/config_refinement_service.dart';

void main() {
  late String root;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('config_refinement_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
  });

  test(
    'builds prompt with vision, architecture, project type, and config',
    () async {
      final agent = _CapturingAgentService('project:\n  type: "python"\n');
      final service = ConfigRefinementService(agentService: agent);

      final result = await service.refineConfig(
        root,
        visionContent: 'Build a secure internal API service.',
        architectureContent: '## Modules\n- api\n- core\n- storage',
        projectType: ProjectType.python,
        currentConfig: 'project:\n  type: "unknown"\n',
      );

      expect(result, isNotNull);
      expect(result!.configContent, contains('type: "python"'));
      expect(agent.lastPrompt, isNotNull);
      expect(agent.lastPrompt, contains('## Project Type'));
      expect(agent.lastPrompt, contains('python'));
      expect(
        agent.lastPrompt,
        contains('Build a secure internal API service.'),
      );
      expect(agent.lastPrompt, contains('## Modules'));
      expect(agent.lastPrompt, contains('type: "unknown"'));
    },
  );

  test('returns null when agent output is empty', () async {
    final service = ConfigRefinementService(
      agentService: _CapturingAgentService('   '),
    );

    final result = await service.refineConfig(
      root,
      visionContent: 'Build a CLI tool.',
      architectureContent: '## Modules\n- cli',
      projectType: ProjectType.dartFlutter,
      currentConfig: 'project:\n  type: "dart_flutter"\n',
    );

    expect(result, isNull);
  });

  test('uses strategy system prompt override when provided', () async {
    final agent = _CapturingAgentService('project:\n  type: "go"\n');
    final service = ConfigRefinementService(
      agentService: agent,
      contextService: _FakeContextService(
        overridePrompt: 'STRATEGY_PERSONA_MARKER',
      ),
    );

    await service.refineConfig(
      root,
      visionContent: 'Build a service.',
      architectureContent: '## Modules\n- core',
      projectType: ProjectType.go,
      currentConfig: 'project:\n  type: "unknown"\n',
    );

    expect(agent.lastSystemPrompt, contains('STRATEGY_PERSONA_MARKER'));
  });
}

class _CapturingAgentService extends AgentService {
  _CapturingAgentService(this.output);

  final String output;
  String? lastPrompt;
  String? lastSystemPrompt;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    lastSystemPrompt = request.systemPrompt;
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}

class _FakeContextService extends AgentContextService {
  _FakeContextService({required this.overridePrompt});

  final String? overridePrompt;

  @override
  String? loadSystemPrompt(String projectRoot, String agentKey) {
    return overridePrompt;
  }
}
