import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner_mixin.dart';

void main() {
  group('AgentRunnerMixin.sanitizeEnvironment', () {
    test('strips CLAUDECODE from custom env map', () {
      final env = <String, String>{
        'PATH': '/usr/bin',
        'CLAUDECODE': 'some-value',
        'HOME': '/home/user',
      };

      final result = AgentRunnerMixin.sanitizeEnvironment(env);

      expect(result.containsKey('CLAUDECODE'), isFalse);
      expect(result['PATH'], '/usr/bin');
      expect(result['HOME'], '/home/user');
    });

    test('strips CLAUDECODE from inherited parent env (null input)', () {
      // When null is passed, sanitizeEnvironment copies Platform.environment
      // and strips blocked keys. We cannot inject CLAUDECODE into
      // Platform.environment in a test, but we can verify the contract:
      // the result must not contain CLAUDECODE regardless of whether it was
      // present in the parent environment.
      final result = AgentRunnerMixin.sanitizeEnvironment(null);

      expect(result.containsKey('CLAUDECODE'), isFalse);
      // The result should still contain standard platform keys that exist.
      if (Platform.environment.containsKey('PATH')) {
        expect(result.containsKey('PATH'), isTrue);
      }
    });

    test('preserves all other keys', () {
      final env = <String, String>{
        'PATH': '/usr/bin',
        'HOME': '/home/user',
        'LANG': 'en_US.UTF-8',
        'CLAUDECODE': 'secret',
        'EDITOR': 'vim',
      };

      final result = AgentRunnerMixin.sanitizeEnvironment(env);

      expect(result['PATH'], '/usr/bin');
      expect(result['HOME'], '/home/user');
      expect(result['LANG'], 'en_US.UTF-8');
      expect(result['EDITOR'], 'vim');
      expect(result, hasLength(4));
    });

    test('returns a copy (original is unmodified)', () {
      final original = <String, String>{
        'PATH': '/usr/bin',
        'CLAUDECODE': 'leaked-token',
        'HOME': '/home/user',
      };

      final result = AgentRunnerMixin.sanitizeEnvironment(original);

      // Original must still contain CLAUDECODE.
      expect(original.containsKey('CLAUDECODE'), isTrue);
      expect(original['CLAUDECODE'], 'leaked-token');
      expect(original, hasLength(3));

      // Result must not contain CLAUDECODE.
      expect(result.containsKey('CLAUDECODE'), isFalse);
      expect(result, hasLength(2));

      // Mutating the result must not affect the original.
      result['NEW_KEY'] = 'new-value';
      expect(original.containsKey('NEW_KEY'), isFalse);
    });
  });
}
