import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI review status --json returns JSON error when state is missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_status_json_error_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final result = runLockedDartSync(<String>[
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'review',
      'status',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 2);
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);
    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['code'], 'state_error');
    expect((decoded['error'] as String), startsWith('No STATE.json found at:'));
  });
}
