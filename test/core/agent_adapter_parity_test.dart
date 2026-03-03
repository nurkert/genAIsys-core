import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_runner_mixin.dart';
import 'package:genaisys/core/agents/amp_runner.dart';
import 'package:genaisys/core/agents/claude_code_runner.dart';
import 'package:genaisys/core/agents/codex_runner.dart';
import 'package:genaisys/core/agents/gemini_runner.dart';
import 'package:genaisys/core/agents/vibe_runner.dart';

/// Adapter parity test for all five CLI runners.
///
/// Verifies that all adapters:
/// - Implement the [AgentRunner] interface
/// - Use [AgentRunnerMixin] for shared behavior
/// - Have consistent `executable` and `args` getters
/// - Build correct input from [AgentRequest]
/// - Produce consistent [AgentCommandEvent] metadata
/// - Support customizable executable and args
void main() {
  group('Agent adapter parity', () {
    group('interface compliance', () {
      test('CodexRunner implements AgentRunner', () {
        final runner = CodexRunner();
        expect(runner, isA<AgentRunner>());
      });

      test('GeminiRunner implements AgentRunner', () {
        final runner = GeminiRunner();
        expect(runner, isA<AgentRunner>());
      });

      test('ClaudeCodeRunner implements AgentRunner', () {
        final runner = ClaudeCodeRunner();
        expect(runner, isA<AgentRunner>());
      });

      test('VibeRunner implements AgentRunner', () {
        final runner = VibeRunner();
        expect(runner, isA<AgentRunner>());
      });

      test('AmpRunner implements AgentRunner', () {
        final runner = AmpRunner();
        expect(runner, isA<AgentRunner>());
      });
    });

    group('default executable and args', () {
      test('CodexRunner defaults to codex executable', () {
        final runner = CodexRunner();
        expect(runner.executable, 'codex');
        expect(runner.args, contains('exec'));
      });

      test('GeminiRunner defaults to gemini executable', () {
        final runner = GeminiRunner();
        expect(runner.executable, 'gemini');
        expect(runner.args, contains('--prompt'));
      });

      test('ClaudeCodeRunner defaults to claude executable', () {
        final runner = ClaudeCodeRunner();
        expect(runner.executable, 'claude');
        expect(runner.args, contains('-p'));
      });

      test('VibeRunner defaults to vibe executable', () {
        final runner = VibeRunner();
        expect(runner.executable, 'vibe');
        expect(runner.args, contains('--prompt'));
        expect(runner.args, contains('--auto-approve'));
      });

      test('AmpRunner defaults to amp executable', () {
        final runner = AmpRunner();
        expect(runner.executable, 'amp');
        expect(runner.args, contains('-x'));
        expect(runner.args, contains('--dangerously-allow-all'));
      });
    });

    group('executable overrides', () {
      test('CodexRunner accepts custom executable', () {
        final runner = CodexRunner(executable: '/usr/local/bin/codex-custom');
        expect(runner.executable, '/usr/local/bin/codex-custom');
      });

      test('GeminiRunner accepts custom executable', () {
        final runner = GeminiRunner(executable: '/usr/local/bin/gemini-custom');
        expect(runner.executable, '/usr/local/bin/gemini-custom');
      });

      test('ClaudeCodeRunner accepts custom executable', () {
        final runner = ClaudeCodeRunner(
          executable: '/usr/local/bin/claude-custom',
        );
        expect(runner.executable, '/usr/local/bin/claude-custom');
      });

      test('VibeRunner accepts custom executable', () {
        final runner = VibeRunner(executable: '/usr/local/bin/vibe-custom');
        expect(runner.executable, '/usr/local/bin/vibe-custom');
      });

      test('AmpRunner accepts custom executable', () {
        final runner = AmpRunner(executable: '/usr/local/bin/amp-custom');
        expect(runner.executable, '/usr/local/bin/amp-custom');
      });
    });

    group('args overrides', () {
      test('CodexRunner accepts custom args', () {
        final runner = CodexRunner(args: ['run', '--verbose']);
        expect(runner.args, ['run', '--verbose']);
      });

      test('GeminiRunner accepts custom args', () {
        final runner = GeminiRunner(args: ['--model', 'pro']);
        expect(runner.args, ['--model', 'pro']);
      });

      test('ClaudeCodeRunner accepts custom args', () {
        final runner = ClaudeCodeRunner(args: ['-p', '--model', 'opus']);
        expect(runner.args, ['-p', '--model', 'opus']);
      });

      test('VibeRunner accepts custom args', () {
        final runner = VibeRunner(args: ['--model', 'large']);
        expect(runner.args, ['--model', 'large']);
      });

      test('AmpRunner accepts custom args', () {
        final runner = AmpRunner(args: ['-x', '--model', 'sonnet']);
        expect(runner.args, ['-x', '--model', 'sonnet']);
      });
    });

    group('buildInput consistency', () {
      test(
        'stdin-based runners produce identical input for same request without system prompt',
        () {
          final request = AgentRequest(prompt: 'Fix the bug');
          final codexInput = CodexRunner().buildInput(request);
          final geminiInput = GeminiRunner().buildInput(request);
          final vibeInput = VibeRunner().buildInput(request);
          final ampInput = AmpRunner().buildInput(request);

          expect(
            codexInput,
            geminiInput,
            reason: 'Stdin-based runners should produce identical input',
          );
          expect(geminiInput, vibeInput);
          expect(vibeInput, ampInput);
          expect(codexInput, 'Fix the bug');
        },
      );

      test(
        'ClaudeCodeRunner sends only prompt via stdin (system prompt via flag)',
        () {
          final request = AgentRequest(
            prompt: 'Fix the bug',
            systemPrompt: 'You are a coding agent.',
          );
          final claudeInput = ClaudeCodeRunner().buildInput(request);
          expect(claudeInput, 'Fix the bug');
        },
      );

      test(
        'stdin-based runners prepend system prompt to input consistently',
        () {
          final request = AgentRequest(
            prompt: 'Fix the bug',
            systemPrompt: 'You are a coding agent.',
          );
          final codexInput = CodexRunner().buildInput(request);
          final geminiInput = GeminiRunner().buildInput(request);
          final vibeInput = VibeRunner().buildInput(request);
          final ampInput = AmpRunner().buildInput(request);

          expect(codexInput, geminiInput);
          expect(geminiInput, vibeInput);
          expect(vibeInput, ampInput);
          expect(codexInput, contains('You are a coding agent.'));
          expect(codexInput, contains('Fix the bug'));
        },
      );
    });

    group('command event metadata consistency', () {
      test('all runners produce AgentCommandEvent with correct executable', () {
        final now = DateTime.now();
        final request = AgentRequest(prompt: 'test');

        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          final event = runner.buildCommandEvent(
            executable: runner.executable,
            arguments: runner.args,
            runInShell: false,
            request: request,
            startedAt: now,
            durationMs: 100,
            timedOut: false,
          );
          expect(event.executable, runner.executable);
          expect(event.timedOut, isFalse);
          expect(event.durationMs, 100);
        }
      });

      test('all runners report timeout in event when timed out', () {
        final now = DateTime.now();
        final request = AgentRequest(prompt: 'test');

        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          final event = runner.buildCommandEvent(
            executable: runner.executable,
            arguments: runner.args,
            runInShell: false,
            request: request,
            startedAt: now,
            durationMs: 30000,
            timedOut: true,
          );
          expect(
            event.timedOut,
            isTrue,
            reason: '${runner.executable} should report timedOut in event',
          );
        }
      });

      test('all runners include args in command line', () {
        final now = DateTime.now();
        final request = AgentRequest(prompt: 'test');

        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          final event = runner.buildCommandEvent(
            executable: runner.executable,
            arguments: runner.args,
            runInShell: false,
            request: request,
            startedAt: now,
            durationMs: 50,
            timedOut: false,
          );
          expect(event.commandLine, startsWith(runner.executable));
          for (final arg in runner.args) {
            expect(event.commandLine, contains(arg));
          }
        }
      });
    });

    group('idle timeout parsing', () {
      test('CodexRunner parses idle timeout from environment', () {
        final runner = CodexRunner();
        final timeout = runner.parseIdleTimeout({
          'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '30',
        });
        expect(timeout, const Duration(seconds: 30));
      });

      test('GeminiRunner parses idle timeout from environment', () {
        final runner = GeminiRunner();
        final timeout = runner.parseIdleTimeout({
          'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '45',
        });
        expect(timeout, const Duration(seconds: 45));
      });

      test('ClaudeCodeRunner parses idle timeout from environment', () {
        final runner = ClaudeCodeRunner();
        final timeout = runner.parseIdleTimeout({
          'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '60',
        });
        expect(timeout, const Duration(seconds: 60));
      });

      test('VibeRunner parses idle timeout from environment', () {
        final runner = VibeRunner();
        final timeout = runner.parseIdleTimeout({
          'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '50',
        });
        expect(timeout, const Duration(seconds: 50));
      });

      test('AmpRunner parses idle timeout from environment', () {
        final runner = AmpRunner();
        final timeout = runner.parseIdleTimeout({
          'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': '55',
        });
        expect(timeout, const Duration(seconds: 55));
      });

      test('all runners return null for missing idle timeout', () {
        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          expect(runner.parseIdleTimeout(null), isNull);
          expect(runner.parseIdleTimeout({}), isNull);
        }
      });

      test('all runners return null for invalid idle timeout', () {
        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          expect(
            runner.parseIdleTimeout({
              'GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS': 'not-a-number',
            }),
            isNull,
          );
        }
      });
    });

    group('error handling parity', () {
      test('all runners produce consistent process exception response', () {
        final request = AgentRequest(prompt: 'test');

        for (final runner in <AgentRunnerMixin>[
          CodexRunner(),
          GeminiRunner(),
          ClaudeCodeRunner(),
          VibeRunner(),
          AmpRunner(),
        ]) {
          final stopwatch = Stopwatch()..start();
          final response = runner.buildProcessExceptionResponse(
            exec: runner.executable,
            execArgs: runner.args,
            runInShell: false,
            request: request,
            startedAt: DateTime.now(),
            stopwatch: stopwatch,
            error: ProcessException(
              runner.executable,
              runner.args,
              'No such file or directory',
              2,
            ),
          );

          // Exit code 127 for missing executable
          expect(
            response.exitCode,
            anyOf(126, 127),
            reason:
                '${runner.executable} should return 126 or 127 for ProcessException',
          );
          expect(response.stderr, contains('No such file'));
          expect(response.commandEvent, isNotNull);
          expect(response.commandEvent!.executable, runner.executable);
        }
      });
    });

    group('timeout exit code', () {
      test('all runners use exit code 124 for timeout', () {
        expect(AgentRunnerMixin.timeoutExitCode, 124);
      });
    });
  });
}
