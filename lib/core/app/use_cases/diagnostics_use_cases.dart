// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../contracts/app_result.dart';
import '../dto/diagnostics_dto.dart';
import '../../config/project_config.dart';
import '../../project_layout.dart';
import '../../services/autopilot/autopilot_preflight_service.dart';
import '../../services/error_pattern_registry_service.dart';
import '../../services/observability/health_check_service.dart';
import '../../services/observability/run_telemetry_service.dart';
import '../../storage/state_store.dart';
import '../../models/task.dart';
import '../../storage/task_store.dart';
import '../contracts/app_error.dart';

// ---------------------------------------------------------------------------
// config validate
// ---------------------------------------------------------------------------

class ConfigValidateUseCase {
  ConfigValidateUseCase({HealthCheckService? healthCheckService})
    : _healthCheckService = healthCheckService ?? HealthCheckService();

  final HealthCheckService _healthCheckService;

  Future<AppResult<ConfigValidationDto>> run(String projectRoot) async {
    try {
      final checks = <ConfigValidationCheckDto>[];
      final warnings = <ConfigValidationCheckDto>[];

      // 1. YAML parse
      ProjectConfig config;
      try {
        config = ProjectConfig.load(projectRoot);
        checks.add(
          const ConfigValidationCheckDto(
            name: 'yaml_parse',
            ok: true,
            message: 'config.yml parsed successfully.',
          ),
        );
      } catch (error) {
        checks.add(
          ConfigValidationCheckDto(
            name: 'yaml_parse',
            ok: false,
            message: 'config.yml parse error: $error',
            remediationHint:
                'Verify YAML syntax in .genaisys/config.yml. '
                'Run: yamllint .genaisys/config.yml',
          ),
        );
        return AppResult.success(
          ConfigValidationDto(ok: false, checks: checks, warnings: warnings),
        );
      }

      // 2. Quality gate commands resolvable
      for (final command in config.qualityGateCommands) {
        final executable = command.split(' ').first;
        final which = Process.runSync('which', [executable]);
        if (which.exitCode == 0) {
          checks.add(
            ConfigValidationCheckDto(
              name: 'quality_gate_command',
              ok: true,
              message: 'Command resolvable: $executable',
            ),
          );
        } else {
          checks.add(
            ConfigValidationCheckDto(
              name: 'quality_gate_command',
              ok: false,
              message: 'Command not found on PATH: $executable',
              remediationHint:
                  'Install $executable or remove the command from '
                  'policies.quality_gate.commands in config.yml.',
            ),
          );
        }
      }

      // 3. Safe-write roots
      for (final root in config.safeWriteRoots) {
        final dir = Directory('$projectRoot/$root');
        final fileCheck = File('$projectRoot/$root');
        if (dir.existsSync() || fileCheck.existsSync()) {
          checks.add(
            ConfigValidationCheckDto(
              name: 'safe_write_root',
              ok: true,
              message: 'Safe-write root exists: $root',
            ),
          );
        } else {
          warnings.add(
            ConfigValidationCheckDto(
              name: 'safe_write_root',
              ok: false,
              message: 'Safe-write root not found: $root',
              remediationHint:
                  'Create the directory or update '
                  'policies.safe_write.roots in config.yml.',
            ),
          );
        }
      }

      // 4. Shell allowlist profile
      final profile = config.shellAllowlistProfile;
      const validProfiles = ['standard', 'strict', 'permissive', 'custom'];
      if (validProfiles.contains(profile)) {
        checks.add(
          ConfigValidationCheckDto(
            name: 'shell_allowlist_profile',
            ok: true,
            message: 'Shell allowlist profile valid: $profile',
          ),
        );
      } else {
        checks.add(
          ConfigValidationCheckDto(
            name: 'shell_allowlist_profile',
            ok: false,
            message: 'Unknown shell allowlist profile: $profile',
            remediationHint: 'Use one of: ${validProfiles.join(', ')}',
          ),
        );
      }

      // 5. Provider credentials
      final credentialCheck = _healthCheckService
          .checkPrimaryProviderCredentials(projectRoot);
      checks.add(
        ConfigValidationCheckDto(
          name: 'provider_credentials',
          ok: credentialCheck.ok,
          message: credentialCheck.message,
          remediationHint: credentialCheck.ok
              ? null
              : 'Set the required environment variable for '
                    'provider ${credentialCheck.provider}.',
        ),
      );

      final allOk = checks.every((c) => c.ok);
      return AppResult.success(
        ConfigValidationDto(ok: allOk, checks: checks, warnings: warnings),
      );
    } catch (error) {
      return AppResult.failure(
        AppError.unknown('Config validation failed: $error'),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// health report
// ---------------------------------------------------------------------------

class HealthReportUseCase {
  HealthReportUseCase({
    AutopilotPreflightService? preflightService,
    HealthCheckService? healthCheckService,
  }) : _preflightService = preflightService ?? AutopilotPreflightService(),
       _healthCheckService = healthCheckService ?? HealthCheckService();

  final AutopilotPreflightService _preflightService;
  final HealthCheckService _healthCheckService;

  Future<AppResult<HealthReportDto>> run(String projectRoot) async {
    try {
      final layout = ProjectLayout(projectRoot);
      final checks = <HealthReportCheckDto>[];

      // 1. Project structure
      final hasDir = Directory(layout.genaisysDir).existsSync();
      final hasState = File(layout.statePath).existsSync();
      final hasTasks = File(layout.tasksPath).existsSync();
      final structureOk = hasDir && hasState && hasTasks;
      checks.add(
        HealthReportCheckDto(
          name: 'project_structure',
          ok: structureOk,
          message: structureOk
              ? 'Project structure valid.'
              : 'Missing: ${[if (!hasDir) '.genaisys/', if (!hasState) 'STATE.json', if (!hasTasks) 'TASKS.md'].join(', ')}',
          errorKind: structureOk ? null : 'state_missing',
        ),
      );

      if (!structureOk) {
        return AppResult.success(HealthReportDto(ok: false, checks: checks));
      }

      // 2. Full preflight (covers schema, git, review, stabilization,
      //    provider, agents, disk)
      final preflight = _preflightService.check(projectRoot);
      if (preflight.ok) {
        checks.add(
          const HealthReportCheckDto(
            name: 'preflight',
            ok: true,
            message: 'All preflight checks passed.',
          ),
        );
      } else {
        checks.add(
          HealthReportCheckDto(
            name: 'preflight',
            ok: false,
            message: preflight.message,
            errorKind: preflight.errorKind,
          ),
        );
      }

      // 3. Health sub-checks (agent, allowlist, git, review)
      final health = _healthCheckService.check(projectRoot);
      checks.add(
        HealthReportCheckDto(
          name: 'agent',
          ok: health.agent.ok,
          message: health.agent.message,
          errorKind: health.agent.ok ? null : 'agent_unavailable',
        ),
      );
      checks.add(
        HealthReportCheckDto(
          name: 'allowlist',
          ok: health.allowlist.ok,
          message: health.allowlist.message,
          errorKind: health.allowlist.ok ? null : 'allowlist_invalid',
        ),
      );
      checks.add(
        HealthReportCheckDto(
          name: 'git',
          ok: health.git.ok,
          message: health.git.message,
          errorKind: health.git.ok ? null : 'git_issue',
        ),
      );
      checks.add(
        HealthReportCheckDto(
          name: 'review',
          ok: health.review.ok,
          message: health.review.message,
          errorKind: health.review.ok ? null : 'review_issue',
        ),
      );

      // 4. Provider credentials
      final credentials = _healthCheckService.checkPrimaryProviderCredentials(
        projectRoot,
      );
      checks.add(
        HealthReportCheckDto(
          name: 'provider_credentials',
          ok: credentials.ok,
          message: credentials.message,
          errorKind: credentials.ok ? null : credentials.errorKind,
        ),
      );

      final allOk = checks.every((c) => c.ok);
      return AppResult.success(HealthReportDto(ok: allOk, checks: checks));
    } catch (error) {
      return AppResult.failure(AppError.unknown('Health check failed: $error'));
    }
  }
}

// ---------------------------------------------------------------------------
// autopilot dry-run
// ---------------------------------------------------------------------------

class AutopilotDryRunUseCase {
  AutopilotDryRunUseCase({AutopilotPreflightService? preflightService})
    : _preflightService = preflightService ?? AutopilotPreflightService();

  final AutopilotPreflightService _preflightService;

  Future<AppResult<AutopilotDryRunDto>> run(String projectRoot) async {
    try {
      final layout = ProjectLayout(projectRoot);

      // Run preflight (read-only).
      final preflight = _preflightService.check(projectRoot);
      if (!preflight.ok) {
        return AppResult.success(
          AutopilotDryRunDto(
            preflightOk: false,
            preflightMessage: preflight.message,
            specGenerated: false,
            plannedTasksAdded: 0,
          ),
        );
      }

      // Read tasks (read-only — no activation or state writes).
      final taskStore = TaskStore(layout.tasksPath);
      final tasks = taskStore.readTasks();
      final openTasks = tasks
          .where((t) => t.completion == TaskCompletion.open && !t.blocked)
          .toList();

      String? selectedTitle;
      String? selectedId;
      if (openTasks.isNotEmpty) {
        // Simple selection: first open task (matches fair-selection default).
        final selected = openTasks.first;
        selectedTitle = selected.title;
        selectedId = selected.id;
      }

      return AppResult.success(
        AutopilotDryRunDto(
          preflightOk: true,
          preflightMessage: preflight.message,
          selectedTaskTitle: selectedTitle,
          selectedTaskId: selectedId,
          specGenerated: false,
          plannedTasksAdded: 0,
        ),
      );
    } catch (error) {
      return AppResult.failure(AppError.unknown('Dry-run failed: $error'));
    }
  }
}

// ---------------------------------------------------------------------------
// autopilot diagnostics
// ---------------------------------------------------------------------------

class AutopilotDiagnosticsUseCase {
  AutopilotDiagnosticsUseCase({
    ErrorPatternRegistryService? errorPatternRegistryService,
    RunTelemetryService? runTelemetryService,
  }) : _errorPatternService =
           errorPatternRegistryService ?? ErrorPatternRegistryService(),
       _runTelemetryService = runTelemetryService ?? RunTelemetryService();

  final ErrorPatternRegistryService _errorPatternService;
  final RunTelemetryService _runTelemetryService;

  Future<AppResult<AutopilotDiagnosticsDto>> run(String projectRoot) async {
    try {
      final layout = ProjectLayout(projectRoot);

      // 1. Error patterns (top 10 by count).
      final patterns = _errorPatternService.load(projectRoot);
      patterns.sort((a, b) => b.count.compareTo(a.count));
      final top10 = patterns
          .take(10)
          .map(
            (p) => ErrorPatternDto(
              errorKind: p.errorKind,
              count: p.count,
              lastSeen: p.lastSeen,
              autoResolvedCount: p.autoResolvedCount,
              resolutionStrategy: p.resolutionStrategy,
            ),
          )
          .toList();

      // 2. Forensic state from STATE.json.
      final forensic = <String, Object?>{};
      final stateFile = File(layout.statePath);
      if (stateFile.existsSync()) {
        final stateStore = StateStore(layout.statePath);
        final state = stateStore.read();
        forensic['forensic_recovery_attempted'] =
            state.forensicRecoveryAttempted;
        forensic['forensic_guidance'] = state.forensicGuidance;
        forensic['consecutive_failures'] = state.consecutiveFailures;
        forensic['last_error'] = state.lastError;
        forensic['last_error_class'] = state.lastErrorClass;
        forensic['last_error_kind'] = state.lastErrorKind;
      }

      // 3. Recent run-log events (last 5).
      final telemetry = _runTelemetryService.load(projectRoot, recentLimit: 5);
      final recentEvents = telemetry.recentEvents
          .map(
            (e) => <String, Object?>{
              'event': e.event,
              'message': e.message,
              'timestamp': e.timestamp,
              if (e.data != null) 'data': e.data,
            },
          )
          .toList();

      // 4. Supervisor status from STATE.json.
      final supervisorStatus = <String, Object?>{};
      if (stateFile.existsSync()) {
        final stateStore = StateStore(layout.statePath);
        final state = stateStore.read();
        supervisorStatus['running'] = state.supervisorRunning;
        supervisorStatus['session_id'] = state.supervisorSessionId;
        supervisorStatus['pid'] = state.supervisorPid;
        supervisorStatus['started_at'] = state.supervisorStartedAt;
        supervisorStatus['profile'] = state.supervisorProfile;
        supervisorStatus['restart_count'] = state.supervisorRestartCount;
        supervisorStatus['last_halt_reason'] = state.supervisorLastHaltReason;
        supervisorStatus['last_exit_code'] = state.supervisorLastExitCode;
      }

      return AppResult.success(
        AutopilotDiagnosticsDto(
          errorPatterns: top10,
          forensicState: forensic,
          recentEvents: recentEvents,
          supervisorStatus: supervisorStatus,
        ),
      );
    } catch (error) {
      return AppResult.failure(AppError.unknown('Diagnostics failed: $error'));
    }
  }
}

// ---------------------------------------------------------------------------
// config diff
// ---------------------------------------------------------------------------

class ConfigDiffUseCase {
  Future<AppResult<ConfigDiffDto>> run(String projectRoot) async {
    try {
      final current = ProjectConfig.load(projectRoot);
      final defaults = ProjectConfig();
      final entries = <ConfigDiffEntryDto>[];

      void compare(
        String field,
        Object? currentValue,
        Object? defaultValue,
        String effect,
      ) {
        final cStr = _stringify(currentValue);
        final dStr = _stringify(defaultValue);
        if (cStr != dStr) {
          entries.add(
            ConfigDiffEntryDto(
              field: field,
              currentValue: cStr,
              defaultValue: dStr,
              effect: effect,
            ),
          );
        }
      }

      // Compare key fields (subset that users commonly customize).
      compare(
        'providers.primary',
        current.providersPrimary,
        defaults.providersPrimary,
        'Controls which AI provider is used for coding tasks.',
      );
      compare(
        'providers.fallback',
        current.providersFallback,
        defaults.providersFallback,
        'Fallback provider when primary is unavailable.',
      );
      compare(
        'diff_budget.max_files',
        current.diffBudgetMaxFiles,
        defaults.diffBudgetMaxFiles,
        'Max files changed per task delivery.',
      );
      compare(
        'diff_budget.max_additions',
        current.diffBudgetMaxAdditions,
        defaults.diffBudgetMaxAdditions,
        'Max line additions per task delivery.',
      );
      compare(
        'diff_budget.max_deletions',
        current.diffBudgetMaxDeletions,
        defaults.diffBudgetMaxDeletions,
        'Max line deletions per task delivery.',
      );
      compare(
        'git.base_branch',
        current.gitBaseBranch,
        defaults.gitBaseBranch,
        'Target branch for merges.',
      );
      compare(
        'git.feature_prefix',
        current.gitFeaturePrefix,
        defaults.gitFeaturePrefix,
        'Prefix for feature branch names.',
      );
      compare(
        'git.auto_stash',
        current.gitAutoStash,
        defaults.gitAutoStash,
        'Stash uncommitted changes before autopilot steps.',
      );
      compare(
        'policies.quality_gate.enabled',
        current.qualityGateEnabled,
        defaults.qualityGateEnabled,
        'Run quality gate (format, analyze, test) after coding.',
      );
      compare(
        'policies.quality_gate.timeout_seconds',
        current.qualityGateTimeout.inSeconds,
        defaults.qualityGateTimeout.inSeconds,
        'Timeout for quality gate command execution.',
      );
      compare(
        'policies.quality_gate.flake_retry_count',
        current.qualityGateFlakeRetryCount,
        defaults.qualityGateFlakeRetryCount,
        'Number of retries for flaky test detection.',
      );
      compare(
        'policies.safe_write.enabled',
        current.safeWriteEnabled,
        defaults.safeWriteEnabled,
        'Restrict agent file writes to allowed directories.',
      );
      compare(
        'workflow.auto_push',
        current.workflowAutoPush,
        defaults.workflowAutoPush,
        'Auto-push to remote after task completion.',
      );
      compare(
        'workflow.auto_merge',
        current.workflowAutoMerge,
        defaults.workflowAutoMerge,
        'Auto-merge feature branch to base branch.',
      );
      compare(
        'autopilot.max_failures',
        current.autopilotMaxFailures,
        defaults.autopilotMaxFailures,
        'Safety halt threshold: max consecutive failures.',
      );
      compare(
        'autopilot.max_task_retries',
        current.autopilotMaxTaskRetries,
        defaults.autopilotMaxTaskRetries,
        'Max retries per task before blocking.',
      );
      compare(
        'autopilot.step_sleep_seconds',
        current.autopilotStepSleep.inSeconds,
        defaults.autopilotStepSleep.inSeconds,
        'Delay between autopilot steps.',
      );
      compare(
        'autopilot.idle_sleep_seconds',
        current.autopilotIdleSleep.inSeconds,
        defaults.autopilotIdleSleep.inSeconds,
        'Delay when no tasks available.',
      );
      compare(
        'autopilot.selection_mode',
        current.autopilotSelectionMode,
        defaults.autopilotSelectionMode,
        'Task selection strategy (fair, priority, fifo).',
      );
      compare(
        'review.max_rounds',
        current.reviewMaxRounds,
        defaults.reviewMaxRounds,
        'Max review rounds before blocking.',
      );
      compare(
        'agents.timeout_seconds',
        current.agentTimeout.inSeconds,
        defaults.agentTimeout.inSeconds,
        'Timeout for agent invocations.',
      );

      return AppResult.success(
        ConfigDiffDto(hasDiff: entries.isNotEmpty, entries: entries),
      );
    } catch (error) {
      return AppResult.failure(AppError.unknown('Config diff failed: $error'));
    }
  }

  static String _stringify(Object? value) {
    if (value == null) return 'null';
    if (value is List) return value.join(', ');
    return value.toString();
  }
}
