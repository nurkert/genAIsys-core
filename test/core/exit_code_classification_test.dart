import 'package:test/test.dart';

import 'package:genaisys/core/errors/failure_reason_mapper.dart';

void main() {
  group('FailureReasonMapper.classifyExitCode', () {
    test('exit code 0 is success', () {
      final reason = FailureReasonMapper.classifyExitCode(0);
      expect(reason.errorClass, 'success');
      expect(reason.errorKind, 'success');
    });

    test('exit code 124 is timeout', () {
      final reason = FailureReasonMapper.classifyExitCode(124);
      expect(reason.errorClass, 'pipeline');
      expect(reason.errorKind, 'timeout');
    });

    test('exit code 126 is agent unavailable (permission denied)', () {
      final reason = FailureReasonMapper.classifyExitCode(126);
      expect(reason.errorClass, 'provider');
      expect(reason.errorKind, 'agent_unavailable');
    });

    test('exit code 127 is agent unavailable (not found)', () {
      final reason = FailureReasonMapper.classifyExitCode(127);
      expect(reason.errorClass, 'provider');
      expect(reason.errorKind, 'agent_unavailable');
    });

    test('exit code 134 (SIGABRT) is agent_crash_abort', () {
      final reason = FailureReasonMapper.classifyExitCode(134);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_crash_abort');
    });

    test('exit code 137 (SIGKILL) is agent_killed', () {
      final reason = FailureReasonMapper.classifyExitCode(137);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_killed');
    });

    test('exit code 138 (SIGBUS) is agent_crash_bus', () {
      final reason = FailureReasonMapper.classifyExitCode(138);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_crash_bus');
    });

    test('exit code 139 (SIGSEGV) is agent_crash_segv', () {
      final reason = FailureReasonMapper.classifyExitCode(139);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_crash_segv');
    });

    test('exit code 141 (SIGPIPE) is agent_pipe', () {
      final reason = FailureReasonMapper.classifyExitCode(141);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_pipe');
    });

    test('exit code 143 (SIGTERM) is agent_terminated', () {
      final reason = FailureReasonMapper.classifyExitCode(143);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_terminated');
    });

    test('exit code 130 (unmapped signal 2/SIGINT) falls back to signal_N', () {
      final reason = FailureReasonMapper.classifyExitCode(130);
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'signal_2');
    });

    test('exit code 1 (generic failure) is unknown', () {
      final reason = FailureReasonMapper.classifyExitCode(1);
      expect(reason.errorClass, 'unknown');
      expect(reason.errorKind, 'unknown');
    });

    test('exit code 192 (out of signal range) is unknown', () {
      final reason = FailureReasonMapper.classifyExitCode(192);
      expect(reason.errorClass, 'unknown');
      expect(reason.errorKind, 'unknown');
    });

    test('exit code 128 (boundary, not a signal) is unknown', () {
      final reason = FailureReasonMapper.classifyExitCode(128);
      expect(reason.errorClass, 'unknown');
      expect(reason.errorKind, 'unknown');
    });
  });

  group('FailureReasonMapper.isSignalExit', () {
    test('returns true for signal range 129..191', () {
      expect(FailureReasonMapper.isSignalExit(129), isTrue);
      expect(FailureReasonMapper.isSignalExit(139), isTrue);
      expect(FailureReasonMapper.isSignalExit(191), isTrue);
    });

    test('returns false for non-signal codes', () {
      expect(FailureReasonMapper.isSignalExit(0), isFalse);
      expect(FailureReasonMapper.isSignalExit(1), isFalse);
      expect(FailureReasonMapper.isSignalExit(124), isFalse);
      expect(FailureReasonMapper.isSignalExit(128), isFalse);
      expect(FailureReasonMapper.isSignalExit(192), isFalse);
    });
  });

  group('FailureReasonMapper.signalFromExitCode', () {
    test('returns signal number for signal exits', () {
      expect(FailureReasonMapper.signalFromExitCode(134), 6); // SIGABRT
      expect(FailureReasonMapper.signalFromExitCode(137), 9); // SIGKILL
      expect(FailureReasonMapper.signalFromExitCode(139), 11); // SIGSEGV
      expect(FailureReasonMapper.signalFromExitCode(143), 15); // SIGTERM
    });

    test('returns null for non-signal exits', () {
      expect(FailureReasonMapper.signalFromExitCode(0), isNull);
      expect(FailureReasonMapper.signalFromExitCode(1), isNull);
      expect(FailureReasonMapper.signalFromExitCode(128), isNull);
    });
  });

  group('FailureReasonMapper.signalName', () {
    test('returns human-readable names for well-known signals', () {
      expect(FailureReasonMapper.signalName(6), 'SIGABRT');
      expect(FailureReasonMapper.signalName(9), 'SIGKILL');
      expect(FailureReasonMapper.signalName(11), 'SIGSEGV');
      expect(FailureReasonMapper.signalName(15), 'SIGTERM');
    });

    test('returns SIG<N> for unknown signals', () {
      expect(FailureReasonMapper.signalName(42), 'SIG42');
      expect(FailureReasonMapper.signalName(99), 'SIG99');
    });
  });

  group('FailureReasonMapper._classByKind includes process kinds', () {
    test('signal kinds have process class in normalize path', () {
      final reason = FailureReasonMapper.normalize(
        errorKind: 'agent_crash_segv',
      );
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_crash_segv');
    });

    test('agent_killed kind has process class', () {
      final reason = FailureReasonMapper.normalize(errorKind: 'agent_killed');
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_killed');
    });

    test('agent_terminated kind has process class', () {
      final reason = FailureReasonMapper.normalize(
        errorKind: 'agent_terminated',
      );
      expect(reason.errorClass, 'process');
      expect(reason.errorKind, 'agent_terminated');
    });
  });
}
