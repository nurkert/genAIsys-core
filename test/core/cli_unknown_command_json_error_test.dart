import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI unknown command --json returns JSON error', () {
    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'wat',
      '--json',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['code'], 'unknown_command');
    expect(decoded['error'], 'Unknown command: wat');
  });
}
