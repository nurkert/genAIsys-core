import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';

/// Phase 4 regression gate: runs every new CLI diagnostic/onboarding handler
/// on the same temp project and verifies all produce valid JSON, return exit
/// code 0, and do not crash.
void main() {
  late Directory temp;
  late File stdoutFile;
  late File stderrFile;

  Future<_RoundTripResult> runHandler(List<String> args) async {
    // Reset stdout/stderr files for each handler invocation.
    if (stdoutFile.existsSync()) {
      stdoutFile.deleteSync();
    }
    if (stderrFile.existsSync()) {
      stderrFile.deleteSync();
    }
    stdoutFile.createSync();
    stderrFile.createSync();

    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();
    try {
      exitCode = 0;
      await CliRunner(stdout: stdoutSink, stderr: stderrSink).run(args);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }
    return _RoundTripResult(
      exitCode: exitCode,
      stdout: stdoutFile.readAsStringSync(),
      stderr: stderrFile.readAsStringSync(),
    );
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_roundtrip_',
    );
    stdoutFile = File('${temp.path}/stdout.txt')..createSync();
    stderrFile = File('${temp.path}/stderr.txt')..createSync();
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
    exitCode = 0;
  });

  test('all Phase 4 CLI handlers produce valid JSON on initialized project',
      () async {
    // Initialize project first.
    await runHandler(['init', temp.path]);

    // Define all Phase 4 handler invocations.
    final handlers = <String, List<String>>{
      'config validate': ['config', 'validate', '--json', temp.path],
      'config diff': ['config', 'diff', '--json', temp.path],
      'health': ['health', '--json', temp.path],
      'diagnostics': ['diagnostics', '--json', temp.path],
    };

    for (final entry in handlers.entries) {
      final name = entry.key;
      final args = entry.value;

      final result = await runHandler(args);

      expect(
        result.exitCode,
        0,
        reason: '$name: exit code ${result.exitCode}, '
            'stderr: ${result.stderr}',
      );

      final jsonStr = result.stdout.trim();
      expect(
        jsonStr,
        isNotEmpty,
        reason: '$name: empty stdout',
      );

      // Verify it is valid JSON.
      late Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        fail('$name: invalid JSON output: $e\nOutput: $jsonStr');
      }

      // Every handler should produce a non-empty map.
      expect(
        decoded,
        isNotEmpty,
        reason: '$name: empty JSON payload',
      );
    }
  });

  test('Phase 4 handlers do not crash on uninitialized project', () async {
    // Run handlers against a bare temp dir (no init).
    final handlers = <String, List<String>>{
      'config validate': ['config', 'validate', '--json', temp.path],
      'config diff': ['config', 'diff', '--json', temp.path],
      'health': ['health', '--json', temp.path],
      'diagnostics': ['diagnostics', '--json', temp.path],
    };

    for (final entry in handlers.entries) {
      final name = entry.key;
      final args = entry.value;

      // Should not throw, even on uninitialized project.
      final result = await runHandler(args);

      // The handler may return a non-zero exit code (graceful error),
      // but must not produce empty output.
      final jsonStr = result.stdout.trim();
      expect(
        jsonStr,
        isNotEmpty,
        reason: '$name: empty stdout on uninitialized project',
      );

      // Must be valid JSON.
      try {
        jsonDecode(jsonStr);
      } catch (e) {
        fail('$name: invalid JSON output on uninitialized project: $e\n'
            'Output: $jsonStr');
      }
    }
  });
}

class _RoundTripResult {
  const _RoundTripResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
