import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late SpecService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_spec_svc_');
    workspace.ensureStructure();
    service = SpecService();
  });

  tearDown(() => workspace.dispose());

  /// Helper: set an active task and workflow stage in state.
  void setActiveTask(
    String title, {
    WorkflowStage stage = WorkflowStage.planning,
  }) {
    final state = ProjectStateBuilder()
        .withActiveTask('task-id', title)
        .withWorkflowStage(stage)
        .build();
    StateStore(workspace.layout.statePath).write(state);
  }

  test('plan file creation with correct path and template', () {
    setActiveTask('Add logging feature');

    final result = service.initSpec(workspace.root.path, kind: SpecKind.plan);

    expect(result.created, isTrue);
    expect(result.kind, SpecKind.plan);
    expect(result.path, contains('add-logging-feature-plan.md'));
    expect(File(result.path).existsSync(), isTrue);

    final content = File(result.path).readAsStringSync();
    expect(content, contains('Add logging feature'));
  });

  test('spec file creation advances workflow from planning to execution', () {
    setActiveTask('Fix bug', stage: WorkflowStage.planning);

    final result = service.initSpec(workspace.root.path, kind: SpecKind.spec);

    expect(result.created, isTrue);
    expect(result.kind, SpecKind.spec);
    expect(result.path, contains('fix-bug.md'));

    // Workflow should have advanced to execution.
    final store = StateStore(workspace.layout.statePath);
    expect(store.read().workflowStage, WorkflowStage.execution);
  });

  test('subtasks file creation advances workflow', () {
    setActiveTask('Refactor service', stage: WorkflowStage.planning);

    final result = service.initSpec(
      workspace.root.path,
      kind: SpecKind.subtasks,
    );

    expect(result.created, isTrue);
    expect(result.kind, SpecKind.subtasks);
    expect(result.path, contains('refactor-service-subtasks.md'));

    // Workflow should have advanced to execution.
    final store = StateStore(workspace.layout.statePath);
    expect(store.read().workflowStage, WorkflowStage.execution);
  });

  test('existing file not overwritten when overwrite=false', () {
    setActiveTask('My task');

    // Create the spec file first.
    service.initSpec(workspace.root.path, kind: SpecKind.plan);

    // Modify the file.
    final result = service.initSpec(workspace.root.path, kind: SpecKind.plan);
    final path = result.path;
    File(path).writeAsStringSync('Custom content');

    // Try to re-create without overwrite.
    final secondResult = service.initSpec(
      workspace.root.path,
      kind: SpecKind.plan,
    );

    expect(secondResult.created, isFalse);
    expect(File(path).readAsStringSync(), 'Custom content');
  });

  test('throws when no active task is set', () {
    // Write state with no active task.
    final state = ProjectStateBuilder().withNoActiveTask().build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.initSpec(workspace.root.path, kind: SpecKind.plan),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No active task set'),
        ),
      ),
    );
  });

  test('throws when STATE.json is missing', () {
    // Delete STATE.json.
    File(workspace.layout.statePath).deleteSync();

    expect(
      () => service.initSpec(workspace.root.path, kind: SpecKind.plan),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No STATE.json found'),
        ),
      ),
    );
  });
}
