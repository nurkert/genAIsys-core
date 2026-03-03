import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'support/cli_json_output_helper.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test(
    'CLI autopilot candidate --json returns candidate summary payload',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_candidate_json_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      await CliRunner().run(['init', temp.path]);
      final layout = ProjectLayout(temp.path);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Done
${_requiredDoneBlockers.join('\n')}
''');

      final result = runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'candidate',
        temp.path,
        '--skip-suites',
        '--json',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = '${result.stdout}\n${result.stderr}'.trim();
      final jsonLine = firstJsonPayload(output);
      expect(jsonLine, isNotEmpty, reason: 'No JSON output found: "$output"');

      final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
      expect(decoded['autopilot_candidate_completed'], true);
      expect(decoded['passed'], true);
      expect(decoded['skip_suites'], true);
      expect(decoded['missing_files'], isEmpty);
      expect(decoded['missing_done_blockers'], isEmpty);
    },
  );

  test(
    'CLI autopilot candidate --json returns exit 1 when gates fail',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_autopilot_candidate_json_fail_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      await CliRunner().run(['init', temp.path]);

      final result = runLockedDartSync([
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'candidate',
        temp.path,
        '--skip-suites',
        '--json',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 1);
      final output = '${result.stdout}\n${result.stderr}'.trim();
      final jsonLine = firstJsonPayload(output);
      expect(jsonLine, isNotEmpty, reason: 'No JSON output found: "$output"');

      final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
      expect(decoded['autopilot_candidate_completed'], true);
      expect(decoded['passed'], false);
      expect(decoded['missing_done_blockers'], isNotEmpty);
    },
  );

  test('CLI autopilot pilot returns invalid option on bad duration', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_autopilot_pilot_invalid_duration_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    await CliRunner().run(['init', temp.path]);

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'pilot',
      temp.path,
      '--duration',
      'abc',
      '--json',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    final output = '${result.stdout}\n${result.stderr}'.trim();
    final jsonLine = firstJsonPayload(output);
    expect(jsonLine, isNotEmpty, reason: 'No JSON error output: "$output"');

    final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
    expect(decoded['code'], 'invalid_option');
    expect(decoded['error'], contains('Invalid --duration value'));
  });
}

const List<String> _requiredDoneBlockers = <String>[
  '- [x] [P1] [SEC] Redact provider secrets and auth tokens from RUN_LOG.jsonl, attempt artifacts, and CLI error surfaces',
  '- [x] [P1] [CORE] Persist normalized failure reasons (timeout, policy, provider, test, review, git) in state and status APIs',
  '- [x] [P1] [CORE] Enforce deterministic subtask scheduling tie-breakers and log scheduler decision inputs for replayability',
  '- [x] [P1] [REF] Split TaskCycleService into explicit planning/coding/testing/review stages with typed stage boundaries',
  '- [x] [P1] [REF] Refactor OrchestratorStepService into explicit state-transition handlers to reduce hidden coupling',
  '- [x] [P1] [REF] Decompose `lib/core/services/orchestrator_run_service.dart` into orchestrator modules under `lib/core/services/orchestrator/` (loop coordinator, lock handling, release-tag flow, run-log events)',
  '- [x] [P1] [QA] Add end-to-end crash-recovery tests for failures injected after each cycle stage boundary',
  '- [x] [P1] [QA] Add regression tests for lock races and concurrent CLI actions (activate, done, review, autopilot run)',
  '- [x] [P1] [SEC] Add adversarial tests for safe-write bypass attempts (path traversal, symlink edges, relative escapes)',
  '- [x] [P1] [SEC] Add adversarial tests for shell_allowlist bypass attempts (chaining, subshell, separator abuse)',
  '- [x] [P1] [CORE] Block task completion when mandatory review evidence bundle is missing or malformed',
  '- [x] [P1] [CORE] Add explicit git delivery preflight (clean index, expected branch, upstream status) before done/merge',
  '- [x] [P1] [QA] Re-enable zero-analysis-issues quality gate in CI and fail pipeline on any new analyzer warning',
  '- [x] [P1] [QA] Add minimum coverage thresholds for core orchestration and policy modules in CI',
];
