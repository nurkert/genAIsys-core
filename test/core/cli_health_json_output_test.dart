import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';

void main() {
  Future<String> captureStdout({
    required List<String> args,
    required File stdoutFile,
    required File stderrFile,
  }) async {
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();
    try {
      await CliRunner(stdout: stdoutSink, stderr: stderrSink).run(args);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }
    return stdoutFile.readAsStringSync();
  }

  test('health --json returns valid JSON with ok and checks array', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_health_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    // Initialize a project so structure exists.
    await CliRunner().run(['init', temp.path]);

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['health', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded.containsKey('ok'), isTrue);
    expect(decoded['ok'], isA<bool>());
    expect(decoded.containsKey('checks'), isTrue);
    expect(decoded['checks'], isA<List>());

    final checks = decoded['checks'] as List<dynamic>;
    expect(checks, isNotEmpty);
    for (final check in checks) {
      final checkMap = check as Map<String, dynamic>;
      expect(checkMap.containsKey('name'), isTrue);
      expect(checkMap.containsKey('ok'), isTrue);
      expect(checkMap.containsKey('message'), isTrue);
      expect(checkMap.containsKey('error_kind'), isTrue);
    }
  });

  test('health --json includes project_structure check', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_health_structure_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    await CliRunner().run(['init', temp.path]);

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['health', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    final checks = (decoded['checks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final structureCheck = checks.firstWhere(
      (c) => c['name'] == 'project_structure',
      orElse: () => <String, dynamic>{},
    );
    expect(structureCheck, isNotEmpty, reason: 'project_structure check missing');
    expect(structureCheck['ok'], isTrue);
  });

  test('health --json reports failure for missing project structure', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_health_missing_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    // Do NOT init, so .genaisys does not exist.
    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['health', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['ok'], isFalse);
    final checks = (decoded['checks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final structureCheck = checks.firstWhere(
      (c) => c['name'] == 'project_structure',
      orElse: () => <String, dynamic>{},
    );
    expect(structureCheck['ok'], isFalse);
    expect(structureCheck['error_kind'], 'state_missing');
  });

  test('health text output includes PASS/FAIL header', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_health_text_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    await CliRunner().run(['init', temp.path]);

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['health', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(output, contains('Health:'));
  });
}
