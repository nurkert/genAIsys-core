import 'package:test/test.dart';

import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/workflow_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late WorkflowService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_workflow_svc_');
    workspace.ensureStructure();
    service = WorkflowService();
  });

  tearDown(() => workspace.dispose());

  /// Helper: set the current workflow stage.
  void setStage(WorkflowStage stage) {
    final store = StateStore(workspace.layout.statePath);
    store.write(store.read().copyWith(workflowStage: stage));
  }

  group('valid transitions', () {
    test('full forward chain: idle → planning → execution → review → done', () {
      setStage(WorkflowStage.idle);

      final r1 = service.transition(
        workspace.root.path,
        WorkflowStage.planning,
      );
      expect(r1.from, WorkflowStage.idle);
      expect(r1.to, WorkflowStage.planning);

      final r2 = service.transition(
        workspace.root.path,
        WorkflowStage.execution,
      );
      expect(r2.from, WorkflowStage.planning);
      expect(r2.to, WorkflowStage.execution);

      final r3 = service.transition(workspace.root.path, WorkflowStage.review);
      expect(r3.from, WorkflowStage.execution);
      expect(r3.to, WorkflowStage.review);

      final r4 = service.transition(workspace.root.path, WorkflowStage.done);
      expect(r4.from, WorkflowStage.review);
      expect(r4.to, WorkflowStage.done);

      // Verify persisted state.
      expect(service.getStage(workspace.root.path), WorkflowStage.done);
    });

    test('review → execution back-loop on reject', () {
      setStage(WorkflowStage.review);

      final result = service.transition(
        workspace.root.path,
        WorkflowStage.execution,
      );
      expect(result.from, WorkflowStage.review);
      expect(result.to, WorkflowStage.execution);
      expect(service.getStage(workspace.root.path), WorkflowStage.execution);
    });

    test('done → planning for next task cycle', () {
      setStage(WorkflowStage.done);

      final result = service.transition(
        workspace.root.path,
        WorkflowStage.planning,
      );
      expect(result.from, WorkflowStage.done);
      expect(result.to, WorkflowStage.planning);
      expect(service.getStage(workspace.root.path), WorkflowStage.planning);
    });
  });

  group('invalid transitions', () {
    test('idle → done is rejected', () {
      setStage(WorkflowStage.idle);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.done),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid workflow transition: idle -> done'),
          ),
        ),
      );
      // State unchanged.
      expect(service.getStage(workspace.root.path), WorkflowStage.idle);
    });

    test(
      'planning → done is rejected (must go through execution + review)',
      () {
        setStage(WorkflowStage.planning);

        expect(
          () => service.transition(workspace.root.path, WorkflowStage.done),
          throwsA(isA<StateError>()),
        );
        expect(service.getStage(workspace.root.path), WorkflowStage.planning);
      },
    );

    test('execution → idle is rejected', () {
      setStage(WorkflowStage.execution);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.idle),
        throwsA(isA<StateError>()),
      );
      expect(service.getStage(workspace.root.path), WorkflowStage.execution);
    });

    test('execution → done skips review (rejected)', () {
      setStage(WorkflowStage.execution);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.done),
        throwsA(isA<StateError>()),
      );
    });

    test('self-transition planning → planning is rejected', () {
      setStage(WorkflowStage.planning);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.planning),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid workflow transition: planning -> planning'),
          ),
        ),
      );
      // State unchanged.
      expect(service.getStage(workspace.root.path), WorkflowStage.planning);
    });

    test('self-transition execution → execution is rejected', () {
      setStage(WorkflowStage.execution);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.execution),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid workflow transition: execution -> execution'),
          ),
        ),
      );
      // State unchanged.
      expect(service.getStage(workspace.root.path), WorkflowStage.execution);
    });

    test('done → idle is rejected (only done → planning is valid)', () {
      setStage(WorkflowStage.done);

      expect(
        () => service.transition(workspace.root.path, WorkflowStage.idle),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid workflow transition: done -> idle'),
          ),
        ),
      );
      // State unchanged.
      expect(service.getStage(workspace.root.path), WorkflowStage.done);
    });
  });

  test('getStage reads persisted workflow stage', () {
    setStage(WorkflowStage.review);
    expect(service.getStage(workspace.root.path), WorkflowStage.review);
  });
}
