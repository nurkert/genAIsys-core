// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent_runner.dart';

/// Runner that calls any OpenAI-compatible chat completions endpoint via HTTP.
///
/// Primary target: Ollama (`http://localhost:11434/v1`). Also compatible with
/// any provider that implements the `/chat/completions` wire format (OpenAI,
/// Together AI, Groq, vLLM, llama.cpp server, etc.).
///
/// This runner does NOT use a subprocess — HTTP I/O is pure Dart.
/// The [AgentCommandEvent.executable] is the synthetic token `'native'`,
/// which satisfies the shell-allowlist policy without real shell execution.
class NativeHttpRunner implements AgentRunner {
  NativeHttpRunner({
    required this.apiBase,
    required this.model,
    this.apiKey = '',
    this.temperature = 0.1,
    this.maxTokens = 16384,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String apiBase;
  final String model;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final HttpClient _httpClient;

  /// Synthetic executable token for shell-allowlist matching.
  static const String syntheticExecutable = 'native';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final startedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();

    final effectiveApiKey = _resolveApiKey(request.environment);
    final body = _buildRequestBody(request);

    try {
      final result = await _sendRequest(
        body: body,
        apiKey: effectiveApiKey,
        timeout: request.timeout,
      );
      stopwatch.stop();

      return AgentResponse(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        commandEvent: _buildCommandEvent(
          request: request,
          startedAt: startedAt,
          durationMs: stopwatch.elapsedMilliseconds,
          timedOut: false,
        ),
      );
    } on TimeoutException {
      stopwatch.stop();
      return AgentResponse(
        exitCode: 124,
        stdout: '',
        stderr: 'Timed out after ${request.timeout?.inSeconds ?? 0}s.',
        commandEvent: _buildCommandEvent(
          request: request,
          startedAt: startedAt,
          durationMs: stopwatch.elapsedMilliseconds,
          timedOut: true,
        ),
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return AgentResponse(
        exitCode: 127,
        stdout: '',
        stderr: 'Connection refused: ${e.message}',
        commandEvent: _buildCommandEvent(
          request: request,
          startedAt: startedAt,
          durationMs: stopwatch.elapsedMilliseconds,
          timedOut: false,
        ),
      );
    } on HttpException catch (e) {
      stopwatch.stop();
      return AgentResponse(
        exitCode: 1,
        stdout: '',
        stderr: 'HTTP error: ${e.message}',
        commandEvent: _buildCommandEvent(
          request: request,
          startedAt: startedAt,
          durationMs: stopwatch.elapsedMilliseconds,
          timedOut: false,
        ),
      );
    }
  }

  /// Multi-turn chat completions call with optional tool definitions.
  ///
  /// Unlike [run], this method takes a raw messages list and returns the full
  /// parsed response including any `tool_calls` the model may have produced.
  Future<NativeHttpChatResult> chatWithTools({
    required List<Map<String, Object?>> messages,
    List<Map<String, Object?>>? tools,
    String? apiKeyOverride,
    Duration? timeout,
    int maxRetries = 2,
  }) async {
    final effectiveApiKey =
        apiKeyOverride ?? (apiKey.isNotEmpty ? apiKey : '');
    final body = <String, Object?>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    };

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final rawResult = await _sendRawRequest(
          body: body,
          apiKey: effectiveApiKey,
          timeout: timeout,
        );

        if (rawResult.statusCode != 200) {
          final mapped =
              _mapHttpResponse(rawResult.statusCode, rawResult.body);
          return NativeHttpChatResult(
            exitCode: mapped.exitCode,
            stderr: mapped.stderr,
          );
        }

        return _parseChatResponse(rawResult.body);
      } on TimeoutException {
        return const NativeHttpChatResult(
          exitCode: 124,
          stderr: 'Timed out.',
        );
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          await Future<void>.delayed(
            Duration(seconds: 5 * (attempt + 1)),
          );
          continue;
        }
        return NativeHttpChatResult(
          exitCode: 127,
          stderr: 'Connection refused after ${attempt + 1} attempts: '
              '${e.message}',
        );
      } on HttpException catch (e) {
        if (attempt < maxRetries) {
          await Future<void>.delayed(
            Duration(seconds: 5 * (attempt + 1)),
          );
          continue;
        }
        return NativeHttpChatResult(
          exitCode: 1,
          stderr: 'HTTP error after ${attempt + 1} attempts: ${e.message}',
        );
      }
    }

    // Unreachable but satisfies the compiler.
    return const NativeHttpChatResult(
      exitCode: 1,
      stderr: 'Unexpected: all retry attempts exhausted.',
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _resolveApiKey(Map<String, String>? environment) {
    if (apiKey.isNotEmpty) return apiKey;
    return environment?['GENAISYS_NATIVE_API_KEY'] ?? '';
  }

  Map<String, Object> _buildRequestBody(AgentRequest request) {
    final messages = <Map<String, String>>[
      if (request.systemPrompt != null &&
          request.systemPrompt!.trim().isNotEmpty)
        {'role': 'system', 'content': request.systemPrompt!},
      {'role': 'user', 'content': request.prompt},
    ];
    return {
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
    };
  }

  Future<_HttpResult> _sendRequest({
    required Map<String, Object> body,
    required String apiKey,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$apiBase/chat/completions');
    final encodedBody = utf8.encode(jsonEncode(body));

    Future<_HttpResult> doRequest() async {
      final request = await _httpClient.openUrl('POST', uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Accept', 'application/json');
      if (apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      request.headers.set('Content-Length', encodedBody.length.toString());
      request.add(encodedBody);

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      return _mapHttpResponse(response.statusCode, responseBody);
    }

    if (timeout != null && timeout.inMilliseconds > 0) {
      return await doRequest().timeout(timeout);
    }
    return await doRequest();
  }

  Future<_RawHttpResult> _sendRawRequest({
    required Map<String, Object?> body,
    required String apiKey,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$apiBase/chat/completions');
    final encodedBody = utf8.encode(jsonEncode(body));

    Future<_RawHttpResult> doRequest() async {
      final request = await _httpClient.openUrl('POST', uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Accept', 'application/json');
      if (apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      request.headers.set('Content-Length', encodedBody.length.toString());
      request.add(encodedBody);

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      return _RawHttpResult(
        statusCode: response.statusCode,
        body: responseBody,
      );
    }

    if (timeout != null && timeout.inMilliseconds > 0) {
      return await doRequest().timeout(timeout);
    }
    return await doRequest();
  }

  _HttpResult _mapHttpResponse(int statusCode, String body) {
    if (statusCode == 200) {
      return _HttpResult(
        exitCode: 0,
        stdout: _extractContent(body),
        stderr: '',
      );
    }
    if (statusCode == 429) {
      return _HttpResult(
        exitCode: 429,
        stdout: '',
        stderr: 'rate limit: HTTP 429 Too Many Requests. $body',
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return _HttpResult(
        exitCode: 1,
        stdout: '',
        stderr: 'unauthorized: HTTP $statusCode. $body',
      );
    }
    return _HttpResult(
      exitCode: 1,
      stdout: '',
      stderr: 'HTTP $statusCode: $body',
    );
  }

  String _extractContent(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return body;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return '';
      final first = choices.first;
      if (first is! Map<String, Object?>) return '';
      final message = first['message'];
      if (message is! Map<String, Object?>) return '';
      final content = message['content'];
      return content is String ? content : '';
    } catch (_) {
      // Best-effort: return raw body if JSON parsing fails.
      return body;
    }
  }

  NativeHttpChatResult _parseChatResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        return NativeHttpChatResult(
          exitCode: 0,
          content: body,
          stderr: 'Unexpected response format: ${decoded.runtimeType}',
        );
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return const NativeHttpChatResult(exitCode: 0, content: '');
      }
      final first = choices.first;
      if (first is! Map<String, Object?>) {
        return const NativeHttpChatResult(exitCode: 0, content: '');
      }
      final message = first['message'];
      if (message is! Map<String, Object?>) {
        return const NativeHttpChatResult(exitCode: 0, content: '');
      }

      final content = message['content'];
      final contentStr = content is String ? content : null;
      final finishReason = first['finish_reason'];
      final finishReasonStr = finishReason is String ? finishReason : null;

      // Parse tool_calls if present.
      final rawToolCalls = message['tool_calls'];
      final toolCalls = <NativeToolCall>[];
      if (rawToolCalls is List) {
        for (final raw in rawToolCalls) {
          if (raw is! Map<String, Object?>) continue;
          final id = raw['id'];
          final idStr = id is String ? id : '';
          final function_ = raw['function'];
          if (function_ is! Map<String, Object?>) continue;
          final name = function_['name'];
          final nameStr = name is String ? name : '';
          Map<String, Object?> arguments;
          try {
            final argsRaw = function_['arguments'];
            if (argsRaw is String) {
              final parsed = jsonDecode(argsRaw);
              arguments = parsed is Map<String, Object?> ? parsed : {};
            } else if (argsRaw is Map<String, Object?>) {
              arguments = argsRaw;
            } else {
              arguments = {};
            }
          } catch (_) {
            // Best-effort: invalid tool arguments are treated as empty.
            arguments = {};
          }
          toolCalls.add(NativeToolCall(
            id: idStr,
            functionName: nameStr,
            arguments: arguments,
          ));
        }
      }

      // Build the raw assistant message for conversation history.
      final assistantMessage = <String, Object?>{
        'role': 'assistant',
        'content': ?contentStr,
        if (toolCalls.isNotEmpty)
          'tool_calls': rawToolCalls,
      };

      return NativeHttpChatResult(
        exitCode: 0,
        content: contentStr,
        toolCalls: toolCalls,
        finishReason: finishReasonStr,
        assistantMessage: assistantMessage,
      );
    } catch (e) {
      return NativeHttpChatResult(
        exitCode: 0,
        content: body,
        stderr: 'Failed to parse response: $e',
      );
    }
  }

  AgentCommandEvent _buildCommandEvent({
    required AgentRequest request,
    required DateTime startedAt,
    required int durationMs,
    required bool timedOut,
  }) {
    return AgentCommandEvent(
      executable: syntheticExecutable,
      arguments: ['POST', '$apiBase/chat/completions'],
      runInShell: false,
      startedAt: startedAt.toIso8601String(),
      durationMs: durationMs < 0 ? 0 : durationMs,
      timedOut: timedOut,
      workingDirectory: request.workingDirectory,
    );
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _HttpResult {
  const _HttpResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class _RawHttpResult {
  const _RawHttpResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// A single tool call parsed from an OpenAI-compatible response.
class NativeToolCall {
  const NativeToolCall({
    required this.id,
    required this.functionName,
    required this.arguments,
  });

  final String id;
  final String functionName;
  final Map<String, Object?> arguments;
}

/// Result of a [NativeHttpRunner.chatWithTools] call.
class NativeHttpChatResult {
  const NativeHttpChatResult({
    required this.exitCode,
    this.content,
    this.toolCalls = const [],
    this.stderr = '',
    this.finishReason,
    this.assistantMessage,
  });

  final int exitCode;
  final String? content;
  final List<NativeToolCall> toolCalls;
  final String stderr;
  final String? finishReason;

  /// The raw assistant message map, suitable for appending to conversation
  /// history (includes tool_calls if present).
  final Map<String, Object?>? assistantMessage;

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get ok => exitCode == 0;
}
