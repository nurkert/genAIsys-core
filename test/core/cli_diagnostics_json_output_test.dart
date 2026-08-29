import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

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

  test(
    'autopilot diagnostics --json returns valid JSON with required keys',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cli_diagnostics_',
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
        args: ['diagnostics', '--json', temp.path],
        stdoutFile: stdoutFile,
        stderrFile: stderrFile,
      );

      expect(exitCode, 0);
      final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(decoded.containsKey('error_patterns'), isTrue);
      expect(decoded['error_patterns'], isA<List>());
      expect(decoded.containsKey('forensic_state'), isTrue);
      expect(decoded['forensic_state'], isA<Map>());
      expect(decoded.containsKey('recent_events'), isTrue);
      expect(decoded['recent_events'], isA<List>());
      expect(decoded.containsKey('supervisor_status'), isTrue);
      expect(decoded['supervisor_status'], isA<Map>());
    },
  );

  test(
    'autopilot diagnostics --json shows error patterns when registry has entries',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cli_diagnostics_patterns_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
        exitCode = 0;
      });

      await CliRunner().run(['init', temp.path]);

      // Write a mock error patterns registry file.
      final layout = ProjectLayout(temp.path);
      final auditDir = Directory(layout.auditDir);
      if (!auditDir.existsSync()) {
        auditDir.createSync(recursive: true);
      }
      File(layout.errorPatternRegistryPath).writeAsStringSync(
        jsonEncode([
          {
            'error_kind': 'test_failure',
            'count': 5,
            'last_seen': '2026-02-18T10:00:00Z',
            'resolution_strategy': 'retry',
            'auto_resolved_count': 2,
          },
          {
            'error_kind': 'git_dirty',
            'count': 3,
            'last_seen': '2026-02-18T09:00:00Z',
            'resolution_strategy': null,
            'auto_resolved_count': 0,
          },
        ]),
      );

      final stdoutFile = File('${temp.path}/stdout.txt');
      final stderrFile = File('${temp.path}/stderr.txt');

      exitCode = 0;
      final output = await captureStdout(
        args: ['diagnostics', '--json', temp.path],
        stdoutFile: stdoutFile,
        stderrFile: stderrFile,
      );

      expect(exitCode, 0);
      final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
      final patterns = decoded['error_patterns'] as List<dynamic>;
      expect(patterns.length, 2);

      final first = patterns[0] as Map<String, dynamic>;
      expect(first['error_kind'], 'test_failure');
      expect(first['count'], 5);
      expect(first['auto_resolved_count'], 2);
      expect(first['resolution_strategy'], 'retry');

      final second = patterns[1] as Map<String, dynamic>;
      expect(second['error_kind'], 'git_dirty');
      expect(second['count'], 3);
    },
  );

  test('autopilot diagnostics text output includes section headers', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_diagnostics_text_',
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
      args: ['diagnostics', temp.path],
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(output, contains('Autopilot Diagnostics'));
    expect(output, contains('Error Patterns'));
    expect(output, contains('Forensic State'));
    expect(output, contains('Supervisor Status'));
  });
}
