// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'release_candidate_builder_service.dart';

/// State of the runtime switch state-machine.
enum RuntimeSwitchState { idle, switching, canary, rolledBack }

/// Persisted runtime switch state on disk.
class RuntimeSwitchStateData {
  const RuntimeSwitchStateData({
    required this.state,
    this.currentVersion,
    this.previousVersion,
    this.canaryCompletedCycles,
    this.canaryTargetCycles,
    this.lastUpdated,
  });

  final RuntimeSwitchState state;
  final String? currentVersion;
  final String? previousVersion;
  final int? canaryCompletedCycles;
  final int? canaryTargetCycles;
  final String? lastUpdated;

  RuntimeSwitchStateData copyWith({
    RuntimeSwitchState? state,
    String? currentVersion,
    bool clearCurrentVersion = false,
    String? previousVersion,
    bool clearPreviousVersion = false,
    int? canaryCompletedCycles,
    int? canaryTargetCycles,
    String? lastUpdated,
  }) {
    return RuntimeSwitchStateData(
      state: state ?? this.state,
      currentVersion: clearCurrentVersion
          ? null
          : (currentVersion ?? this.currentVersion),
      previousVersion: clearPreviousVersion
          ? null
          : (previousVersion ?? this.previousVersion),
      canaryCompletedCycles:
          canaryCompletedCycles ?? this.canaryCompletedCycles,
      canaryTargetCycles: canaryTargetCycles ?? this.canaryTargetCycles,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': state.name,
      'current_version': currentVersion,
      'previous_version': previousVersion,
      'canary_completed_cycles': canaryCompletedCycles,
      'canary_target_cycles': canaryTargetCycles,
      'last_updated': lastUpdated,
    };
  }

  factory RuntimeSwitchStateData.fromJson(Map<String, dynamic> json) {
    final rawState = (json['state'] ?? 'idle').toString();
    final state = RuntimeSwitchState.values.firstWhere(
      (e) => e.name == rawState,
      orElse: () => RuntimeSwitchState.idle,
    );
    return RuntimeSwitchStateData(
      state: state,
      currentVersion: json['current_version']?.toString(),
      previousVersion: json['previous_version']?.toString(),
      canaryCompletedCycles: _parseInt(json['canary_completed_cycles']),
      canaryTargetCycles: _parseInt(json['canary_target_cycles']),
      lastUpdated: json['last_updated']?.toString(),
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

/// Result of a runtime switch operation.
class RuntimeSwitchResult {
  const RuntimeSwitchResult({
    required this.switched,
    this.fromVersion,
    required this.toVersion,
    required this.reason,
  });

  final bool switched;
  final String? fromVersion;
  final String toVersion;
  final String reason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'switched': switched,
      'from_version': fromVersion,
      'to_version': toVersion,
      'reason': reason,
    };
  }
}

/// Result of a runtime rollback operation.
class RuntimeRollbackResult {
  const RuntimeRollbackResult({
    required this.rolledBack,
    this.fromVersion,
    this.toVersion,
    required this.reason,
  });

  final bool rolledBack;
  final String? fromVersion;
  final String? toVersion;
  final String reason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rolled_back': rolledBack,
      'from_version': fromVersion,
      'to_version': toVersion,
      'reason': reason,
    };
  }
}

/// Current status snapshot.
class RuntimeSwitchStatus {
  const RuntimeSwitchStatus({
    required this.state,
    this.currentVersion,
    this.previousVersion,
    this.canaryCompletedCycles,
    this.canaryTargetCycles,
  });

  final RuntimeSwitchState state;
  final String? currentVersion;
  final String? previousVersion;
  final int? canaryCompletedCycles;
  final int? canaryTargetCycles;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': state.name,
      'current_version': currentVersion,
      'previous_version': previousVersion,
      'canary_completed_cycles': canaryCompletedCycles,
      'canary_target_cycles': canaryTargetCycles,
    };
  }
}

/// State-machine service for recording runtime version switch intent and
/// transitions. Does NOT spawn or stop processes -- it records state only.
class RuntimeSwitchService {
  RuntimeSwitchService({
    ReleaseCandidateBuilderService? releaseCandidateBuilderService,
  }) : _releaseCandidateBuilderService =
           releaseCandidateBuilderService ?? ReleaseCandidateBuilderService();

  final ReleaseCandidateBuilderService _releaseCandidateBuilderService;

  /// Switch to the given version. This is a state-machine transition.
  RuntimeSwitchResult switchTo(String projectRoot, {required String version}) {
    final layout = ProjectLayout(projectRoot);

    // Verify candidate manifest exists.
    final manifest = _releaseCandidateBuilderService.loadManifest(
      projectRoot,
      version: version,
    );
    if (manifest == null) {
      return RuntimeSwitchResult(
        switched: false,
        toVersion: version,
        reason: 'candidate_manifest_not_found',
      );
    }

    // Read current state.
    final currentState = _loadState(layout);
    final previousVersion = currentState.currentVersion;

    // Transition: idle/rolledBack -> switching -> canary.
    final now = DateTime.now().toUtc().toIso8601String();

    // Emit start event.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'runtime_switch_start',
        message:
            'Runtime switch starting from '
            '${previousVersion ?? 'none'} to $version',
        data: <String, Object?>{
          'from_version': previousVersion,
          'to_version': version,
        },
      );
    }

    // Write switching state, then canary state.
    final switchingState = currentState.copyWith(
      state: RuntimeSwitchState.switching,
      currentVersion: version,
      previousVersion: previousVersion,
      canaryCompletedCycles: 0,
      lastUpdated: now,
    );
    _saveState(layout, switchingState);

    final canaryState = switchingState.copyWith(
      state: RuntimeSwitchState.canary,
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
    );
    _saveState(layout, canaryState);

    // Emit complete event.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'runtime_switch_complete',
        message: 'Runtime switch to $version complete (canary)',
        data: <String, Object?>{
          'from_version': previousVersion,
          'to_version': version,
        },
      );
    }

    return RuntimeSwitchResult(
      switched: true,
      fromVersion: previousVersion,
      toVersion: version,
      reason: 'switched',
    );
  }

  /// Rollback to the previous version.
  RuntimeRollbackResult rollback(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final currentState = _loadState(layout);

    final fromVersion = currentState.currentVersion;
    final toVersion = currentState.previousVersion;

    if (toVersion == null || toVersion.isEmpty) {
      return RuntimeRollbackResult(
        rolledBack: false,
        fromVersion: fromVersion,
        reason: 'no_previous_version',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final rolledBackState = currentState.copyWith(
      state: RuntimeSwitchState.rolledBack,
      currentVersion: toVersion,
      previousVersion: fromVersion,
      canaryCompletedCycles: 0,
      lastUpdated: now,
    );
    _saveState(layout, rolledBackState);

    // Emit rollback event.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'runtime_rollback',
        message: 'Runtime rolled back from $fromVersion to $toVersion',
        data: <String, Object?>{
          'from_version': fromVersion,
          'to_version': toVersion,
        },
      );
    }

    return RuntimeRollbackResult(
      rolledBack: true,
      fromVersion: fromVersion,
      toVersion: toVersion,
      reason: 'rolled_back',
    );
  }

  /// Get current runtime switch status.
  RuntimeSwitchStatus getStatus(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final stateData = _loadState(layout);
    return RuntimeSwitchStatus(
      state: stateData.state,
      currentVersion: stateData.currentVersion,
      previousVersion: stateData.previousVersion,
      canaryCompletedCycles: stateData.canaryCompletedCycles,
      canaryTargetCycles: stateData.canaryTargetCycles,
    );
  }

  RuntimeSwitchStateData _loadState(ProjectLayout layout) {
    final file = File(layout.runtimeSwitchStatePath);
    if (!file.existsSync()) {
      return const RuntimeSwitchStateData(state: RuntimeSwitchState.idle);
    }
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return RuntimeSwitchStateData.fromJson(decoded);
    } catch (_) {
      return const RuntimeSwitchStateData(state: RuntimeSwitchState.idle);
    }
  }

  void _saveState(ProjectLayout layout, RuntimeSwitchStateData stateData) {
    final dir = Directory(layout.auditDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    File(layout.runtimeSwitchStatePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(stateData.toJson()),
    );
  }
}
