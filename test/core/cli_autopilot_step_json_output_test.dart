import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test(
    'CLI autopilot step --json returns idle payload when no open task exists',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_step_json_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      await CliRunner().run(['init', temp.path]);
      final layout = ProjectLayout(temp.path);
      final binDir = Directory('${temp.path}/bin');
      binDir.createSync(recursive: true);
      final codex = File('${binDir.path}/codex');
      codex.writeAsStringSync(
        '#!/bin/sh\n'
        'cat >/dev/null\n'
        'printf "OK\\n"\n',
      );
      Process.runSync('chmod', ['+x', codex.path]);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Bootstrap Genaisys core engine
''');

      final env = Map<String, String>.from(Platform.environment);
      env['PATH'] = '${binDir.path}:${env['PATH'] ?? ''}';
      final result = Process.runSync(
        'dart',
        [
          'run',
          '--verbosity=error',
          '--',
          'bin/genaisys_cli.dart',
          'step',
          temp.path,
          '--json',
        ],
        workingDirectory: Directory.current.path,
        environment: env,
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString().trim();
      expect(output, isNotEmpty);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['autopilot_step_completed'], true);
      expect(decoded['executed_cycle'], false);
      expect(decoded['active_task'], isNull);
      expect(decoded['planned_tasks_added'], isA<int>());
    },
  );
}
