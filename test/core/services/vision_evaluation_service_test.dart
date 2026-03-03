import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';

void main() {
  late String root;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('vision_eval_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
  });

  group('VisionEvaluationService', () {
    test('returns null when no VISION.md exists', () async {
      final layout = ProjectLayout(root);
      final visionFile = File(layout.visionPath);
      if (visionFile.existsSync()) visionFile.deleteSync();

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(''),
      );

      final result = await service.evaluate(root);
      expect(result, isNull);
    });

    test('returns null when VISION.md is empty', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('');

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(''),
      );

      final result = await service.evaluate(root);
      expect(result, isNull);
    });

    test('parses fulfilled evaluation correctly', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a task tracker.');

      const agentOutput = '''
FULFILLED: yes
COMPLETION: 0.95
REASONING: All core features are implemented and tested.

COVERED_GOALS:
- Task CRUD operations
- Persistence layer
- CLI interface

UNCOVERED_GOALS:

NEXT_STEPS:
''';

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(agentOutput),
      );

      final result = await service.evaluate(root);
      expect(result, isNotNull);
      expect(result!.visionFulfilled, isTrue);
      expect(result.completionEstimate, closeTo(0.95, 0.01));
      expect(result.coveredGoals, hasLength(3));
      expect(result.uncoveredGoals, isEmpty);
      expect(result.suggestedNextSteps, isEmpty);
      expect(result.reasoning, 'All core features are implemented and tested.');
    });

    test('parses unfulfilled evaluation with gaps', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a task tracker.');

      const agentOutput = '''
FULFILLED: no
COMPLETION: 0.4
REASONING: Core model exists but no UI or persistence.

COVERED_GOALS:
- Task data model

UNCOVERED_GOALS:
- Persistence layer
- CLI interface
- Filtering and sorting

NEXT_STEPS:
- Implement SQLite persistence for tasks
- Add CLI argument parser
''';

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(agentOutput),
      );

      final result = await service.evaluate(root);
      expect(result, isNotNull);
      expect(result!.visionFulfilled, isFalse);
      expect(result.completionEstimate, closeTo(0.4, 0.01));
      expect(result.coveredGoals, hasLength(1));
      expect(result.uncoveredGoals, hasLength(3));
      expect(result.suggestedNextSteps, hasLength(2));
      expect(result.suggestedNextSteps.first, contains('SQLite'));
    });

    test('clamps completion estimate to [0.0, 1.0]', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build something.');

      const agentOutput = '''
FULFILLED: no
COMPLETION: 1.5
REASONING: Over-estimated.

COVERED_GOALS:

UNCOVERED_GOALS:

NEXT_STEPS:
''';

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(agentOutput),
      );

      final result = await service.evaluate(root);
      expect(result, isNotNull);
      expect(result!.completionEstimate, 1.0);
    });

    test('includes done and open tasks in prompt', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a CLI tool.');

      // Write some tasks.
      File(layout.tasksPath).writeAsStringSync(
        '# Tasks\n\n## Backlog\n'
        '- [x] [P1] [CORE] Implement parser\n'
        '- [ ] [P2] [UI] Build dashboard\n',
      );

      final capturing = _CapturingAgentService(
        'FULFILLED: no\nCOMPLETION: 0.5\nREASONING: Half done.\n\n'
        'COVERED_GOALS:\n- Parser\n\n'
        'UNCOVERED_GOALS:\n- Dashboard\n\n'
        'NEXT_STEPS:\n- Build dashboard UI\n',
      );

      final service = VisionEvaluationService(agentService: capturing);

      final result = await service.evaluate(root);
      expect(result, isNotNull);
      expect(capturing.lastPrompt, isNotNull);
      expect(capturing.lastPrompt, contains('Completed Tasks'));
      expect(capturing.lastPrompt, contains('Implement parser'));
      expect(capturing.lastPrompt, contains('Open Tasks'));
      expect(capturing.lastPrompt, contains('Build dashboard'));
    });

    test('returns null when agent output is empty', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build something.');

      final service = VisionEvaluationService(
        agentService: _FakeAgentService(''),
      );

      final result = await service.evaluate(root);
      expect(result, isNull);
    });
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

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    return super.run(projectRoot, request);
  }
}
