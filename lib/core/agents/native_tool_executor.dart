// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../policy/safe_write_policy.dart';
import '../policy/shell_allowlist_policy.dart';
import 'native_http_runner.dart';

/// Executes tool calls produced by an LLM during the native agent loop.
///
/// Security: all file writes go through [SafeWritePolicy], all commands go
/// through [ShellAllowlistPolicy]. Policy violations are returned as error
/// messages to the LLM (the loop does NOT abort).
class NativeToolExecutor {
  NativeToolExecutor({
    required this.projectRoot,
    required this.safeWritePolicy,
    required this.shellAllowlistPolicy,
    this.commandTimeout = const Duration(seconds: 120),
    this.maxReadBytes = 100 * 1024,
    this.maxStdoutBytes = 50 * 1024,
  });

  final String projectRoot;
  final SafeWritePolicy safeWritePolicy;
  final ShellAllowlistPolicy shellAllowlistPolicy;
  final Duration commandTimeout;

  /// Maximum file size for read_file (100 KB).
  final int maxReadBytes;

  /// Maximum stdout size for run_command (50 KB).
  final int maxStdoutBytes;

  /// Execute a single tool call and return the result.
  Future<NativeToolResult> execute(NativeToolCall call) async {
    switch (call.functionName) {
      case 'read_file':
        return _readFile(call);
      case 'write_file':
        return _writeFile(call);
      case 'list_directory':
        return _listDirectory(call);
      case 'run_command':
        return await _runCommand(call);
      default:
        return NativeToolResult(
          toolCallId: call.id,
          output: 'Unknown tool: ${call.functionName}',
          isError: true,
        );
    }
  }

  NativeToolResult _readFile(NativeToolCall call) {
    final path = call.arguments['path'] as String?;
    if (path == null || path.trim().isEmpty) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: missing required parameter "path".',
        isError: true,
      );
    }
    final resolved = _resolvePath(path);
    final file = File(resolved);
    if (!file.existsSync()) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: file not found: $path',
        isError: true,
      );
    }
    final stat = file.statSync();
    if (stat.size > maxReadBytes) {
      return NativeToolResult(
        toolCallId: call.id,
        output:
            'Error: file too large (${stat.size} bytes, max $maxReadBytes).',
        isError: true,
      );
    }
    try {
      final content = file.readAsStringSync();
      return NativeToolResult(toolCallId: call.id, output: content);
    } catch (e) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error reading file: $e',
        isError: true,
      );
    }
  }

  NativeToolResult _writeFile(NativeToolCall call) {
    final path = call.arguments['path'] as String?;
    final content = call.arguments['content'] as String?;
    if (path == null || path.trim().isEmpty) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: missing required parameter "path".',
        isError: true,
      );
    }
    if (content == null) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: missing required parameter "content".',
        isError: true,
      );
    }

    // Enforce SafeWritePolicy.
    final violation = safeWritePolicy.violationForPath(path);
    if (violation != null) {
      return NativeToolResult(
        toolCallId: call.id,
        output:
            'Error: write blocked by safe-write policy '
            '(${violation.category}): ${violation.message}',
        isError: true,
      );
    }

    try {
      final resolved = _resolvePath(path);
      final file = File(resolved);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      return NativeToolResult(
        toolCallId: call.id,
        output: 'File written: $path (${content.length} bytes)',
      );
    } catch (e) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error writing file: $e',
        isError: true,
      );
    }
  }

  NativeToolResult _listDirectory(NativeToolCall call) {
    final path = call.arguments['path'] as String?;
    if (path == null || path.trim().isEmpty) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: missing required parameter "path".',
        isError: true,
      );
    }
    final rawDepth = call.arguments['depth'];
    var depth = 1;
    if (rawDepth is int) {
      depth = rawDepth.clamp(1, 3);
    } else if (rawDepth is String) {
      depth = (int.tryParse(rawDepth) ?? 1).clamp(1, 3);
    }

    final resolved = _resolvePath(path);
    final dir = Directory(resolved);
    if (!dir.existsSync()) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: directory not found: $path',
        isError: true,
      );
    }

    try {
      final entries = <String>[];
      _listRecursive(dir, resolved, depth, 0, entries);
      return NativeToolResult(
        toolCallId: call.id,
        output: entries.isEmpty ? '(empty directory)' : entries.join('\n'),
      );
    } catch (e) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error listing directory: $e',
        isError: true,
      );
    }
  }

  void _listRecursive(
    Directory dir,
    String basePath,
    int maxDepth,
    int currentDepth,
    List<String> output,
  ) {
    final entities = dir.listSync(followLinks: false);
    entities.sort((a, b) => a.path.compareTo(b.path));
    for (final entity in entities) {
      final relative = entity.path.substring(basePath.length);
      final cleaned =
          relative.startsWith('/') ? relative.substring(1) : relative;
      if (entity is Directory) {
        output.add('$cleaned/');
        if (currentDepth + 1 < maxDepth) {
          _listRecursive(entity, basePath, maxDepth, currentDepth + 1, output);
        }
      } else {
        output.add(cleaned);
      }
    }
  }

  Future<NativeToolResult> _runCommand(NativeToolCall call) async {
    final command = call.arguments['command'] as String?;
    if (command == null || command.trim().isEmpty) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: missing required parameter "command".',
        isError: true,
      );
    }

    // Parse the command safely (blocks shell operators).
    final parsed = ShellCommandTokenizer.tryParse(command);
    if (parsed == null) {
      return NativeToolResult(
        toolCallId: call.id,
        output:
            'Error: command contains disallowed shell operators or syntax: '
            '$command',
        isError: true,
      );
    }

    // Enforce ShellAllowlistPolicy.
    if (!shellAllowlistPolicy.allows(command)) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: command not in shell allowlist: $command',
        isError: true,
      );
    }

    try {
      final result = await Process.run(
        parsed.executable,
        parsed.arguments,
        workingDirectory: projectRoot,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(commandTimeout);

      var stdout = result.stdout as String;
      final stderr = result.stderr as String;

      // Truncate stdout to prevent context-window bloat.
      if (stdout.length > maxStdoutBytes) {
        stdout =
            '${stdout.substring(0, maxStdoutBytes)}\n... (truncated at '
            '$maxStdoutBytes bytes)';
      }

      final exitCode = result.exitCode;
      final output = StringBuffer();
      if (stdout.isNotEmpty) output.write(stdout);
      if (stderr.isNotEmpty) {
        if (output.isNotEmpty) output.write('\n');
        output.write('[stderr] $stderr');
      }
      output.write('\n[exit code: $exitCode]');

      return NativeToolResult(
        toolCallId: call.id,
        output: output.toString(),
        isError: exitCode != 0,
      );
    } on TimeoutException {
      return NativeToolResult(
        toolCallId: call.id,
        output:
            'Error: command timed out after ${commandTimeout.inSeconds}s: '
            '$command',
        isError: true,
      );
    } on ProcessException catch (e) {
      return NativeToolResult(
        toolCallId: call.id,
        output: 'Error: failed to run command: ${e.message}',
        isError: true,
      );
    }
  }

  String _resolvePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    // Strip leading "./" or "/"
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return '$projectRoot/$normalized';
  }
}

/// Result of executing a single tool call.
class NativeToolResult {
  const NativeToolResult({
    required this.toolCallId,
    required this.output,
    this.isError = false,
  });

  final String toolCallId;
  final String output;
  final bool isError;

  /// Convert to an OpenAI-compatible tool message for the conversation history.
  Map<String, Object?> toToolMessage() {
    return {
      'role': 'tool',
      'tool_call_id': toolCallId,
      'content': output,
    };
  }
}
