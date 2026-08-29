import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/planning_audit_cadence_service.dart';
import 'package:genaisys/core/storage/task_store.dart';

import '../support/test_workspace.dart';

void main() {
  test(
    'PlanningAuditCadenceService skips foundation tasks during first cadence window',
    () {
      final workspace = TestWorkspace.create(prefix: 'genaisys_plan_audit_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final service = PlanningAuditCadenceService(
        now: () => DateTime.utc(2026, 2, 7),
      );
      final config = ProjectConfig(
        autopilotPlanningAuditEnabled: true,
        autopilotPlanningAuditCadenceSteps: 12,
        autopilotPlanningAuditMaxAdd: 4,
      );

      // Step 1 is within the first cadence window (1 <= 12), so foundation
      // tasks are deferred to let new projects establish their backlog first.
      final result = service.seedForStep(
        workspace.root.path,
        stepIndex: 1,
        config: config,
      );

      expect(result.due, isFalse);
      expect(result.created, 0);
      final tasks = TaskStore(workspace.layout.tasksPath).readTasks();
      // Only the pre-existing bootstrap task should remain; no foundation
      // meta-tasks were added during the first cadence window.
      expect(
        tasks.where(
          (t) => t.title.contains('self-review') || t.title.contains('refactor backlog') || t.title.contains('regression checks'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'PlanningAuditCadenceService seeds foundation tasks after first cadence window',
    () {
      final workspace = TestWorkspace.create(prefix: 'genaisys_plan_audit_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final service = PlanningAuditCadenceService(
        now: () => DateTime.utc(2026, 2, 7),
      );
      final config = ProjectConfig(
        autopilotPlanningAuditEnabled: true,
        autopilotPlanningAuditCadenceSteps: 12,
        autopilotPlanningAuditMaxAdd: 4,
      );

      // Step 13 is past the first cadence window: foundation tasks are created.
      final result = service.seedForStep(
        workspace.root.path,
        stepIndex: 13,
        config: config,
      );

      expect(result.due, isFalse);
      expect(result.created, 3);
      final tasks = TaskStore(workspace.layout.tasksPath).readTasks();
      expect(
        tasks.any(
          (task) => task.title.startsWith(
            'Run a full self-review of the current core and CLI architecture',
          ),
        ),
        isTrue,
      );
      expect(
        tasks.any(
          (task) => task.title.startsWith(
            'Create a concrete refactor backlog from self-review findings',
          ),
        ),
        isTrue,
      );
      expect(
        tasks.any(
          (task) => task.title.startsWith(
            'Add focused regression checks for every refactor step',
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'PlanningAuditCadenceService seeds periodic audits on cadence and skips open duplicates',
    () {
      final workspace = TestWorkspace.create(prefix: 'genaisys_plan_audit_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final service = PlanningAuditCadenceService(
        now: () => DateTime.utc(2026, 2, 7),
      );
      final config = ProjectConfig(
        autopilotPlanningAuditEnabled: true,
        autopilotPlanningAuditCadenceSteps: 6,
        autopilotPlanningAuditMaxAdd: 4,
      );

      // Step 6 is at cadence boundary but still within first window (6 <= 6),
      // so foundation tasks are skipped but periodic audits are seeded.
      final first = service.seedForStep(
        workspace.root.path,
        stepIndex: 6,
        config: config,
      );
      expect(first.due, isTrue);
      expect(first.created, 4); // 0 foundation + 4 periodic

      // Step 12 is past the first window: foundation tasks are now created,
      // periodic audits are duplicates and skipped.
      final second = service.seedForStep(
        workspace.root.path,
        stepIndex: 12,
        config: config,
      );
      expect(second.due, isTrue);
      expect(second.created, 3); // 3 foundation + 0 periodic (duplicates)
      expect(second.skipped, greaterThanOrEqualTo(4));
    },
  );

  test('PlanningAuditCadenceService respects periodic max add limit', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_plan_audit_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final service = PlanningAuditCadenceService(
      now: () => DateTime.utc(2026, 2, 7),
    );
    final config = ProjectConfig(
      autopilotPlanningAuditEnabled: true,
      autopilotPlanningAuditCadenceSteps: 1,
      autopilotPlanningAuditMaxAdd: 2,
    );

    // With cadence=1 and step=1, step is within first window (1 <= 1),
    // so foundation tasks are skipped. Only periodic limited by max add.
    final result = service.seedForStep(
      workspace.root.path,
      stepIndex: 1,
      config: config,
    );

    expect(result.created, 2); // 0 foundation + 2 periodic (limited)
    final tasks = TaskStore(workspace.layout.tasksPath).readTasks();
    final periodic = tasks
        .where((task) => task.title.contains('audit sweep'))
        .toList(growable: false);
    expect(periodic.length, 2);
  });
}
