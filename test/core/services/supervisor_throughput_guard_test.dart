import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/supervisor_state.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/supervisor_throughput_guard.dart';

void main() {
  group('SupervisorThroughputGuard', () {
    late SupervisorThroughputGuard guard;

    setUp(() {
      guard = SupervisorThroughputGuard();
    });

    group('rollWindow', () {
      test('accumulates steps and rejects', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 10,
            throughputRejects: 2,
            throughputHighRetries: 1,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 5,
            successfulSteps: 3,
            idleSteps: 0,
            failedSteps: 2,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 0,
          now: DateTime.utc(2026, 1, 1, 0, 10),
        );

        expect(result.steps, 15);
        expect(result.rejects, 4);
        expect(result.highRetries, 1);
        expect(result.halted, isFalse);
        expect(result.haltReason, isNull);
      });

      test('resets window when elapsed time exceeds window duration', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 100,
            throughputRejects: 50,
            throughputHighRetries: 10,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 3,
            successfulSteps: 3,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 0,
          now: DateTime.utc(2026, 1, 1, 1, 0), // 1 hour later
        );

        // Counters reset to zero + new segment values.
        expect(result.steps, 3);
        expect(result.rejects, 0);
        expect(result.highRetries, 0);
        expect(result.halted, isFalse);
      });

      test('halts on step limit breach', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 95,
            throughputRejects: 0,
            throughputHighRetries: 0,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 10,
            successfulSteps: 10,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 0,
          now: DateTime.utc(2026, 1, 1, 0, 10),
        );

        expect(result.halted, isTrue);
        expect(result.haltReason, 'throughput_steps');
      });

      test('halts on reject limit breach', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 10,
            throughputRejects: 8,
            throughputHighRetries: 0,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 5,
            successfulSteps: 0,
            idleSteps: 0,
            failedSteps: 5,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 10,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 0,
          now: DateTime.utc(2026, 1, 1, 0, 10),
        );

        expect(result.halted, isTrue);
        expect(result.haltReason, 'throughput_rejects');
      });

      test('halts on high retry limit breach', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 10,
            throughputRejects: 0,
            throughputHighRetries: 15,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 5,
            successfulSteps: 5,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 6, // 6 new high retries
          now: DateTime.utc(2026, 1, 1, 0, 10),
        );

        expect(result.halted, isTrue);
        expect(result.haltReason, 'throughput_high_retries');
        expect(result.highRetries, 21);
      });

      test('resets window when windowStartedAt is null', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: null,
            throughputSteps: 999,
            throughputRejects: 999,
            throughputHighRetries: 999,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 2,
            successfulSteps: 2,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 0,
          retry2PlusAfter: 0,
          now: DateTime.utc(2026, 1, 1),
        );

        expect(result.steps, 2);
        expect(result.rejects, 0);
        expect(result.highRetries, 0);
      });

      test('clamps negative retry delta to zero', () {
        final result = guard.rollWindow(
          currentState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-01T00:00:00.000Z',
            throughputSteps: 0,
            throughputRejects: 0,
            throughputHighRetries: 5,
          ),
          runResult: OrchestratorRunResult(
            totalSteps: 1,
            successfulSteps: 1,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          ),
          window: const Duration(minutes: 30),
          stepLimit: 100,
          rejectLimit: 50,
          highRetryLimit: 20,
          retry2PlusBefore: 10,
          retry2PlusAfter: 5, // negative delta
          now: DateTime.utc(2026, 1, 1, 0, 10),
        );

        expect(result.highRetries, 5); // unchanged
      });
    });

    group('evaluateDegradedMode', () {
      test('enters degraded mode when failure rate exceeds 60%', () {
        final result = guard.evaluateDegradedMode(
          throughput: const ThroughputResult(
            windowStartedAt: '',
            steps: 10,
            rejects: 7,
            highRetries: 0,
            halted: false,
            haltReason: null,
          ),
          currentDegradedMode: false,
        );

        expect(result.degradedMode, isTrue);
        expect(result.changed, isTrue);
        expect(result.failureRate, closeTo(0.7, 0.01));
      });

      test('exits degraded mode when failure rate drops below 30%', () {
        final result = guard.evaluateDegradedMode(
          throughput: const ThroughputResult(
            windowStartedAt: '',
            steps: 10,
            rejects: 2,
            highRetries: 0,
            halted: false,
            haltReason: null,
          ),
          currentDegradedMode: true,
        );

        expect(result.degradedMode, isFalse);
        expect(result.changed, isTrue);
        expect(result.failureRate, closeTo(0.2, 0.01));
      });

      test('stays in degraded mode between thresholds', () {
        final result = guard.evaluateDegradedMode(
          throughput: const ThroughputResult(
            windowStartedAt: '',
            steps: 10,
            rejects: 4, // 40% — between 30% exit and 60% entry
            highRetries: 0,
            halted: false,
            haltReason: null,
          ),
          currentDegradedMode: true,
        );

        expect(result.degradedMode, isTrue);
        expect(result.changed, isFalse);
      });

      test('stays in normal mode when failure rate is below entry threshold', () {
        final result = guard.evaluateDegradedMode(
          throughput: const ThroughputResult(
            windowStartedAt: '',
            steps: 10,
            rejects: 5, // 50% — below 60% entry
            highRetries: 0,
            halted: false,
            haltReason: null,
          ),
          currentDegradedMode: false,
        );

        expect(result.degradedMode, isFalse);
        expect(result.changed, isFalse);
      });

      test('preserves mode when no steps', () {
        final result = guard.evaluateDegradedMode(
          throughput: const ThroughputResult(
            windowStartedAt: '',
            steps: 0,
            rejects: 0,
            highRetries: 0,
            halted: false,
            haltReason: null,
          ),
          currentDegradedMode: true,
        );

        expect(result.degradedMode, isTrue);
        expect(result.changed, isFalse);
        expect(result.failureRate, isNull);
      });
    });

    group('isLowSignalSegment', () {
      test('returns false when successful steps > 0', () {
        expect(
          guard.isLowSignalSegment(OrchestratorRunResult(
            totalSteps: 10,
            successfulSteps: 1,
            idleSteps: 5,
            failedSteps: 4,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          )),
          isFalse,
        );
      });

      test('returns true when all steps are idle', () {
        expect(
          guard.isLowSignalSegment(OrchestratorRunResult(
            totalSteps: 5,
            successfulSteps: 0,
            idleSteps: 5,
            failedSteps: 0,
            stoppedByMaxSteps: false,
            stoppedWhenIdle: true,
            stoppedBySafetyHalt: false,
          )),
          isTrue,
        );
      });

      test('returns true when all steps are failures', () {
        expect(
          guard.isLowSignalSegment(OrchestratorRunResult(
            totalSteps: 5,
            successfulSteps: 0,
            idleSteps: 0,
            failedSteps: 5,
            stoppedByMaxSteps: true,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          )),
          isTrue,
        );
      });

      test('returns true for zero total steps', () {
        expect(
          guard.isLowSignalSegment(OrchestratorRunResult(
            totalSteps: 0,
            successfulSteps: 0,
            idleSteps: 0,
            failedSteps: 0,
            stoppedByMaxSteps: false,
            stoppedWhenIdle: false,
            stoppedBySafetyHalt: false,
          )),
          isTrue,
        );
      });
    });
  });
}
