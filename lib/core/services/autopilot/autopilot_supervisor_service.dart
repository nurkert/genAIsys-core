// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../config/project_config.dart';
import '../../errors/failure_reason_mapper.dart';
import '../../models/project_state.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../../storage/state_store.dart';
import 'autopilot_preflight_service.dart';
import '../orchestrator_run_service.dart';
import '../pid_liveness_service.dart';
import '../productivity_reflection_service.dart';
import '../observability/run_telemetry_service.dart';
import '../state_repair_service.dart';
import '../supervisor_health_reporter.dart';
import '../supervisor_resume_policy.dart';
import '../supervisor_throughput_guard.dart';

typedef SupervisorSleep = Future<void> Function(Duration duration);
typedef SupervisorNow = DateTime Function();
typedef SupervisorSpawnWorker =
    Future<int> Function(
      String projectRoot, {
      required String sessionId,
      required String profile,
      required String prompt,
      required String startReason,
      required int maxRestarts,
      required int restartBackoffBaseSeconds,
      required int restartBackoffMaxSeconds,
      required int lowSignalLimit,
      required int throughputWindowMinutes,
      required int throughputMaxSteps,
      required int throughputMaxRejects,
      required int throughputMaxHighRetries,
    });

class AutopilotSupervisorProfile {
  const AutopilotSupervisorProfile({
    required this.name,
    required this.segmentMaxSteps,
    required this.stepSleep,
    required this.idleSleep,
    required this.stopWhenIdle,
    required this.segmentPause,
  });

  final String name;
  final int segmentMaxSteps;
  final Duration stepSleep;
  final Duration idleSleep;
  final bool stopWhenIdle;
  final Duration segmentPause;

  static const pilot = AutopilotSupervisorProfile(
    name: 'pilot',
    segmentMaxSteps: 20,
    stepSleep: Duration(seconds: 2),
    idleSleep: Duration(seconds: 10),
    stopWhenIdle: true,
    segmentPause: Duration(seconds: 6),
  );

  static const overnight = AutopilotSupervisorProfile(
    name: 'overnight',
    segmentMaxSteps: 80,
    stepSleep: Duration(seconds: 2),
    idleSleep: Duration(seconds: 20),
    stopWhenIdle: false,
    segmentPause: Duration(seconds: 4),
  );

  static const longrun = AutopilotSupervisorProfile(
    name: 'longrun',
    segmentMaxSteps: 160,
    stepSleep: Duration(seconds: 1),
    idleSleep: Duration(seconds: 12),
    stopWhenIdle: false,
    segmentPause: Duration(seconds: 3),
  );

  /// Sprint profile: never stops on idle — SprintPlannerService takes over
  /// termination via vision_fulfilled or max_sprints_reached.
  static const sprint = AutopilotSupervisorProfile(
    name: 'sprint',
    segmentMaxSteps: 120,
    stepSleep: Duration(seconds: 2),
    idleSleep: Duration(seconds: 5),
    stopWhenIdle: false,
    segmentPause: Duration(seconds: 4),
  );

  static AutopilotSupervisorProfile parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'pilot':
        return pilot;
      case 'longrun':
        return longrun;
      case 'sprint':
        return sprint;
      case 'overnight':
      case null:
      case '':
        return overnight;
      default:
        throw ArgumentError.value(
          value,
          'profile',
          'must be one of: pilot, overnight, longrun, sprint',
        );
    }
  }
}

class AutopilotSupervisorStartResult {
  const AutopilotSupervisorStartResult({
    required this.started,
    required this.sessionId,
    required this.profile,
    required this.pid,
    required this.resumeAction,
  });

  final bool started;
  final String sessionId;
  final String profile;
  final int pid;
  final String resumeAction;
}

class AutopilotSupervisorStopResult {
  const AutopilotSupervisorStopResult({
    required this.stopped,
    required this.wasRunning,
    required this.reason,
  });

  final bool stopped;
  final bool wasRunning;
  final String reason;
}

class AutopilotSupervisorStatus {
  const AutopilotSupervisorStatus({
    required this.running,
    required this.workerPid,
    required this.sessionId,
    required this.profile,
    required this.startReason,
    required this.restartCount,
    required this.cooldownUntil,
    required this.lastHaltReason,
    required this.lastResumeAction,
    required this.lastExitCode,
    required this.lowSignalStreak,
    required this.throughputWindowStartedAt,
    required this.throughputSteps,
    required this.throughputRejects,
    required this.throughputHighRetries,
    required this.startedAt,
    required this.autopilotRunning,
    required this.autopilotPid,
    required this.autopilotLastLoopAt,
    required this.autopilotConsecutiveFailures,
    required this.autopilotLastError,
  });

  final bool running;
  final int? workerPid;
  final String? sessionId;
  final String? profile;
  final String? startReason;
  final int restartCount;
  final String? cooldownUntil;
  final String? lastHaltReason;
  final String? lastResumeAction;
  final int? lastExitCode;
  final int lowSignalStreak;
  final String? throughputWindowStartedAt;
  final int throughputSteps;
  final int throughputRejects;
  final int throughputHighRetries;
  final String? startedAt;
  final bool autopilotRunning;
  final int? autopilotPid;
  final String? autopilotLastLoopAt;
  final int autopilotConsecutiveFailures;
  final String? autopilotLastError;
}

class AutopilotSupervisorService {
  AutopilotSupervisorService({
    OrchestratorRunService? runService,
    AutopilotPreflightService? preflightService,
    RunTelemetryService? telemetryService,
    StateRepairService? stateRepairService,
    ProductivityReflectionService? reflectionService,
    PidLivenessService? pidLivenessService,
    SupervisorThroughputGuard? throughputGuard,
    SupervisorResumePolicy? resumePolicy,
    SupervisorHealthReporter? healthReporter,
    SupervisorSleep? sleep,
    SupervisorNow? now,
    SupervisorSpawnWorker? spawnWorker,
  }) : _runService = runService ?? OrchestratorRunService(),
       _preflightService = preflightService ?? AutopilotPreflightService(),
       _telemetryService = telemetryService ?? RunTelemetryService(),
       _stateRepairService = stateRepairService ?? StateRepairService(),
       _reflectionService =
           reflectionService ?? ProductivityReflectionService(),
       _pidLivenessService = pidLivenessService ?? PidLivenessService(),
       _throughputGuard = throughputGuard ?? SupervisorThroughputGuard(),
       _resumePolicy = resumePolicy ?? SupervisorResumePolicy(),
       _healthReporter = healthReporter ?? SupervisorHealthReporter(),
       _sleep = sleep ?? Future<void>.delayed,
       _now = now ?? (() => DateTime.now().toUtc()),
       _spawnWorker = spawnWorker ?? _defaultSpawnWorker;

  static const defaultMaxRestarts = 3;
  static const defaultRestartBackoffBaseSeconds = 5;
  static const defaultRestartBackoffMaxSeconds = 90;
  static const defaultLowSignalLimit = 3;
  static const defaultThroughputWindowMinutes = 30;
  static const defaultThroughputMaxSteps = 200;
  static const defaultThroughputMaxRejects = 10;
  static const defaultThroughputMaxHighRetries = 20;

  final OrchestratorRunService _runService;
  final AutopilotPreflightService _preflightService;
  final RunTelemetryService _telemetryService;
  final StateRepairService _stateRepairService;
  final ProductivityReflectionService _reflectionService;
  final PidLivenessService _pidLivenessService;
  final SupervisorThroughputGuard _throughputGuard;
  final SupervisorResumePolicy _resumePolicy;
  final SupervisorHealthReporter _healthReporter;
  final SupervisorSleep _sleep;
  final SupervisorNow _now;
  final SupervisorSpawnWorker _spawnWorker;

  Future<AutopilotSupervisorStartResult> start(
    String projectRoot, {
    String profile = 'overnight',
    String? prompt,
    String startReason = 'manual_start',
    int maxRestarts = defaultMaxRestarts,
    int restartBackoffBaseSeconds = defaultRestartBackoffBaseSeconds,
    int restartBackoffMaxSeconds = defaultRestartBackoffMaxSeconds,
    int lowSignalLimit = defaultLowSignalLimit,
    int throughputWindowMinutes = defaultThroughputWindowMinutes,
    int throughputMaxSteps = defaultThroughputMaxSteps,
    int throughputMaxRejects = defaultThroughputMaxRejects,
    int throughputMaxHighRetries = defaultThroughputMaxHighRetries,
  }) async {
    final resolvedProfile = AutopilotSupervisorProfile.parse(profile);
    final normalizedReason = _normalizeToken(startReason, fallback: 'manual');
    final normalizedPrompt = prompt?.trim().isNotEmpty == true
        ? prompt!.trim()
        : _defaultPrompt();

    _stateRepairService.repair(projectRoot);
    _cleanupStaleSupervisorState(projectRoot);
    final existing = getStatus(projectRoot);
    if (existing.running) {
      throw StateError(
        'Autopilot supervisor already running (pid=${existing.workerPid ?? 'unknown'}).',
      );
    }

    final preflight = _preflightService.check(
      projectRoot,
      requirePushReadiness: true,
    );
    if (!preflight.ok) {
      final normalized = FailureReasonMapper.normalize(
        errorClass: preflight.errorClass,
        errorKind: preflight.errorKind,
        message: preflight.message,
        event: 'preflight_failed',
      );
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_start_blocked',
        message: 'Supervisor start blocked by preflight',
        data: {
          'error_class': normalized.errorClass,
          'error_kind': normalized.errorKind,
          'error': preflight.message,
          'reason': preflight.reason ?? '',
        },
      );
      throw StateError(preflight.message);
    }

    final now = _now();
    final sessionId = _buildSessionId(now);
    final resumeAction = _resumePolicy.peekResumeAction(_readState(projectRoot));

    _updateState(projectRoot, (state) {
      final nowIso = now.toIso8601String();
      return state.copyWith(
        supervisor: state.supervisor.copyWith(
          running: true,
          sessionId: sessionId,
          profile: resolvedProfile.name,
          startReason: normalizedReason,
          startedAt: nowIso,
          restartCount: 0,
          cooldownUntil: null,
          lastHaltReason: null,
          lastExitCode: null,
          lastResumeAction: resumeAction,
          lowSignalStreak: 0,
          throughputWindowStartedAt: nowIso,
          throughputSteps: 0,
          throughputRejects: 0,
          throughputHighRetries: 0,
        ),
      );
    });

    final pid = await _spawnWorker(
      projectRoot,
      sessionId: sessionId,
      profile: resolvedProfile.name,
      prompt: normalizedPrompt,
      startReason: normalizedReason,
      maxRestarts: _clampPositive(maxRestarts, fallback: defaultMaxRestarts),
      restartBackoffBaseSeconds: _clampPositive(
        restartBackoffBaseSeconds,
        fallback: defaultRestartBackoffBaseSeconds,
      ),
      restartBackoffMaxSeconds: _clampPositive(
        restartBackoffMaxSeconds,
        fallback: defaultRestartBackoffMaxSeconds,
      ),
      lowSignalLimit: _clampPositive(
        lowSignalLimit,
        fallback: defaultLowSignalLimit,
      ),
      throughputWindowMinutes: _clampPositive(
        throughputWindowMinutes,
        fallback: defaultThroughputWindowMinutes,
      ),
      throughputMaxSteps: _clampPositive(
        throughputMaxSteps,
        fallback: defaultThroughputMaxSteps,
      ),
      throughputMaxRejects: _clampPositive(
        throughputMaxRejects,
        fallback: defaultThroughputMaxRejects,
      ),
      throughputMaxHighRetries: _clampPositive(
        throughputMaxHighRetries,
        fallback: defaultThroughputMaxHighRetries,
      ),
    );

    _updateState(projectRoot, (state) {
      return state.copyWith(
        supervisor: state.supervisor.copyWith(pid: pid),
      );
    });

    _appendRunLog(
      projectRoot,
      event: 'autopilot_supervisor_start',
      message: 'Autopilot supervisor started',
      data: {
        'session_id': sessionId,
        'profile': resolvedProfile.name,
        'start_reason': normalizedReason,
        'resume_action': resumeAction,
        'supervisor_pid': pid,
      },
    );

    return AutopilotSupervisorStartResult(
      started: true,
      sessionId: sessionId,
      profile: resolvedProfile.name,
      pid: pid,
      resumeAction: resumeAction,
    );
  }

  Future<AutopilotSupervisorStopResult> stop(
    String projectRoot, {
    String reason = 'manual_stop',
  }) async {
    final status = getStatus(projectRoot);
    final normalizedReason = _normalizeToken(reason, fallback: 'manual_stop');
    _writeSupervisorStopSignal(projectRoot);

    try {
      await _runService.stop(projectRoot);
    } catch (_) {
      // Best-effort: worker might not currently run a segment.
    }

    final pid = status.workerPid;
    if (pid != null && _pidLivenessService.isProcessAlive(pid)) {
      _pidLivenessService.terminateProcess(pid);
    }

    _updateState(projectRoot, (state) {
      return state.copyWith(
        supervisor: state.supervisor.copyWith(
          running: false,
          pid: null,
          cooldownUntil: null,
          lastHaltReason: normalizedReason,
        ),
      );
    });

    _appendRunLog(
      projectRoot,
      event: 'autopilot_supervisor_stop',
      message: 'Autopilot supervisor stopped',
      data: {
        'was_running': status.running,
        'reason': normalizedReason,
        'session_id': status.sessionId ?? '',
        'supervisor_pid': pid,
      },
    );

    return AutopilotSupervisorStopResult(
      stopped: true,
      wasRunning: status.running,
      reason: normalizedReason,
    );
  }

  Future<AutopilotSupervisorStartResult> restart(
    String projectRoot, {
    String profile = 'overnight',
    String? prompt,
    String startReason = 'manual_restart',
    int maxRestarts = defaultMaxRestarts,
    int restartBackoffBaseSeconds = defaultRestartBackoffBaseSeconds,
    int restartBackoffMaxSeconds = defaultRestartBackoffMaxSeconds,
    int lowSignalLimit = defaultLowSignalLimit,
    int throughputWindowMinutes = defaultThroughputWindowMinutes,
    int throughputMaxSteps = defaultThroughputMaxSteps,
    int throughputMaxRejects = defaultThroughputMaxRejects,
    int throughputMaxHighRetries = defaultThroughputMaxHighRetries,
  }) async {
    await stop(projectRoot, reason: 'restart_requested');
    return start(
      projectRoot,
      profile: profile,
      prompt: prompt,
      startReason: startReason,
      maxRestarts: maxRestarts,
      restartBackoffBaseSeconds: restartBackoffBaseSeconds,
      restartBackoffMaxSeconds: restartBackoffMaxSeconds,
      lowSignalLimit: lowSignalLimit,
      throughputWindowMinutes: throughputWindowMinutes,
      throughputMaxSteps: throughputMaxSteps,
      throughputMaxRejects: throughputMaxRejects,
      throughputMaxHighRetries: throughputMaxHighRetries,
    );
  }

  AutopilotSupervisorStatus getStatus(String projectRoot) {
    _cleanupStaleSupervisorState(projectRoot);
    final state = _readState(projectRoot);
    final runStatus = _runService.getStatus(projectRoot);
    final running =
        state.supervisorRunning &&
        state.supervisorPid != null &&
        _pidLivenessService.isProcessAlive(state.supervisorPid!);
    return AutopilotSupervisorStatus(
      running: running,
      workerPid: state.supervisorPid,
      sessionId: state.supervisorSessionId,
      profile: state.supervisorProfile,
      startReason: state.supervisorStartReason,
      restartCount: state.supervisorRestartCount,
      cooldownUntil: state.supervisorCooldownUntil,
      lastHaltReason: state.supervisorLastHaltReason,
      lastResumeAction: state.supervisorLastResumeAction,
      lastExitCode: state.supervisorLastExitCode,
      lowSignalStreak: state.supervisorLowSignalStreak,
      throughputWindowStartedAt: state.supervisorThroughputWindowStartedAt,
      throughputSteps: state.supervisorThroughputSteps,
      throughputRejects: state.supervisorThroughputRejects,
      throughputHighRetries: state.supervisorThroughputHighRetries,
      startedAt: state.supervisorStartedAt,
      autopilotRunning: runStatus.isRunning,
      autopilotPid: runStatus.pid,
      autopilotLastLoopAt: runStatus.lastLoopAt,
      autopilotConsecutiveFailures: runStatus.consecutiveFailures,
      autopilotLastError: runStatus.lastError,
    );
  }

  Future<void> runWorker(
    String projectRoot, {
    required String sessionId,
    required String profile,
    required String prompt,
    required String startReason,
    required int maxRestarts,
    required int restartBackoffBaseSeconds,
    required int restartBackoffMaxSeconds,
    required int lowSignalLimit,
    required int throughputWindowMinutes,
    required int throughputMaxSteps,
    required int throughputMaxRejects,
    required int throughputMaxHighRetries,
  }) async {
    final resolvedProfile = AutopilotSupervisorProfile.parse(profile);
    final config = ProjectConfig.load(projectRoot);
    final checkInterval = config.supervisorCheckInterval;
    final maxInterventionsPerHour = config.supervisorMaxInterventionsPerHour;
    final interventionTimestamps = <DateTime>[];
    final restartBudget = _clampPositive(
      maxRestarts,
      fallback: defaultMaxRestarts,
    );
    final baseBackoff = _clampPositive(
      restartBackoffBaseSeconds,
      fallback: defaultRestartBackoffBaseSeconds,
    );
    final maxBackoff = _clampPositive(
      restartBackoffMaxSeconds,
      fallback: defaultRestartBackoffMaxSeconds,
    );
    final watchdogLimit = _clampPositive(
      lowSignalLimit,
      fallback: defaultLowSignalLimit,
    );
    final throughputWindow = Duration(
      minutes: _clampPositive(
        throughputWindowMinutes,
        fallback: defaultThroughputWindowMinutes,
      ),
    );
    final throughputStepLimit = _clampPositive(
      throughputMaxSteps,
      fallback: defaultThroughputMaxSteps,
    );
    final throughputRejectLimit = _clampPositive(
      throughputMaxRejects,
      fallback: defaultThroughputMaxRejects,
    );
    final throughputHighRetryLimit = _clampPositive(
      throughputMaxHighRetries,
      fallback: defaultThroughputMaxHighRetries,
    );

    final lock = _acquireSupervisorLock(projectRoot);
    if (lock == null) {
      return;
    }

    var restartCount = 0;
    var lowSignalStreak = 0;
    var healAttempted = false;
    var segmentsCompleted = 0;
    var degradedMode = false;
    String? haltReason;
    int? lastExitCode;
    final workerStartedAt = _now();

    _clearSupervisorStopSignal(projectRoot);
    _updateState(projectRoot, (state) {
      return state.copyWith(
        supervisor: state.supervisor.copyWith(
          running: true,
          sessionId: sessionId,
          profile: resolvedProfile.name,
          startReason: _normalizeToken(startReason, fallback: 'worker'),
          pid: pid,
          startedAt: _now().toIso8601String(),
        ),
      );
    });
    _appendRunLog(
      projectRoot,
      event: 'autopilot_supervisor_worker_start',
      message: 'Autopilot supervisor worker started',
      data: {
        'session_id': sessionId,
        'profile': resolvedProfile.name,
        'start_reason': startReason,
        'restart_budget': restartBudget,
      },
    );

    try {
      while (true) {
        if (_supervisorStopRequested(projectRoot)) {
          haltReason = 'stop_requested';
          break;
        }

        // Write heartbeat for external watchdog / systemd monitoring.
        _healthReporter.writeHeartbeat(projectRoot, now: _now());

        final preflight = _preflightService.check(
          projectRoot,
          requirePushReadiness: true,
        );
        if (!preflight.ok) {
          final backoff = _restartBackoff(
            restartCount: restartCount + 1,
            baseSeconds: baseBackoff,
            maxSeconds: maxBackoff,
          );
          final reason = FailureReasonMapper.normalize(
            errorClass: preflight.errorClass,
            errorKind: preflight.errorKind,
            message: preflight.message,
            event: 'preflight_failed',
          );
          _appendRunLog(
            projectRoot,
            event: 'autopilot_supervisor_preflight_failed',
            message: 'Supervisor preflight failed before segment start',
            data: {
              'session_id': sessionId,
              'error_class': reason.errorClass,
              'error_kind': reason.errorKind,
              'error': preflight.message,
              'restart_count': restartCount,
              'backoff_seconds': backoff.inSeconds,
            },
          );
          if (restartCount >= restartBudget) {
            haltReason = 'preflight_restart_budget_exhausted';
            break;
          }
          restartCount += 1;
          interventionTimestamps.add(_now());
          if (_interventionsExceedHourlyLimit(
            interventionTimestamps,
            limit: maxInterventionsPerHour,
          )) {
            haltReason = 'interventions_per_hour_exceeded';
            _appendRunLog(
              projectRoot,
              event: 'autopilot_supervisor_halt',
              message:
                  'Supervisor halted: interventions per hour limit reached',
              data: {
                'session_id': sessionId,
                'halt_reason': 'interventions_per_hour_exceeded',
                'limit': maxInterventionsPerHour,
                'interventions_in_window': interventionTimestamps.length,
              },
            );
            break;
          }
          _updateRestartState(
            projectRoot,
            restartCount: restartCount,
            cooldown: backoff,
            haltReason: 'preflight_failed',
          );
          await _sleep(backoff);
          continue;
        }

        try {
          final resumeAction = await _resumePolicy.apply(
            projectRoot,
            state: _readState(projectRoot),
            sessionId: sessionId,
          );
          _updateState(projectRoot, (state) {
            return state.copyWith(
              supervisor: state.supervisor.copyWith(
                lastResumeAction: resumeAction,
              ),
            );
          });

          final telemetryBefore = _telemetryService.load(projectRoot);
          final retry2PlusBefore =
              telemetryBefore.healthSummary.retryDistribution.retry2Plus;
          // In degraded mode, double sleep intervals to reduce burn rate.
          final effectiveStepSleep = degradedMode
              ? resolvedProfile.stepSleep * 2
              : resolvedProfile.stepSleep;
          final effectiveIdleSleep = degradedMode
              ? resolvedProfile.idleSleep * 2
              : resolvedProfile.idleSleep;
          final runResult = await _runService.run(
            projectRoot,
            codingPrompt: prompt,
            maxSteps: resolvedProfile.segmentMaxSteps,
            stopWhenIdle: resolvedProfile.stopWhenIdle,
            stepSleep: effectiveStepSleep,
            idleSleep: effectiveIdleSleep,
            unattendedMode: true,
          );
          lastExitCode = 0;

          final telemetryAfter = _telemetryService.load(projectRoot);
          final retry2PlusAfter =
              telemetryAfter.healthSummary.retryDistribution.retry2Plus;
          final currentState = _readState(projectRoot);
          final throughput = _throughputGuard.rollWindow(
            currentState: currentState.supervisor,
            runResult: runResult,
            window: throughputWindow,
            stepLimit: throughputStepLimit,
            rejectLimit: throughputRejectLimit,
            highRetryLimit: throughputHighRetryLimit,
            retry2PlusBefore: retry2PlusBefore,
            retry2PlusAfter: retry2PlusAfter,
            now: _now(),
          );
          _updateState(projectRoot, (state) {
            return state.copyWith(
              supervisor: state.supervisor.copyWith(
                throughputWindowStartedAt: throughput.windowStartedAt,
                throughputSteps: throughput.steps,
                throughputRejects: throughput.rejects,
                throughputHighRetries: throughput.highRetries,
              ),
            );
          });
          if (throughput.halted) {
            haltReason = throughput.haltReason;
            _appendRunLog(
              projectRoot,
              event: 'autopilot_supervisor_halt',
              message: 'Supervisor halted by throughput guardrail',
              data: {
                'session_id': sessionId,
                'halt_reason': haltReason,
                'throughput_steps': throughput.steps,
                'throughput_rejects': throughput.rejects,
                'throughput_high_retries': throughput.highRetries,
                'window_started_at': throughput.windowStartedAt,
              },
            );
            break;
          }

          // Degraded mode escalation / recovery based on failure rate.
          final degradedResult = _throughputGuard.evaluateDegradedMode(
            throughput: throughput,
            currentDegradedMode: degradedMode,
          );
          if (degradedResult.changed) {
            final rate = degradedResult.failureRate ?? 0.0;
            _appendRunLog(
              projectRoot,
              event: degradedResult.degradedMode
                  ? 'autopilot_degraded_mode_entered'
                  : 'autopilot_degraded_mode_exited',
              message: degradedResult.degradedMode
                  ? 'Degraded mode activated: failure rate ${(rate * 100).toStringAsFixed(1)}% exceeds ${(SupervisorThroughputGuard.degradedModeEntryThreshold * 100).toStringAsFixed(0)}% threshold'
                  : 'Degraded mode deactivated: failure rate ${(rate * 100).toStringAsFixed(1)}% below ${(SupervisorThroughputGuard.degradedModeExitThreshold * 100).toStringAsFixed(0)}% recovery threshold',
              data: {
                'session_id': sessionId,
                'failure_rate': rate,
                'throughput_steps': throughput.steps,
                'throughput_rejects': throughput.rejects,
              },
            );
          }
          degradedMode = degradedResult.degradedMode;

          final lowSignal = _throughputGuard.isLowSignalSegment(runResult);
          if (lowSignal) {
            lowSignalStreak += 1;
          } else {
            lowSignalStreak = 0;
            healAttempted = false;
          }
          _updateState(projectRoot, (state) {
            return state.copyWith(
              supervisor: state.supervisor.copyWith(
                lowSignalStreak: lowSignalStreak,
              ),
            );
          });

          if (lowSignalStreak >= watchdogLimit) {
            if (!healAttempted) {
              // Auto-heal: repair state + attempt one more segment before halt.
              healAttempted = true;
              _appendRunLog(
                projectRoot,
                event: 'autopilot_supervisor_auto_heal',
                message: 'Attempting auto-heal before watchdog halt',
                data: {
                  'session_id': sessionId,
                  'low_signal_streak': lowSignalStreak,
                  'watchdog_limit': watchdogLimit,
                },
              );
              try {
                _stateRepairService.repair(projectRoot);
              } catch (e) {
                _appendRunLog(
                  projectRoot,
                  event: 'auto_heal_repair_failed',
                  message: 'State repair during auto-heal failed: $e',
                  data: {
                    'session_id': sessionId,
                    'error_class': 'state',
                    'error_kind': 'auto_heal_repair_failed',
                  },
                );
              }
              // Reset streak to give the heal segment a fair shot.
              lowSignalStreak = watchdogLimit - 1;
              _updateState(projectRoot, (state) {
                return state.copyWith(
                  supervisor: state.supervisor.copyWith(
                    lowSignalStreak: lowSignalStreak,
                  ),
                );
              });
              continue;
            }
            haltReason = 'progress_watchdog';
            _appendRunLog(
              projectRoot,
              event: 'autopilot_supervisor_halt',
              message:
                  'Supervisor halted by low-signal watchdog after auto-heal',
              data: {
                'session_id': sessionId,
                'halt_reason': haltReason,
                'low_signal_streak': lowSignalStreak,
                'watchdog_limit': watchdogLimit,
                'heal_attempted': true,
              },
            );
            _reflectOnHalt(
              projectRoot,
              haltReason: haltReason,
              sessionId: sessionId,
            );
            break;
          }

          if (_supervisorStopRequested(projectRoot)) {
            haltReason = 'stop_requested';
            break;
          }
          if (runResult.stoppedBySafetyHalt) {
            haltReason = 'run_safety_halt';
            _reflectOnHalt(
              projectRoot,
              haltReason: haltReason,
              sessionId: sessionId,
            );
            break;
          }

          if (checkInterval.inMicroseconds > 0) {
            await _sleep(checkInterval);
          }
          segmentsCompleted += 1;
          restartCount = 0;
          _updateState(projectRoot, (state) {
            return state.copyWith(
              supervisor: state.supervisor.copyWith(
                restartCount: 0,
                cooldownUntil: null,
              ),
            );
          });

          // Export health summary for external monitoring after each segment.
          _healthReporter.exportHealthSummary(
            projectRoot,
            sessionId: sessionId,
            profile: resolvedProfile.name,
            pid: pid,
            startedAt: workerStartedAt,
            totalSteps: segmentsCompleted,
            consecutiveFailures: 0,
            lastHaltReason: null,
            status: degradedMode ? 'degraded' : 'running',
          );
        } catch (error) {
          final normalized = FailureReasonMapper.normalize(
            message: error.toString(),
            event: 'autopilot_supervisor_segment_error',
          );
          lastExitCode = 1;
          if (restartCount >= restartBudget) {
            haltReason = 'restart_budget_exhausted';
            _appendRunLog(
              projectRoot,
              event: 'autopilot_supervisor_halt',
              message: 'Supervisor restart budget exhausted',
              data: {
                'session_id': sessionId,
                'halt_reason': haltReason,
                'error_class': normalized.errorClass,
                'error_kind': normalized.errorKind,
                'error': error.toString(),
                'restart_count': restartCount,
                'restart_budget': restartBudget,
              },
            );
            _reflectOnHalt(
              projectRoot,
              haltReason: haltReason,
              sessionId: sessionId,
            );
            break;
          }

          restartCount += 1;
          interventionTimestamps.add(_now());
          if (_interventionsExceedHourlyLimit(
            interventionTimestamps,
            limit: maxInterventionsPerHour,
          )) {
            haltReason = 'interventions_per_hour_exceeded';
            _appendRunLog(
              projectRoot,
              event: 'autopilot_supervisor_halt',
              message:
                  'Supervisor halted: interventions per hour limit reached',
              data: {
                'session_id': sessionId,
                'halt_reason': 'interventions_per_hour_exceeded',
                'limit': maxInterventionsPerHour,
                'interventions_in_window': interventionTimestamps.length,
              },
            );
            break;
          }
          final backoff = _restartBackoff(
            restartCount: restartCount,
            baseSeconds: baseBackoff,
            maxSeconds: maxBackoff,
          );
          _updateRestartState(
            projectRoot,
            restartCount: restartCount,
            cooldown: backoff,
            haltReason: normalized.errorKind,
          );
          _appendRunLog(
            projectRoot,
            event: 'autopilot_supervisor_restart',
            message: 'Supervisor restarting after segment failure',
            data: {
              'session_id': sessionId,
              'restart_count': restartCount,
              'restart_budget': restartBudget,
              'backoff_seconds': backoff.inSeconds,
              'error_class': normalized.errorClass,
              'error_kind': normalized.errorKind,
              'error': error.toString(),
            },
          );
          await _sleep(backoff);
        }
      }
    } finally {
      final normalizedHalt = haltReason == null || haltReason.trim().isEmpty
          ? 'completed'
          : haltReason.trim();
      _updateState(projectRoot, (state) {
        return state.copyWith(
          supervisor: state.supervisor.copyWith(
            running: false,
            pid: null,
            cooldownUntil: null,
            lastHaltReason: normalizedHalt,
            lastExitCode: lastExitCode,
          ),
        );
      });
      // Export final health summary with halted status.
      _healthReporter.exportHealthSummary(
        projectRoot,
        sessionId: sessionId,
        profile: resolvedProfile.name,
        pid: pid,
        startedAt: workerStartedAt,
        totalSteps: segmentsCompleted,
        consecutiveFailures: restartCount,
        lastHaltReason: normalizedHalt,
        status: 'halted',
      );

      // Write structured exit summary for post-mortem analysis.
      _healthReporter.writeExitSummary(
        projectRoot,
        sessionId: sessionId,
        haltReason: normalizedHalt,
        exitCode: lastExitCode,
        restartCount: restartCount,
        segmentsCompleted: segmentsCompleted,
        lowSignalStreak: lowSignalStreak,
        startedAt: workerStartedAt,
        now: _now(),
        supervisorState: _readState(projectRoot).supervisor,
      );

      _clearSupervisorStopSignal(projectRoot);
      lock.release();
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_worker_end',
        message: 'Autopilot supervisor worker stopped',
        data: {
          'session_id': sessionId,
          'halt_reason': normalizedHalt,
          'last_exit_code': lastExitCode,
          'restart_count': restartCount,
          'segments_completed': segmentsCompleted,
        },
      );
    }
  }

  Duration _restartBackoff({
    required int restartCount,
    required int baseSeconds,
    required int maxSeconds,
  }) {
    final exponent = restartCount < 1 ? 0 : (restartCount - 1);
    final multiplied = baseSeconds * (1 << exponent);
    final clamped = multiplied > maxSeconds ? maxSeconds : multiplied;
    return Duration(seconds: clamped);
  }

  void _updateRestartState(
    String projectRoot, {
    required int restartCount,
    required Duration cooldown,
    required String haltReason,
  }) {
    final now = _now();
    final cooldownUntil = now.add(cooldown).toIso8601String();
    _updateState(projectRoot, (state) {
      return state.copyWith(
        supervisor: state.supervisor.copyWith(
          restartCount: restartCount,
          cooldownUntil: cooldownUntil,
          lastHaltReason: haltReason,
        ),
      );
    });
  }

  static Future<int> _defaultSpawnWorker(
    String projectRoot, {
    required String sessionId,
    required String profile,
    required String prompt,
    required String startReason,
    required int maxRestarts,
    required int restartBackoffBaseSeconds,
    required int restartBackoffMaxSeconds,
    required int lowSignalLimit,
    required int throughputWindowMinutes,
    required int throughputMaxSteps,
    required int throughputMaxRejects,
    required int throughputMaxHighRetries,
  }) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        'run',
        '--',
        'bin/genaisys_cli.dart',
        'autopilot',
        'supervisor',
        '_worker',
        projectRoot,
        '--session-id',
        sessionId,
        '--profile',
        profile,
        '--prompt',
        prompt,
        '--reason',
        startReason,
        '--max-restarts',
        '$maxRestarts',
        '--restart-backoff-base',
        '$restartBackoffBaseSeconds',
        '--restart-backoff-max',
        '$restartBackoffMaxSeconds',
        '--low-signal-limit',
        '$lowSignalLimit',
        '--throughput-window-minutes',
        '$throughputWindowMinutes',
        '--throughput-max-steps',
        '$throughputMaxSteps',
        '--throughput-max-rejects',
        '$throughputMaxRejects',
        '--throughput-max-high-retries',
        '$throughputMaxHighRetries',
      ],
      workingDirectory: Directory.current.path,
      mode: ProcessStartMode.detachedWithStdio,
    );
    return process.pid;
  }

  int _clampPositive(int value, {required int fallback}) {
    return value < 1 ? fallback : value;
  }

  /// Returns `true` when the number of interventions within the last hour
  /// exceeds [limit]. Expired entries older than 1 hour are pruned.
  bool _interventionsExceedHourlyLimit(
    List<DateTime> timestamps, {
    required int limit,
  }) {
    final cutoff = _now().subtract(const Duration(hours: 1));
    timestamps.removeWhere((t) => t.isBefore(cutoff));
    return timestamps.length > limit;
  }

  String _defaultPrompt() {
    return 'Advance the roadmap with one minimal, safe, production-grade step.';
  }

  void _reflectOnHalt(
    String projectRoot, {
    required String haltReason,
    required String sessionId,
  }) {
    final config = _loadConfig(projectRoot);
    if (!config.supervisorReflectionOnHalt) return;

    try {
      final result = _reflectionService.reflect(
        projectRoot,
        maxOptimizationTasks: config.reflectionMaxOptimizationTasks,
        optimizationPriority: config.reflectionOptimizationPriority,
      );
      _updateState(projectRoot, (state) {
        return state.copyWith(
          supervisor: state.supervisor.copyWith(
            reflectionCount: state.supervisor.reflectionCount + 1,
            lastReflectionAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      });
      _appendRunLog(
        projectRoot,
        event: 'supervisor_reflection_on_halt',
        message: 'Supervisor triggered productivity reflection on halt',
        data: {
          'session_id': sessionId,
          'halt_reason': haltReason,
          'optimization_tasks_created': result.optimizationTasksCreated,
          'patterns': result.patterns,
          if (result.healthReport != null)
            'health_score': result.healthReport!.overallScore,
        },
      );
    } catch (e) {
      _appendRunLog(
        projectRoot,
        event: 'supervisor_reflection_failed',
        message: 'Supervisor reflection failed: $e',
        data: {'session_id': sessionId, 'halt_reason': haltReason},
      );
    }
  }

  ProjectConfig _loadConfig(String projectRoot) {
    try {
      return ProjectConfig.load(projectRoot);
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'config_load_failed',
        message: 'Failed to load config; falling back to empty defaults',
        data: {
          'error_class': 'config',
          'error_kind': 'config_parse_error',
          'error': error.toString(),
        },
      );
      return ProjectConfig.empty();
    }
  }

  void _appendRunLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: event,
      message: message,
      data: {'root': projectRoot, ...data},
    );
  }

  void _updateState(
    String projectRoot,
    ProjectState Function(ProjectState state) transform,
  ) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    final store = StateStore(layout.statePath);
    final current = store.read();
    store.write(transform(current));
  }

  ProjectState _readState(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    return StateStore(layout.statePath).read();
  }

  void _cleanupStaleSupervisorState(String projectRoot) {
    final state = _readState(projectRoot);
    if (!state.supervisorRunning) {
      return;
    }
    final pidValue = state.supervisorPid;
    final alive = pidValue != null && _pidLivenessService.isProcessAlive(pidValue);
    if (alive) {
      return;
    }
    _updateState(projectRoot, (current) {
      return current.copyWith(
        supervisor: current.supervisor.copyWith(
          running: false,
          pid: null,
          cooldownUntil: null,
          lastHaltReason: 'stale_supervisor_recovered',
        ),
      );
    });
    _appendRunLog(
      projectRoot,
      event: 'autopilot_supervisor_stale_recovered',
      message: 'Recovered stale supervisor state',
      data: {
        'error_class': 'locking',
        'error_kind': 'stale_supervisor',
        'supervisor_pid': pidValue,
      },
    );
  }

  _SupervisorWorkerLock? _acquireSupervisorLock(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.autopilotSupervisorLockPath);
    file.parent.createSync(recursive: true);
    final raf = file.openSync(mode: FileMode.write);
    try {
      raf.lockSync(FileLock.exclusive);
    } on FileSystemException {
      try {
        raf.closeSync();
      } catch (_) {}
      _appendRunLog(
        projectRoot,
        event: 'autopilot_supervisor_worker_skip',
        message: 'Supervisor worker start skipped; lock already held',
        data: {
          'error_class': 'locking',
          'error_kind': 'supervisor_lock_held',
          'lock_file': file.path,
        },
      );
      return null;
    }
    final nowIso = _now().toIso8601String();
    raf.writeStringSync('version=1\nstarted_at=$nowIso\npid=$pid\n');
    raf.flushSync();
    return _SupervisorWorkerLock(file: file, raf: raf);
  }

  bool _supervisorStopRequested(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    return File(layout.autopilotSupervisorStopPath).existsSync();
  }

  void _writeSupervisorStopSignal(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.autopilotSupervisorStopPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_now().toIso8601String(), flush: true);
  }

  void _clearSupervisorStopSignal(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.autopilotSupervisorStopPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  String _buildSessionId(DateTime now) {
    final safe = now.toIso8601String().replaceAll(':', '').replaceAll('.', '');
    return 'supervisor-$safe';
  }

  String _normalizeToken(String value, {required String fallback}) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

}

class _SupervisorWorkerLock {
  _SupervisorWorkerLock({required this.file, required this.raf});

  final File file;
  final RandomAccessFile raf;

  void release() {
    try {
      raf.unlockSync();
    } catch (_) {}
    try {
      raf.closeSync();
    } catch (_) {}
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}
