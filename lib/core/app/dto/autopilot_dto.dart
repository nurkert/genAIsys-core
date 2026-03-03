// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'telemetry_dto.dart';

class AutopilotStepDto {
  const AutopilotStepDto({
    required this.executedCycle,
    required this.activatedTask,
    required this.activeTaskTitle,
    required this.plannedTasksAdded,
    required this.reviewDecision,
    required this.retryCount,
    required this.taskBlocked,
    required this.deactivatedTask,
  });

  final bool executedCycle;
  final bool activatedTask;
  final String? activeTaskTitle;
  final int plannedTasksAdded;
  final String? reviewDecision;
  final int retryCount;
  final bool taskBlocked;
  final bool deactivatedTask;
}

class AutopilotRunDto {
  const AutopilotRunDto({
    required this.totalSteps,
    required this.successfulSteps,
    required this.idleSteps,
    required this.failedSteps,
    required this.stoppedByMaxSteps,
    required this.stoppedWhenIdle,
    required this.stoppedBySafetyHalt,
  });

  final int totalSteps;
  final int successfulSteps;
  final int idleSteps;
  final int failedSteps;
  final bool stoppedByMaxSteps;
  final bool stoppedWhenIdle;
  final bool stoppedBySafetyHalt;
}

class AutopilotCandidateCommandDto {
  const AutopilotCandidateCommandDto({
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

class AutopilotCandidateDto {
  const AutopilotCandidateDto({
    required this.passed,
    required this.skipSuites,
    required this.missingFiles,
    required this.missingDoneBlockers,
    required this.openCriticalP1Lines,
    required this.commands,
  });

  final bool passed;
  final bool skipSuites;
  final List<String> missingFiles;
  final List<String> missingDoneBlockers;
  final List<String> openCriticalP1Lines;
  final List<AutopilotCandidateCommandDto> commands;
}

class AutopilotPilotDto {
  const AutopilotPilotDto({
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
    this.error,
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

class AutopilotBranchCleanupDto {
  const AutopilotBranchCleanupDto({
    required this.baseBranch,
    required this.dryRun,
    required this.deletedLocalBranches,
    required this.deletedRemoteBranches,
    required this.skippedBranches,
    required this.failures,
  });

  final String baseBranch;
  final bool dryRun;
  final List<String> deletedLocalBranches;
  final List<String> deletedRemoteBranches;
  final List<String> skippedBranches;
  final List<String> failures;
}

class AutopilotStatusDto {
  const AutopilotStatusDto({
    required this.autopilotRunning,
    required this.pid,
    required this.startedAt,
    required this.lastLoopAt,
    required this.consecutiveFailures,
    required this.lastError,
    this.lastErrorClass,
    this.lastErrorKind,
    required this.subtaskQueue,
    required this.currentSubtask,
    required this.lastStepSummary,
    required this.health,
    required this.telemetry,
    required this.healthSummary,
    required this.stallReason,
    required this.stallDetail,
    this.hitlGatePending = false,
    this.hitlGateEvent,
  });

  final bool autopilotRunning;
  final int? pid;
  final String? startedAt;
  final String? lastLoopAt;
  final int consecutiveFailures;
  final String? lastError;
  final String? lastErrorClass;
  final String? lastErrorKind;
  final List<String> subtaskQueue;
  final String? currentSubtask;
  final AutopilotStepSummaryDto? lastStepSummary;
  final AppHealthSnapshotDto health;
  final AppRunTelemetryDto telemetry;
  final AutopilotHealthSummaryDto healthSummary;
  final String? stallReason;
  final String? stallDetail;
  final bool hitlGatePending;
  final String? hitlGateEvent;
}

class AutopilotHealthSummaryDto {
  const AutopilotHealthSummaryDto({
    required this.failureTrend,
    required this.retryDistribution,
    required this.cooldown,
  });

  final AutopilotFailureTrendDto failureTrend;
  final AutopilotRetryDistributionDto retryDistribution;
  final AutopilotCooldownDto cooldown;
}

class AutopilotFailureTrendDto {
  const AutopilotFailureTrendDto({
    required this.direction,
    required this.recentFailures,
    required this.previousFailures,
    required this.windowSeconds,
    required this.sampleSize,
    required this.dominantErrorKind,
  });

  final String direction;
  final int recentFailures;
  final int previousFailures;
  final int windowSeconds;
  final int sampleSize;
  final String? dominantErrorKind;
}

class AutopilotRetryDistributionDto {
  const AutopilotRetryDistributionDto({
    required this.samples,
    required this.retry0,
    required this.retry1,
    required this.retry2Plus,
    required this.maxRetry,
  });

  final int samples;
  final int retry0;
  final int retry1;
  final int retry2Plus;
  final int maxRetry;
}

class AutopilotCooldownDto {
  const AutopilotCooldownDto({
    required this.active,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.until,
    required this.sourceEvent,
    required this.reason,
  });

  final bool active;
  final int totalSeconds;
  final int remainingSeconds;
  final String? until;
  final String? sourceEvent;
  final String? reason;
}

class AutopilotStopDto {
  const AutopilotStopDto({required this.autopilotStopped});

  final bool autopilotStopped;
}

class AutopilotSupervisorStartDto {
  const AutopilotSupervisorStartDto({
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

class AutopilotSupervisorStopDto {
  const AutopilotSupervisorStopDto({
    required this.stopped,
    required this.wasRunning,
    required this.reason,
  });

  final bool stopped;
  final bool wasRunning;
  final String reason;
}

class AutopilotSupervisorStatusDto {
  const AutopilotSupervisorStatusDto({
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

class AutopilotSmokeDto {
  const AutopilotSmokeDto({
    required this.ok,
    required this.projectRoot,
    required this.taskTitle,
    required this.reviewDecision,
    required this.taskDone,
    required this.commitCount,
    required this.failures,
  });

  final bool ok;
  final String projectRoot;
  final String taskTitle;
  final String? reviewDecision;
  final bool taskDone;
  final int commitCount;
  final List<String> failures;
}

class AutopilotSimulationDto {
  const AutopilotSimulationDto({
    required this.projectRoot,
    required this.workspaceRoot,
    required this.hasTask,
    required this.activatedTask,
    required this.plannedTasksAdded,
    required this.taskTitle,
    required this.taskId,
    required this.subtask,
    required this.reviewDecision,
    required this.diffSummary,
    required this.diffPatch,
    required this.filesChanged,
    required this.additions,
    required this.deletions,
    required this.policyViolation,
    required this.policyMessage,
  });

  final String projectRoot;
  final String? workspaceRoot;
  final bool hasTask;
  final bool activatedTask;
  final int plannedTasksAdded;
  final String? taskTitle;
  final String? taskId;
  final String? subtask;
  final String? reviewDecision;
  final String diffSummary;
  final String diffPatch;
  final int filesChanged;
  final int additions;
  final int deletions;
  final bool policyViolation;
  final String? policyMessage;
}

class AutopilotMetaTasksDto {
  const AutopilotMetaTasksDto({
    required this.created,
    required this.skipped,
    required this.createdTitles,
    required this.skippedTitles,
  });

  final int created;
  final int skipped;
  final List<String> createdTitles;
  final List<String> skippedTitles;
}

class AutopilotEvalCaseDto {
  const AutopilotEvalCaseDto({
    required this.id,
    required this.title,
    required this.passed,
    required this.reviewDecision,
    required this.filesChanged,
    required this.additions,
    required this.deletions,
    required this.policyViolation,
    required this.policyMessage,
    required this.reason,
  });

  final String id;
  final String title;
  final bool passed;
  final String? reviewDecision;
  final int filesChanged;
  final int additions;
  final int deletions;
  final bool policyViolation;
  final String? policyMessage;
  final String? reason;
}

class AutopilotEvalRunDto {
  const AutopilotEvalRunDto({
    required this.runId,
    required this.runAt,
    required this.successRate,
    required this.passed,
    required this.total,
    required this.outputDir,
    required this.results,
  });

  final String runId;
  final String runAt;
  final double successRate;
  final int passed;
  final int total;
  final String outputDir;
  final List<AutopilotEvalCaseDto> results;
}

class AutopilotSelfTuneDto {
  const AutopilotSelfTuneDto({
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

class AutopilotImproveDto {
  const AutopilotImproveDto({
    required this.meta,
    required this.eval,
    required this.selfTune,
  });

  final AutopilotMetaTasksDto? meta;
  final AutopilotEvalRunDto? eval;
  final AutopilotSelfTuneDto? selfTune;
}

class AutopilotHealDto {
  const AutopilotHealDto({
    required this.bundlePath,
    required this.reason,
    required this.detail,
    required this.executedCycle,
    required this.recovered,
    required this.activatedTask,
    required this.deactivatedTask,
    required this.taskBlocked,
    required this.plannedTasksAdded,
    required this.retryCount,
    required this.reviewDecision,
    required this.activeTaskId,
    required this.activeTaskTitle,
    required this.subtaskId,
  });

  final String bundlePath;
  final String reason;
  final String? detail;
  final bool executedCycle;
  final bool recovered;
  final bool activatedTask;
  final bool deactivatedTask;
  final bool taskBlocked;
  final int plannedTasksAdded;
  final int retryCount;
  final String? reviewDecision;
  final String? activeTaskId;
  final String? activeTaskTitle;
  final String? subtaskId;
}

class AutopilotStepSummaryDto {
  const AutopilotStepSummaryDto({
    required this.stepId,
    this.taskId,
    this.subtaskId,
    this.decision,
    this.event,
    this.timestamp,
  });

  final String stepId;
  final String? taskId;
  final String? subtaskId;
  final String? decision;
  final String? event;
  final String? timestamp;
}
