import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/claude_code_runner.dart';

void main() {
  test('ClaudeCodeRunner buildInput returns only the user prompt', () {
    final runner = ClaudeCodeRunner();

    final input = runner.buildInput(
      AgentRequest(
        prompt: 'Implement feature',
        systemPrompt: 'You are a strict reviewer.',
      ),
    );

    // System prompt is passed via --system-prompt flag, not stdin.
    expect(input, 'Implement feature');
  });

  test('ClaudeCodeRunner builds input without system prompt', () {
    final runner = ClaudeCodeRunner();

    final input = runner.buildInput(AgentRequest(prompt: 'Just a prompt'));

    expect(input, 'Just a prompt');
  });

  test('ClaudeCodeRunner appends --system-prompt flag when system prompt set',
      () async {
    final runner = ClaudeCodeRunner(
      executable: 'genaisys_missing_claude',
      args: const ['-p', '--output-format', 'text'],
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        systemPrompt: 'You are a strict reviewer.',
        timeout: const Duration(seconds: 2),
      ),
    );

    expect(response.commandEvent, isNotNull);
    final args = response.commandEvent!.arguments;
    expect(args, contains('--system-prompt'));
    expect(args, contains('You are a strict reviewer.'));
  });

  test(
    'ClaudeCodeRunner does not append --system-prompt when system prompt is empty',
    () async {
      final runner = ClaudeCodeRunner(
        executable: 'genaisys_missing_claude',
        args: const ['-p', '--output-format', 'text'],
      );

      final response = await runner.run(
        AgentRequest(
          prompt: 'Implement feature',
          systemPrompt: '  ',
          timeout: const Duration(seconds: 2),
        ),
      );

      expect(response.commandEvent, isNotNull);
      final args = response.commandEvent!.arguments;
      expect(args, isNot(contains('--system-prompt')));
    },
  );

  test('ClaudeCodeRunner emits structured command event metadata', () async {
    final runner = ClaudeCodeRunner(
      executable: 'genaisys_missing_claude',
      args: const ['-p'],
    );

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.executable, 'genaisys_missing_claude');
    expect(response.commandEvent!.arguments, const ['-p']);
    expect(response.commandEvent!.phase, 'run');
  });

  test(
    'ClaudeCodeRunner fails closed when process produces no output (idle timeout)',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'genaisys_claude_idle_timeout_',
      );
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final bin = Directory('${temp.path}${Platform.pathSeparator}bin');
      await bin.create(recursive: true);
      final fakeClaude = File('${bin.path}${Platform.pathSeparator}claude');
      await fakeClaude.writeAsString('''#!/bin/sh
cat >/dev/null
sleep 5
''');
      await Process.run('chmod', ['+x', fakeClaude.path]);

      final runner = ClaudeCodeRunner(
        executable: 'claude',
        args: const ['-p', '--output-format', 'text'],
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

  test(
    'ClaudeCodeRunner applies --flag config overrides from environment',
    () async {
      final runner = ClaudeCodeRunner(
        executable: 'genaisys_missing_claude',
        args: const ['-p', '--output-format', 'text'],
      );

      final response = await runner.run(
        AgentRequest(
          prompt: 'Ping',
          timeout: const Duration(seconds: 2),
          environment: const {
            'GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES':
                '--model claude-sonnet-4-5-20250929\ninvalid_no_dash\n--max-turns 5',
          },
        ),
      );

      expect(response.commandEvent, isNotNull);
      expect(
        response.commandEvent!.arguments,
        equals([
          '-p',
          '--output-format',
          'text',
          '--model',
          'claude-sonnet-4-5-20250929',
          '--max-turns',
          '5',
        ]),
      );
    },
  );

  test(
    'ClaudeCodeRunner returns exit code 127 when executable not found',
    () async {
      final runner = ClaudeCodeRunner(executable: 'genaisys_missing_claude');

      final response = await runner.run(
        AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
      );

      expect(response.ok, isFalse);
      expect(response.exitCode == 126 || response.exitCode == 127, isTrue);
      expect(response.commandEvent, isNotNull);
      expect(response.commandEvent!.timedOut, isFalse);
    },
  );

  test('ClaudeCodeRunner default args use print mode with text output', () {
    final runner = ClaudeCodeRunner();

    expect(runner.executable, 'claude');
    expect(runner.args, ['-p', '--output-format', 'text']);
  });
}
