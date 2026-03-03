import 'dart:convert';

import 'package:test/test.dart';

import 'package:genaisys/core/services/productivity_reflection_service.dart';
import '../support/test_workspace.dart';

void main() {
  group('reflectionMinSamples wiring', () {
    late TestWorkspace workspace;

    setUp(() {
      workspace = TestWorkspace.create();
      workspace.ensureStructure();
    });

    tearDown(() => workspace.dispose());

    test('skips reflection when sample count is below configured minimum', () {
      workspace.writeConfig('reflection:\n  min_samples: 10\n');
      workspace.writeRunLog([
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_approve'),
      ]);

      final service = ProductivityReflectionService();
      final result = service.reflect(workspace.root.path);

      expect(result.triggered, isFalse);
    });

    test('proceeds with reflection when sample count meets minimum', () {
      workspace.writeConfig('reflection:\n  min_samples: 2\n');
      workspace.writeRunLog([
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_approve'),
      ]);

      final service = ProductivityReflectionService();
      final result = service.reflect(workspace.root.path);

      expect(result.triggered, isTrue);
    });
  });

  group('ReflectionTrigger shouldTrigger', () {
    late ProductivityReflectionService service;

    setUp(() {
      service = ProductivityReflectionService();
    });

    test('loop_count triggers when divisible', () {
      final trigger = ReflectionTrigger(mode: 'loop_count', threshold: 10);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 10,
          completedTasks: 3,
          elapsed: const Duration(hours: 1),
          trigger: trigger,
        ),
        isTrue,
      );
    });

    test('loop_count does not trigger when not divisible', () {
      final trigger = ReflectionTrigger(mode: 'loop_count', threshold: 10);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 7,
          completedTasks: 3,
          elapsed: const Duration(hours: 1),
          trigger: trigger,
        ),
        isFalse,
      );
    });

    test('loop_count does not trigger at zero', () {
      final trigger = ReflectionTrigger(mode: 'loop_count', threshold: 10);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 0,
          completedTasks: 0,
          elapsed: Duration.zero,
          trigger: trigger,
        ),
        isFalse,
      );
    });

    test('task_count triggers when divisible', () {
      final trigger = ReflectionTrigger(mode: 'task_count', threshold: 5);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 20,
          completedTasks: 15,
          elapsed: const Duration(hours: 2),
          trigger: trigger,
        ),
        isTrue,
      );
    });

    test('time triggers when hours exceeded', () {
      final trigger = ReflectionTrigger(mode: 'time', threshold: 4);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 100,
          completedTasks: 50,
          elapsed: const Duration(hours: 5),
          trigger: trigger,
        ),
        isTrue,
      );
    });

    test('time does not trigger before threshold', () {
      final trigger = ReflectionTrigger(mode: 'time', threshold: 4);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 100,
          completedTasks: 50,
          elapsed: const Duration(hours: 3),
          trigger: trigger,
        ),
        isFalse,
      );
    });

    test('unknown mode does not trigger', () {
      final trigger = ReflectionTrigger(mode: 'unknown', threshold: 1);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 100,
          completedTasks: 50,
          elapsed: const Duration(hours: 10),
          trigger: trigger,
        ),
        isFalse,
      );
    });

    test('zero threshold does not trigger', () {
      final trigger = ReflectionTrigger(mode: 'loop_count', threshold: 0);

      expect(
        service.shouldTrigger(
          '/dummy',
          completedLoops: 100,
          completedTasks: 50,
          elapsed: const Duration(hours: 10),
          trigger: trigger,
        ),
        isFalse,
      );
    });
  });
}

String _event(String event, {Map<String, Object?>? data}) {
  final payload = <String, Object?>{
    'timestamp': '2025-01-01T00:00:00Z',
    'event': event,
  };
  if (data != null) {
    payload['data'] = data;
  }
  return jsonEncode(payload);
}
