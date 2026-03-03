// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/workflow_stage.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';

class WorkflowTransitionResult {
  WorkflowTransitionResult({required this.from, required this.to});

  final WorkflowStage from;
  final WorkflowStage to;
}

class WorkflowService {
  static const Map<WorkflowStage, List<WorkflowStage>> _allowedTransitions = {
    WorkflowStage.idle: [WorkflowStage.planning],
    WorkflowStage.planning: [WorkflowStage.execution],
    WorkflowStage.execution: [WorkflowStage.review],
    WorkflowStage.review: [WorkflowStage.execution, WorkflowStage.done],
    WorkflowStage.done: [WorkflowStage.planning],
  };

  WorkflowStage getStage(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    return state.workflowStage;
  }

  WorkflowTransitionResult transition(
    String projectRoot,
    WorkflowStage target,
  ) {
    final layout = ProjectLayout(projectRoot);
    final stateStore = StateStore(layout.statePath);
    final current = stateStore.read();
    final from = current.workflowStage;

    final allowed = _allowedTransitions[from] ?? const [];
    if (!allowed.contains(target)) {
      throw StateError(
        'Invalid workflow transition: ${from.name} -> ${target.name}',
      );
    }

    final updated = current.copyWith(
      workflowStage: target,
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
    );
    stateStore.write(updated);

    RunLogStore(layout.runLogPath).append(
      event: 'workflow_transition',
      message: 'Workflow stage transitioned',
      data: {'root': projectRoot, 'from': from.name, 'to': target.name},
    );

    return WorkflowTransitionResult(from: from, to: target);
  }
}
