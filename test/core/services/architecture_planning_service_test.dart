import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';

void main() {
  late String root;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('arch_plan_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
  });

  test('returns null when VISION.md does not exist', () async {
    final layout = ProjectLayout(root);
    final visionFile = File(layout.visionPath);
    if (visionFile.existsSync()) visionFile.deleteSync();

    final service = ArchitecturePlanningService(
      agentService: _FakeAgentService('architecture output'),
    );

    final result = await service.planArchitecture(root);
    expect(result, isNull);
  });

  test('returns null when VISION.md is empty', () async {
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('   ');

    final service = ArchitecturePlanningService(
      agentService: _FakeAgentService('architecture output'),
    );

    final result = await service.planArchitecture(root);
    expect(result, isNull);
  });

  test('returns architecture content from agent', () async {
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('Build a task tracker app.');

    const agentOutput = '''
## Overview
A task tracker application.

## Modules
- core: Business logic
- ui: User interface
- storage: Persistence layer

## Dependencies & Layer Rules
ui → core → storage

## Key Interfaces
TaskRepository, TaskService

## Technology Stack
- Dart/Flutter

## Constraints & Boundaries
- Core must not import UI
''';

    final service = ArchitecturePlanningService(
      agentService: _FakeAgentService(agentOutput),
    );

    final result = await service.planArchitecture(root);

    expect(result, isNotNull);
    expect(result!.architectureContent, contains('## Overview'));
    expect(result.architectureContent, contains('## Modules'));
    expect(result.suggestedModules, containsAll(['core', 'ui', 'storage']));
    expect(result.suggestedConstraints, isNotEmpty);
    expect(result.suggestedConstraints.first, contains('Core must not import UI'));
  });

  test('returns null when agent returns empty output', () async {
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('Build something.');

    final service = ArchitecturePlanningService(
      agentService: _FakeAgentService(''),
    );

    final result = await service.planArchitecture(root);
    expect(result, isNull);
  });

  test('includes RULES.md content in prompt when available', () async {
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('Build a CLI tool.');
    File(layout.rulesPath).writeAsStringSync('No external dependencies.');

    final capturing = _CapturingAgentService('## Overview\nSimple CLI');
    final service = ArchitecturePlanningService(agentService: capturing);

    await service.planArchitecture(root);

    expect(capturing.lastPrompt, isNotNull);
    expect(capturing.lastPrompt, contains('No external dependencies'));
  });

  test('uses architecture persona when available', () async {
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('Build an app.');

    final archPrompt = File('${layout.agentContextsDir}/architecture.md');
    archPrompt.createSync(recursive: true);
    archPrompt.writeAsStringSync('ARCH_PERSONA_MARKER');

    final capturing = _CapturingAgentService('## Overview\nApp architecture');
    final service = ArchitecturePlanningService(agentService: capturing);

    await service.planArchitecture(root);

    expect(capturing.lastSystemPrompt, contains('ARCH_PERSONA_MARKER'));
  });
}

class _FakeAgentService extends AgentService {
  _FakeAgentService(this.output);

  final String output;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}

class _CapturingAgentService extends _FakeAgentService {
  _CapturingAgentService(super.output);

  String? lastPrompt;
  String? lastSystemPrompt;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    lastSystemPrompt = request.systemPrompt;
    return super.run(projectRoot, request);
  }
}
