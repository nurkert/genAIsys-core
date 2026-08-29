import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/codex_runner.dart';

void main() {
  test('CodexRunner builds input with system prompt', () async {
    final runner = _TestCodexRunner();

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

  test('CodexRunner default args include exec, --color never, and stdin marker',
      () {
    final runner = CodexRunner();

    expect(runner.executable, 'codex');
    expect(runner.args, ['exec', '--color', 'never', '-']);
  });

  test('CodexRunner emits structured command event metadata', () async {
    final runner = CodexRunner(
      executable: 'genaisys_missing_codex',
      args: const ['--version'],
    );

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.executable, 'genaisys_missing_codex');
    expect(response.commandEvent!.arguments, const ['--version']);
    expect(response.commandEvent!.phase, 'run');
  });

  test(
    'CodexRunner fails closed when the process produces no output (idle timeout)',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'genaisys_codex_idle_timeout_',
      );
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final bin = Directory('${temp.path}${Platform.pathSeparator}bin');
      await bin.create(recursive: true);
      final fakeCodex = File('${bin.path}${Platform.pathSeparator}codex');
      await fakeCodex.writeAsString('''#!/bin/sh
cat >/dev/null
sleep 5
''');
      await Process.run('chmod', ['+x', fakeCodex.path]);

      final runner = CodexRunner(
        executable: 'codex',
        args: const ['exec', '--color', 'never', '-'],
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

  test('CodexRunner applies -c config overrides from environment', () async {
    final runner = CodexRunner(
      executable: 'genaisys_missing_codex',
      args: const ['exec', '--color', 'never', '-'],
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Ping',
        timeout: const Duration(seconds: 2),
        environment: const {
          'GENAISYS_CODEX_CLI_CONFIG_OVERRIDES':
              'reasoning_effort="low"\ninvalid\nmodel="gpt-5.3-codex"',
        },
      ),
    );

    expect(response.commandEvent, isNotNull);
    expect(
      response.commandEvent!.arguments,
      equals([
        'exec',
        '-c',
        'reasoning_effort="low"',
        '-c',
        'model="gpt-5.3-codex"',
        '--color',
        'never',
        '-',
      ]),
    );
  });
}

class _TestCodexRunner extends CodexRunner {
  String lastInput = '';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    lastInput = buildInput(request);
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
