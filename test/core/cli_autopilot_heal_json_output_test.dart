import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import 'support/cli_json_output_helper.dart';

void main() {
  test(
    'CLI autopilot heal --json returns heal payload and bundle path',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_heal_json_',
      );
      final runner = CliRunner();

      addTearDown(() {
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
            .replaceAll(
              'release_tag_on_ready: true',
              'release_tag_on_ready: false',
            )
            .replaceAll('release_tag_push: true', 'release_tag_push: false'),
      );
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Heal autopilot deadlock path
''');
      File(layout.visionPath).writeAsStringSync('# Vision\n\n## Goals\n- \n');
      File('${temp.path}/.gitignore').writeAsStringSync('.genaisys/\nbin/\n');

      Process.runSync('git', [
        'init',
        '-b',
        'main',
      ], workingDirectory: temp.path);
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

      final binDir = Directory('${temp.path}/bin');
      binDir.createSync(recursive: true);
      final codex = File('${binDir.path}/codex');
      codex.writeAsStringSync(
        '#!/bin/sh\n'
        'cat >/dev/null\n'
        'printf "OK\\n"\n',
      );
      Process.runSync('chmod', ['+x', codex.path]);

      final env = Map<String, String>.from(Platform.environment);
      env['PATH'] = '${binDir.path}:${env['PATH'] ?? ''}';

      final result = Process.runSync(
        'dart',
        [
          'run',
          '--verbosity=error',
          '--',
          'bin/genaisys_cli.dart',
          'heal',
          temp.path,
          '--reason',
          'stuck',
          '--detail',
          'No productive steps in recent segments.',
          '--json',
        ],
        workingDirectory: Directory.current.path,
        environment: env,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final output = '${result.stdout}\n${result.stderr}'.trim();
      final jsonLine = firstJsonPayload(output);
      expect(
        jsonLine,
        isNotEmpty,
        reason: 'No JSON output found. Full output: "$output"',
      );

      final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
      expect(decoded['autopilot_heal_completed'], true);
      expect(decoded['reason'], 'stuck');
      expect(decoded['detail'], 'No productive steps in recent segments.');
      final bundlePath = decoded['bundle_path']?.toString();
      expect(bundlePath, isNotNull);
      expect(bundlePath!.isNotEmpty, isTrue);
      expect(File(bundlePath).existsSync(), isTrue);
      expect(decoded['recovered'], isA<bool>());
    },
  );
}
