// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'in_process_genaisys_api.dart';

extension _InProcessGenaisysApiMappingHelpers on InProcessGenaisysApi {
  AppTaskDto _toTaskDto(Task task) {
    final status = task.blocked
        ? AppTaskStatus.blocked
        : task.completion == TaskCompletion.done
        ? AppTaskStatus.done
        : AppTaskStatus.open;
    return AppTaskDto(
      id: task.id,
      title: task.title,
      section: task.section,
      priority: task.priority.name,
      category: task.category.name,
      status: status,
    );
  }

  AppConfigDto _toConfigDto(ProjectConfig config) {
    return AppConfigDto(
      gitBaseBranch: config.gitBaseBranch,
      gitFeaturePrefix: config.gitFeaturePrefix,
      gitAutoStash: config.gitAutoStash,
      safeWriteEnabled: config.safeWriteEnabled,
      safeWriteRoots: config.safeWriteRoots,
      shellAllowlist: config.shellAllowlist,
      shellAllowlistProfile: config.shellAllowlistProfile,
      diffBudgetMaxFiles: config.diffBudgetMaxFiles,
      diffBudgetMaxAdditions: config.diffBudgetMaxAdditions,
      diffBudgetMaxDeletions: config.diffBudgetMaxDeletions,
      autopilotMinOpenTasks: config.autopilotMinOpenTasks,
      autopilotMaxPlanAdd: config.autopilotMaxPlanAdd,
      autopilotStepSleepSeconds: config.autopilotStepSleep.inSeconds,
      autopilotIdleSleepSeconds: config.autopilotIdleSleep.inSeconds,
      autopilotMaxSteps: config.autopilotMaxSteps,
      autopilotMaxFailures: config.autopilotMaxFailures,
      autopilotMaxTaskRetries: config.autopilotMaxTaskRetries,
      autopilotSelectionMode: config.autopilotSelectionMode,
      autopilotFairnessWindow: config.autopilotFairnessWindow,
      autopilotPriorityWeightP1: config.autopilotPriorityWeightP1,
      autopilotPriorityWeightP2: config.autopilotPriorityWeightP2,
      autopilotPriorityWeightP3: config.autopilotPriorityWeightP3,
      autopilotReactivateBlocked: config.autopilotReactivateBlocked,
      autopilotReactivateFailed: config.autopilotReactivateFailed,
      autopilotBlockedCooldownSeconds:
          config.autopilotBlockedCooldown.inSeconds,
      autopilotFailedCooldownSeconds: config.autopilotFailedCooldown.inSeconds,
      autopilotLockTtlSeconds: config.autopilotLockTtl.inSeconds,
      autopilotNoProgressThreshold: config.autopilotNoProgressThreshold,
      autopilotStuckCooldownSeconds: config.autopilotStuckCooldown.inSeconds,
      autopilotSelfRestart: config.autopilotSelfRestart,
      autopilotScopeMaxFiles: config.autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions: config.autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions: config.autopilotScopeMaxDeletions,
      autopilotApproveBudget: config.autopilotApproveBudget,
      autopilotManualOverride: config.autopilotManualOverride,
      autopilotOvernightUnattendedEnabled:
          config.autopilotOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled: config.autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow: config.autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples: config.autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent: config.autopilotSelfTuneSuccessPercent,
    );
  }

  AppConfigDto _normalizeConfig(AppConfigDto config) {
    final normalizedAllowlist = <String>[];
    final seen = <String>{};
    for (final entry in config.shellAllowlist) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        normalizedAllowlist.add(trimmed);
      }
    }

    final normalizedRoots = ProjectConfig.normalizeSafeWriteRoots(
      config.safeWriteRoots,
    );
    final resolvedProfile = ProjectConfig.normalizeShellAllowlistProfile(
      config.shellAllowlistProfile,
      fallback: normalizedAllowlist.isNotEmpty
          ? 'custom'
          : ProjectConfig.defaultShellAllowlistProfile,
    );
    final resolvedAllowlist = ProjectConfig.resolveShellAllowlist(
      profile: resolvedProfile,
      customAllowlist: normalizedAllowlist,
    );

    var mode = config.autopilotSelectionMode.trim().toLowerCase();
    if (mode == 'fairness') {
      mode = 'fair';
    }
    if (mode != 'fair' && mode != 'priority') {
      mode = 'fair';
    }

    return AppConfigDto(
      gitBaseBranch: config.gitBaseBranch.trim(),
      gitFeaturePrefix: config.gitFeaturePrefix.trim(),
      gitAutoStash: config.gitAutoStash,
      safeWriteEnabled: config.safeWriteEnabled,
      safeWriteRoots: normalizedRoots.isEmpty
          ? ProjectConfig.defaultSafeWriteRoots
          : normalizedRoots,
      shellAllowlist: resolvedAllowlist,
      shellAllowlistProfile: resolvedProfile,
      diffBudgetMaxFiles: config.diffBudgetMaxFiles,
      diffBudgetMaxAdditions: config.diffBudgetMaxAdditions,
      diffBudgetMaxDeletions: config.diffBudgetMaxDeletions,
      autopilotMinOpenTasks: config.autopilotMinOpenTasks,
      autopilotMaxPlanAdd: config.autopilotMaxPlanAdd,
      autopilotStepSleepSeconds: config.autopilotStepSleepSeconds,
      autopilotIdleSleepSeconds: config.autopilotIdleSleepSeconds,
      autopilotMaxSteps: config.autopilotMaxSteps,
      autopilotMaxFailures: config.autopilotMaxFailures,
      autopilotMaxTaskRetries: config.autopilotMaxTaskRetries,
      autopilotSelectionMode: mode,
      autopilotFairnessWindow: config.autopilotFairnessWindow,
      autopilotPriorityWeightP1: config.autopilotPriorityWeightP1,
      autopilotPriorityWeightP2: config.autopilotPriorityWeightP2,
      autopilotPriorityWeightP3: config.autopilotPriorityWeightP3,
      autopilotReactivateBlocked: config.autopilotReactivateBlocked,
      autopilotReactivateFailed: config.autopilotReactivateFailed,
      autopilotBlockedCooldownSeconds: config.autopilotBlockedCooldownSeconds,
      autopilotFailedCooldownSeconds: config.autopilotFailedCooldownSeconds,
      autopilotLockTtlSeconds: config.autopilotLockTtlSeconds,
      autopilotNoProgressThreshold: config.autopilotNoProgressThreshold,
      autopilotStuckCooldownSeconds: config.autopilotStuckCooldownSeconds,
      autopilotSelfRestart: config.autopilotSelfRestart,
      autopilotScopeMaxFiles: config.autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions: config.autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions: config.autopilotScopeMaxDeletions,
      autopilotApproveBudget: config.autopilotApproveBudget,
      autopilotManualOverride: config.autopilotManualOverride,
      autopilotOvernightUnattendedEnabled:
          config.autopilotOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled: config.autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow: config.autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples: config.autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent: config.autopilotSelfTuneSuccessPercent,
    );
  }

  void _validateConfig(AppConfigDto config) {
    if (config.gitBaseBranch.trim().isEmpty) {
      throw ArgumentError('Git base branch must not be empty.');
    }
    if (config.gitFeaturePrefix.trim().isEmpty) {
      throw ArgumentError('Git feature prefix must not be empty.');
    }
    if (config.safeWriteEnabled && config.safeWriteRoots.isEmpty) {
      throw ArgumentError('Safe-write roots must not be empty.');
    }
    if (config.diffBudgetMaxFiles < 1) {
      throw ArgumentError('Diff budget max files must be >= 1.');
    }
    if (config.diffBudgetMaxAdditions < 1) {
      throw ArgumentError('Diff budget max additions must be >= 1.');
    }
    if (config.diffBudgetMaxDeletions < 1) {
      throw ArgumentError('Diff budget max deletions must be >= 1.');
    }
    if (config.autopilotMinOpenTasks < 1) {
      throw ArgumentError('Autopilot min open tasks must be >= 1.');
    }
    if (config.autopilotMaxPlanAdd < 1) {
      throw ArgumentError('Autopilot max plan add must be >= 1.');
    }
    if (config.autopilotStepSleepSeconds < 0) {
      throw ArgumentError('Autopilot step sleep must be >= 0.');
    }
    if (config.autopilotIdleSleepSeconds < 0) {
      throw ArgumentError('Autopilot idle sleep must be >= 0.');
    }
    if (config.autopilotMaxSteps != null && config.autopilotMaxSteps! < 1) {
      throw ArgumentError('Autopilot max steps must be >= 1.');
    }
    if (config.autopilotMaxFailures < 1) {
      throw ArgumentError('Autopilot max failures must be >= 1.');
    }
    if (config.autopilotMaxTaskRetries < 1) {
      throw ArgumentError('Autopilot max task retries must be >= 1.');
    }
    if (config.autopilotFairnessWindow < 0) {
      throw ArgumentError('Autopilot fairness window must be >= 0.');
    }
    if (config.autopilotPriorityWeightP1 < 1 ||
        config.autopilotPriorityWeightP2 < 1 ||
        config.autopilotPriorityWeightP3 < 1) {
      throw ArgumentError('Autopilot priority weights must be >= 1.');
    }
    if (config.autopilotBlockedCooldownSeconds < 0 ||
        config.autopilotFailedCooldownSeconds < 0) {
      throw ArgumentError('Autopilot cooldowns must be >= 0.');
    }
    if (config.autopilotLockTtlSeconds < 1) {
      throw ArgumentError('Autopilot lock TTL must be >= 1.');
    }
    if (config.autopilotNoProgressThreshold < 0) {
      throw ArgumentError('Autopilot no-progress threshold must be >= 0.');
    }
    if (config.autopilotStuckCooldownSeconds < 0) {
      throw ArgumentError('Autopilot stuck cooldown must be >= 0.');
    }
    if (config.autopilotScopeMaxFiles < 0 ||
        config.autopilotScopeMaxAdditions < 0 ||
        config.autopilotScopeMaxDeletions < 0) {
      throw ArgumentError('Autopilot scope budgets must be >= 0.');
    }
    if (config.autopilotApproveBudget < 0) {
      throw ArgumentError('Autopilot approve budget must be >= 0.');
    }
    if (config.autopilotSelfTuneWindow < 1) {
      throw ArgumentError('Autopilot self-tune window must be >= 1.');
    }
    if (config.autopilotSelfTuneMinSamples < 1) {
      throw ArgumentError('Autopilot self-tune min samples must be >= 1.');
    }
    if (config.autopilotSelfTuneSuccessPercent < 0 ||
        config.autopilotSelfTuneSuccessPercent > 100) {
      throw ArgumentError(
        'Autopilot self-tune success percent must be 0..100.',
      );
    }
    if (config.autopilotSelfTuneMinSamples > config.autopilotSelfTuneWindow) {
      throw ArgumentError('Autopilot self-tune min samples must be <= window.');
    }
    final mode = config.autopilotSelectionMode.trim().toLowerCase();
    if (mode != 'fair' && mode != 'priority') {
      throw ArgumentError('Autopilot selection mode must be fair or priority.');
    }
  }

  TaskPriority _mapPriority(AppTaskPriority priority) {
    switch (priority) {
      case AppTaskPriority.p1:
        return TaskPriority.p1;
      case AppTaskPriority.p2:
        return TaskPriority.p2;
      case AppTaskPriority.p3:
        return TaskPriority.p3;
    }
  }

  TaskCategory _mapCategory(AppTaskCategory category) {
    switch (category) {
      case AppTaskCategory.core:
        return TaskCategory.core;
      case AppTaskCategory.ui:
        return TaskCategory.ui;
      case AppTaskCategory.security:
        return TaskCategory.security;
      case AppTaskCategory.docs:
        return TaskCategory.docs;
      case AppTaskCategory.architecture:
        return TaskCategory.architecture;
      case AppTaskCategory.qa:
        return TaskCategory.qa;
      case AppTaskCategory.agent:
        return TaskCategory.agent;
      case AppTaskCategory.refactor:
        return TaskCategory.refactor;
      case AppTaskCategory.unknown:
        throw ArgumentError('Task category is required.');
    }
  }

  AppError _mapError(Object error, StackTrace stackTrace) {
    return mapToAppError(error, stackTrace);
  }

  void _safeAppendLog(
    String projectRoot, {
    required String event,
    String? message,
    Map<String, Object?>? data,
  }) {
    try {
      final layout = ProjectLayout(projectRoot);
      RunLogStore(
        layout.runLogPath,
      ).append(event: event, message: message, data: data);
    } catch (_) {
      // Logging should not break app flows.
    }
  }

  AppHealthSnapshotDto _toHealthDto(HealthSnapshot snapshot) {
    return AppHealthSnapshotDto(
      agent: _toHealthCheckDto(snapshot.agent),
      allowlist: _toHealthCheckDto(snapshot.allowlist),
      git: _toHealthCheckDto(snapshot.git),
      review: _toHealthCheckDto(snapshot.review),
    );
  }

  AppHealthCheckDto _toHealthCheckDto(HealthCheck check) {
    return AppHealthCheckDto(ok: check.ok, message: check.message);
  }

  AppRunTelemetryDto _toTelemetryDto(RunTelemetrySnapshot snapshot) {
    return AppRunTelemetryDto(
      recentEvents: snapshot.recentEvents
          .map(_toRunLogEventDto)
          .toList(growable: false),
      errorClass: snapshot.errorClass,
      errorKind: snapshot.errorKind,
      errorMessage: snapshot.errorMessage,
      agentExitCode: snapshot.agentExitCode,
      agentStderrExcerpt: snapshot.agentStderrExcerpt,
      lastErrorEvent: snapshot.lastErrorEvent,
      healthSummary: _toAppRunHealthSummaryDto(snapshot.healthSummary),
    );
  }

  AppRunHealthSummaryDto _toAppRunHealthSummaryDto(
    RunHealthSummarySnapshot summary,
  ) {
    return AppRunHealthSummaryDto(
      failureTrend: AppRunFailureTrendDto(
        direction: summary.failureTrend.direction,
        recentFailures: summary.failureTrend.recentFailures,
        previousFailures: summary.failureTrend.previousFailures,
        windowSeconds: summary.failureTrend.windowSeconds,
        sampleSize: summary.failureTrend.sampleSize,
        dominantErrorKind: summary.failureTrend.dominantErrorKind,
      ),
      retryDistribution: AppRunRetryDistributionDto(
        samples: summary.retryDistribution.samples,
        retry0: summary.retryDistribution.retry0,
        retry1: summary.retryDistribution.retry1,
        retry2Plus: summary.retryDistribution.retry2Plus,
        maxRetry: summary.retryDistribution.maxRetry,
      ),
      cooldown: AppRunCooldownDto(
        active: summary.cooldown.active,
        totalSeconds: summary.cooldown.totalSeconds,
        remainingSeconds: summary.cooldown.remainingSeconds,
        until: summary.cooldown.until,
        sourceEvent: summary.cooldown.sourceEvent,
        reason: summary.cooldown.reason,
      ),
    );
  }

  AppRunLogEventDto _toRunLogEventDto(RunLogEvent event) {
    return AppRunLogEventDto(
      timestamp: event.timestamp,
      eventId: event.eventId,
      correlationId: event.correlationId,
      event: event.event,
      message: event.message,
      correlation: event.correlation,
      data: event.data,
    );
  }

  String _filterMode(TaskListQuery query) {
    if (query.blockedOnly) {
      return 'blocked';
    }
    if (query.openOnly && query.doneOnly) {
      return 'all';
    }
    if (query.openOnly) {
      return 'open';
    }
    if (query.doneOnly) {
      return 'done';
    }
    return 'all';
  }

  String? _normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed == '(none)' || trimmed == '(unknown)') {
      return null;
    }
    return trimmed;
  }
}
