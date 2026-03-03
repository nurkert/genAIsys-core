// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/hitl_gate.dart';
import '../project_layout.dart';
import '../storage/atomic_file_write.dart';
import '../storage/run_log_store.dart';

/// Manages Human-in-the-Loop (HITL) gate files for the autopilot orchestrator.
///
/// When the orchestrator reaches a configured gate point it calls
/// [waitForDecision], which:
///   1. Writes `.genaisys/locks/hitl.gate` with gate context.
///   2. Emits a `hitl_gate_opened` run-log event.
///   3. Polls every [pollInterval], calling [heartbeat] each iteration.
///   4. Returns when a decision file is found or when [timeout] elapses
///      (auto-approve on timeout, [HitlDecisionType.timeout]).
///
/// External processes (CLI, GUI) write the decision via [submitDecision].
class HitlGateService {
  const HitlGateService();

  /// Returns the currently pending gate, or `null` if no gate is active.
  HitlGateInfo? pendingGate(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.hitlGatePath);
    if (!file.existsSync()) return null;
    return _readGate(file);
  }

  /// Writes a decision file that resolves the pending gate.
  ///
  /// Throws [StateError] if no gate is currently open at [projectRoot].
  void submitDecision(
    String projectRoot, {
    required HitlDecisionType decision,
    String? note,
  }) {
    if (pendingGate(projectRoot) == null) {
      throw StateError(
        'Cannot submit HITL decision: no gate is currently open at $projectRoot',
      );
    }
    final layout = ProjectLayout(projectRoot);
    final lines = StringBuffer()
      ..writeln('version=1')
      ..writeln('decision=${_decisionString(decision)}')
      ..writeln('decided_at=${DateTime.now().toUtc().toIso8601String()}');
    if (note != null && note.isNotEmpty) {
      lines.writeln('note=$note');
    }
    AtomicFileWrite.writeStringSync(layout.hitlDecisionPath, lines.toString());
  }

  /// Opens a gate and polls for a human decision.
  ///
  /// [heartbeat] is called on every poll iteration to keep the autopilot lock
  /// fresh. [timeout] of `null` (or `Duration.zero`) waits indefinitely.
  Future<HitlDecision> waitForDecision(
    String projectRoot, {
    required HitlGateInfo gate,
    required void Function() heartbeat,
    required Duration pollInterval,
    Duration? timeout,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);

    _writeGate(layout.hitlGatePath, gate);

    runLog.append(
      event: 'hitl_gate_opened',
      message: 'HITL gate opened: ${gate.event.serialized}',
      data: {
        'event': gate.event.serialized,
        if (gate.stepId != null) 'step_id': gate.stepId,
        if (gate.taskId != null) 'task_id': gate.taskId,
        if (gate.taskTitle != null) 'task_title': gate.taskTitle,
        if (gate.sprintNumber != null) 'sprint_number': gate.sprintNumber,
        if (gate.expiresAt != null)
          'expires_at': gate.expiresAt!.toIso8601String(),
        'error_class': 'hitl',
      },
    );

    final startedAt = DateTime.now().toUtc();
    final effectiveTimeout =
        (timeout == null || timeout == Duration.zero) ? null : timeout;

    while (true) {
      heartbeat();

      // Check for decision file.
      final decisionFile = File(layout.hitlDecisionPath);
      if (decisionFile.existsSync()) {
        final decision = _readDecision(decisionFile);
        _clearFiles(layout);
        runLog.append(
          event: 'hitl_gate_resolved',
          message: 'HITL gate resolved: ${decision.type.name}',
          data: {
            'decision': _decisionString(decision.type),
            if (gate.stepId != null) 'step_id': gate.stepId,
            if (decision.note != null) 'note': decision.note,
            'waited_seconds':
                DateTime.now().toUtc().difference(startedAt).inSeconds,
            'error_class': 'hitl',
          },
        );
        return decision;
      }

      // Check timeout.
      if (effectiveTimeout != null) {
        final elapsed = DateTime.now().toUtc().difference(startedAt);
        if (elapsed >= effectiveTimeout) {
          _clearFiles(layout);
          runLog.append(
            event: 'hitl_gate_timeout',
            message: 'HITL gate timed out — auto-approving',
            data: {
              'event': gate.event.serialized,
              if (gate.stepId != null) 'step_id': gate.stepId,
              'timeout_minutes': effectiveTimeout.inMinutes,
              'auto_action': 'approve',
              'error_class': 'hitl',
              'error_kind': 'hitl_timeout',
            },
          );
          return const HitlDecision(type: HitlDecisionType.timeout);
        }
      }

      await Future<void>.delayed(pollInterval);
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _writeGate(String gatePath, HitlGateInfo gate) {
    final lines = StringBuffer()
      ..writeln('version=1')
      ..writeln('event=${gate.event.serialized}')
      ..writeln('created_at=${gate.createdAt.toIso8601String()}');
    if (gate.stepId != null) lines.writeln('step_id=${gate.stepId}');
    if (gate.taskId != null) lines.writeln('task_id=${gate.taskId}');
    if (gate.taskTitle != null) lines.writeln('task_title=${gate.taskTitle}');
    if (gate.sprintNumber != null) {
      lines.writeln('sprint_number=${gate.sprintNumber}');
    }
    if (gate.expiresAt != null) {
      lines.writeln('expires_at=${gate.expiresAt!.toIso8601String()}');
    }
    AtomicFileWrite.writeStringSync(gatePath, lines.toString());
  }

  HitlGateInfo? _readGate(File file) {
    try {
      final content = file.readAsStringSync();
      final fields = _parseKeyValue(content);
      final event = HitlGateEvent.tryParse(fields['event']);
      if (event == null) return null;
      final createdAt =
          DateTime.tryParse(fields['created_at'] ?? '') ?? DateTime.now().toUtc();
      final expiresAt = fields['expires_at'] != null
          ? DateTime.tryParse(fields['expires_at']!)
          : null;
      final sprintStr = fields['sprint_number'];
      return HitlGateInfo(
        event: event,
        stepId: fields['step_id'],
        taskId: fields['task_id'],
        taskTitle: fields['task_title'],
        sprintNumber: sprintStr != null ? int.tryParse(sprintStr) : null,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  HitlDecision _readDecision(File file) {
    try {
      final content = file.readAsStringSync();
      final fields = _parseKeyValue(content);
      final decisionStr = fields['decision'] ?? 'approve';
      final type = decisionStr == 'reject'
          ? HitlDecisionType.reject
          : HitlDecisionType.approve;
      return HitlDecision(type: type, note: fields['note']);
    } catch (_) {
      return const HitlDecision(type: HitlDecisionType.approve);
    }
  }

  void _clearFiles(ProjectLayout layout) {
    try {
      File(layout.hitlGatePath).deleteSync();
    } catch (_) {}
    try {
      File(layout.hitlDecisionPath).deleteSync();
    } catch (_) {}
  }

  Map<String, String> _parseKeyValue(String content) {
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        result[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
      }
    }
    return result;
  }

  String _decisionString(HitlDecisionType type) {
    switch (type) {
      case HitlDecisionType.approve:
      case HitlDecisionType.timeout:
        return 'approve';
      case HitlDecisionType.reject:
        return 'reject';
    }
  }
}
