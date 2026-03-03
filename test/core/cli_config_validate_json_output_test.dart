import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

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

  test('config validate --json returns valid JSON with checks array', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_validate_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    // Initialize a project so config.yml exists.
    await CliRunner().run(['init', temp.path]);

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['config', 'validate', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded.containsKey('ok'), isTrue);
    expect(decoded['ok'], isA<bool>());
    expect(decoded.containsKey('checks'), isTrue);
    expect(decoded['checks'], isA<List>());
    expect(decoded.containsKey('warnings'), isTrue);
    expect(decoded['warnings'], isA<List>());

    final checks = decoded['checks'] as List<dynamic>;
    expect(checks, isNotEmpty);
    for (final check in checks) {
      final checkMap = check as Map<String, dynamic>;
      expect(checkMap.containsKey('name'), isTrue);
      expect(checkMap.containsKey('ok'), isTrue);
      expect(checkMap.containsKey('message'), isTrue);
      expect(checkMap.containsKey('remediation_hint'), isTrue);
    }
  });

  test('config validate --json reports yaml_parse ok for valid config',
      () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_validate_yaml_',
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
      args: ['config', 'validate', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    final checks = (decoded['checks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final yamlCheck = checks.firstWhere(
      (c) => c['name'] == 'yaml_parse',
      orElse: () => <String, dynamic>{},
    );
    expect(yamlCheck, isNotEmpty, reason: 'yaml_parse check missing');
    expect(yamlCheck['ok'], isTrue);
  });

  test('config validate text output includes PASS/FAIL header', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_validate_text_',
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
      args: ['config', 'validate', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(output, contains('Config validation:'));
  });

  test('config missing subcommand returns error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_no_sub_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['config', '--json'],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 64);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['code'], 'missing_subcommand');
  });

  test('config unknown subcommand returns error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_unknown_sub_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['config', 'bogus', '--json'],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 64);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['code'], 'unknown_subcommand');
  });
}
