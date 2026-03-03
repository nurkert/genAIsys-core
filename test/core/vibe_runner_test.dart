import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/vibe_runner.dart';

void main() {
  test('VibeRunner builds input with system prompt', () async {
    final runner = _TestVibeRunner();

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

  test('VibeRunner builds input without system prompt', () async {
    final runner = _TestVibeRunner();

    await runner.run(AgentRequest(prompt: 'Just a prompt'));

    expect(runner.lastInput, 'Just a prompt');
  });

  test('VibeRunner default args include --auto-approve and --prompt', () {
    final runner = VibeRunner();

    expect(runner.executable, 'vibe');
    expect(runner.args, contains('--auto-approve'));
    expect(runner.args, contains('--prompt'));
    expect(runner.args, contains('-'));
  });

  test('VibeRunner emits structured command event metadata', () async {
    final runner = VibeRunner(
      executable: 'genaisys_missing_vibe',
      args: const ['--version'],
    );

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.executable, 'genaisys_missing_vibe');
    expect(response.commandEvent!.arguments, const ['--version']);
    expect(response.commandEvent!.phase, 'run');
  });

  test(
    'VibeRunner fails closed when process produces no output (idle timeout)',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'genaisys_vibe_idle_timeout_',
      );
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final bin = Directory('${temp.path}${Platform.pathSeparator}bin');
      await bin.create(recursive: true);
      final fakeVibe = File('${bin.path}${Platform.pathSeparator}vibe');
      await fakeVibe.writeAsString('''#!/bin/sh
cat >/dev/null
sleep 5
''');
      await Process.run('chmod', ['+x', fakeVibe.path]);

      final runner = VibeRunner(
        executable: 'vibe',
        args: const ['--prompt', '-', '--output', 'text', '--auto-approve'],
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

  test('VibeRunner config overrides are prepended before --prompt', () async {
    final runner = VibeRunner(
      executable: 'genaisys_missing_vibe',
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        timeout: const Duration(seconds: 2),
        environment: {
          'GENAISYS_VIBE_CLI_CONFIG_OVERRIDES':
              '--model mistral-large\ninvalid_no_dash',
        },
      ),
    );

    final args = response.commandEvent!.arguments;
    expect(args, contains('--model'));
    expect(args, contains('mistral-large'));
    // Overrides must appear before --prompt so they don't split `--prompt -`.
    final modelIndex = args.indexOf('--model');
    final promptIndex = args.indexOf('--prompt');
    expect(modelIndex, lessThan(promptIndex));
  });

  test('VibeRunner returns exit code 127 when executable not found', () async {
    final runner = VibeRunner(executable: 'genaisys_missing_vibe');

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.ok, isFalse);
    expect(response.exitCode == 126 || response.exitCode == 127, isTrue);
    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.timedOut, isFalse);
  });
}

class _TestVibeRunner extends VibeRunner {
  String lastInput = '';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    lastInput = buildInput(request);
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
