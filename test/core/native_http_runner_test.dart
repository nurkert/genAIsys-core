import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/native_http_runner.dart';

void main() {
  group('NativeHttpRunner', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}/v1';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('returns assistant content on HTTP 200', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'Hello world'},
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      expect(response.exitCode, 0);
      expect(response.stdout, 'Hello world');
      expect(response.stderr, isEmpty);
      expect(response.commandEvent, isNotNull);
      expect(response.commandEvent!.executable, 'native');
    });

    test('maps HTTP 429 to exitCode 429 with rate limit in stderr', () async {
      server.listen((req) {
        req.response
          ..statusCode = 429
          ..write('Too Many Requests');
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      expect(response.exitCode, 429);
      expect(response.stderr, contains('rate limit'));
    });

    test('maps HTTP 401 to exitCode 1 with unauthorized in stderr', () async {
      server.listen((req) {
        req.response
          ..statusCode = 401
          ..write('Invalid token');
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      expect(response.exitCode, 1);
      expect(response.stderr, contains('unauthorized'));
    });

    test('maps SocketException to exitCode 127', () async {
      final port = server.port;
      await server.close(force: true);

      final runner = NativeHttpRunner(
        apiBase: 'http://127.0.0.1:$port/v1',
        model: 'test-model',
      );
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      expect(response.exitCode, 127);
      expect(response.stderr, contains('Connection refused'));
      expect(response.commandEvent, isNotNull);
    });

    test('maps timeout to exitCode 124', () async {
      server.listen((req) async {
        // Never respond — hang until timeout triggers.
        await Future<void>.delayed(const Duration(seconds: 30));
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(
        AgentRequest(
          prompt: 'Hi',
          timeout: const Duration(milliseconds: 200),
        ),
      );

      expect(response.exitCode, 124);
      expect(response.commandEvent!.timedOut, isTrue);
    });

    test('returns raw body as stdout on malformed JSON', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..write('not json at all');
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      expect(response.exitCode, 0);
      expect(response.stdout, 'not json at all');
    });

    test('resolves API key from environment', () async {
      String? receivedAuth;
      server.listen((req) {
        receivedAuth = req.headers.value('authorization');
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      await runner.run(
        AgentRequest(
          prompt: 'Hi',
          environment: {'GENAISYS_NATIVE_API_KEY': 'sk-test-123'},
        ),
      );

      expect(receivedAuth, 'Bearer sk-test-123');
    });

    test('includes system prompt as system message', () async {
      Map<String, Object?>? receivedBody;
      server.listen((req) async {
        final raw = await utf8.decodeStream(req);
        receivedBody = jsonDecode(raw) as Map<String, Object?>;
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      await runner.run(
        AgentRequest(prompt: 'User question', systemPrompt: 'Be concise.'),
      );

      final messages = receivedBody!['messages'] as List<Object?>;
      expect(messages.length, 2);
      expect((messages.first as Map)['role'], 'system');
      expect((messages.first as Map)['content'], 'Be concise.');
      expect((messages.last as Map)['role'], 'user');
      expect((messages.last as Map)['content'], 'User question');
    });

    test('commandEvent has valid fields', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final response = await runner.run(AgentRequest(prompt: 'Hi'));

      final event = response.commandEvent!;
      expect(event.executable, isNotEmpty);
      expect(event.executable, 'native');
      expect(DateTime.tryParse(event.startedAt), isNotNull);
      expect(event.durationMs, greaterThanOrEqualTo(0));
      expect(event.runInShell, isFalse);
      expect(event.phase, 'run');
      expect(event.arguments, contains('POST'));
    });
  });

  group('NativeHttpRunner.chatWithTools', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}/v1';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('parses tool_calls correctly', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'read_file',
                        'arguments': '{"path": "lib/main.dart"}',
                      },
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final result = await runner.chatWithTools(
        messages: [
          {'role': 'user', 'content': 'read the file'},
        ],
      );

      expect(result.ok, isTrue);
      expect(result.hasToolCalls, isTrue);
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.first.functionName, 'read_file');
      expect(result.toolCalls.first.arguments['path'], 'lib/main.dart');
      expect(result.assistantMessage, isNotNull);
      expect(result.assistantMessage!['role'], 'assistant');
    });

    test('content-only response has no tool_calls', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Just text.',
                },
                'finish_reason': 'stop',
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final result = await runner.chatWithTools(
        messages: [
          {'role': 'user', 'content': 'hello'},
        ],
      );

      expect(result.ok, isTrue);
      expect(result.hasToolCalls, isFalse);
      expect(result.content, 'Just text.');
      expect(result.finishReason, 'stop');
    });

    test('malformed tool_calls degrade gracefully', () async {
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'partial',
                  'tool_calls': [
                    'not a map',
                    {
                      'id': 'c1',
                      // Missing 'function' key.
                    },
                    {
                      'id': 'c2',
                      'function': {
                        'name': 'read_file',
                        'arguments': 'INVALID JSON{{{',
                      },
                    },
                  ],
                },
                'finish_reason': 'stop',
              },
            ],
          }));
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final result = await runner.chatWithTools(
        messages: [
          {'role': 'user', 'content': 'hello'},
        ],
      );

      expect(result.ok, isTrue);
      expect(result.content, 'partial');
      // Only the third tool_call should parse (with empty arguments fallback).
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.first.functionName, 'read_file');
      expect(result.toolCalls.first.arguments, isEmpty);
    });

    test('HTTP 429 returns non-zero exitCode', () async {
      server.listen((req) {
        req.response
          ..statusCode = 429
          ..write('Rate limited');
        req.response.close();
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final result = await runner.chatWithTools(
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      );

      expect(result.ok, isFalse);
      expect(result.exitCode, 429);
      expect(result.stderr, contains('rate limit'));
    });

    test('timeout returns exit code 124', () async {
      server.listen((req) async {
        await Future<void>.delayed(const Duration(seconds: 30));
      });

      final runner = NativeHttpRunner(apiBase: baseUrl, model: 'test-model');
      final result = await runner.chatWithTools(
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.ok, isFalse);
      expect(result.exitCode, 124);
    });
  });
}
