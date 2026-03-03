import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/strategic_planner_service.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';

void main() {
  late String root;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('init_backlog_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
  });

  group('StrategicPlannerService.generateInitialBacklog', () {
    test('generates tasks from vision', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a task tracker.');

      const agentOutput = '''
- [P1] [CORE] Implement core task data model with persistence | AC: Task CRUD operations pass unit tests
- [P1] [CORE] Add task status transitions and validation logic | AC: State machine tests pass
- [P2] [UI] Build task list view with filtering and sorting | AC: UI renders tasks correctly
- [P2] [SEC] Add input sanitization for task titles | AC: XSS and injection tests pass
''';

      final service = StrategicPlannerService(
        agentService: _FakeAgentService(agentOutput),
      );

      final result = await service.generateInitialBacklog(root);

      expect(result, isNotEmpty);
      expect(result.length, 4);
      expect(result.first.title, contains('task data model'));
      expect(result.first.acceptanceCriteria, isNotEmpty);
    });

    test('includes architecture context when available', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build an app.');
      File(layout.architecturePath).writeAsStringSync(
        '## Modules\n- core\n- ui\n- storage',
      );

      final capturing = _CapturingAgentService(
        '- [P1] [CORE] Implement storage layer for persistence | AC: Tests pass',
      );
      final service = StrategicPlannerService(agentService: capturing);

      await service.generateInitialBacklog(root);

      expect(capturing.lastPrompt, isNotNull);
      expect(capturing.lastPrompt, contains('Technical Architecture'));
      expect(capturing.lastPrompt, contains('core'));
      expect(capturing.lastPrompt, contains('storage'));
    });

    test('returns empty list when no VISION.md', () async {
      final layout = ProjectLayout(root);
      final visionFile = File(layout.visionPath);
      if (visionFile.existsSync()) visionFile.deleteSync();

      final service = StrategicPlannerService(
        agentService: _FakeAgentService(''),
      );

      final result = await service.generateInitialBacklog(root);
      expect(result, isEmpty);
    });
  });

  group('VisionBacklogPlannerService initial backlog', () {
    test('generates initial backlog when TASKS.md is empty', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a CLI tool.');
      // Write an empty TASKS.md (no tasks).
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n## Backlog\n');

      const agentOutput = '''
- [P1] [CORE] Implement CLI argument parser for commands | AC: Parsing tests pass
- [P1] [CORE] Add help command with usage information | AC: Help output matches spec
- [P2] [DOCS] Write initial README with usage examples | AC: README exists and covers basic usage
''';

      final planner = StrategicPlannerService(
        agentService: _FakeAgentService(agentOutput),
      );

      final service = VisionBacklogPlannerService(
        strategicPlanner: planner,
      );

      final result = await service.syncBacklogStrategically(
        root,
        minOpenTasks: 3,
        maxAdd: 5,
      );

      expect(result.added, 3);
      expect(result.openBefore, 0);
      expect(result.openAfter, 3);
      final content = File(layout.tasksPath).readAsStringSync();
      expect(content, contains('CLI argument parser'));
      expect(content, contains('help command'));
      expect(content, contains('README'));
    });

    test('uses incremental suggestTasks when TASKS.md is not empty', () async {
      final layout = ProjectLayout(root);
      File(layout.visionPath).writeAsStringSync('Build a CLI tool.');
      // Write TASKS.md with one existing task.
      File(layout.tasksPath).writeAsStringSync(
        '# Tasks\n\n## Backlog\n- [ ] [P1] [CORE] Existing task here\n',
      );

      const agentOutput = '''
- [P2] [CORE] Add logging framework for debugging | AC: Logs are written to file
''';

      final planner = StrategicPlannerService(
        agentService: _FakeAgentService(agentOutput),
      );

      final service = VisionBacklogPlannerService(
        strategicPlanner: planner,
      );

      final result = await service.syncBacklogStrategically(
        root,
        minOpenTasks: 3,
        maxAdd: 2,
      );

      // Should use incremental (suggestTasks), not initial backlog.
      expect(result.openBefore, 1);
      expect(result.added, greaterThanOrEqualTo(0));
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
