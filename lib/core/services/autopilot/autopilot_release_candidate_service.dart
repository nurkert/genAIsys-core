// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../git/git_service.dart';
import '../../project_layout.dart';
import '../build_test_runner_service.dart';
import '../observability/health_check_service.dart';
import '../orchestrator_run_service.dart';
import '../observability/run_telemetry_service.dart';

class CandidateCommandOutcome {
  const CandidateCommandOutcome({
    required this.command,
    required this.ok,
    required this.exitCode,
    required this.timedOut,
    required this.durationMs,
    required this.stdoutExcerpt,
    required this.stderrExcerpt,
  });

  final String command;
  final bool ok;
  final int exitCode;
  final bool timedOut;
  final int durationMs;
  final String stdoutExcerpt;
  final String stderrExcerpt;
}

class AutopilotCandidateResult {
  const AutopilotCandidateResult({
    required this.passed,
    required this.skipSuites,
    required this.missingFiles,
    required this.missingDoneBlockers,
    required this.openCriticalP1Lines,
    required this.commandOutcomes,
  });

  final bool passed;
  final bool skipSuites;
  final List<String> missingFiles;
  final List<String> missingDoneBlockers;
  final List<String> openCriticalP1Lines;
  final List<CandidateCommandOutcome> commandOutcomes;
}

class AutopilotPilotResult {
  const AutopilotPilotResult({
    required this.passed,
    required this.timedOut,
    required this.commandExitCode,
    required this.branch,
    required this.durationSeconds,
    required this.maxCycles,
    required this.reportPath,
    required this.totalSteps,
    required this.successfulSteps,
    required this.idleSteps,
    required this.failedSteps,
    required this.stoppedByMaxSteps,
    required this.stoppedWhenIdle,
    required this.stoppedBySafetyHalt,
    required this.error,
  });

  final bool passed;
  final bool timedOut;
  final int commandExitCode;
  final String branch;
  final int durationSeconds;
  final int maxCycles;
  final String reportPath;
  final int totalSteps;
  final int successfulSteps;
  final int idleSteps;
  final int failedSteps;
  final bool stoppedByMaxSteps;
  final bool stoppedWhenIdle;
  final bool stoppedBySafetyHalt;
  final String? error;
}

class AutopilotReleaseCandidateService {
  AutopilotReleaseCandidateService({
    ShellCommandRunner? commandRunner,
    GitService? gitService,
    OrchestratorRunService? runService,
    RunTelemetryService? telemetryService,
    HealthCheckService? healthCheckService,
    DateTime Function()? now,
  }) : _commandRunner = commandRunner ?? ProcessShellCommandRunner(),
       _gitService = gitService ?? GitService(),
       _runService = runService ?? OrchestratorRunService(),
       _telemetryService = telemetryService ?? RunTelemetryService(),
       _healthCheckService = healthCheckService ?? HealthCheckService(),
       _now = now ?? (() => DateTime.now().toUtc());

  final ShellCommandRunner _commandRunner;
  final GitService _gitService;
  final OrchestratorRunService _runService;
  final RunTelemetryService _telemetryService;
  final HealthCheckService _healthCheckService;
  final DateTime Function() _now;

  static const List<String> _candidateSuites = <String>[
    'dart format --output=none --set-exit-if-changed .',
    'dart analyze --fatal-infos --fatal-warnings .',
    'flutter test test/core/task_cycle_service_test.dart test/core/orchestrator_step_service_test.dart test/core/orchestrator_run_service_test.dart test/core/orchestrator_module_parity_regression_test.dart test/core/done_service_delivery_gates_test.dart test/core/failure_reason_mapper_test.dart test/core/run_telemetry_service_test.dart',
    'flutter test test/core/safe_write_policy_adversarial_test.dart',
    'flutter test test/core/shell_allowlist_policy_adversarial_test.dart',
    'flutter test --timeout 2x -j 1 test/core/orchestrator_reliability_matrix_test.dart',
  ];

  static const List<String> _requiredDoneBlockers = <String>[
    '[x] [P1] [SEC] Redact provider secrets and auth tokens from RUN_LOG.jsonl, attempt artifacts, and CLI error surfaces',
    '[x] [P1] [CORE] Persist normalized failure reasons (timeout, policy, provider, test, review, git) in state and status APIs',
    '[x] [P1] [CORE] Enforce deterministic subtask scheduling tie-breakers and log scheduler decision inputs for replayability',
    '[x] [P1] [REF] Split TaskCycleService into explicit planning/coding/testing/review stages with typed stage boundaries',
    '[x] [P1] [REF] Refactor OrchestratorStepService into explicit state-transition handlers to reduce hidden coupling',
    '[x] [P1] [REF] Decompose `lib/core/services/orchestrator_run_service.dart` into orchestrator modules under `lib/core/services/orchestrator/` (loop coordinator, lock handling, release-tag flow, run-log events)',
    '[x] [P1] [QA] Add end-to-end crash-recovery tests for failures injected after each cycle stage boundary',
    '[x] [P1] [QA] Add regression tests for lock races and concurrent CLI actions (activate, done, review, autopilot run)',
    '[x] [P1] [SEC] Add adversarial tests for safe-write bypass attempts (path traversal, symlink edges, relative escapes)',
    '[x] [P1] [SEC] Add adversarial tests for shell_allowlist bypass attempts (chaining, subshell, separator abuse)',
    '[x] [P1] [CORE] Block task completion when mandatory review evidence bundle is missing or malformed',
    '[x] [P1] [CORE] Add explicit git delivery preflight (clean index, expected branch, upstream status) before done/merge',
    '[x] [P1] [QA] Re-enable zero-analysis-issues quality gate in CI and fail pipeline on any new analyzer warning',
    '[x] [P1] [QA] Add minimum coverage thresholds for core orchestration and policy modules in CI',
  ];

  static final RegExp _openCriticalP1Pattern = RegExp(
    r'(redact provider secrets|normalized failure reasons|deterministic subtask scheduling|split taskcycleservice|refactor orchestratorstepservice|decompose .*orchestrator_run_service\.dart|crash-recovery tests|lock races and concurrent cli actions|adversarial tests for safe-write|adversarial tests for shell_allowlist|mandatory review evidence bundle|git delivery preflight|zero-analysis-issues quality gate|coverage thresholds for core orchestration and policy)',
    caseSensitive: false,
  );

  static const Set<String> _incidentEvents = <String>{
    'preflight_failed',
    'orchestrator_run_error',
    'orchestrator_run_safety_halt',
    'orchestrator_run_progress_failure',
    'orchestrator_run_lock_recovered',
    'delivery_preflight_failed',
    'task_blocked',
  };

  static const List<String> _requiredLimitKeys = <String>[
    'max_failures',
    'max_task_retries',
    'failed_cooldown_seconds',
    'stuck_cooldown_seconds',
    'lock_ttl_seconds',
  ];

  Future<AutopilotCandidateResult> runCandidate(
    String projectRoot, {
    bool skipSuites = false,
  }) async {
    final layout = ProjectLayout(projectRoot);
    final missingFiles = <String>[];
    if (!File(layout.tasksPath).existsSync()) {
      missingFiles.add(layout.tasksPath);
    }
    if (!File(layout.statePath).existsSync()) {
      missingFiles.add(layout.statePath);
    }

    final missingDoneBlockers = <String>[];
    final openCriticalP1Lines = <String>[];
    if (missingFiles.isEmpty) {
      final tasksText = File(layout.tasksPath).readAsStringSync();
      for (final blocker in _requiredDoneBlockers) {
        if (!tasksText.contains(blocker)) {
          missingDoneBlockers.add(blocker);
        }
      }
      for (final rawLine in LineSplitter.split(tasksText)) {
        final line = rawLine.trimLeft();
        if (!line.startsWith('- [ ] [P1]')) {
          continue;
        }
        if (_openCriticalP1Pattern.hasMatch(rawLine)) {
          openCriticalP1Lines.add(rawLine.trimRight());
        }
      }
    }

    final commandOutcomes = <CandidateCommandOutcome>[];
    var suitesPassed = true;
    if (missingFiles.isEmpty &&
        missingDoneBlockers.isEmpty &&
        openCriticalP1Lines.isEmpty &&
        !skipSuites) {
      for (final command in _candidateSuites) {
        final result = await _commandRunner.run(
          command,
          workingDirectory: projectRoot,
          timeout: const Duration(minutes: 45),
        );
        final outcome = CandidateCommandOutcome(
          command: command,
          ok: result.ok,
          exitCode: result.exitCode,
          timedOut: result.timedOut,
          durationMs: result.duration.inMilliseconds,
          stdoutExcerpt: _truncate(result.stdout.trim(), 2400),
          stderrExcerpt: _truncate(result.stderr.trim(), 2400),
        );
        commandOutcomes.add(outcome);
        if (!result.ok) {
          suitesPassed = false;
          break;
        }
      }
    }

    final passed =
        missingFiles.isEmpty &&
        missingDoneBlockers.isEmpty &&
        openCriticalP1Lines.isEmpty &&
        (skipSuites || suitesPassed);
    return AutopilotCandidateResult(
      passed: passed,
      skipSuites: skipSuites,
      missingFiles: List<String>.unmodifiable(missingFiles),
      missingDoneBlockers: List<String>.unmodifiable(missingDoneBlockers),
      openCriticalP1Lines: List<String>.unmodifiable(openCriticalP1Lines),
      commandOutcomes: List<CandidateCommandOutcome>.unmodifiable(
        commandOutcomes,
      ),
    );
  }

  Future<AutopilotPilotResult> runPilot(
    String projectRoot, {
    required Duration duration,
    required int maxCycles,
    String? branch,
    String? prompt,
    bool skipCandidate = false,
    bool autoFixFormatDrift = false,
  }) async {
    if (duration.inSeconds < 1) {
      throw ArgumentError.value(duration, 'duration', 'must be >= 1 second');
    }
    if (maxCycles < 1) {
      throw ArgumentError.value(maxCycles, 'maxCycles', 'must be >= 1');
    }

    final layout = ProjectLayout(projectRoot);
    final configFile = File(layout.configPath);
    if (!configFile.existsSync()) {
      throw StateError('Missing required config file: ${layout.configPath}');
    }
    final configText = configFile.readAsStringSync();
    final missingLimitKeys = _requiredLimitKeys
        .where((key) => !_containsConfigKey(configText, key))
        .toList(growable: false);
    if (missingLimitKeys.isNotEmpty) {
      throw StateError(
        'Missing autopilot hard-limit keys in config.yml: ${missingLimitKeys.join(', ')}',
      );
    }

    AutopilotCandidateResult? candidateResult;
    if (!skipCandidate && !autoFixFormatDrift) {
      candidateResult = await runCandidate(projectRoot);
      if (!candidateResult.passed) {
        throw StateError('Release candidate gates failed.');
      }
    }

    if (!_gitService.isGitRepo(projectRoot)) {
      throw StateError('Project is not a git repository: $projectRoot');
    }
    if (!_gitService.isClean(projectRoot)) {
      throw StateError('Git worktree must be clean before pilot run.');
    }

    final resolvedBranch = branch?.trim().isNotEmpty == true
        ? branch!.trim()
        : 'feat/pilot-${_timestampCompact(_now())}';
    if (_gitService.branchExists(projectRoot, resolvedBranch)) {
      _gitService.checkout(projectRoot, resolvedBranch);
    } else {
      _gitService.createBranch(projectRoot, resolvedBranch);
    }

    if (autoFixFormatDrift) {
      final formatCheck = await _commandRunner.run(
        'dart format --output=none --set-exit-if-changed .',
        workingDirectory: projectRoot,
        timeout: const Duration(minutes: 20),
      );
      if (!formatCheck.ok) {
        final apply = await _commandRunner.run(
          'dart format .',
          workingDirectory: projectRoot,
          timeout: const Duration(minutes: 20),
        );
        if (!apply.ok) {
          throw StateError(
            'Unable to apply format baseline: ${_preferredOutput(apply)}',
          );
        }
        if (_gitService.hasChanges(projectRoot)) {
          _gitService.addAll(projectRoot);
          _gitService.commit(
            projectRoot,
            'chore: format baseline before unattended pilot run',
          );
        }
      }
      if (!skipCandidate) {
        candidateResult = await runCandidate(projectRoot);
        if (!candidateResult.passed) {
          throw StateError('Release candidate gates failed after format fix.');
        }
      }
    }

    Directory(
      '${layout.genaisysDir}${Platform.pathSeparator}logs',
    ).createSync(recursive: true);
    final startedAt = _now();
    final resolvedPrompt = prompt?.trim().isNotEmpty == true
        ? prompt!.trim()
        : 'Work the next task. Keep changes minimal, safe, and policy-compliant.';

    var timedOut = false;
    Timer? timeoutTimer;
    OrchestratorRunResult? runResult;
    Object? runError;
    int exitCode = 0;

    timeoutTimer = Timer(duration, () {
      timedOut = true;
      _runService.stop(projectRoot);
    });

    try {
      runResult = await _runService.run(
        projectRoot,
        codingPrompt: resolvedPrompt,
        maxSteps: maxCycles,
        stopWhenIdle: true,
      );
    } catch (error) {
      runError = error;
      exitCode = 1;
    } finally {
      timeoutTimer.cancel();
      await _runService.stop(projectRoot);
    }
    if (exitCode == 0 && timedOut) {
      exitCode = 124;
    }

    final endedAt = _now();
    final reportPath = _writePilotReport(
      projectRoot,
      branch: resolvedBranch,
      startUtc: startedAt,
      endUtc: endedAt,
      durationSeconds: duration.inSeconds,
      maxCycles: maxCycles,
      commandExitCode: exitCode,
      runError: runError?.toString(),
    );

    return AutopilotPilotResult(
      passed: exitCode == 0 || exitCode == 124,
      timedOut: timedOut,
      commandExitCode: exitCode,
      branch: resolvedBranch,
      durationSeconds: duration.inSeconds,
      maxCycles: maxCycles,
      reportPath: reportPath,
      totalSteps: runResult?.totalSteps ?? 0,
      successfulSteps: runResult?.successfulSteps ?? 0,
      idleSteps: runResult?.idleSteps ?? 0,
      failedSteps: runResult?.failedSteps ?? 0,
      stoppedByMaxSteps: runResult?.stoppedByMaxSteps ?? false,
      stoppedWhenIdle: runResult?.stoppedWhenIdle ?? false,
      stoppedBySafetyHalt: runResult?.stoppedBySafetyHalt ?? false,
      error: runError?.toString(),
    );
  }

  String _writePilotReport(
    String projectRoot, {
    required String branch,
    required DateTime startUtc,
    required DateTime endUtc,
    required int durationSeconds,
    required int maxCycles,
    required int commandExitCode,
    required String? runError,
  }) {
    final layout = ProjectLayout(projectRoot);
    final logsDir = '${layout.genaisysDir}${Platform.pathSeparator}logs';
    Directory(logsDir).createSync(recursive: true);
    final reportPath =
        '$logsDir${Platform.pathSeparator}pilot_run_report_${_timestampCompact(_now())}.md';
    final statusPayload = _buildStatusPayload(projectRoot);
    final incidentLines = _readIncidentLines(layout.runLogPath);
    final incidentTail = incidentLines.length <= 40
        ? incidentLines
        : incidentLines.sublist(incidentLines.length - 40);

    final buffer = StringBuffer()
      ..writeln('# Pilot Run Report')
      ..writeln()
      ..writeln('- start_utc: ${startUtc.toIso8601String()}')
      ..writeln('- end_utc: ${endUtc.toIso8601String()}')
      ..writeln('- branch: $branch')
      ..writeln('- duration_seconds: $durationSeconds')
      ..writeln('- max_cycles: $maxCycles')
      ..writeln('- command_exit_code: $commandExitCode')
      ..writeln('- incident_count: ${incidentLines.length}')
      ..writeln()
      ..writeln('## Autopilot Status JSON')
      ..writeln('```json')
      ..writeln(const JsonEncoder.withIndent('  ').convert(statusPayload))
      ..writeln('```')
      ..writeln()
      ..writeln('## Incident Event Tail');
    if (incidentTail.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final line in incidentTail) {
        buffer.writeln(line);
      }
    }
    if (runError != null && runError.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Run Error')
        ..writeln(runError.trim());
    }
    File(reportPath).writeAsStringSync(buffer.toString());
    return reportPath;
  }

  Map<String, Object?> _buildStatusPayload(String projectRoot) {
    final status = _runService.getStatus(projectRoot);
    final telemetry = _telemetryService.load(projectRoot, recentLimit: 5);
    final health = _healthCheckService.check(projectRoot);
    return <String, Object?>{
      'autopilot_running': status.isRunning,
      'pid': status.pid,
      'started_at': status.startedAt,
      'last_loop_at': status.lastLoopAt,
      'consecutive_failures': status.consecutiveFailures,
      'last_error': status.lastError,
      'last_error_class': status.lastErrorClass,
      'last_error_kind': status.lastErrorKind,
      'subtask_queue': status.subtaskQueue,
      'current_subtask': status.currentSubtask,
      'health': {
        'all_ok': health.allOk,
        'agent': {'ok': health.agent.ok, 'message': health.agent.message},
        'allowlist': {
          'ok': health.allowlist.ok,
          'message': health.allowlist.message,
        },
        'git': {'ok': health.git.ok, 'message': health.git.message},
        'review': {'ok': health.review.ok, 'message': health.review.message},
      },
      'telemetry': {
        'error_class': telemetry.errorClass,
        'error_kind': telemetry.errorKind,
        'error_message': telemetry.errorMessage,
        'agent_exit_code': telemetry.agentExitCode,
        'agent_stderr_excerpt': telemetry.agentStderrExcerpt,
        'last_error_event': telemetry.lastErrorEvent,
        'recent_events': telemetry.recentEvents
            .map(
              (event) => <String, Object?>{
                'timestamp': event.timestamp,
                'event': event.event,
                'message': event.message,
                'data': event.data,
              },
            )
            .toList(growable: false),
      },
      'last_step_summary': status.lastStepSummary == null
          ? null
          : <String, Object?>{
              'step_id': status.lastStepSummary!.stepId,
              'task_id': status.lastStepSummary!.taskId,
              'subtask_id': status.lastStepSummary!.subtaskId,
              'decision': status.lastStepSummary!.decision,
              'event': status.lastStepSummary!.event,
              'timestamp': status.lastStepSummary!.timestamp,
            },
    };
  }

  List<String> _readIncidentLines(String runLogPath) {
    final runLogFile = File(runLogPath);
    if (!runLogFile.existsSync()) {
      return const <String>[];
    }
    final lines = runLogFile.readAsLinesSync();
    final incidents = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          continue;
        }
        final event = decoded['event']?.toString() ?? '';
        if (_incidentEvents.contains(event)) {
          incidents.add(line);
        }
      } catch (_) {
        // Ignore malformed run-log lines in reports.
      }
    }
    return incidents;
  }

  bool _containsConfigKey(String configText, String key) {
    final pattern = RegExp('^\\s*${RegExp.escape(key)}:\\s*', multiLine: true);
    return pattern.hasMatch(configText);
  }

  String _timestampCompact(DateTime timestamp) {
    final utc = timestamp.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }

  String _preferredOutput(ShellCommandResult result) {
    final stderr = result.stderr.trim();
    if (stderr.isNotEmpty) {
      return _truncate(stderr, 800);
    }
    return _truncate(result.stdout.trim(), 800);
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }
}
