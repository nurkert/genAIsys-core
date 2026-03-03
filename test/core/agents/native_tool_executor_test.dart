import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/native_http_runner.dart';
import 'package:genaisys/core/agents/native_tool_executor.dart';
import 'package:genaisys/core/policy/safe_write_policy.dart';
import 'package:genaisys/core/policy/shell_allowlist_policy.dart';

void main() {
  late Directory tempDir;
  late NativeToolExecutor executor;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tool_executor_test_');
    executor = NativeToolExecutor(
      projectRoot: tempDir.path,
      safeWritePolicy: SafeWritePolicy(
        projectRoot: tempDir.path,
        allowedRoots: const ['lib', 'test', 'bin'],
      ),
      shellAllowlistPolicy: ShellAllowlistPolicy(
        allowedPrefixes: const ['echo', 'dart analyze', 'ls'],
      ),
      commandTimeout: const Duration(seconds: 5),
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('read_file', () {
    test('reads an existing file', () async {
      File('${tempDir.path}/lib/hello.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('Hello World');

      final result = await executor.execute(NativeToolCall(
        id: 'c1',
        functionName: 'read_file',
        arguments: {'path': 'lib/hello.txt'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, 'Hello World');
      expect(result.toolCallId, 'c1');
    });

    test('returns error for missing file', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'c2',
        functionName: 'read_file',
        arguments: {'path': 'lib/nope.txt'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('file not found'));
    });

    test('returns error for file too large', () async {
      final bigFile = File('${tempDir.path}/lib/big.txt')
        ..parent.createSync(recursive: true);
      bigFile.writeAsBytesSync(List.filled(200 * 1024, 65)); // 200KB of 'A'

      final result = await executor.execute(NativeToolCall(
        id: 'c3',
        functionName: 'read_file',
        arguments: {'path': 'lib/big.txt'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('too large'));
    });

    test('returns error for missing path parameter', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'c4',
        functionName: 'read_file',
        arguments: {},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('missing required parameter'));
    });

    test('handles path with leading ./', () async {
      File('${tempDir.path}/lib/foo.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('content');

      final result = await executor.execute(NativeToolCall(
        id: 'c5',
        functionName: 'read_file',
        arguments: {'path': './lib/foo.txt'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, 'content');
    });

    test('handles path with leading /', () async {
      File('${tempDir.path}/lib/bar.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('bar');

      final result = await executor.execute(NativeToolCall(
        id: 'c6',
        functionName: 'read_file',
        arguments: {'path': '/lib/bar.txt'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, 'bar');
    });
  });

  group('write_file', () {
    test('writes a file and creates parent dirs', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'w1',
        functionName: 'write_file',
        arguments: {'path': 'lib/sub/dir/new.txt', 'content': 'new content'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, contains('File written'));

      final file = File('${tempDir.path}/lib/sub/dir/new.txt');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'new content');
    });

    test('returns error for safe-write violation (no throw)', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'w2',
        functionName: 'write_file',
        arguments: {'path': '.git/config', 'content': 'hacked'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('safe-write policy'));
      // File should NOT have been written.
      expect(File('${tempDir.path}/.git/config').existsSync(), isFalse);
    });

    test('returns error for path outside allowed roots', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'w3',
        functionName: 'write_file',
        arguments: {'path': 'docs/readme.md', 'content': 'hi'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('safe-write policy'));
    });

    test('returns error for missing content parameter', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'w4',
        functionName: 'write_file',
        arguments: {'path': 'lib/foo.txt'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('missing required parameter'));
    });
  });

  group('list_directory', () {
    test('lists files in a directory', () async {
      Directory('${tempDir.path}/lib').createSync(recursive: true);
      File('${tempDir.path}/lib/a.dart').writeAsStringSync('');
      File('${tempDir.path}/lib/b.dart').writeAsStringSync('');

      final result = await executor.execute(NativeToolCall(
        id: 'l1',
        functionName: 'list_directory',
        arguments: {'path': 'lib'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, contains('a.dart'));
      expect(result.output, contains('b.dart'));
    });

    test('respects depth limit', () async {
      Directory('${tempDir.path}/lib/sub/deep').createSync(recursive: true);
      File('${tempDir.path}/lib/top.dart').writeAsStringSync('');
      File('${tempDir.path}/lib/sub/mid.dart').writeAsStringSync('');
      File('${tempDir.path}/lib/sub/deep/bottom.dart').writeAsStringSync('');

      // depth 1: should list lib/ contents but not recurse into sub/
      final result1 = await executor.execute(NativeToolCall(
        id: 'l2',
        functionName: 'list_directory',
        arguments: {'path': 'lib', 'depth': 1},
      ));

      expect(result1.isError, isFalse);
      expect(result1.output, contains('top.dart'));
      expect(result1.output, contains('sub/'));
      expect(result1.output, isNot(contains('mid.dart')));

      // depth 2: should recurse into sub/ but not deep/
      final result2 = await executor.execute(NativeToolCall(
        id: 'l3',
        functionName: 'list_directory',
        arguments: {'path': 'lib', 'depth': 2},
      ));

      expect(result2.isError, isFalse);
      expect(result2.output, contains('mid.dart'));
      expect(result2.output, isNot(contains('bottom.dart')));
    });

    test('returns error for missing directory', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'l4',
        functionName: 'list_directory',
        arguments: {'path': 'nope'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('directory not found'));
    });

    test('depth is clamped to 3', () async {
      Directory('${tempDir.path}/lib/a/b/c/d').createSync(recursive: true);
      File('${tempDir.path}/lib/a/b/c/d/file.txt').writeAsStringSync('');

      final result = await executor.execute(NativeToolCall(
        id: 'l5',
        functionName: 'list_directory',
        arguments: {'path': 'lib', 'depth': 99},
      ));

      expect(result.isError, isFalse);
      // Depth 3 (clamped from 99) means we list entries 3 levels deep.
      // Level 0: a/, Level 1: a/b/, Level 2: a/b/c/
      // c/ is NOT recursed into (depth 3 is the limit), so d/ is NOT visible.
      expect(result.output, contains('a/'));
      expect(result.output, contains('a/b/'));
      expect(result.output, contains('a/b/c/'));
      expect(result.output, isNot(contains('file.txt')));
    });
  });

  group('run_command', () {
    test('runs an allowed command', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'r1',
        functionName: 'run_command',
        arguments: {'command': 'echo hello'},
      ));

      expect(result.isError, isFalse);
      expect(result.output, contains('hello'));
      expect(result.output, contains('[exit code: 0]'));
    });

    test('returns error for disallowed command', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'r2',
        functionName: 'run_command',
        arguments: {'command': 'rm -rf /'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('not in shell allowlist'));
    });

    test('returns error for shell operators', () async {
      for (final cmd in [
        'echo hello; rm -rf /',
        'echo hello | grep hello',
        'echo hello && echo world',
        'echo hello > file.txt',
      ]) {
        final result = await executor.execute(NativeToolCall(
          id: 'r3',
          functionName: 'run_command',
          arguments: {'command': cmd},
        ));

        expect(result.isError, isTrue, reason: 'cmd: $cmd');
        expect(
          result.output,
          contains('disallowed shell operators'),
          reason: 'cmd: $cmd',
        );
      }
    });

    test('returns error for missing command parameter', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'r4',
        functionName: 'run_command',
        arguments: {},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('missing required parameter'));
    });

    test('handles command timeout', () async {
      final slowExecutor = NativeToolExecutor(
        projectRoot: tempDir.path,
        safeWritePolicy: SafeWritePolicy(
          projectRoot: tempDir.path,
          allowedRoots: const [],
          enabled: false,
        ),
        shellAllowlistPolicy: ShellAllowlistPolicy(
          allowedPrefixes: const ['sleep'],
        ),
        commandTimeout: const Duration(milliseconds: 200),
      );

      final result = await slowExecutor.execute(NativeToolCall(
        id: 'r5',
        functionName: 'run_command',
        arguments: {'command': 'sleep 30'},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('timed out'));
    });
  });

  group('unknown tool', () {
    test('returns error for unknown tool name', () async {
      final result = await executor.execute(NativeToolCall(
        id: 'u1',
        functionName: 'hack_the_planet',
        arguments: {},
      ));

      expect(result.isError, isTrue);
      expect(result.output, contains('Unknown tool'));
    });
  });

  group('toToolMessage', () {
    test('produces correct OpenAI tool message', () {
      final result = NativeToolResult(
        toolCallId: 'tc1',
        output: 'some output',
      );
      final msg = result.toToolMessage();
      expect(msg['role'], 'tool');
      expect(msg['tool_call_id'], 'tc1');
      expect(msg['content'], 'some output');
    });
  });
}
