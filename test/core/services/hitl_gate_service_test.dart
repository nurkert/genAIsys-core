import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/hitl_gate.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/hitl_gate_service.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late HitlGateService service;
  late ProjectLayout layout;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_hitl_');
    workspace.ensureStructure();
    service = const HitlGateService();
    layout = workspace.layout;
  });

  tearDown(() => workspace.dispose());

  HitlGateInfo _makeGate({
    HitlGateEvent event = HitlGateEvent.afterTaskDone,
    String? taskId,
    String? taskTitle,
    int? sprintNumber,
    DateTime? expiresAt,
  }) {
    return HitlGateInfo(
      event: event,
      taskId: taskId,
      taskTitle: taskTitle,
      sprintNumber: sprintNumber,
      createdAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
    );
  }

  group('pendingGate', () {
    test('returns null when no gate file exists', () {
      expect(service.pendingGate(workspace.root.path), isNull);
    });

    test('returns gate info when gate file is present', () async {
      final gate = _makeGate(
        event: HitlGateEvent.beforeSprint,
        sprintNumber: 2,
      );
      // Write gate via waitForDecision but cancel after first poll by writing
      // an approval decision immediately.
      // ignore: unawaited_futures
      service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );
      // Give the service time to write the gate file.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final pending = service.pendingGate(workspace.root.path);
      expect(pending, isNotNull);
      expect(pending!.event, HitlGateEvent.beforeSprint);
      expect(pending.sprintNumber, 2);
    });
  });

  group('submitDecision', () {
    test('writes a decision file in key=value format', () async {
      // Open a gate first so submitDecision is valid.
      final gate = _makeGate();
      // ignore: unawaited_futures
      service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.approve,
        note: 'looks good',
      );
      final file = File(layout.hitlDecisionPath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('decision=approve'));
      expect(content, contains('note=looks good'));
      expect(content, contains('decided_at='));
    });

    test('reject writes decision=reject', () async {
      // Open a gate first so submitDecision is valid.
      final gate = _makeGate();
      // ignore: unawaited_futures
      service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.reject,
      );
      final content = File(layout.hitlDecisionPath).readAsStringSync();
      expect(content, contains('decision=reject'));
    });
  });

  group('waitForDecision — approve via decision file', () {
    test('resolves approved when decision file written', () async {
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      // Write decision after a short delay.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.approve,
        note: 'all good',
      );

      final decision = await resultFuture;
      expect(decision.approved, isTrue);
      expect(decision.type, HitlDecisionType.approve);
      expect(decision.note, 'all good');
    });

    test('clears gate and decision files after resolution', () async {
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.approve,
      );

      await resultFuture;
      expect(File(layout.hitlGatePath).existsSync(), isFalse);
      expect(File(layout.hitlDecisionPath).existsSync(), isFalse);
    });
  });

  group('waitForDecision — reject via decision file', () {
    test('resolves not-approved when decision=reject', () async {
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.reject,
        note: 'not ready',
      );

      final decision = await resultFuture;
      expect(decision.approved, isFalse);
      expect(decision.type, HitlDecisionType.reject);
      expect(decision.note, 'not ready');
    });
  });

  group('waitForDecision — timeout auto-approve', () {
    test('auto-approves after timeout elapses', () async {
      final gate = _makeGate();
      final result = await service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
        timeout: const Duration(milliseconds: 50),
      );

      expect(result.type, HitlDecisionType.timeout);
      expect(result.approved, isTrue);
    });

    test('clears gate file on timeout', () async {
      final gate = _makeGate();
      await service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
        timeout: const Duration(milliseconds: 50),
      );

      expect(File(layout.hitlGatePath).existsSync(), isFalse);
    });
  });

  group('waitForDecision — infinite timeout', () {
    test('does not auto-approve when timeout is null (resolves on decision)',
        () async {
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
        // timeout: null → infinite wait
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Should still be waiting — write approval now.
      service.submitDecision(
        workspace.root.path,
        decision: HitlDecisionType.approve,
      );

      final result = await resultFuture;
      expect(result.type, HitlDecisionType.approve);
      expect(result.approved, isTrue);
    });
  });

  group('gate file format', () {
    test('gate file contains all expected key=value fields', () async {
      final now = DateTime.utc(2026, 3, 1, 12, 0, 0);
      final expires = now.add(const Duration(hours: 1));
      final gate = HitlGateInfo(
        event: HitlGateEvent.afterTaskDone,
        taskId: 'task-123',
        taskTitle: 'Implement auth',
        sprintNumber: 3,
        createdAt: now,
        expiresAt: expires,
      );

      // ignore: unawaited_futures
      service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final content = File(layout.hitlGatePath).readAsStringSync();
      expect(content, contains('event=after_task_done'));
      expect(content, contains('task_id=task-123'));
      expect(content, contains('task_title=Implement auth'));
      expect(content, contains('sprint_number=3'));
      expect(content, contains('created_at='));
      expect(content, contains('expires_at='));
    });

    test('stepId survives write→read round-trip', () async {
      final gate = HitlGateInfo(
        event: HitlGateEvent.afterTaskDone,
        stepId: 'run-abc-5',
        taskId: 'task-42',
        taskTitle: 'Deploy feature',
        createdAt: DateTime.utc(2026, 3, 1, 9, 0, 0),
      );

      // ignore: unawaited_futures
      service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final content = File(layout.hitlGatePath).readAsStringSync();
      expect(content, contains('step_id=run-abc-5'));

      final pending = service.pendingGate(workspace.root.path);
      expect(pending, isNotNull);
      expect(pending!.stepId, 'run-abc-5');
      expect(pending.taskId, 'task-42');
    });
  });

  group('heartbeat callback', () {
    test('heartbeat is called on each poll iteration', () async {
      var heartbeatCount = 0;
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () => heartbeatCount++,
        pollInterval: const Duration(milliseconds: 20),
        timeout: const Duration(milliseconds: 100),
      );

      await resultFuture;
      expect(heartbeatCount, greaterThan(1));
    });
  });

  group('submitDecision validation', () {
    test('throws StateError when no gate is open', () {
      expect(
        () => service.submitDecision(
          workspace.root.path,
          decision: HitlDecisionType.approve,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds when gate is open', () async {
      final gate = _makeGate();
      final resultFuture = service.waitForDecision(
        workspace.root.path,
        gate: gate,
        heartbeat: () {},
        pollInterval: const Duration(milliseconds: 20),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Should not throw — gate is open.
      expect(
        () => service.submitDecision(
          workspace.root.path,
          decision: HitlDecisionType.approve,
        ),
        returnsNormally,
      );
      await resultFuture;
    });
  });
}
