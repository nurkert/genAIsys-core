// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';
import 'background_api_runner.dart';

/// Manages autopilot status polling, live sync, and step/stop commands.
///
/// Extracted from [ProjectWorkspaceController] to isolate autopilot
/// state changes so they don't trigger rebuilds in unrelated views.
class AutopilotController {
  AutopilotController({
    required String projectRootPath,
    AutopilotStatusUseCase? autopilotStatusUseCase,
    AutopilotStopUseCase? autopilotStopUseCase,
    AutopilotStepUseCase? autopilotStepUseCase,
    Duration pollIntervalRunning = _defaultPollIntervalRunning,
    Duration pollIntervalIdle = _defaultPollIntervalIdle,
  }) : _projectRootPath = projectRootPath,
       _statusUseCase = autopilotStatusUseCase ?? AutopilotStatusUseCase(),
       _stopUseCase = autopilotStopUseCase ?? AutopilotStopUseCase(),
       _stepUseCase = autopilotStepUseCase ?? AutopilotStepUseCase(),
       _useIsolate = autopilotStatusUseCase == null,
       _pollIntervalRunning = pollIntervalRunning,
       _pollIntervalIdle = pollIntervalIdle;

  static const String _defaultPrompt =
      'Continue the active subtask in small safe steps. Keep tests and '
      'review gates green.';
  static const Duration _defaultPollIntervalRunning = Duration(seconds: 1);
  static const Duration _defaultPollIntervalIdle = Duration(seconds: 5);
  static const int _maxPollJitterMs = 500;

  final String _projectRootPath;
  final AutopilotStatusUseCase _statusUseCase;
  final AutopilotStopUseCase _stopUseCase;
  final AutopilotStepUseCase _stepUseCase;
  final bool _useIsolate;
  final Duration _pollIntervalRunning;
  final Duration _pollIntervalIdle;
  final Random _jitterRandom = Random();

  bool _pollingInProgress = false;
  bool _paused = false;
  int _pollingSubscribers = 0;
  Timer? _pollingTimer;
  bool _disposed = false;

  AutopilotStatusDto? _status;

  /// Fires only when autopilot status changes.
  final ValueNotifier<AutopilotStatusDto?> statusNotifier =
      ValueNotifier<AutopilotStatusDto?>(null);

  AutopilotStatusDto? get status => _status;
  bool get isRunning => _status?.autopilotRunning ?? false;

  /// Applies a pre-fetched status (e.g. from an isolate) without hitting the API.
  void applyStatus(AutopilotStatusDto status) {
    _status = status;
    statusNotifier.value = status;
  }

  /// Refreshes autopilot status once. Returns an error string on failure.
  ///
  /// In production, runs the status load in a background isolate because
  /// [AutopilotStatusUseCase.load] calls [HealthCheckService.check] which
  /// spawns 3 synchronous git sub-processes (Process.runSync) that would
  /// otherwise block the UI thread for 300-700ms.
  ///
  /// When a custom [AutopilotStatusUseCase] was injected (tests), calls it
  /// directly to honour mock overrides.
  Future<String?> refreshStatus({
    required bool Function() isActionInProgress,
  }) async {
    if (_disposed || _pollingInProgress || _projectRootPath.isEmpty) {
      return null;
    }
    _pollingInProgress = true;
    try {
      if (_useIsolate) {
        return _refreshStatusViaIsolate();
      }
      return _refreshStatusDirect();
    } finally {
      _pollingInProgress = false;
    }
  }

  /// Runs the status load in a background [Isolate].
  Future<String?> _refreshStatusViaIsolate() async {
    final AutopilotStatusRefreshResult result =
        await runAutopilotStatusInBackground(projectRootPath: _projectRootPath);
    if (result.status != null) {
      _status = result.status;
      statusNotifier.value = result.status;
      return null;
    }
    return result.error;
  }

  /// Runs the status load directly on the main thread (test path).
  Future<String?> _refreshStatusDirect() async {
    final AppResult<AutopilotStatusDto> result = await _statusUseCase.load(
      _projectRootPath,
    );
    if (result.ok && result.data != null) {
      _status = result.data;
      statusNotifier.value = result.data;
      return null;
    }
    return result.error?.message ?? 'Unknown autopilot status error.';
  }

  /// Pauses live-sync polling without altering the subscriber count.
  ///
  /// Call this when the window loses focus to prevent background isolate
  /// spawning that would starve the main thread on focus regain.
  void pausePolling() {
    if (_paused) {
      return;
    }
    _paused = true;
    _cancelPollTimer();
  }

  /// Resumes live-sync polling after a [pausePolling] call.
  ///
  /// If there are active subscribers, polling is rescheduled immediately
  /// so the UI catches up after window focus returns.
  void resumePolling() {
    if (!_paused) {
      return;
    }
    _paused = false;
    if (_pollingSubscribers > 0) {
      _scheduleNextPoll(immediate: true);
    }
  }

  /// Starts live polling. Multiple callers are reference-counted.
  void attachLiveSync() {
    if (_disposed) {
      return;
    }
    _pollingSubscribers += 1;
    if (_pollingSubscribers > 1) {
      return;
    }
    _scheduleNextPoll(immediate: true);
  }

  /// Stops live polling when all subscribers have detached.
  void detachLiveSync() {
    if (_disposed) {
      return;
    }
    if (_pollingSubscribers == 0) {
      return;
    }
    _pollingSubscribers -= 1;
    if (_pollingSubscribers > 0) {
      return;
    }
    _cancelPollTimer();
  }

  /// Runs a single autopilot step.
  Future<AppResult<AutopilotStepDto>> runStep({String? prompt}) {
    final String effectivePrompt = (prompt ?? _defaultPrompt).trim();
    return _stepUseCase.run(_projectRootPath, prompt: effectivePrompt);
  }

  /// Stops the autopilot.
  Future<AppResult<AutopilotStopDto>> stop() {
    return _stopUseCase.run(_projectRootPath);
  }

  Duration _nextPollInterval() {
    final Duration base = isRunning ? _pollIntervalRunning : _pollIntervalIdle;
    // Add random jitter (up to 10% of base interval, capped at 500ms) to
    // avoid timer alignment with the dashboard poll.
    final int maxJitterMs = (base.inMilliseconds * 0.1).round().clamp(
      0,
      _maxPollJitterMs,
    );
    if (maxJitterMs <= 0) {
      return base;
    }
    final Duration jitter = Duration(
      milliseconds: _jitterRandom.nextInt(maxJitterMs),
    );
    return base + jitter;
  }

  void _scheduleNextPoll({bool immediate = false}) {
    if (_disposed || _paused || _pollingSubscribers <= 0) {
      return;
    }
    _cancelPollTimer();
    _pollingTimer = Timer(
      immediate ? Duration.zero : _nextPollInterval(),
      () async {
        if (_disposed) {
          return;
        }
        await refreshStatus(isActionInProgress: () => false);
        if (_disposed) {
          return;
        }
        _scheduleNextPoll();
      },
    );
  }

  void _cancelPollTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pollingSubscribers = 0;
    _cancelPollTimer();
    statusNotifier.dispose();
  }
}
