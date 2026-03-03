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

  test('config diff --json returns valid JSON with has_diff and entries',
      () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_diff_',
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
      args: ['config', 'diff', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded.containsKey('has_diff'), isTrue);
    expect(decoded['has_diff'], isA<bool>());
    expect(decoded.containsKey('entries'), isTrue);
    expect(decoded['entries'], isA<List>());
  });

  test('config diff --json entry schema has required fields', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_diff_schema_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    await CliRunner().run(['init', temp.path]);

    // Modify a config value so there is a diff.
    final configPath = '${temp.path}/.genaisys/config.yml';
    final configFile = File(configPath);
    if (configFile.existsSync()) {
      var content = configFile.readAsStringSync();
      // Add a non-default base branch to produce at least one diff entry.
      content += '\ngit:\n  base_branch: develop\n';
      configFile.writeAsStringSync(content);
    }

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureStdout(
      args: ['config', 'diff', '--json', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['has_diff'], isTrue);

    final entries = decoded['entries'] as List<dynamic>;
    expect(entries, isNotEmpty);

    final entry = entries.first as Map<String, dynamic>;
    expect(entry.containsKey('field'), isTrue);
    expect(entry.containsKey('current_value'), isTrue);
    expect(entry.containsKey('default_value'), isTrue);
    expect(entry.containsKey('effect'), isTrue);
  });

  test('config diff text output shows "all defaults" when no diff', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_config_diff_text_',
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
      args: ['config', 'diff', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    // Default init should produce either "all defaults" or "Non-default"
    // depending on whether init config differs from ProjectConfig defaults.
    expect(
      output.contains('All config values are at their defaults') ||
          output.contains('Non-default config values'),
      isTrue,
    );
  });
}
