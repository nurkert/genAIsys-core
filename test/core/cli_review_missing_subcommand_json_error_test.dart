import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI review --json returns JSON error for missing subcommand', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_missing_subcommand_json_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'review',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['code'], 'missing_subcommand');
    expect(
      decoded['error'],
      'Missing subcommand. Use: review approve|reject [path]',
    );
  });
}
