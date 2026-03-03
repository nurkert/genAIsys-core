import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/models/task_draft.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/services/sprint_planner_service.dart';
import 'package:genaisys/core/services/strategic_planner_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';

import '../../support/test_workspace.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

class _FakeStrategicPlanner extends StrategicPlannerService {
  _FakeStrategicPlanner({required this.drafts});

  final List<TaskDraft> drafts;

  @override
  Future<List<TaskDraft>> suggestTasks(
    String projectRoot, {
    int count = 5,
  }) async => drafts.take(count).toList();
}

class _FakeVisionEval extends VisionEvaluationService {
  _FakeVisionEval({required this.result});

  final VisionEvaluationResult? result;

  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async => result;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

VisionEvaluationResult _notFulfilled() => const VisionEvaluationResult(
  visionFulfilled: false,
  completionEstimate: 0.4,
  coveredGoals: [],
  uncoveredGoals: ['goal1'],
  suggestedNextSteps: [],
  reasoning: 'Not done yet.',
  usedFallback: false,
);

VisionEvaluationResult _fulfilled() => const VisionEvaluationResult(
  visionFulfilled: true,
  completionEstimate: 1.0,
  coveredGoals: ['goal1'],
  uncoveredGoals: [],
  suggestedNextSteps: [],
  reasoning: 'All done.',
  usedFallback: false,
);

List<TaskDraft> _drafts(int count) => List.generate(
  count,
  (i) => TaskDraft(
    title: 'Task ${i + 1}',
    priority: TaskPriority.p1,
    category: TaskCategory.core,
    acceptanceCriteria: 'It works.',
  ),
);

ProjectConfig _config({
  bool sprintPlanningEnabled = true,
  int maxSprints = 0,
  int sprintSize = 5,
}) => ProjectConfig(
  autopilotSprintPlanningEnabled: sprintPlanningEnabled,
  autopilotMaxSprints: maxSprints,
  autopilotSprintSize: sprintSize,
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'sprint_planner_');
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  SprintPlannerService _makeService({
    List<TaskDraft>? drafts,
    VisionEvaluationResult? visionResult,
  }) => SprintPlannerService(
    strategicPlanner: _FakeStrategicPlanner(drafts: drafts ?? _drafts(5)),
    visionEvaluationService: _FakeVisionEval(result: visionResult ?? _notFulfilled()),
  );

  // ─── detectCurrentSprint ────────────────────────────────────────────────────

  group('detectCurrentSprint', () {
    test('returns 0 when TASKS.md has no Sprint headers', () {
      workspace.writeTasks('- [ ] [P1] [CORE] Do something\n');
      final svc = _makeService();
      expect(svc.detectCurrentSprint(workspace.layout.tasksPath), 0);
    });

    test('returns sprint number when Sprint header exists', () {
      workspace.writeTasks('## Sprint 3\n- [ ] [P1] [CORE] Task\n');
      final svc = _makeService();
      expect(svc.detectCurrentSprint(workspace.layout.tasksPath), 3);
    });

    test('returns highest sprint number when multiple headers exist', () {
      workspace.writeTasks(
        '## Sprint 1\n- [x] [P1] [CORE] Done\n'
        '## Sprint 2\n- [x] [P1] [CORE] Done2\n'
        '## Sprint 3\n- [ ] [P1] [CORE] Open\n',
      );
      final svc = _makeService();
      expect(svc.detectCurrentSprint(workspace.layout.tasksPath), 3);
    });

    test('returns 0 when TASKS.md does not exist', () {
      final svc = _makeService();
      expect(svc.detectCurrentSprint('/nonexistent/TASKS.md'), 0);
    });
  });

  // ─── maybeStartNextSprint — no action needed ────────────────────────────────

  group('no action when open tasks remain', () {
    test('returns noAction when there are open tasks', () async {
      workspace.writeTasks('## Sprint 1\n- [ ] [P1] [CORE] Still open\n');
      final svc = _makeService();

      final result = await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(),
        stepId: 'step-1',
      );

      expect(result.sprintStarted, isFalse);
      expect(result.visionFulfilled, isFalse);
      expect(result.maxSprintsReached, isFalse);
    });
  });

  // ─── maybeStartNextSprint — next sprint generated ───────────────────────────

  group('generates next sprint', () {
    test('sprint 0 → sprint 1 created with N tasks', () async {
      workspace.writeTasks('## Sprint 1\n- [x] [P1] [CORE] Done task\n');
      final svc = _makeService(drafts: _drafts(3));

      final result = await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(sprintSize: 3),
        stepId: 'step-2',
      );

      expect(result.sprintStarted, isTrue);
      expect(result.sprintNumber, 2);
      expect(result.tasksAdded, 3);
    });

    test('tasks are written under ## Sprint 2 header in TASKS.md', () async {
      workspace.writeTasks('## Sprint 1\n- [x] [P1] [CORE] Done task\n');
      final svc = _makeService(drafts: _drafts(2));

      await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(sprintSize: 2),
        stepId: 'step-2',
      );

      final content = File(workspace.layout.tasksPath).readAsStringSync();
      expect(content, contains('## Sprint 2'));
      expect(content, contains('Task 1'));
      expect(content, contains('Task 2'));
    });

    test('run-log contains sprint_planning_started and sprint_planning_complete', () async {
      workspace.writeTasks('- [x] [P1] [CORE] Done\n');
      final svc = _makeService(drafts: _drafts(2));

      await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(sprintSize: 2),
        stepId: 'step-3',
      );

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('sprint_planning_started'));
      expect(log, contains('sprint_planning_complete'));
    });
  });

  // ─── maybeStartNextSprint — vision fulfilled ────────────────────────────────

  group('vision fulfilled', () {
    test('returns visionFulfilled=true and writes no tasks', () async {
      workspace.writeTasks('## Sprint 1\n- [x] [P1] [CORE] Done\n');
      final svc = _makeService(visionResult: _fulfilled());

      final result = await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(),
        stepId: 'step-v',
      );

      expect(result.visionFulfilled, isTrue);
      expect(result.sprintStarted, isFalse);
      expect(result.maxSprintsReached, isFalse);
    });

    test('run-log contains sprint_vision_fulfilled event', () async {
      workspace.writeTasks('## Sprint 1\n- [x] [P1] [CORE] Done\n');
      final svc = _makeService(visionResult: _fulfilled());

      await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(),
        stepId: 'step-v',
      );

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('sprint_vision_fulfilled'));
    });
  });

  // ─── maybeStartNextSprint — max sprints reached ─────────────────────────────

  group('max sprints reached', () {
    test('returns maxSprintsReached=true when sprint >= maxSprints', () async {
      workspace.writeTasks('## Sprint 3\n- [x] [P1] [CORE] Done\n');
      final svc = _makeService();

      final result = await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(maxSprints: 3),
        stepId: 'step-m',
      );

      expect(result.maxSprintsReached, isTrue);
      expect(result.sprintStarted, isFalse);
    });

    test('run-log contains sprint_max_reached event', () async {
      workspace.writeTasks('## Sprint 2\n- [x] [P1] [CORE] Done\n');
      final svc = _makeService();

      await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(maxSprints: 2),
        stepId: 'step-m',
      );

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('sprint_max_reached'));
    });

    test('never reaches maxSprintsReached when maxSprints=0 (unlimited)', () async {
      workspace.writeTasks('## Sprint 99\n- [x] [P1] [CORE] Done\n');
      final svc = _makeService(drafts: _drafts(1));

      final result = await svc.maybeStartNextSprint(
        workspace.root.path,
        config: _config(maxSprints: 0),
        stepId: 'step-u',
      );

      expect(result.maxSprintsReached, isFalse);
      expect(result.sprintStarted, isTrue);
    });
  });
}
