import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';

/// Integration tests for the autonomous vision-to-delivery lifecycle.
///
/// Verifies the full flow:
///   VISION.md → Architecture → Strategy → Execution → Evaluation → idle/continue
void main() {
  late String root;
  late ProjectLayout layout;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('lifecycle_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
    layout = ProjectLayout(root);
  });

  group('Vision-to-delivery lifecycle', () {
    test(
      'idle step with fulfilled vision returns visionFulfilled=true',
      () async {
        // Set up: VISION.md exists, ARCHITECTURE.md exists, empty backlog (all done).
        File(layout.visionPath).writeAsStringSync('Build a task tracker.');
        File(layout.architecturePath).writeAsStringSync('## Modules\n- core');
        File(layout.tasksPath).writeAsStringSync(
          '# Tasks\n\n## Backlog\n'
          '- [x] [P1] [CORE] Implement core model\n',
        );

        final service = OrchestratorStepService(
          plannerService: _EmptyPlannerService(),
          architecturePlanningService: _NoopArchitecturePlanningService(),
          visionEvaluationService: _FulfilledVisionService(),
        );

        final result = await service.run(root, codingPrompt: 'Build.');

        expect(result.executedCycle, isFalse);
        expect(result.visionFulfilled, isTrue);

        // Verify run log contains vision_complete event.
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('vision_complete'));
      },
    );

    test(
      'idle step with unfulfilled vision returns visionFulfilled=false',
      () async {
        // Set up: VISION.md exists, ARCHITECTURE.md exists, empty backlog.
        File(layout.visionPath).writeAsStringSync('Build a task tracker.');
        File(layout.architecturePath).writeAsStringSync('## Modules\n- core');
        File(layout.tasksPath).writeAsStringSync('# Tasks\n\n## Backlog\n');

        final service = OrchestratorStepService(
          plannerService: _EmptyPlannerService(),
          architecturePlanningService: _NoopArchitecturePlanningService(),
          visionEvaluationService: _UnfulfilledVisionService(),
        );

        final result = await service.run(root, codingPrompt: 'Build.');

        expect(result.executedCycle, isFalse);
        expect(result.visionFulfilled, isFalse);

        // Verify run log contains vision_gap_detected event.
        final runLog = File(layout.runLogPath).readAsStringSync();
        expect(runLog, contains('vision_gap_detected'));
      },
    );

    test('idle step without VISION.md returns null visionFulfilled', () async {
      // No VISION.md — evaluation skipped.
      final visionFile = File(layout.visionPath);
      if (visionFile.existsSync()) visionFile.deleteSync();
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n## Backlog\n');

      final service = OrchestratorStepService(
        plannerService: _EmptyPlannerService(),
        architecturePlanningService: _NoopArchitecturePlanningService(),
        visionEvaluationService: _NoopVisionEvaluationService(),
      );

      final result = await service.run(root, codingPrompt: 'Build.');

      expect(result.executedCycle, isFalse);
      expect(result.visionFulfilled, isNull);
    });

    test('architecture planning phase runs before task activation', () async {
      // VISION.md exists, no ARCHITECTURE.md → should trigger architecture phase.
      File(layout.visionPath).writeAsStringSync('Build a CLI tool.');
      final archFile = File(layout.architecturePath);
      if (archFile.existsSync()) archFile.deleteSync();
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n## Backlog\n');

      final archService = _WritingArchitectureService();
      final service = OrchestratorStepService(
        plannerService: _EmptyPlannerService(),
        architecturePlanningService: archService,
        visionEvaluationService: _NoopVisionEvaluationService(),
      );

      final result = await service.run(root, codingPrompt: 'Build.');

      // Architecture phase returns early (executedCycle=false).
      expect(result.executedCycle, isFalse);
      expect(archService.planCalled, isTrue);

      // Verify run log evidence.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('architecture_planning_started'));
      expect(runLog, contains('architecture_planning_completed'));
    });

    test('lifecycle phases execute in order across steps', () async {
      // Step 1: Architecture planning (ARCHITECTURE.md missing)
      File(layout.visionPath).writeAsStringSync('Build a CLI tool.');
      final archFile = File(layout.architecturePath);
      if (archFile.existsSync()) archFile.deleteSync();
      File(layout.tasksPath).writeAsStringSync('# Tasks\n\n## Backlog\n');

      final archService = _WritingArchitectureService();
      final service = OrchestratorStepService(
        plannerService: _EmptyPlannerService(),
        architecturePlanningService: archService,
        visionEvaluationService: _FulfilledVisionService(),
      );

      final result1 = await service.run(root, codingPrompt: 'Build.');
      expect(result1.executedCycle, isFalse);
      // Architecture was planned, ARCHITECTURE.md written.
      expect(archFile.existsSync(), isTrue);

      // Step 2: Now architecture exists, no tasks → vision evaluation.
      final result2 = await service.run(root, codingPrompt: 'Build.');
      expect(result2.executedCycle, isFalse);
      expect(result2.visionFulfilled, isTrue);

      // Verify the full lifecycle trace in run log.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('architecture_planning_started'));
      expect(runLog, contains('architecture_planning_completed'));
      expect(runLog, contains('vision_evaluation_started'));
      expect(runLog, contains('vision_complete'));
    });
  });
}

// --- Test doubles ---

class _EmptyPlannerService extends VisionBacklogPlannerService {
  @override
  Future<PlannerSyncResult> syncBacklogStrategically(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) async {
    return PlannerSyncResult(
      openBefore: 0,
      openAfter: 0,
      added: 0,
      addedTitles: const [],
    );
  }
}

class _NoopArchitecturePlanningService extends ArchitecturePlanningService {
  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    return null;
  }
}

class _WritingArchitectureService extends ArchitecturePlanningService {
  bool planCalled = false;

  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    planCalled = true;
    return ArchitecturePlanningResult(
      architectureContent: '## Architecture\n- core module\n- cli module',
      suggestedModules: ['core', 'cli'],
      suggestedConstraints: ['No circular deps'],
      usedFallback: false,
    );
  }
}

class _NoopVisionEvaluationService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return null;
  }
}

class _FulfilledVisionService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return VisionEvaluationResult(
      visionFulfilled: true,
      completionEstimate: 1.0,
      coveredGoals: ['All features implemented'],
      uncoveredGoals: [],
      suggestedNextSteps: [],
      reasoning: 'Project is feature-complete.',
      usedFallback: false,
    );
  }
}

class _UnfulfilledVisionService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return VisionEvaluationResult(
      visionFulfilled: false,
      completionEstimate: 0.3,
      coveredGoals: ['Core model'],
      uncoveredGoals: ['Persistence', 'CLI'],
      suggestedNextSteps: ['Add persistence layer', 'Build CLI'],
      reasoning: 'Major gaps remain.',
      usedFallback: false,
    );
  }
}
