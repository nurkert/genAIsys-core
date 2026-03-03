import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_runner_mixin.dart';
import 'package:genaisys/core/agents/amp_runner.dart';

void main() {
  test('AmpRunner builds input with system prompt', () async {
    final runner = _TestAmpRunner();

    await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        systemPrompt: 'You are a strict reviewer.',
      ),
    );

    expect(
      runner.lastInput,
      'System: You are a strict reviewer.\n\nImplement feature',
    );
  });

  test('AmpRunner builds input without system prompt', () async {
    final runner = _TestAmpRunner();

    await runner.run(AgentRequest(prompt: 'Just a prompt'));

    expect(runner.lastInput, 'Just a prompt');
  });

  test('AmpRunner default args include -x and --dangerously-allow-all', () {
    final runner = AmpRunner();

    expect(runner.executable, 'amp');
    expect(runner.args, contains('-x'));
    expect(runner.args, contains('--dangerously-allow-all'));
  });

  test('AmpRunner emits structured command event metadata', () async {
    final runner = AmpRunner(
      executable: 'genaisys_missing_amp',
      args: const ['--version'],
    );

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.executable, 'genaisys_missing_amp');
    expect(response.commandEvent!.arguments, const ['--version']);
    expect(response.commandEvent!.phase, 'run');
  });

  test(
    'AmpRunner fails closed when process produces no output (idle timeout)',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'genaisys_amp_idle_timeout_',
      );
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final bin = Directory('${temp.path}${Platform.pathSeparator}bin');
      await bin.create(recursive: true);
      final fakeAmp = File('${bin.path}${Platform.pathSeparator}amp');
      await fakeAmp.writeAsString('''#!/bin/sh
cat >/dev/null
sleep 5
''');
      await Process.run('chmod', ['+x', fakeAmp.path]);

      final runner = AmpRunner(
        executable: 'amp',
        args: const ['-x', '--dangerously-allow-all'],
      );
      final env = <String, String>{
        'PATH': '${bin.path}:${Platform.environment['PATH'] ?? ''}',
        'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '1',
      };

      final response = await runner.run(
        AgentRequest(
          prompt: 'Ping',
          environment: env,
          timeout: const Duration(seconds: 10),
        ),
      );

      expect(response.ok, isFalse);
      expect(response.exitCode, 124);
      expect(response.stderr, contains('idle timeout'));
      expect(response.commandEvent, isNotNull);
      expect(response.commandEvent!.timedOut, isTrue);
    },
  );

  test('AmpRunner config overrides are appended after core args', () async {
    final runner = AmpRunner(
      executable: 'genaisys_missing_amp',
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        timeout: const Duration(seconds: 2),
        environment: {
          'GENAISYS_AMP_CLI_CONFIG_OVERRIDES':
              '--model claude-sonnet\ninvalid_no_dash',
        },
      ),
    );

    final args = response.commandEvent!.arguments;
    expect(args, contains('--model'));
    expect(args, contains('claude-sonnet'));
    // Overrides should be appended after core args (-x, --dangerously-allow-all).
    final xIndex = args.indexOf('-x');
    final modelIndex = args.indexOf('--model');
    expect(modelIndex, greaterThan(xIndex));
  });

  test('AmpRunner returns exit code 127 when executable not found', () async {
    final runner = AmpRunner(executable: 'genaisys_missing_amp');

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.ok, isFalse);
    expect(response.exitCode == 126 || response.exitCode == 127, isTrue);
    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.timedOut, isFalse);
  });

  test('CLAUDECODE env var is stripped from child environment', () {
    // Verify that sanitizeEnvironment removes CLAUDECODE (which Amp sets).
    final sanitized = AgentRunnerMixin.sanitizeEnvironment({
      'PATH': '/usr/bin',
      'CLAUDECODE': '1',
      'HOME': '/home/test',
    });
    expect(sanitized.containsKey('CLAUDECODE'), isFalse);
    expect(sanitized['PATH'], '/usr/bin');
    expect(sanitized['HOME'], '/home/test');
  });
}

class _TestAmpRunner extends AmpRunner {
  String lastInput = '';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    lastInput = buildInput(request);
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
