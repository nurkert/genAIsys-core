// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../models/project_state.dart';
import '../../models/task.dart';
import '../../policy/interaction_parity_policy.dart';
import '../../project_layout.dart';
import '../../storage/state_store.dart';
import '../../storage/task_store.dart';
import '../../policy/shell_allowlist_policy.dart';
import '../observability/health_check_service.dart';
import '../observability/resource_monitor_service.dart';
import 'stabilization_exit_gate_service.dart';
import '../step_schema_validation_service.dart';

class AutopilotPreflightResult {
  const AutopilotPreflightResult({
    required this.ok,
    this.reason,
    required this.message,
    this.errorClass,
    this.errorKind,
  });

  const AutopilotPreflightResult.ok()
    : ok = true,
      reason = null,
      message = 'Preflight passed.',
      errorClass = null,
      errorKind = null;

  final bool ok;
  final String? reason;
  final String message;
  final String? errorClass;
  final String? errorKind;
}

class AutopilotPreflightService {
  AutopilotPreflightService({
    HealthCheckService? healthCheckService,
    GitService? gitService,
    StepSchemaValidationService? schemaValidationService,
    StabilizationExitGateService? stabilizationExitGateService,
    ResourceMonitorService? resourceMonitorService,
  }) : _healthCheckService = healthCheckService ?? HealthCheckService(),
       _gitService = gitService ?? GitService(),
       _schemaValidationService =
           schemaValidationService ?? StepSchemaValidationService(),
       _stabilizationExitGateService =
           stabilizationExitGateService ?? StabilizationExitGateService(),
       _resourceMonitorService =
           resourceMonitorService ?? ResourceMonitorService();

  final HealthCheckService _healthCheckService;
  final GitService _gitService;
  final StepSchemaValidationService _schemaValidationService;
  final StabilizationExitGateService _stabilizationExitGateService;
  final ResourceMonitorService _resourceMonitorService;

  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    final stopwatch = Stopwatch()..start();
    final layout = ProjectLayout(projectRoot);

    final structure = _checkProjectStructure(layout);
    if (structure != null) {
      return structure;
    }

    final schemaGuard = _checkSchema(layout);
    if (schemaGuard != null) {
      return schemaGuard;
    }

    ProjectConfig config;
    try {
      config = ProjectConfig.load(projectRoot);
    } catch (error) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'Unable to load config.yml: $error',
        errorClass: 'preflight',
        errorKind: 'config_unavailable',
      );
    }

    final timeout =
        preflightTimeoutOverride ?? config.autopilotPreflightTimeout;

    final qualityGateGuard = _checkQualityGateConfig(config);
    if (qualityGateGuard != null) {
      return qualityGateGuard;
    }

    final resourceGuard = _checkResources(projectRoot, config);
    if (resourceGuard != null) {
      return resourceGuard;
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final gitGuard = _checkGitGuard(projectRoot, layout, config);
    if (gitGuard != null) {
      return gitGuard;
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final reviewGuard = _checkReviewPolicy(layout);
    if (reviewGuard != null) {
      return reviewGuard;
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final parityGuard = _checkActiveTaskParity(layout);
    if (parityGuard != null) {
      return parityGuard;
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final stabilizationExitGuard = _checkStabilizationExitGate(layout);
    if (stabilizationExitGuard != null) {
      return stabilizationExitGuard;
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final credentials = _healthCheckService.checkPrimaryProviderCredentials(
      projectRoot,
      environment: environment,
    );
    if (!credentials.ok) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'provider',
        message: credentials.message,
        errorClass: 'preflight',
        errorKind: credentials.errorKind ?? 'provider_credentials_missing',
      );
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    final health = _healthCheckService.check(
      projectRoot,
      environment: environment,
    );
    if (!health.agent.ok) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'agent_unavailable',
        message: health.agent.message,
        errorClass: 'preflight',
        errorKind: 'agent_unavailable',
      );
    }
    if (!health.allowlist.ok) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'allowlist',
        message: health.allowlist.message,
        errorClass: 'preflight',
        errorKind: 'allowlist',
      );
    }
    if (_isTimedOut(stopwatch, timeout)) {
      return _timeoutResult(stopwatch);
    }

    if (requirePushReadiness) {
      final pushGuard = _checkRemotePushReadiness(projectRoot);
      if (pushGuard != null) {
        return pushGuard;
      }
    }

    return const AutopilotPreflightResult.ok();
  }

  bool _isTimedOut(Stopwatch stopwatch, Duration timeout) {
    return stopwatch.elapsed >= timeout;
  }

  AutopilotPreflightResult _timeoutResult(Stopwatch stopwatch) {
    return AutopilotPreflightResult(
      ok: false,
      reason: 'timeout',
      message:
          'Preflight checks exceeded timeout '
          '(${stopwatch.elapsed.inSeconds}s elapsed).',
      errorClass: 'preflight',
      errorKind: 'preflight_timeout',
    );
  }

  AutopilotPreflightResult? _checkSchema(ProjectLayout layout) {
    try {
      _schemaValidationService.validateLayout(layout);
      return null;
    } on StateError catch (error) {
      final message = error.message.toString();
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: message,
        errorClass: 'preflight',
        errorKind: _schemaErrorKind(message),
      );
    } catch (error) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'Schema validation unavailable: $error',
        errorClass: 'preflight',
        errorKind: 'schema_unavailable',
      );
    }
  }

  String _schemaErrorKind(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('state.json')) {
      return 'state_schema';
    }
    if (normalized.contains('config.yml')) {
      return 'config_schema';
    }
    if (normalized.contains('tasks.md')) {
      return 'tasks_schema';
    }
    return 'schema_invalid';
  }

  AutopilotPreflightResult? _checkResources(
    String projectRoot,
    ProjectConfig config,
  ) {
    if (!config.autopilotResourceCheckEnabled) {
      return null;
    }
    try {
      final result = _resourceMonitorService.checkDiskSpace(projectRoot);
      if (result.ok) {
        return null;
      }
      return AutopilotPreflightResult(
        ok: false,
        reason: 'resource',
        message: result.message,
        errorClass: 'preflight',
        errorKind: 'disk_space_critical',
      );
    } catch (_) {
      // Best-effort resource check — do not block on monitoring errors.
      return null;
    }
  }

  AutopilotPreflightResult? _checkProjectStructure(ProjectLayout layout) {
    if (!Directory(layout.genaisysDir).existsSync()) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'No .genaisys directory found at: ${layout.genaisysDir}',
        errorClass: 'preflight',
        errorKind: 'state_missing',
      );
    }
    if (!File(layout.statePath).existsSync()) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'No STATE.json found at: ${layout.statePath}',
        errorClass: 'preflight',
        errorKind: 'state_missing',
      );
    }
    if (!File(layout.tasksPath).existsSync()) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'No TASKS.md found at: ${layout.tasksPath}',
        errorClass: 'preflight',
        errorKind: 'tasks_missing',
      );
    }
    return null;
  }

  AutopilotPreflightResult? _checkGitGuard(
    String projectRoot,
    ProjectLayout layout,
    ProjectConfig config,
  ) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'Not a git repository.',
        errorClass: 'preflight',
        errorKind: 'git_missing',
      );
    }
    if (_gitService.hasMergeInProgress(projectRoot)) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message:
            'Merge in progress. Manual intervention required before autopilot can run.',
        errorClass: 'preflight',
        errorKind: 'merge_conflict',
      );
    }
    if (_hasRebaseInProgress(projectRoot)) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message:
            'Rebase in progress. Manual intervention required before autopilot can run.',
        errorClass: 'preflight',
        errorKind: 'merge_conflict',
      );
    }
    if (_gitService.isClean(projectRoot)) {
      return null;
    }
    if (_canAutoRemediateDirtyRepo(layout, config)) {
      return null;
    }
    return const AutopilotPreflightResult(
      ok: false,
      reason: 'git',
      message:
          'Git repo has uncommitted changes. Clean the repo or enable auto-stash.',
      errorClass: 'preflight',
      errorKind: 'git_dirty',
    );
  }

  AutopilotPreflightResult? _checkStabilizationExitGate(ProjectLayout layout) {
    final result = _stabilizationExitGateService.evaluate(layout.tasksPath);
    if (result.ok) {
      return null;
    }
    if (result.errorKind == 'tasks_missing') {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'No TASKS.md found for stabilization exit gate check.',
        errorClass: 'preflight',
        errorKind: 'tasks_missing',
      );
    }
    return AutopilotPreflightResult(
      ok: false,
      reason: 'policy',
      message: result.message,
      errorClass: 'preflight',
      errorKind: result.errorKind ?? 'stabilization_exit_gate',
    );
  }

  bool _hasRebaseInProgress(String projectRoot) {
    try {
      return _gitService.hasRebaseInProgress(projectRoot);
    } catch (_) {
      // Fail-closed: treat unknown git state as rebase-in-progress to prevent
      // unsafe autopilot execution when git state cannot be determined.
      return true;
    }
  }

  bool _canAutoRemediateDirtyRepo(ProjectLayout layout, ProjectConfig config) {
    if (!config.gitAutoStash) {
      return false;
    }

    try {
      final state = StateStore(layout.statePath).read();
      final reviewRejected =
          state.reviewStatus?.trim().toLowerCase() == 'rejected';
      final hasActiveTask =
          (state.activeTaskId?.trim().isNotEmpty ?? false) ||
          (state.activeTaskTitle?.trim().isNotEmpty ?? false);

      if (reviewRejected && hasActiveTask) {
        // In unattended/autopilot mode, consult the skip-rejected-unattended
        // flag: when false (default), we allow auto-remediation so the step
        // service can stash rejected context and retry.  When true, the
        // preflight blocks to prevent stashing rejected work.
        // This aligns with OrchestratorStepService._shouldSkipRejectedContextStash.
        final unattended =
            state.autopilotRunning ||
            state.currentMode == 'autopilot_run' ||
            state.currentMode == 'autopilot_step';
        if (unattended) {
          return !config.gitAutoStashSkipRejectedUnattended;
        }
        // Attended mode: consult the attended-mode flag (default: true = skip).
        return !config.gitAutoStashSkipRejected;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  AutopilotPreflightResult? _checkReviewPolicy(ProjectLayout layout) {
    try {
      final state = StateStore(layout.statePath).read();
      final reviewStatus = state.reviewStatus?.trim().toLowerCase();
      if (reviewStatus != 'rejected') {
        return null;
      }

      // In autopilot/unattended mode, allow the step service to handle
      // rejected reviews (stash + retry) unless the config explicitly blocks
      // it.  This aligns with _canAutoRemediateDirtyRepo and
      // OrchestratorStepService._shouldSkipRejectedContextStash.
      final unattended =
          state.autopilotRunning ||
          state.currentMode == 'autopilot_run' ||
          state.currentMode == 'autopilot_step';
      if (unattended) {
        try {
          final config = ProjectConfig.load(layout.projectRoot);
          if (!config.gitAutoStashSkipRejectedUnattended) {
            // Config allows auto-remediation of rejected state in unattended
            // mode — let the step service handle stash and retry.
            return null;
          }
        } catch (_) {
          // Config unavailable — fail closed and block.
        }
      }

      return const AutopilotPreflightResult(
        ok: false,
        reason: 'review',
        message:
            'Review rejected. Unattended policy blocks next step until review is cleared or fixed.',
        errorClass: 'preflight',
        errorKind: 'review_rejected',
      );
    } catch (_) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'review',
        message: 'Review status unavailable.',
        errorClass: 'preflight',
        errorKind: 'review_unavailable',
      );
    }
  }

  AutopilotPreflightResult? _checkActiveTaskParity(ProjectLayout layout) {
    final ProjectState state;
    try {
      state = StateStore(layout.statePath).read();
    } catch (error) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'STATE.json could not be read for task parity check: $error',
        errorClass: 'preflight',
        errorKind: 'state_corrupt',
      );
    }
    final activeId = state.activeTaskId?.trim();
    final activeTitle = state.activeTaskTitle?.trim();
    final hasActive =
        (activeId != null && activeId.isNotEmpty) ||
        (activeTitle != null && activeTitle.isNotEmpty);
    if (!hasActive) {
      return null;
    }

    final List<Task> tasks;
    try {
      tasks = TaskStore(layout.tasksPath).readTasks();
    } catch (error) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'TASKS.md could not be parsed for task parity check: $error',
        errorClass: 'preflight',
        errorKind: 'state_corrupt',
      );
    }
    final task = _resolveActiveTask(
      tasks,
      activeId: activeId,
      activeTitle: activeTitle,
    );
    if (task == null) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'state',
        message: 'Active task is missing in TASKS.md.',
        errorClass: 'preflight',
        errorKind: 'active_task_missing',
      );
    }

    final parity = InteractionParityPolicy.evaluate(task, tasks);
    if (parity.ok) {
      return null;
    }
    return AutopilotPreflightResult(
      ok: false,
      reason: 'policy',
      message: parity.message ?? 'CLI-first parity policy failed.',
      errorClass: parity.errorClass ?? 'policy',
      errorKind: parity.errorKind ?? 'cli_gui_parity_invalid',
    );
  }

  Task? _resolveActiveTask(
    List<Task> tasks, {
    required String? activeId,
    required String? activeTitle,
  }) {
    if (activeId != null && activeId.isNotEmpty) {
      for (final task in tasks) {
        if (task.id == activeId) {
          return task;
        }
      }
    }
    if (activeTitle != null && activeTitle.isNotEmpty) {
      final normalized = activeTitle.toLowerCase();
      for (final task in tasks) {
        if (task.title.trim().toLowerCase() == normalized) {
          return task;
        }
      }
    }
    return null;
  }

  AutopilotPreflightResult? _checkRemotePushReadiness(String projectRoot) {
    String? remote;
    try {
      remote = _gitService.defaultRemote(projectRoot);
    } catch (_) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'Unable to read git remote configuration.',
        errorClass: 'preflight',
        errorKind: 'remote_unavailable',
      );
    }
    if (remote == null || remote.trim().isEmpty) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'No git remote configured for unattended push workflow.',
        errorClass: 'preflight',
        errorKind: 'remote_unavailable',
      );
    }

    String branch;
    try {
      branch = _gitService.currentBranch(projectRoot);
    } catch (_) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'Unable to determine current git branch.',
        errorClass: 'preflight',
        errorKind: 'git_missing',
      );
    }
    if (branch.trim().isEmpty) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'Current git branch is empty.',
        errorClass: 'preflight',
        errorKind: 'git_missing',
      );
    }

    final ProcessResult result;
    try {
      result = _gitService.pushDryRun(
        projectRoot,
        remote.trim(),
        branch.trim(),
      );
    } on ProcessException catch (error) {
      return AutopilotPreflightResult(
        ok: false,
        reason: 'git',
        message: 'Push dry-run process crashed: $error',
        errorClass: 'preflight',
        errorKind: 'push_check_crash',
      );
    }
    if (result.exitCode == 0) {
      return null;
    }
    final stderr = result.stderr.toString().trim();
    final stdout = result.stdout.toString().trim();
    final detail = stderr.isNotEmpty ? stderr : stdout;
    final message = detail.isEmpty
        ? 'Dry-run push failed for branch "$branch" to "$remote".'
        : 'Dry-run push failed for branch "$branch" to "$remote": $detail';
    return AutopilotPreflightResult(
      ok: false,
      reason: 'git',
      message: message,
      errorClass: 'preflight',
      errorKind: 'push_not_ready',
    );
  }

  AutopilotPreflightResult? _checkQualityGateConfig(ProjectConfig config) {
    if (!config.qualityGateEnabled) {
      return null;
    }
    if (config.qualityGateCommands.isEmpty) {
      return const AutopilotPreflightResult(
        ok: false,
        reason: 'policy',
        message:
            'Quality gate is enabled but no commands are configured.',
        errorClass: 'preflight',
        errorKind: 'config_schema',
      );
    }
    for (final command in config.qualityGateCommands) {
      final parsed = ShellCommandTokenizer.tryParse(command);
      if (parsed == null) {
        return AutopilotPreflightResult(
          ok: false,
          reason: 'policy',
          message:
              'Quality gate command is not parseable: "$command"',
          errorClass: 'preflight',
          errorKind: 'config_schema',
        );
      }
      final allowlistPolicy = ShellAllowlistPolicy(
        allowedPrefixes: config.shellAllowlist,
      );
      if (!allowlistPolicy.allows(command)) {
        return AutopilotPreflightResult(
          ok: false,
          reason: 'policy',
          message:
              'Quality gate command "${parsed.executable}" is not in shell allowlist.',
          errorClass: 'preflight',
          errorKind: 'config_schema',
        );
      }
    }
    return null;
  }
}
