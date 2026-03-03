import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI scaffold --json returns JSON error for missing subcommand', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_scaffold_missing_subcommand_json_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'scaffold',
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
      'Missing subcommand. Use: scaffold spec|plan|subtasks [path]',
    );
  });
}
