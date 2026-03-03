// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../agents/native_http_runner.dart';
import '../config/project_config.dart';

/// Non-agentic chat interface for local LLMs via OpenAI-compatible endpoints.
///
/// Unlike the agent loop runner (which executes tool calls autonomously), this
/// service provides a simple multi-turn conversation: the caller sends a
/// message, the LLM replies with text. No tools, no file writes, no side
/// effects.
///
/// Designed for use from CLI (`genaisys chat`) and GUI chat panels.
class NativeChatService {
  NativeChatService({
    required NativeHttpRunner httpRunner,
    String? systemPrompt,
  })  : _httpRunner = httpRunner,
        _systemPrompt = systemPrompt,
        _messages = [];

  /// Create from a [NativeProviderConfig] (convenience factory).
  factory NativeChatService.fromConfig(
    NativeProviderConfig config, {
    String? systemPrompt,
  }) {
    return NativeChatService(
      httpRunner: NativeHttpRunner(
        apiBase: config.apiBase,
        model: config.model,
        apiKey: config.apiKey,
        temperature: config.temperature,
        maxTokens: config.maxTokens,
      ),
      systemPrompt: systemPrompt,
    );
  }

  final NativeHttpRunner _httpRunner;
  final String? _systemPrompt;
  final List<ChatMessage> _messages;

  /// Current conversation history (read-only snapshot).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// The model identifier used by the underlying HTTP runner.
  String get model => _httpRunner.model;

  /// The API base URL used by the underlying HTTP runner.
  String get apiBase => _httpRunner.apiBase;

  /// Send a user message and receive the assistant's reply.
  ///
  /// The message and reply are appended to the conversation history so that
  /// subsequent calls carry full context.
  ///
  /// Returns a [ChatResult] that is always non-throwing — errors are captured
  /// in the result object.
  Future<ChatResult> send(
    String userMessage, {
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    if (userMessage.trim().isEmpty) {
      return const ChatResult(
        ok: false,
        content: '',
        errorMessage: 'Empty message.',
      );
    }

    _messages.add(ChatMessage.user(userMessage));

    final apiKey = _resolveApiKey(environment);
    final wireMessages = _buildWireMessages();

    final result = await _httpRunner.chatWithTools(
      messages: wireMessages,
      apiKeyOverride: apiKey,
      timeout: timeout,
    );

    if (!result.ok) {
      // Remove the user message so the caller can retry.
      _messages.removeLast();
      return ChatResult(
        ok: false,
        content: '',
        errorMessage: result.stderr,
        exitCode: result.exitCode,
      );
    }

    final content = result.content ?? '';
    _messages.add(ChatMessage.assistant(content));

    return ChatResult(
      ok: true,
      content: content,
      finishReason: result.finishReason,
    );
  }

  /// Clear the conversation history and start fresh.
  void reset() {
    _messages.clear();
  }

  /// Replace the current conversation history with [newMessages].
  ///
  /// Useful for restoring a previous session.
  void restore(List<ChatMessage> newMessages) {
    _messages
      ..clear()
      ..addAll(newMessages);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  List<Map<String, Object?>> _buildWireMessages() {
    return [
      if (_systemPrompt != null && _systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': _systemPrompt},
      for (final msg in _messages) msg.toWireMessage(),
    ];
  }

  String _resolveApiKey(Map<String, String>? environment) {
    if (_httpRunner.apiKey.isNotEmpty) return _httpRunner.apiKey;
    return environment?['GENAISYS_NATIVE_API_KEY'] ?? '';
  }
}

// ---------------------------------------------------------------------------
// Value objects
// ---------------------------------------------------------------------------

/// A single message in a chat conversation.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  const ChatMessage.user(String content) : this(role: 'user', content: content);

  const ChatMessage.assistant(String content)
      : this(role: 'assistant', content: content);

  const ChatMessage.system(String content)
      : this(role: 'system', content: content);

  final String role;
  final String content;

  Map<String, Object?> toWireMessage() => {'role': role, 'content': content};
}

/// Result of a [NativeChatService.send] call.
class ChatResult {
  const ChatResult({
    required this.ok,
    required this.content,
    this.errorMessage,
    this.exitCode,
    this.finishReason,
  });

  /// Whether the request succeeded (HTTP 200 + valid response).
  final bool ok;

  /// The assistant's reply text. Empty on error.
  final String content;

  /// Human-readable error description when [ok] is false.
  final String? errorMessage;

  /// HTTP-level exit code when [ok] is false.
  final int? exitCode;

  /// The model's finish reason (e.g. `stop`, `length`).
  final String? finishReason;
}
