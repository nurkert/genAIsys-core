// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/supervisor_state.dart';
import 'orchestrator_run_service.dart';

/// Pure-computation service for throughput window management and
/// degraded-mode evaluation.
///
/// All methods are deterministic: state goes in, decisions come out.
/// The caller is responsible for persisting state updates and emitting
/// run-log events.
class SupervisorThroughputGuard {
  /// Threshold (inclusive) for entering degraded mode: >60% failure rate.
  static const double degradedModeEntryThreshold = 0.60;

  /// Threshold (inclusive) for exiting degraded mode: <30% failure rate.
  static const double degradedModeExitThreshold = 0.30;

  /// Roll the throughput window forward after a segment completes.
  ///
  /// Returns a [ThroughputResult] with the updated counters and an optional
  /// halt reason if any throughput limit was breached.
  ThroughputResult rollWindow({
    required SupervisorState currentState,
    required OrchestratorRunResult runResult,
    required Duration window,
    required int stepLimit,
    required int rejectLimit,
    required int highRetryLimit,
    required int retry2PlusBefore,
    required int retry2PlusAfter,
    required DateTime now,
  }) {
    final windowStartedAt = DateTime.tryParse(
      currentState.throughputWindowStartedAt ?? '',
    )?.toUtc();
    final reset =
        windowStartedAt == null || now.difference(windowStartedAt) >= window;
    final baselineStartedAt = reset ? now : windowStartedAt;
    final baseSteps = reset ? 0 : currentState.throughputSteps;
    final baseRejects = reset ? 0 : currentState.throughputRejects;
    final baseHighRetries = reset ? 0 : currentState.throughputHighRetries;

    final highRetryDelta = (retry2PlusAfter - retry2PlusBefore) < 0
        ? 0
        : (retry2PlusAfter - retry2PlusBefore);

    final nextSteps = baseSteps + runResult.totalSteps;
    final nextRejects = baseRejects + runResult.failedSteps;
    final nextHighRetries = baseHighRetries + highRetryDelta;
    final startedAtIso = baselineStartedAt.toIso8601String();

    String? haltReason;
    if (nextSteps >= stepLimit) {
      haltReason = 'throughput_steps';
    } else if (nextRejects >= rejectLimit) {
      haltReason = 'throughput_rejects';
    } else if (nextHighRetries >= highRetryLimit) {
      haltReason = 'throughput_high_retries';
    }

    return ThroughputResult(
      windowStartedAt: startedAtIso,
      steps: nextSteps,
      rejects: nextRejects,
      highRetries: nextHighRetries,
      halted: haltReason != null,
      haltReason: haltReason,
    );
  }

  /// Evaluate whether degraded mode should be entered or exited based on the
  /// failure rate in the current throughput window.
  ///
  /// Returns a [DegradedModeResult] with the new mode and whether it changed.
  DegradedModeResult evaluateDegradedMode({
    required ThroughputResult throughput,
    required bool currentDegradedMode,
  }) {
    if (throughput.steps < 1) {
      return DegradedModeResult(
        degradedMode: currentDegradedMode,
        changed: false,
        failureRate: null,
      );
    }
    final failureRate = throughput.rejects / throughput.steps;

    if (!currentDegradedMode && failureRate > degradedModeEntryThreshold) {
      return DegradedModeResult(
        degradedMode: true,
        changed: true,
        failureRate: failureRate,
      );
    }

    if (currentDegradedMode && failureRate < degradedModeExitThreshold) {
      return DegradedModeResult(
        degradedMode: false,
        changed: true,
        failureRate: failureRate,
      );
    }

    return DegradedModeResult(
      degradedMode: currentDegradedMode,
      changed: false,
      failureRate: failureRate,
    );
  }

  /// Returns `true` when a segment produced no meaningful progress.
  bool isLowSignalSegment(OrchestratorRunResult result) {
    if (result.successfulSteps > 0) {
      return false;
    }
    if (result.idleSteps > 0 || result.failedSteps > 0) {
      return true;
    }
    return result.totalSteps == 0;
  }
}

class ThroughputResult {
  const ThroughputResult({
    required this.windowStartedAt,
    required this.steps,
    required this.rejects,
    required this.highRetries,
    required this.halted,
    required this.haltReason,
  });

  final String windowStartedAt;
  final int steps;
  final int rejects;
  final int highRetries;
  final bool halted;
  final String? haltReason;
}

class DegradedModeResult {
  const DegradedModeResult({
    required this.degradedMode,
    required this.changed,
    required this.failureRate,
  });

  final bool degradedMode;
  final bool changed;
  final double? failureRate;
}
