import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'support/cli_json_output_helper.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI autopilot run --json returns run summary payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_run_json_',
    );

    final runner = CliRunner();

    addTearDown(() {
      runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'stop',
        temp.path,
      ], workingDirectory: Directory.current.path);
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    await runner.run(['init', temp.path]);
    final layout = ProjectLayout(temp.path);
    final config = File(layout.configPath).readAsStringSync();
    File(layout.configPath).writeAsStringSync(
      config
          .replaceAll('min_open: 8', 'min_open: 1')
          .replaceAll('  fallback: "gemini"', '  fallback: "codex"')
          .replaceAll('    - "gemini@default"', '    - "codex@default"')
          .replaceFirst(
            '      - "dart format --output=none --set-exit-if-changed ."\n'
                '      - "dart analyze"\n'
                '      - "dart test"',
            '      - "ls"',
          )
          .replaceAll(
            'release_tag_on_ready: true',
            'release_tag_on_ready: false',
          )
          .replaceAll('release_tag_push: true', 'release_tag_push: false'),
    );
    final binDir = Directory('${temp.path}/bin');
    binDir.createSync(recursive: true);
    final codex = File('${binDir.path}/codex');
    codex.writeAsStringSync(
      '#!/bin/sh\n'
      'printf "OK\\n"\n',
    );
    Process.runSync('chmod', ['+x', codex.path]);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Bootstrap Genaisys core engine
- [ ] [P1] [CORE] Keep autopilot idle
''');
    File(layout.visionPath).writeAsStringSync('# Vision\n\n## Goals\n- \n');
    Process.runSync('git', ['init', '-b', 'main'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test',
    ], workingDirectory: temp.path);
    Process.runSync('git', ['add', '-A'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '--no-gpg-sign',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final env = Map<String, String>.from(Platform.environment);
    env['PATH'] = '${binDir.path}:${env['PATH'] ?? ''}';

    final result = runLockedDartSync(
      [
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'run',
        temp.path,
        '--max-steps',
        '1',
        '--json',
      ],
      workingDirectory: Directory.current.path,
      environment: env,
    );
    expect(result.exitCode, 0, reason: 'stderr=${result.stderr}');

    final output = '${result.stdout}\n${result.stderr}'.trim();
    final jsonLine = firstJsonPayload(output);
    expect(
      jsonLine,
      isNotEmpty,
      reason: 'No JSON output found. Full output: "$output"',
    );

    final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
    expect(decoded['autopilot_run_completed'], true);
    expect(decoded['total_steps'], 1);
    expect(decoded['successful_steps'], isA<int>());
    expect(decoded['failed_steps'], isA<int>());
    final stoppedByMaxSteps = decoded['stopped_by_max_steps'] == true;
    final stoppedBySafetyHalt = decoded['stopped_by_safety_halt'] == true;
    final stoppedWhenIdle = decoded['stopped_when_idle'] == true;
    expect(stoppedByMaxSteps || stoppedBySafetyHalt || stoppedWhenIdle, true);
  });

  test('CLI autopilot run fails when lock file already exists', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_run_lock_json_',
    );

    final runner = CliRunner();

    addTearDown(() {
      runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'stop',
        temp.path,
      ], workingDirectory: Directory.current.path);
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    await runner.run(['init', temp.path]);
    final layout = ProjectLayout(temp.path);
    final config = File(layout.configPath).readAsStringSync();
    File(layout.configPath).writeAsStringSync(
      config
          .replaceAll('  fallback: "gemini"', '  fallback: "codex"')
          .replaceAll('    - "gemini@default"', '    - "codex@default"')
          .replaceFirst(
            '  quality_gate:\n    enabled: true',
            '  quality_gate:\n    enabled: false',
          )
          .replaceFirst('require_review: true', 'require_review: false')
          .replaceAll(
            'release_tag_on_ready: true',
            'release_tag_on_ready: false',
          )
          .replaceAll('release_tag_push: true', 'release_tag_push: false'),
    );
    final locksDir = Directory(layout.locksDir);
    locksDir.createSync(recursive: true);
    final now = DateTime.now().toUtc().toIso8601String();
    File(layout.autopilotLockPath).writeAsStringSync('''
version=1
started_at=$now
last_heartbeat=$now
pid=unknown
project_root=${temp.path}
''');

    final binDir = Directory('${temp.path}/bin');
    binDir.createSync(recursive: true);
    final codex = File('${binDir.path}/codex');
    codex.writeAsStringSync(
      '#!/bin/sh\n'
      'printf "OK\\n"\n',
    );
    Process.runSync('chmod', ['+x', codex.path]);
    final env = Map<String, String>.from(Platform.environment);
    env['PATH'] = '${binDir.path}:${env['PATH'] ?? ''}';

    final result = runLockedDartSync(
      [
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'run',
        temp.path,
        '--max-steps',
        '1',
        '--json',
      ],
      workingDirectory: Directory.current.path,
      environment: env,
    );

    final output = '${result.stdout}\n${result.stderr}'.trim();
    final jsonLine = firstJsonPayload(output);
    expect(
      jsonLine,
      isNotEmpty,
      reason: 'No JSON error output found in: "$output"',
    );

    final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
    expect(decoded['code'], 'state_error');
    expect(decoded['error'], contains('Autopilot is already running'));
  });
}
