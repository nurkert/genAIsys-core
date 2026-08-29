import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI init --json returns valid JSON payload', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_init_json_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'init',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    final layout = ProjectLayout(temp.path);

    expect(decoded['initialized'], true);
    expect(decoded['genaisys_dir'], layout.genaisysDir);
    expect(Directory(layout.genaisysDir).existsSync(), isTrue);
  });

  test('CLI init --json normalizes dot path without /./ segment', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_init_dot_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final dottedPath = '${temp.path}${Platform.pathSeparator}.';
    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'init',
      '--json',
      dottedPath,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    final genaisysDir = decoded['genaisys_dir'].toString();

    expect(
      genaisysDir.contains(
        '${Platform.pathSeparator}.${Platform.pathSeparator}',
      ),
      isFalse,
    );
    expect(genaisysDir, '${temp.path}${Platform.pathSeparator}.genaisys');
  });
}
