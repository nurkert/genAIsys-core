// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'health_score_service.dart';
import 'runtime_switch_service.dart';
import 'trend_analysis_service.dart' show TrendReport;

/// Result of a canary validation cycle.
class CanaryValidationResult {
  const CanaryValidationResult({
    required this.passed,
    required this.cyclesCompleted,
    required this.cyclesTarget,
    this.rollbackTrigger,
    required this.reason,
  });

  final bool passed;
  final int cyclesCompleted;
  final int cyclesTarget;
  final String? rollbackTrigger;
  final String reason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'passed': passed,
      'cycles_completed': cyclesCompleted,
      'cycles_target': cyclesTarget,
      'rollback_trigger': rollbackTrigger,
      'reason': reason,
    };
  }
}

class CanaryValidationService {
  CanaryValidationService({
    RuntimeSwitchService? runtimeSwitchService,
    this.canaryCycles = 10,
    this.criticalScoreThreshold = 35.0,
    this.regressionThreshold = 15.0,
  }) : _runtimeSwitchService = runtimeSwitchService ?? RuntimeSwitchService();

  final RuntimeSwitchService _runtimeSwitchService;

  /// Number of canary cycles required for promotion.
  final int canaryCycles;

  /// Score below which rollback is triggered immediately.
  final double criticalScoreThreshold;

  /// Overall delta threshold for regression-based rollback.
  final double regressionThreshold;

  /// Validate the canary deployment.
  CanaryValidationResult validate(
    String projectRoot, {
    required HealthReport healthReport,
    required TrendReport trendReport,
  }) {
    final layout = ProjectLayout(projectRoot);

    // Check if we are in canary state.
    final status = _runtimeSwitchService.getStatus(projectRoot);
    if (status.state != RuntimeSwitchState.canary) {
      return CanaryValidationResult(
        passed: false,
        cyclesCompleted: 0,
        cyclesTarget: canaryCycles,
        reason: 'not_in_canary',
      );
    }

    // Load current cycle count from runtime switch state file.
    final currentCycles = status.canaryCompletedCycles ?? 0;

    // Check rollback triggers.
    // 1. Critical health grade.
    if (healthReport.grade == HealthGrade.critical) {
      _triggerRollback(
        projectRoot,
        layout: layout,
        trigger: 'critical_health_grade',
        cyclesCompleted: currentCycles,
      );
      return CanaryValidationResult(
        passed: false,
        cyclesCompleted: currentCycles,
        cyclesTarget: canaryCycles,
        rollbackTrigger: 'critical_health_grade',
        reason: 'rollback_triggered',
      );
    }

    // 2. Score below critical threshold.
    if (healthReport.overallScore < criticalScoreThreshold) {
      _triggerRollback(
        projectRoot,
        layout: layout,
        trigger: 'score_below_threshold',
        cyclesCompleted: currentCycles,
      );
      return CanaryValidationResult(
        passed: false,
        cyclesCompleted: currentCycles,
        cyclesTarget: canaryCycles,
        rollbackTrigger: 'score_below_threshold',
        reason: 'rollback_triggered',
      );
    }

    // 3. Regression with large negative delta.
    if (trendReport.regressions.isNotEmpty &&
        trendReport.overallDelta < -regressionThreshold) {
      _triggerRollback(
        projectRoot,
        layout: layout,
        trigger: 'regression_detected',
        cyclesCompleted: currentCycles,
      );
      return CanaryValidationResult(
        passed: false,
        cyclesCompleted: currentCycles,
        cyclesTarget: canaryCycles,
        rollbackTrigger: 'regression_detected',
        reason: 'rollback_triggered',
      );
    }

    // Increment cycle counter.
    final nextCycles = currentCycles + 1;
    _updateCanaryCycles(layout, nextCycles);

    // Check if we reached the target.
    if (nextCycles >= canaryCycles) {
      // Canary passed -- set state back to idle.
      _setStateIdle(layout);

      if (Directory(layout.genaisysDir).existsSync()) {
        RunLogStore(layout.runLogPath).append(
          event: 'canary_validation_passed',
          message: 'Canary validation passed after $nextCycles cycles',
          data: <String, Object?>{
            'cycles_completed': nextCycles,
            'cycles_target': canaryCycles,
          },
        );
      }

      return CanaryValidationResult(
        passed: true,
        cyclesCompleted: nextCycles,
        cyclesTarget: canaryCycles,
        reason: 'canary_passed',
      );
    }

    // Still in progress.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'canary_validation_cycle',
        message: 'Canary validation cycle $nextCycles/$canaryCycles',
        data: <String, Object?>{
          'cycles_completed': nextCycles,
          'cycles_target': canaryCycles,
          'health_score': healthReport.overallScore,
        },
      );
    }

    return CanaryValidationResult(
      passed: false,
      cyclesCompleted: nextCycles,
      cyclesTarget: canaryCycles,
      reason: 'in_progress',
    );
  }

  void _triggerRollback(
    String projectRoot, {
    required ProjectLayout layout,
    required String trigger,
    required int cyclesCompleted,
  }) {
    final rollbackResult = _runtimeSwitchService.rollback(projectRoot);

    // If rollback could not revert (e.g. no previous version), force
    // the state machine out of canary to avoid an infinite retry loop.
    if (!rollbackResult.rolledBack) {
      _forceRolledBackState(layout);
    }

    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'canary_validation_failed',
        message: 'Canary validation failed: $trigger',
        data: <String, Object?>{
          'trigger': trigger,
          'cycles_completed': cyclesCompleted,
          'cycles_target': canaryCycles,
        },
      );
    }
  }

  void _forceRolledBackState(ProjectLayout layout) {
    final file = File(layout.runtimeSwitchStatePath);
    if (!file.existsSync()) return;
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final stateData = RuntimeSwitchStateData.fromJson(decoded);
      final updated = stateData.copyWith(
        state: RuntimeSwitchState.rolledBack,
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(updated.toJson()),
      );
    } catch (_) {
      // Best effort.
    }
  }

  void _updateCanaryCycles(ProjectLayout layout, int cycles) {
    final file = File(layout.runtimeSwitchStatePath);
    if (!file.existsSync()) return;
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final stateData = RuntimeSwitchStateData.fromJson(decoded);
      final updated = stateData.copyWith(
        canaryCompletedCycles: cycles,
        canaryTargetCycles: canaryCycles,
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(updated.toJson()),
      );
    } catch (_) {
      // Best effort.
    }
  }

  void _setStateIdle(ProjectLayout layout) {
    final file = File(layout.runtimeSwitchStatePath);
    if (!file.existsSync()) return;
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final stateData = RuntimeSwitchStateData.fromJson(decoded);
      final updated = stateData.copyWith(
        state: RuntimeSwitchState.idle,
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(updated.toJson()),
      );
    } catch (_) {
      // Best effort.
    }
  }
}
