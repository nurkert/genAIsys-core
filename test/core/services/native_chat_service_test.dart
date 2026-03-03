import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/native_http_runner.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/native_chat_service.dart';

void main() {
  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}/v1';
  });

  tearDown(() async {
    await server.close(force: true);
  });

  void respondContent(HttpRequest req, String content, {String? finishReason}) {
    req.response
      ..statusCode = 200
      ..headers.set('Content-Type', 'application/json')
      ..write(jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content},
            'finish_reason': finishReason ?? 'stop',
          },
        ],
      }));
    req.response.close();
  }

  NativeChatService makeService({String? systemPrompt}) {
    return NativeChatService(
      httpRunner: NativeHttpRunner(apiBase: baseUrl, model: 'test-model'),
      systemPrompt: systemPrompt,
    );
  }

  group('NativeChatService', () {
    test('send returns assistant reply', () async {
      server.listen((req) => respondContent(req, 'Hello!'));

      final service = makeService();
      final result = await service.send('Hi');

      expect(result.ok, isTrue);
      expect(result.content, 'Hello!');
      expect(result.finishReason, 'stop');
    });

    test('conversation history accumulates across turns', () async {
      var turnCount = 0;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        final decoded = jsonDecode(body) as Map<String, Object?>;
        final messages = decoded['messages'] as List<Object?>;

        turnCount++;
        if (turnCount == 1) {
          // First turn: system + 1 user message.
          expect(messages, hasLength(2));
          respondContent(req, 'Reply 1');
        } else {
          // Second turn: system + user1 + assistant1 + user2.
          expect(messages, hasLength(4));
          respondContent(req, 'Reply 2');
        }
      });

      final service = makeService(systemPrompt: 'Be helpful.');

      await service.send('First');
      expect(service.messages, hasLength(2));

      await service.send('Second');
      expect(service.messages, hasLength(4));
      expect(service.messages[0].role, 'user');
      expect(service.messages[1].role, 'assistant');
      expect(service.messages[2].role, 'user');
      expect(service.messages[3].role, 'assistant');
    });

    test('includes system prompt in wire messages', () async {
      Map<String, Object?>? receivedBody;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        receivedBody = jsonDecode(body) as Map<String, Object?>;
        respondContent(req, 'ok');
      });

      final service = makeService(systemPrompt: 'You are a poet.');
      await service.send('Hello');

      final messages = receivedBody!['messages'] as List<Object?>;
      expect((messages.first as Map)['role'], 'system');
      expect((messages.first as Map)['content'], 'You are a poet.');
    });

    test('does not include system prompt when null', () async {
      Map<String, Object?>? receivedBody;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        receivedBody = jsonDecode(body) as Map<String, Object?>;
        respondContent(req, 'ok');
      });

      final service = makeService();
      await service.send('Hello');

      final messages = receivedBody!['messages'] as List<Object?>;
      expect(messages, hasLength(1));
      expect((messages.first as Map)['role'], 'user');
    });

    test('does not send tools in request body', () async {
      Map<String, Object?>? receivedBody;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        receivedBody = jsonDecode(body) as Map<String, Object?>;
        respondContent(req, 'ok');
      });

      final service = makeService();
      await service.send('Hello');

      expect(receivedBody!.containsKey('tools'), isFalse);
    });

    test('error removes user message from history for retry', () async {
      server.listen((req) {
        req.response
          ..statusCode = 429
          ..write('Rate limited');
        req.response.close();
      });

      final service = makeService();
      final result = await service.send('Hi');

      expect(result.ok, isFalse);
      expect(result.errorMessage, contains('rate limit'));
      expect(result.exitCode, 429);
      // History should be empty — failed message was rolled back.
      expect(service.messages, isEmpty);
    });

    test('empty message returns error without sending request', () async {
      var requestCount = 0;
      server.listen((req) {
        requestCount++;
        respondContent(req, 'ok');
      });

      final service = makeService();
      final result = await service.send('   ');

      expect(result.ok, isFalse);
      expect(result.errorMessage, contains('Empty'));
      expect(requestCount, 0);
    });

    test('reset clears conversation history', () async {
      server.listen((req) => respondContent(req, 'reply'));

      final service = makeService();
      await service.send('Hello');
      expect(service.messages, hasLength(2));

      service.reset();
      expect(service.messages, isEmpty);
    });

    test('restore replaces conversation history', () async {
      final service = makeService();
      service.restore([
        const ChatMessage.user('Restored question'),
        const ChatMessage.assistant('Restored answer'),
      ]);

      expect(service.messages, hasLength(2));
      expect(service.messages[0].content, 'Restored question');
      expect(service.messages[1].content, 'Restored answer');
    });

    test('restore + send carries restored context', () async {
      Map<String, Object?>? receivedBody;
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        receivedBody = jsonDecode(body) as Map<String, Object?>;
        respondContent(req, 'new reply');
      });

      final service = makeService();
      service.restore([
        const ChatMessage.user('old question'),
        const ChatMessage.assistant('old answer'),
      ]);
      await service.send('follow-up');

      final messages = receivedBody!['messages'] as List<Object?>;
      // old user + old assistant + new user = 3 messages.
      expect(messages, hasLength(3));
      expect((messages[0] as Map)['content'], 'old question');
      expect((messages[1] as Map)['content'], 'old answer');
      expect((messages[2] as Map)['content'], 'follow-up');
    });

    test('timeout returns error', () async {
      server.listen((req) async {
        await Future<void>.delayed(const Duration(seconds: 30));
      });

      final service = makeService();
      final result = await service.send(
        'Hi',
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.ok, isFalse);
      expect(service.messages, isEmpty);
    });

    test('model and apiBase accessors', () {
      final service = makeService();
      expect(service.model, 'test-model');
      expect(service.apiBase, baseUrl);
    });

    test('fromConfig factory', () {
      final service = NativeChatService.fromConfig(
        const NativeProviderConfig(
          apiBase: 'http://localhost:11434/v1',
          model: 'qwen2.5:14b',
        ),
        systemPrompt: 'test',
      );
      expect(service.model, 'qwen2.5:14b');
      expect(service.apiBase, 'http://localhost:11434/v1');
    });
  });
}
