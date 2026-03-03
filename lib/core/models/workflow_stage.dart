// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum WorkflowStage { idle, planning, execution, review, done }

WorkflowStage parseWorkflowStage(String? value) {
  final normalized = value?.trim().toLowerCase();
  for (final stage in WorkflowStage.values) {
    if (stage.name == normalized) {
      return stage;
    }
  }
  return WorkflowStage.idle;
}
