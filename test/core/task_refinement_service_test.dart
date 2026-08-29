import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/task_management/task_refinement_service.dart';
import 'package:genaisys/core/templates/task_spec_templates.dart';

import '../support/test_workspace.dart';

class _StubAgentService extends AgentService {
  _StubAgentService(this.result);

  final AgentServiceResult result;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    return result;
  }
}

AgentServiceResult _emptyAgentResult({required bool usedFallback}) {
  return AgentServiceResult(
    response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    usedFallback: usedFallback,
  );
}

void main() {
  test(
    'TaskRefinementService writes fallback drafts and marks fallback',
    () async {
      final workspace = TestWorkspace.create(prefix: 'genaisys_refine_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final service = TaskRefinementService(
        agentService: _StubAgentService(_emptyAgentResult(usedFallback: true)),
      );

      final result = await service.refine(
        workspace.root.path,
        title: 'Refine Task',
        overwrite: true,
      );

      expect(result.artifacts.length, 3);
      expect(result.usedFallback, isTrue);
      for (final artifact in result.artifacts) {
        expect(artifact.wrote, isTrue);
        expect(artifact.usedFallback, isTrue);
        expect(File(artifact.path).existsSync(), isTrue);
      }

      final layout = ProjectLayout(workspace.root.path);
      final plan = File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}refine-task-plan.md',
      ).readAsStringSync();
      final spec = File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}refine-task.md',
      ).readAsStringSync();
      final subtasks = File(
        '${layout.taskSpecsDir}${Platform.pathSeparator}refine-task-subtasks.md',
      ).readAsStringSync();

      expect(plan, TaskSpecTemplates.plan('Refine Task'));
      expect(spec, TaskSpecTemplates.spec('Refine Task'));
      expect(subtasks, TaskSpecTemplates.subtasks('Refine Task'));
    },
  );

  test(
    'TaskRefinementService skips existing artifacts when overwrite is false',
    () async {
      final workspace = TestWorkspace.create(prefix: 'genaisys_refine_skip_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final layout = ProjectLayout(workspace.root.path);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      final existingPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}skip-task-plan.md';
      File(existingPath).writeAsStringSync('existing');

      final service = TaskRefinementService(
        agentService: _StubAgentService(_emptyAgentResult(usedFallback: false)),
      );

      final result = await service.refine(
        workspace.root.path,
        title: 'Skip Task',
        overwrite: false,
      );

      final planArtifact = result.artifacts.firstWhere(
        (artifact) => artifact.kind.name == 'plan',
      );
      expect(planArtifact.wrote, isFalse);
      expect(File(existingPath).readAsStringSync(), 'existing');
    },
  );
}
