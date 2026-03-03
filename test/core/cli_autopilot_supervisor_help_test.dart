import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('CLI help lists autopilot supervisor commands', () {
    final result = Process.runSync('dart', [
      'run',
      '--',
      'bin/genaisys_cli.dart',
      'help',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final stdoutText = result.stdout.toString();
    expect(
      stdoutText,
      contains('supervisor'),
    );
    expect(
      stdoutText,
      contains('Manage the autopilot supervisor process'),
    );
  });
}
