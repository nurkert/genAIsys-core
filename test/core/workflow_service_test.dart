import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/workflow_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/models/workflow_stage.dart';

void main() {
  test('WorkflowService allows valid transitions', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_workflow_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(workflowStage: WorkflowStage.idle),
    );

    final service = WorkflowService();
    service.transition(temp.path, WorkflowStage.planning);
    service.transition(temp.path, WorkflowStage.execution);
    service.transition(temp.path, WorkflowStage.review);
    service.transition(temp.path, WorkflowStage.done);

    final updated = stateStore.read();
    expect(updated.workflowStage, WorkflowStage.done);
  });

  test('WorkflowService rejects invalid transitions', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_workflow_invalid_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(workflowStage: WorkflowStage.planning),
    );

    final service = WorkflowService();
    expect(
      () => service.transition(temp.path, WorkflowStage.done),
      throwsA(isA<StateError>()),
    );
  });
}
