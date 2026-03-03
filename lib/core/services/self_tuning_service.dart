// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

import '../config/project_config.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'config_service.dart';

class SelfTuneResult {
  SelfTuneResult({
    required this.applied,
    required this.reason,
    required this.successRate,
    required this.samples,
    required this.before,
    required this.after,
  });

  final bool applied;
  final String reason;
  final double successRate;
  final int samples;
  final Map<String, int> before;
  final Map<String, int> after;
}

class SelfTuningService {
  static const int _minAutopilotRetries = 3;
  static const int _maxAutopilotRetries = 10;

  SelfTuningService({ConfigService? configService})
    : _configService = configService ?? ConfigService();

  final ConfigService _configService;

  SelfTuneResult tune(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final config = ProjectConfig.load(projectRoot);
    if (!config.autopilotSelfTuneEnabled) {
      return _result(
        applied: false,
        reason: 'disabled',
        successRate: 0.0,
        samples: 0,
        before: _snapshot(config),
        after: _snapshot(config),
      );
    }

    final window = config.autopilotSelfTuneWindow < 1
        ? 1
        : config.autopilotSelfTuneWindow;
    final minSamples = config.autopilotSelfTuneMinSamples < 1
        ? 1
        : config.autopilotSelfTuneMinSamples;
    if (minSamples > window) {
      return _result(
        applied: false,
        reason: 'min_samples_gt_window',
        successRate: 0.0,
        samples: 0,
        before: _snapshot(config),
        after: _snapshot(config),
      );
    }

    final outcomes = _collectOutcomes(layout.runLogPath, window);
    final total = outcomes.successes + outcomes.failures;
    if (total < minSamples) {
      return _result(
        applied: false,
        reason: 'insufficient_samples',
        successRate: total == 0 ? 0.0 : (outcomes.successes / total) * 100.0,
        samples: total,
        before: _snapshot(config),
        after: _snapshot(config),
      );
    }

    final successRate = (outcomes.successes / total) * 100.0;
    final target = config.autopilotSelfTuneSuccessPercent;

    final before = _snapshot(config);
    var updatedStepSleep = config.autopilotStepSleep.inSeconds;
    var updatedIdleSleep = config.autopilotIdleSleep.inSeconds;
    var updatedMaxPlanAdd = config.autopilotMaxPlanAdd;
    var updatedMaxRetries = config.autopilotMaxTaskRetries;

    String reason = 'no_change';

    if (successRate < target) {
      updatedStepSleep = _clamp(updatedStepSleep + 2, 0, 30);
      updatedIdleSleep = _clamp(updatedIdleSleep + 10, 0, 120);
      updatedMaxPlanAdd = _clamp(updatedMaxPlanAdd - 1, 1, 10);
      updatedMaxRetries = _clamp(
        updatedMaxRetries + 1,
        _minAutopilotRetries,
        _maxAutopilotRetries,
      );
      reason = 'below_target';
    } else if (successRate >= target + 10) {
      updatedStepSleep = _clamp(updatedStepSleep - 1, 0, 30);
      updatedIdleSleep = _clamp(updatedIdleSleep - 5, 0, 120);
      updatedMaxPlanAdd = _clamp(updatedMaxPlanAdd + 1, 1, 10);
      updatedMaxRetries = _clamp(
        updatedMaxRetries - 1,
        _minAutopilotRetries,
        _maxAutopilotRetries,
      );
      reason = 'above_target';
    }

    final after = {
      'step_sleep_seconds': updatedStepSleep,
      'idle_sleep_seconds': updatedIdleSleep,
      'max_plan_add': updatedMaxPlanAdd,
      'max_task_retries': updatedMaxRetries,
    };

    // Compute reasoning effort adjustment in the same pass.
    final effortResult = _computeReasoningEffortChange(
      config,
      successRate: successRate,
      samples: total,
    );

    final changed = !_mapsEqual(before, after);
    final effortChanged = effortResult != null;

    if (changed || effortChanged) {
      _configService.update(
        projectRoot,
        update: ConfigUpdate(
          autopilotStepSleepSeconds: updatedStepSleep,
          autopilotIdleSleepSeconds: updatedIdleSleep,
          autopilotMaxPlanAdd: updatedMaxPlanAdd,
          autopilotMaxTaskRetries: updatedMaxRetries,
          reasoningEffortByCategory: effortResult?.updatedMap,
        ),
      );
      if (changed) {
        RunLogStore(layout.runLogPath).append(
          event: 'self_tune_applied',
          message: 'Self-tune adjusted autopilot settings',
          data: {
            'root': projectRoot,
            'success_rate': successRate,
            'samples': total,
            'reason': reason,
            'before': before,
            'after': after,
          },
        );
      }
      if (effortChanged) {
        RunLogStore(layout.runLogPath).append(
          event: 'self_tune_reasoning_effort',
          message: 'Adjusted default reasoning effort',
          data: {
            'root': projectRoot,
            'success_rate': successRate,
            'samples': total,
            'before': effortResult.beforeDefault,
            'after': effortResult.afterDefault,
          },
        );
      }
    } else {
      RunLogStore(layout.runLogPath).append(
        event: 'self_tune_skipped',
        message: 'Self-tune made no changes',
        data: {
          'root': projectRoot,
          'success_rate': successRate,
          'samples': total,
          'reason': reason,
        },
      );
    }

    return _result(
      applied: changed || effortChanged,
      reason: reason,
      successRate: successRate,
      samples: total,
      before: before,
      after: after,
    );
  }

  /// Computes reasoning effort adjustment without persisting.
  ///
  /// - >90% success → lower the default effort one step (save tokens).
  /// - <50% success → raise the default effort one step (improve quality).
  ///
  /// Returns `null` if no change is needed.
  _EffortChange? _computeReasoningEffortChange(
    ProjectConfig config, {
    required double successRate,
    required int samples,
  }) {
    final minSamples = config.autopilotSelfTuneMinSamples < 1
        ? 1
        : config.autopilotSelfTuneMinSamples;
    if (samples < minSamples) {
      return null;
    }

    final currentMap = Map<String, String>.from(
      config.reasoningEffortByCategory,
    );
    final currentDefault = currentMap['default'] ?? 'medium';

    String? newDefault;
    if (successRate > 90.0 && currentDefault != 'low') {
      newDefault = _lowerEffort(currentDefault);
    } else if (successRate < 50.0 && currentDefault != 'high') {
      newDefault = _raiseEffort(currentDefault);
    }

    if (newDefault == null || newDefault == currentDefault) {
      return null;
    }

    final updatedMap = Map<String, String>.from(currentMap);
    updatedMap['default'] = newDefault;

    return _EffortChange(
      beforeDefault: currentDefault,
      afterDefault: newDefault,
      updatedMap: updatedMap,
    );
  }

  static String _lowerEffort(String current) {
    switch (current) {
      case 'high':
        return 'medium';
      case 'medium':
        return 'low';
      default:
        return current;
    }
  }

  static String _raiseEffort(String current) {
    switch (current) {
      case 'low':
        return 'medium';
      case 'medium':
        return 'high';
      default:
        return current;
    }
  }

  _OutcomeSummary _collectOutcomes(String path, int window) {
    // Use windowed tail-read to avoid loading the entire run-log file.
    // We request a generous window of lines; the inner loop still stops
    // after collecting `window` outcome events.
    final lines = RunLogStore.readTailLines(path, maxLines: window * 5);
    if (lines.isEmpty) {
      return const _OutcomeSummary();
    }

    var successes = 0;
    var failures = 0;
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      final decoded = _decode(line);
      if (decoded == null) {
        continue;
      }
      final event = decoded['event']?.toString() ?? '';
      if (event.isEmpty) {
        continue;
      }
      if (event == 'orchestrator_run_step') {
        final data = decoded['data'];
        final idle = data is Map && data['idle'] == true;
        if (!idle) {
          successes += 1;
        }
      } else if (_isFailureEvent(event)) {
        failures += 1;
      } else {
        continue;
      }
      if (successes + failures >= window) {
        break;
      }
    }

    return _OutcomeSummary(successes: successes, failures: failures);
  }

  bool _isFailureEvent(String event) {
    return event == 'orchestrator_run_error' ||
        event == 'orchestrator_run_transient_error' ||
        event == 'orchestrator_run_permanent_error' ||
        event == 'orchestrator_run_stuck' ||
        event == 'orchestrator_run_safety_halt';
  }

  Map<String, Object?>? _decode(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, Object?>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _snapshot(ProjectConfig config) {
    return {
      'step_sleep_seconds': config.autopilotStepSleep.inSeconds,
      'idle_sleep_seconds': config.autopilotIdleSleep.inSeconds,
      'max_plan_add': config.autopilotMaxPlanAdd,
      'max_task_retries': config.autopilotMaxTaskRetries,
    };
  }

  bool _mapsEqual(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  SelfTuneResult _result({
    required bool applied,
    required String reason,
    required double successRate,
    required int samples,
    required Map<String, int> before,
    required Map<String, int> after,
  }) {
    return SelfTuneResult(
      applied: applied,
      reason: reason,
      successRate: successRate,
      samples: samples,
      before: before,
      after: after,
    );
  }
}

class _EffortChange {
  const _EffortChange({
    required this.beforeDefault,
    required this.afterDefault,
    required this.updatedMap,
  });

  final String beforeDefault;
  final String afterDefault;
  final Map<String, String> updatedMap;
}

class _OutcomeSummary {
  const _OutcomeSummary({this.successes = 0, this.failures = 0});

  final int successes;
  final int failures;
}

int _clamp(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
