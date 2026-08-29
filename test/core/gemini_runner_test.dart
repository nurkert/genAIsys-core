import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/gemini_runner.dart';

void main() {
  test('GeminiRunner builds input with system prompt', () async {
    final runner = _TestGeminiRunner();

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

  test('GeminiRunner default args include --approval-mode yolo', () {
    final runner = GeminiRunner();

    expect(runner.executable, 'gemini');
    expect(runner.args, contains('--approval-mode'));
    expect(runner.args, contains('yolo'));
    expect(runner.args, contains('--prompt'));
  });

  test('GeminiRunner emits structured command event metadata', () async {
    final runner = GeminiRunner(
      executable: 'genaisys_missing_gemini',
      args: const ['--version'],
    );

    final response = await runner.run(
      AgentRequest(prompt: 'Ping', timeout: const Duration(seconds: 2)),
    );

    expect(response.commandEvent, isNotNull);
    expect(response.commandEvent!.executable, 'genaisys_missing_gemini');
    expect(response.commandEvent!.arguments, const ['--version']);
    expect(response.commandEvent!.phase, 'run');
  });

  test(
    'GeminiRunner fails closed when process produces no output (idle timeout)',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'genaisys_gemini_idle_timeout_',
      );
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final bin = Directory('${temp.path}${Platform.pathSeparator}bin');
      await bin.create(recursive: true);
      final fakeGemini = File('${bin.path}${Platform.pathSeparator}gemini');
      await fakeGemini.writeAsString('''#!/bin/sh
cat >/dev/null
sleep 5
''');
      await Process.run('chmod', ['+x', fakeGemini.path]);

      final runner = GeminiRunner(
        executable: 'gemini',
        args: const [
          '--approval-mode',
          'yolo',
          '--prompt',
          '-',
          '--output-format',
          'text',
        ],
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

  test('GeminiRunner config overrides with -y are prepended before --prompt',
      () async {
    final runner = GeminiRunner(
      executable: 'genaisys_missing_gemini',
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        timeout: const Duration(seconds: 2),
        environment: {
          'GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES': '-y',
        },
      ),
    );

    final args = response.commandEvent!.arguments;
    expect(args, contains('-y'));
    // -y must appear before --prompt so it doesn't split `--prompt -`.
    final yIndex = args.indexOf('-y');
    final promptIndex = args.indexOf('--prompt');
    expect(yIndex, lessThan(promptIndex));
  });

  test('GeminiRunner config overrides with --flag=value are prepended before '
      '--prompt', () async {
    final runner = GeminiRunner(
      executable: 'genaisys_missing_gemini',
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        timeout: const Duration(seconds: 2),
        environment: {
          'GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES':
              '-y\n--model=gemini-2.5-pro',
        },
      ),
    );

    final args = response.commandEvent!.arguments;
    expect(args, contains('-y'));
    expect(args, contains('--model=gemini-2.5-pro'));
    final promptIndex = args.indexOf('--prompt');
    expect(args.indexOf('-y'), lessThan(promptIndex));
    expect(args.indexOf('--model=gemini-2.5-pro'), lessThan(promptIndex));
  });

  test('GeminiRunner ignores invalid config override entries', () async {
    final runner = GeminiRunner(
      executable: 'genaisys_missing_gemini',
    );

    final response = await runner.run(
      AgentRequest(
        prompt: 'Implement feature',
        timeout: const Duration(seconds: 2),
        environment: {
          'GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES':
              '-y\n; rm -rf /\nvalid=nope',
        },
      ),
    );

    final args = response.commandEvent!.arguments;
    expect(args, contains('-y'));
    expect(args, isNot(contains('; rm -rf /')));
    expect(args, isNot(contains('valid=nope')));
  });
}

class _TestGeminiRunner extends GeminiRunner {
  String lastInput = '';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    lastInput = buildInput(request);
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
