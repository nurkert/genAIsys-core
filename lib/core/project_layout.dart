// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

class ProjectLayout {
  const ProjectLayout(this.projectRoot);

  final String projectRoot;

  String get genaisysDir => _join(projectRoot, '.genaisys');
  String get visionPath => _join(genaisysDir, 'VISION.md');
  String get rulesPath => _join(genaisysDir, 'RULES.md');
  String get tasksPath => _join(genaisysDir, 'TASKS.md');
  String get architecturePath => _join(genaisysDir, 'ARCHITECTURE.md');
  String get rootVisionCompatPath => _join(projectRoot, 'VISION.md');
  String get rootRulesCompatPath => _join(projectRoot, 'RULES.md');
  String get rootTasksCompatPath => _join(projectRoot, 'TASKS.md');
  String get statePath => _join(genaisysDir, 'STATE.json');
  String get runLogPath => _join(genaisysDir, 'RUN_LOG.jsonl');
  String get configPath => _join(genaisysDir, 'config.yml');
  String get gitignorePath => _join(genaisysDir, '.gitignore');

  String get agentContextsDir => _join(genaisysDir, 'agent_contexts');
  String get taskSpecsDir => _join(genaisysDir, 'task_specs');
  String get attemptsDir => _join(genaisysDir, 'attempts');
  String get workspacesDir => _join(genaisysDir, 'workspaces');
  String get locksDir => _join(genaisysDir, 'locks');
  String get auditDir => _join(genaisysDir, 'audit');
  String get evalsDir => _join(genaisysDir, 'evals');
  String get evalResultsDir => _join(evalsDir, 'runs');
  String get evalBenchmarksPath => _join(genaisysDir, 'benchmarks.json');
  String get evalSummaryPath => _join(evalsDir, 'summary.json');
  String get autopilotLockPath => _join(locksDir, 'autopilot.lock');
  String get autopilotStopPath => _join(locksDir, 'autopilot.stop');
  String get autopilotSupervisorLockPath =>
      _join(locksDir, 'autopilot_supervisor.lock');
  String get autopilotSupervisorStopPath =>
      _join(locksDir, 'autopilot_supervisor.stop');
  String get hitlGatePath => _join(locksDir, 'hitl.gate');
  String get hitlDecisionPath => _join(locksDir, 'hitl.decision');
  String get trendSnapshotsPath =>
      _join(auditDir, 'health_trend_snapshots.json');
  String get unattendedProviderBlocklistPath =>
      _join(auditDir, 'unattended_provider_blocklist.json');
  String get providerPoolStatePath =>
      _join(auditDir, 'provider_pool_state.json');
  String get runtimeSwitchStatePath =>
      _join(auditDir, 'runtime_switch_state.json');
  String get errorPatternRegistryPath => _join(auditDir, 'error_patterns.json');
  String get lessonsLearnedPath => _join(genaisysDir, 'lessons_learned.md');

  // Health / observability paths.
  String get healthLedgerPath => _join(genaisysDir, 'health_ledger.jsonl');
  String get healthSummaryPath => _join(genaisysDir, 'health.json');
  String get heartbeatPath => _join(locksDir, 'heartbeat');
  String get exitSummaryPath => _join(auditDir, 'exit_summary.json');

  String get releasesDir => _join(genaisysDir, 'releases');
  String get releaseCandidatesDir => _join(releasesDir, 'candidates');
  String get releaseStableDir => _join(releasesDir, 'stable');

  List<String> get requiredDirs => [
    genaisysDir,
    agentContextsDir,
    taskSpecsDir,
    attemptsDir,
    workspacesDir,
    locksDir,
    auditDir,
    evalsDir,
    evalResultsDir,
    releasesDir,
    releaseCandidatesDir,
    releaseStableDir,
  ];

  static String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
