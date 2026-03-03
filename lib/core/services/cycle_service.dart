// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';

class CycleResult {
  CycleResult({required this.cycleCount});

  final int cycleCount;
}

class CycleService {
  CycleResult tick(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      throw StateError(
        'No .genaisys directory found at: ${layout.genaisysDir}',
      );
    }

    final stateStore = StateStore(layout.statePath);
    final current = stateStore.read();
    final updated = current.copyWith(
      cycleCount: current.cycleCount + 1,
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
    );
    stateStore.write(updated);

    RunLogStore(layout.runLogPath).append(
      event: 'cycle',
      message: 'Cycle tick',
      data: {'root': projectRoot, 'cycle_count': updated.cycleCount},
    );

    return CycleResult(cycleCount: updated.cycleCount);
  }
}
