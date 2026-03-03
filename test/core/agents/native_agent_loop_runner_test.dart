import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/native_agent_loop_runner.dart';
import 'package:genaisys/core/agents/native_http_runner.dart';

void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}/v1';
    tempDir = Directory.systemTemp.createTempSync('loop_runner_test_');
    // Create an allowed directory with a test file.
    Directory('${tempDir.path}/lib').createSync(recursive: true);
    File('${tempDir.path}/lib/main.dart').writeAsStringSync('void main() {}');
  });

  tearDown(() async {
    await server.close(force: true);
    tempDir.deleteSync(recursive: true);
  });

  NativeAgentLoopRunner makeRunner({int maxTurns = 10}) {
    return NativeAgentLoopRunner(
      httpRunner: NativeHttpRunner(apiBase: baseUrl, model: 'test-model'),
      maxTurns: maxTurns,
      safeWriteEnabled: true,
      safeWriteRoots: const ['lib', 'test'],
      shellAllowlist: const ['echo', 'dart analyze'],
    );
  }

  void respondJson(HttpRequest req, Object json) {
    req.response
      ..statusCode = 200
      ..headers.set('Content-Type', 'application/json')
      ..write(jsonEncode(json));
    req.response.close();
  }

  Map<String, Object?> contentResponse(String content) {
    return {
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        },
      ],
    };
  }

  Map<String, Object?> toolCallResponse(
    List<Map<String, Object?>> toolCalls, {
    String? content,
  }) {
    return {
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': ?content,
            'tool_calls': toolCalls,
          },
          'finish_reason': 'stop',
        },
      ],
    };
  }

  Map<String, Object?> makeToolCall(
    String id,
    String name,
    Map<String, Object?> args,
  ) {
    return {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': jsonEncode(args)},
    };
  }

  group('NativeAgentLoopRunner', () {
    test('single-turn: LLM responds with content only', () async {
      server.listen((req) => respondJson(req, contentResponse('Done!')));

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'hello', workingDirectory: tempDir.path),
      );

      expect(response.exitCode, 0);
      expect(response.stdout, contains('Done!'));
      expect(response.commandEvent, isNotNull);
      expect(response.commandEvent!.executable, 'native');
    });

    test('multi-turn: read_file then content', () async {
      var turnCount = 0;
      server.listen((req) async {
        turnCount++;
        if (turnCount == 1) {
          // First turn: LLM asks to read a file.
          respondJson(
            req,
            toolCallResponse([
              makeToolCall('tc1', 'read_file', {'path': 'lib/main.dart'}),
            ]),
          );
        } else {
          // Second turn: LLM responds with content.
          respondJson(req, contentResponse('I read the file.'));
        }
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'read my file', workingDirectory: tempDir.path),
      );

      expect(response.exitCode, 0);
      expect(response.stdout, contains('I read the file.'));
      expect(response.stdout, contains('[tool:read_file] OK'));
      expect(turnCount, 2);
    });

    test('multi-turn: write_file creates file on disk', () async {
      var turnCount = 0;
      server.listen((req) async {
        turnCount++;
        if (turnCount == 1) {
          respondJson(
            req,
            toolCallResponse([
              makeToolCall('tc1', 'write_file', {
                'path': 'lib/new_file.dart',
                'content': '// new file',
              }),
            ]),
          );
        } else {
          respondJson(req, contentResponse('File created.'));
        }
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'create a file', workingDirectory: tempDir.path),
      );

      expect(response.exitCode, 0);
      expect(response.stdout, contains('File created.'));

      final newFile = File('${tempDir.path}/lib/new_file.dart');
      expect(newFile.existsSync(), isTrue);
      expect(newFile.readAsStringSync(), '// new file');
    });

    test('max-turns cap stops the loop', () async {
      // LLM always returns tool_calls, never content-only.
      server.listen((req) {
        respondJson(
          req,
          toolCallResponse([
            makeToolCall('tc_inf', 'read_file', {'path': 'lib/main.dart'}),
          ]),
        );
      });

      final runner = makeRunner(maxTurns: 3);
      final response = await runner.run(
        AgentRequest(prompt: 'infinite loop', workingDirectory: tempDir.path),
      );

      // Should have completed after maxTurns without error.
      expect(response.exitCode, 0);
      // Should have 3 tool calls logged.
      expect('[tool:read_file] OK'.allMatches(response.stdout).length, 3);
    });

    test('timeout mid-loop returns exit code 124', () async {
      server.listen((req) async {
        // Delay long enough to exhaust the tiny timeout budget.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        respondJson(req, contentResponse('too late'));
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(
          prompt: 'hi',
          workingDirectory: tempDir.path,
          timeout: const Duration(milliseconds: 100),
        ),
      );

      expect(response.exitCode, 124);
      expect(response.commandEvent!.timedOut, isTrue);
    });

    test('HTTP error mid-loop propagates as non-zero exitCode', () async {
      var turnCount = 0;
      server.listen((req) {
        turnCount++;
        if (turnCount == 1) {
          respondJson(
            req,
            toolCallResponse([
              makeToolCall('tc1', 'read_file', {'path': 'lib/main.dart'}),
            ]),
          );
        } else {
          // Second request returns 429.
          req.response
            ..statusCode = 429
            ..write('Too Many Requests');
          req.response.close();
        }
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'hi', workingDirectory: tempDir.path),
      );

      expect(response.exitCode, 429);
      expect(response.stderr, contains('rate limit'));
    });

    test('safe-write violation returns error to LLM, loop continues', () async {
      var turnCount = 0;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        final decoded = jsonDecode(body) as Map<String, Object?>;
        final messages = decoded['messages'] as List<Object?>;
        turnCount++;

        if (turnCount == 1) {
          // LLM tries to write to a protected path.
          respondJson(
            req,
            toolCallResponse([
              makeToolCall('tc1', 'write_file', {
                'path': '.git/config',
                'content': 'hacked',
              }),
            ]),
          );
        } else if (turnCount == 2) {
          // Verify the tool error was sent back.
          final lastMsg = messages.last as Map<String, Object?>;
          expect(lastMsg['role'], 'tool');
          expect(
            (lastMsg['content'] as String?)?.contains('safe-write policy'),
            isTrue,
          );
          respondJson(req, contentResponse('OK, I will not do that.'));
        } else {
          respondJson(req, contentResponse('done'));
        }
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'write to git', workingDirectory: tempDir.path),
      );

      expect(response.exitCode, 0);
      expect(response.stdout, contains('[tool:write_file] ERROR'));
      expect(response.stdout, contains('OK, I will not do that.'));
      expect(turnCount, 2);
    });

    test('finish_reason length stops the loop', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': 'partial',
                    'tool_calls': [
                      makeToolCall('tc1', 'read_file', {
                        'path': 'lib/main.dart',
                      }),
                    ],
                  },
                  'finish_reason': 'length',
                },
              ],
            }),
          );
        req.response.close();
      });

      final runner = makeRunner();
      final response = await runner.run(
        AgentRequest(prompt: 'hi', workingDirectory: tempDir.path),
      );

      // Should stop after first turn due to finish_reason=length.
      expect(response.exitCode, 0);
      expect(response.stdout, contains('partial'));
    });
  });
}
