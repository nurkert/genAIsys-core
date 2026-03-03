import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI review unknown decision --json returns JSON error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_unknown_decision_json_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'review',
      'maybe',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['code'], 'unknown_decision');
    expect(decoded['error'], 'Unknown review decision: maybe');
  });
}
