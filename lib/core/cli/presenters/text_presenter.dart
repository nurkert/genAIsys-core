// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../app/app.dart';
import '../../security/redaction_service.dart';
import '../output/cli_output.dart';
import 'cli_presenter.dart';

class TextPresenter implements CliPresenter {
  const TextPresenter([this.o = CliOutput.plain]);

  final CliOutput o;

  static final RedactionService _redactionService = RedactionService.shared;

  void writeInit(IOSink out, ProjectInitializationDto dto) {
    _writeLine(out, 'Genaisys initialized at: ${dto.genaisysDir}');
  }

  void writeStatus(IOSink out, AppStatusSnapshotDto dto) {
    _writeLine(out, 'Project root: ${dto.projectRoot}');
    _writeLine(out, 'Tasks total: ${dto.tasksTotal}');
    _writeLine(out, 'Tasks open: ${dto.tasksOpen}');
    _writeLine(out, 'Tasks blocked: ${dto.tasksBlocked}');
    _writeLine(out, 'Tasks done: ${dto.tasksDone}');
    _writeLine(out, 'Active task: ${_labelOrNone(dto.activeTaskTitle)}');
    _writeLine(out, 'Active task id: ${_labelOrNone(dto.activeTaskId)}');
    _writeLine(out, 'Review status: ${_labelOrNone(dto.reviewStatus)}');
    _writeLine(out, 'Review updated at: ${_labelOrNone(dto.reviewUpdatedAt)}');
    _writeLine(out, 'Workflow stage: ${dto.workflowStage}');
    _writeLine(out, 'Cycle count: ${dto.cycleCount}');
    _writeLine(out, 'Last updated: ${_labelOrUnknown(dto.lastUpdated)}');
    _writeHealth(out, dto.health);
    _writeTelemetry(out, dto.telemetry);
  }

  void writeCycle(IOSink out, CycleTickDto dto) {
    _writeLine(out, 'Cycle updated to ${dto.cycleCount}');
  }

  void writeCycleRun(IOSink out, TaskCycleExecutionDto dto) {
    _writeLine(out, 'Task cycle completed.');
    _writeLine(out, 'Review recorded: ${dto.reviewRecorded}');
  }

  void writeTasks(IOSink out, AppTaskListDto dto, {required bool showIds}) {
    if (dto.tasks.isEmpty) {
      _writeLine(out, 'No tasks found.');
      return;
    }

    for (final task in dto.tasks) {
      final status = task.status.name;
      final priority = task.priority.toUpperCase();
      final category = task.category.toUpperCase();
      final idSuffix = showIds ? ' [id: ${task.id}]' : '';
      _writeLine(
        out,
        '[${task.section}] $status $priority $category - ${task.title}$idSuffix',
      );
    }
  }

  void writeNext(IOSink out, AppTaskDto task, {required bool showIds}) {
    final priority = task.priority.toUpperCase();
    final category = task.category.toUpperCase();
    final idSuffix = showIds ? ' [id: ${task.id}]' : '';
    _writeLine(
      out,
      '[${task.section}] $priority $category - ${task.title}$idSuffix',
    );
  }

  void writeActivate(IOSink out, TaskActivationDto dto) {
    if (!dto.activated || dto.task == null) {
      _writeLine(out, 'No open tasks found.');
      return;
    }
    _writeLine(out, 'Activated: ${dto.task!.title}');
  }

  void writeDeactivate(IOSink out, TaskDeactivationDto dto) {
    _writeLine(out, 'Active task cleared.');
  }

  void writeSpecInit(IOSink out, SpecInitializationDto dto) {
    if (!dto.created) {
      _writeLine(out, 'Already exists: ${dto.path}');
      return;
    }
    _writeLine(out, 'Created: ${dto.path}');
  }

  void writeDone(IOSink out, TaskDoneDto dto) {
    _writeLine(out, 'Marked done: ${dto.taskTitle}');
  }

  void writeBlock(IOSink out, TaskBlockedDto dto) {
    _writeLine(out, 'Blocked: ${dto.taskTitle}');
  }

  void writeReviewStatus(IOSink out, AppReviewStatusDto dto) {
    _writeLine(out, 'Review status: ${dto.status}');
    _writeLine(out, 'Review updated at: ${dto.updatedAt}');
  }

  void writeReviewDecision(
    IOSink out,
    ReviewDecisionDto dto, {
    required String decision,
  }) {
    if (dto.note != null && dto.note!.isNotEmpty) {
      _writeLine(out, 'Review note: ${dto.note}');
    }
    _writeLine(out, 'Review ${decision}d for: ${dto.taskTitle}');
  }

  void writeReviewClear(IOSink out, ReviewClearDto dto) {
    if (dto.note != null && dto.note!.isNotEmpty) {
      _writeLine(out, 'Review note: ${dto.note}');
    }
    _writeLine(out, 'Review status cleared.');
  }

  void writeAutopilotStep(IOSink out, AutopilotStepDto dto) {
    _writeLine(out, 'Autopilot step completed.');
    _writeLine(out, 'Executed cycle: ${dto.executedCycle}');
    _writeLine(out, 'Active task: ${dto.activeTaskTitle ?? '(none)'}');
    _writeLine(out, 'Planned tasks added: ${dto.plannedTasksAdded}');
    _writeLine(out, 'Review decision: ${dto.reviewDecision ?? '(none)'}');
    _writeLine(out, 'Retry count: ${dto.retryCount}');
    _writeLine(out, 'Task blocked: ${dto.taskBlocked}');
  }

  void writeAutopilotRun(IOSink out, AutopilotRunDto dto) {
    if (o.isRich) {
      _writeLine(out, o.separator());
      _writeLine(
        out,
        '  Run stopped  ${o.bullet}  ${dto.totalSteps} steps  ${o.bullet}'
        '  ${o.green(o.ok)}${dto.successfulSteps}'
        '  ${o.yellow(o.retry)}${dto.idleSteps}'
        '  ${o.red(o.fail)}${dto.failedSteps}',
      );
      _writeLine(out, o.separator());
    } else {
      _writeLine(
        out,
        'run.stopped steps=${dto.totalSteps}'
        ' success=${dto.successfulSteps}'
        ' idle=${dto.idleSteps}'
        ' failed=${dto.failedSteps}',
      );
    }
  }

  void writeAutopilotCandidate(IOSink out, AutopilotCandidateDto dto) {
    _writeLine(
      out,
      dto.passed
          ? 'Autopilot release-candidate gates passed.'
          : 'Autopilot release-candidate gates failed.',
    );
    if (dto.skipSuites) {
      _writeLine(out, 'Suites: skipped by option.');
    }
    if (dto.missingFiles.isNotEmpty) {
      _writeLine(out, 'Missing required files:');
      for (final path in dto.missingFiles) {
        _writeLine(out, '- $path');
      }
    }
    if (dto.missingDoneBlockers.isNotEmpty) {
      _writeLine(out, 'Missing done blockers:');
      for (final blocker in dto.missingDoneBlockers) {
        _writeLine(out, '- $blocker');
      }
    }
    if (dto.openCriticalP1Lines.isNotEmpty) {
      _writeLine(out, 'Open P1 blockers in release-critical areas:');
      for (final line in dto.openCriticalP1Lines) {
        _writeLine(out, '- $line');
      }
    }
    if (dto.commands.isNotEmpty) {
      _writeLine(out, 'Suite commands:');
      for (final command in dto.commands) {
        final status = command.ok ? 'PASS' : 'FAIL';
        final timeoutSuffix = command.timedOut ? ', timed_out=true' : '';
        _writeLine(
          out,
          '- [$status] ${command.command} (${command.durationMs}ms, exit=${command.exitCode}$timeoutSuffix)',
        );
      }
    }
  }

  void writeAutopilotPilot(IOSink out, AutopilotPilotDto dto) {
    _writeLine(
      out,
      dto.passed
          ? 'Autopilot pilot run completed.'
          : 'Autopilot pilot run failed.',
    );
    _writeLine(out, 'Branch: ${dto.branch}');
    _writeLine(out, 'Duration seconds: ${dto.durationSeconds}');
    _writeLine(out, 'Max cycles: ${dto.maxCycles}');
    _writeLine(out, 'Command exit code: ${dto.commandExitCode}');
    _writeLine(out, 'Timed out: ${dto.timedOut}');
    _writeLine(out, 'Report: ${dto.reportPath}');
    _writeLine(out, 'Total steps: ${dto.totalSteps}');
    _writeLine(out, 'Successful steps: ${dto.successfulSteps}');
    _writeLine(out, 'Idle steps: ${dto.idleSteps}');
    _writeLine(out, 'Failed steps: ${dto.failedSteps}');
    _writeLine(out, 'Stopped by max steps: ${dto.stoppedByMaxSteps}');
    _writeLine(out, 'Stopped when idle: ${dto.stoppedWhenIdle}');
    _writeLine(out, 'Stopped by safety halt: ${dto.stoppedBySafetyHalt}');
    if (dto.error != null && dto.error!.trim().isNotEmpty) {
      _writeLine(out, 'Error: ${dto.error}');
    }
  }

  void writeAutopilotBranchCleanup(IOSink out, AutopilotBranchCleanupDto dto) {
    _writeLine(out, 'Autopilot branch cleanup completed.');
    _writeLine(out, 'Base branch: ${dto.baseBranch}');
    _writeLine(out, 'Dry run: ${dto.dryRun}');
    _writeLine(
      out,
      'Deleted local branches: ${dto.deletedLocalBranches.length}',
    );
    for (final branch in dto.deletedLocalBranches) {
      _writeLine(out, '- $branch');
    }
    if (dto.deletedRemoteBranches.isNotEmpty) {
      _writeLine(
        out,
        'Deleted remote branches: ${dto.deletedRemoteBranches.length}',
      );
      for (final branch in dto.deletedRemoteBranches) {
        _writeLine(out, '- $branch');
      }
    }
    if (dto.failures.isNotEmpty) {
      _writeLine(out, 'Failures: ${dto.failures.length}');
      for (final failure in dto.failures) {
        _writeLine(out, '- $failure');
      }
    }
  }

  void writeAutopilotStatus(IOSink out, AutopilotStatusDto dto) {
    if (o.isRich) {
      _writeAutopilotStatusRich(out, dto);
    } else {
      _writeAutopilotStatusLog(out, dto);
    }
  }

  void _writeAutopilotStatusRich(IOSink out, AutopilotStatusDto dto) {
    final runLabel = dto.autopilotRunning ? o.bold('RUNNING') : o.dim('STOPPED');
    final pid = dto.pid != null ? '  ${o.bullet}  PID ${dto.pid}' : '';
    final started = dto.startedAt != null
        ? '  ${o.bullet}  started ${o.parseTimestamp(dto.startedAt)}'
        : '';
    _writeLine(out, o.boxHeader('AUTOPILOT'));
    _writeLine(out, o.boxRow('$runLabel$pid$started'));
    final activeTask = dto.lastStepSummary?.taskId;
    if (activeTask != null && activeTask.isNotEmpty) {
      _writeLine(out, o.boxRow('Active: $activeTask'));
    }
    final lastLoop = o.parseTimestamp(dto.lastLoopAt);
    _writeLine(
      out,
      o.boxRow(
        'Last loop: $lastLoop  ${o.bullet}  ${dto.consecutiveFailures} failures',
      ),
    );
    _writeLine(out, o.boxFooter());

    final health = dto.health;
    final healthLine = StringBuffer('  Health  ');
    healthLine
      ..write('${_richHealthSymbol(health.agent)} agent  ')
      ..write('${_richHealthSymbol(health.allowlist)} allowlist  ')
      ..write('${_richHealthSymbol(health.git)} git  ')
      ..write('${_richHealthSymbol(health.review)} review');
    _writeLine(out, healthLine);

    final summary = dto.lastStepSummary;
    if (summary != null) {
      final stepAt = o.parseTimestamp(summary.timestamp);
      final decision = summary.decision != null
          ? '  ${o.bullet}  ${summary.decision!.toUpperCase()}'
          : '';
      _writeLine(
        out,
        '  Last    step ${summary.stepId}  ${o.bullet}  $stepAt$decision',
      );
    }

    final retries = dto.healthSummary.retryDistribution;
    final cooldown = dto.healthSummary.cooldown;
    final cooldownLabel = cooldown.active
        ? 'active (${cooldown.remainingSeconds}s)'
        : 'inactive';
    _writeLine(
      out,
      '  Retry   0×${retries.retry0}  1×${retries.retry1}  2+×${retries.retry2Plus}'
      '  |  Cooldown: $cooldownLabel',
    );

    if (dto.hitlGatePending) {
      _writeLine(
        out,
        '  ${o.yellow('⏸ HITL GATE')}  awaiting decision  ${dto.hitlGateEvent ?? ''}',
      );
      _writeLine(out, '    ${o.arrow} genaisys hitl approve <path>  |  genaisys hitl reject <path>');
    }
    if (dto.stallReason != null && dto.stallReason!.isNotEmpty) {
      _writeLine(out, '  Stall   ${o.yellow(dto.stallReason!)}');
    }
    if (dto.lastError != null && dto.lastError!.isNotEmpty) {
      _writeLine(out, '  Error   ${o.red(dto.lastError!)}');
    }
    _writeTelemetry(out, dto.telemetry, includeHealthSummary: false);
  }

  void _writeAutopilotStatusLog(IOSink out, AutopilotStatusDto dto) {
    final running = dto.autopilotRunning ? 'RUNNING' : 'STOPPED';
    final pid = dto.pid != null ? ' pid=${dto.pid}' : '';
    final started = dto.startedAt != null
        ? ' started=${o.parseTimestamp(dto.startedAt)}'
        : '';
    _writeLine(out, 'status=$running$pid$started');

    final activeTask = dto.lastStepSummary?.taskId;
    if (activeTask != null && activeTask.isNotEmpty) {
      _writeLine(out, 'active="$activeTask"');
    }

    final lastLoop = o.parseTimestamp(dto.lastLoopAt);
    final cooldown = dto.healthSummary.cooldown;
    final cooldownLabel = cooldown.active
        ? 'active(${cooldown.remainingSeconds}s)'
        : 'inactive';
    _writeLine(
      out,
      'last_loop=$lastLoop failures=${dto.consecutiveFailures}'
      ' cooldown=$cooldownLabel',
    );

    final h = dto.health;
    _writeLine(
      out,
      'health agent=${_logHealthLabel(h.agent)}'
      ' allowlist=${_logHealthLabel(h.allowlist)}'
      ' git=${_logHealthLabel(h.git)}'
      ' review=${_logHealthLabel(h.review)}',
    );

    final summary = dto.lastStepSummary;
    if (summary != null) {
      final stepAt = o.parseTimestamp(summary.timestamp);
      final decision =
          summary.decision != null ? ' decision=${summary.decision}' : '';
      _writeLine(
        out,
        'last_step step=${summary.stepId} at=$stepAt$decision',
      );
    }

    if (dto.hitlGatePending) {
      _writeLine(
        out,
        'hitl_pending=true hitl_event=${dto.hitlGateEvent ?? 'unknown'}',
      );
    }
    if (dto.stallReason != null && dto.stallReason!.isNotEmpty) {
      _writeLine(out, 'stall=${dto.stallReason}');
    }
    if (dto.stallDetail != null && dto.stallDetail!.isNotEmpty) {
      _writeLine(out, 'stall_detail=${dto.stallDetail}');
    }
    if (dto.lastError != null && dto.lastError!.isNotEmpty) {
      _writeLine(out, 'last_error="${dto.lastError}"');
    }

    final trend = dto.healthSummary.failureTrend;
    _writeLine(
      out,
      'failure_trend=${trend.direction}'
      ' recent=${trend.recentFailures} previous=${trend.previousFailures}',
    );

    final retries = dto.healthSummary.retryDistribution;
    _writeLine(
      out,
      'retry_dist 0=${retries.retry0} 1=${retries.retry1}'
      ' 2+=${retries.retry2Plus} max=${retries.maxRetry}',
    );

    _writeTelemetry(out, dto.telemetry, includeHealthSummary: false);
  }

  String _richHealthSymbol(AppHealthCheckDto check) =>
      check.ok ? o.green(o.ok) : o.red(o.fail);

  String _logHealthLabel(AppHealthCheckDto check) => check.ok ? 'OK' : 'FAIL';

  void writeAutopilotStop(IOSink out, AutopilotStopDto dto) {
    _writeLine(out, 'Autopilot stopped.');
  }

  void writeAutopilotSupervisorStart(
    IOSink out,
    AutopilotSupervisorStartDto dto,
  ) {
    _writeLine(out, 'Autopilot supervisor started.');
    _writeLine(out, 'Session id: ${dto.sessionId}');
    _writeLine(out, 'Profile: ${dto.profile}');
    _writeLine(out, 'Supervisor PID: ${dto.pid}');
    _writeLine(out, 'Resume action: ${dto.resumeAction}');
  }

  void writeAutopilotSupervisorStop(
    IOSink out,
    AutopilotSupervisorStopDto dto,
  ) {
    _writeLine(
      out,
      dto.wasRunning
          ? 'Autopilot supervisor stopped.'
          : 'Autopilot supervisor was already stopped.',
    );
    _writeLine(out, 'Reason: ${dto.reason}');
  }

  void writeAutopilotSupervisorStatus(
    IOSink out,
    AutopilotSupervisorStatusDto dto,
  ) {
    if (o.isRich) {
      _writeAutopilotSupervisorStatusRich(out, dto);
    } else {
      _writeAutopilotSupervisorStatusLog(out, dto);
    }
  }

  void _writeAutopilotSupervisorStatusRich(
    IOSink out,
    AutopilotSupervisorStatusDto dto,
  ) {
    final runLabel =
        dto.running ? o.bold('RUNNING') : o.dim('STOPPED');
    final session = _labelOrNone(dto.sessionId);
    final profile = _labelOrNone(dto.profile);
    _writeLine(out, o.boxHeader('SUPERVISOR'));
    _writeLine(
      out,
      o.boxRow('$runLabel  ${o.bullet}  session $session  ${o.bullet}  profile $profile'),
    );
    if (dto.workerPid != null) {
      _writeLine(
        out,
        o.boxRow(
          'Worker PID ${dto.workerPid}'
          '  ${o.bullet}  restarts ${dto.restartCount}',
        ),
      );
    }
    final startedAt = o.parseTimestamp(dto.startedAt);
    _writeLine(out, o.boxRow('Started $startedAt'));
    _writeLine(out, o.boxFooter());

    final apLabel = dto.autopilotRunning ? o.green('RUNNING') : o.dim('STOPPED');
    final apPid = dto.autopilotPid != null ? ' PID ${dto.autopilotPid}' : '';
    _writeLine(out, '  Autopilot  $apLabel$apPid');

    if (dto.throughputSteps > 0) {
      _writeLine(
        out,
        '  Throughput  steps=${dto.throughputSteps}'
        ' rejects=${dto.throughputRejects}'
        ' high_retry=${dto.throughputHighRetries}',
      );
    }
    if (dto.lastHaltReason != null && dto.lastHaltReason!.isNotEmpty) {
      _writeLine(out, '  Last halt   ${o.yellow(dto.lastHaltReason!)}');
    }
    if (dto.autopilotLastError != null &&
        dto.autopilotLastError!.isNotEmpty) {
      _writeLine(
        out,
        '  Last error  ${o.red(dto.autopilotLastError!)}',
      );
    }
  }

  void _writeAutopilotSupervisorStatusLog(
    IOSink out,
    AutopilotSupervisorStatusDto dto,
  ) {
    final running = dto.running ? 'RUNNING' : 'STOPPED';
    final pid = dto.workerPid != null ? ' pid=${dto.workerPid}' : '';
    final startedAt = o.parseTimestamp(dto.startedAt);
    _writeLine(
      out,
      'status=$running$pid started=$startedAt'
      ' session=${_labelOrNone(dto.sessionId)}'
      ' profile=${_labelOrNone(dto.profile)}'
      ' restarts=${dto.restartCount}',
    );
    _writeLine(
      out,
      'autopilot running=${dto.autopilotRunning}'
      ' pid=${_labelOrNone(dto.autopilotPid?.toString())}'
      ' failures=${dto.autopilotConsecutiveFailures}',
    );
    if (dto.throughputSteps > 0) {
      _writeLine(
        out,
        'throughput steps=${dto.throughputSteps}'
        ' rejects=${dto.throughputRejects}'
        ' high_retry=${dto.throughputHighRetries}',
      );
    }
    if (dto.lastHaltReason != null && dto.lastHaltReason!.isNotEmpty) {
      _writeLine(out, 'halt_reason=${dto.lastHaltReason}');
    }
    if (dto.autopilotLastError != null &&
        dto.autopilotLastError!.isNotEmpty) {
      _writeLine(out, 'last_error="${dto.autopilotLastError}"');
    }
    if (dto.cooldownUntil != null && dto.cooldownUntil!.isNotEmpty) {
      _writeLine(
        out,
        'cooldown_until=${o.parseTimestamp(dto.cooldownUntil)}',
      );
    }
    if (dto.lastResumeAction != null && dto.lastResumeAction!.isNotEmpty) {
      _writeLine(out, 'last_resume=${dto.lastResumeAction}');
    }
  }

  void writeAutopilotSmoke(IOSink out, AutopilotSmokeDto dto) {
    if (dto.ok) {
      _writeLine(out, 'Autopilot smoke check OK.');
    } else {
      _writeLine(out, 'Autopilot smoke check FAILED.');
    }
    _writeLine(out, 'Project: ${dto.projectRoot}');
    _writeLine(out, 'Task: ${dto.taskTitle}');
    _writeLine(out, 'Review decision: ${dto.reviewDecision ?? '(none)'}');
    _writeLine(out, 'Task done: ${dto.taskDone}');
    _writeLine(out, 'Commit count: ${dto.commitCount}');
    if (dto.failures.isNotEmpty) {
      _writeLine(out, 'Failures:');
      for (final failure in dto.failures) {
        _writeLine(out, '- $failure');
      }
    }
  }

  void writeAutopilotSimulation(
    IOSink out,
    AutopilotSimulationDto dto, {
    bool showPatch = false,
  }) {
    _writeLine(out, 'Autopilot simulation completed.');
    if (!dto.hasTask) {
      _writeLine(out, 'No open task to simulate.');
      return;
    }
    _writeLine(out, 'Task: ${_labelOrUnknown(dto.taskTitle)}');
    if (dto.taskId != null && dto.taskId!.isNotEmpty) {
      _writeLine(out, 'Task ID: ${dto.taskId}');
    }
    if (dto.subtask != null && dto.subtask!.isNotEmpty) {
      _writeLine(out, 'Subtask: ${dto.subtask}');
    }
    _writeLine(out, 'Review: ${_labelOrNone(dto.reviewDecision)}');
    _writeLine(
      out,
      'Diff Stats: ${dto.filesChanged} files, +${dto.additions}, -${dto.deletions}',
    );
    if (dto.policyViolation) {
      _writeLine(
        out,
        'Policy violation: ${_labelOrUnknown(dto.policyMessage)}',
      );
    }
    if (dto.workspaceRoot != null && dto.workspaceRoot!.isNotEmpty) {
      _writeLine(out, 'Workspace kept at: ${dto.workspaceRoot}');
    }
    _writeLine(out, 'Diff Summary:');
    final summary = dto.diffSummary.trim();
    _writeLine(out, summary.isEmpty ? '(none)' : summary);
    if (showPatch) {
      _writeLine(out, 'Diff Patch:');
      final patch = dto.diffPatch.trim();
      _writeLine(out, patch.isEmpty ? '(none)' : patch);
    }
  }

  void writeAutopilotImprove(IOSink out, AutopilotImproveDto dto) {
    _writeLine(out, 'Autopilot self-improvement completed.');
    final meta = dto.meta;
    if (meta != null) {
      _writeLine(out, 'Meta tasks created: ${meta.created}');
      if (meta.createdTitles.isNotEmpty) {
        _writeLine(out, 'Created tasks:');
        for (final title in meta.createdTitles) {
          _writeLine(out, '- $title');
        }
      }
      if (meta.skipped > 0) {
        _writeLine(out, 'Meta tasks skipped: ${meta.skipped}');
      }
    }
    final eval = dto.eval;
    if (eval != null) {
      _writeLine(
        out,
        'Eval run: ${eval.runId} (${eval.passed}/${eval.total}, ${eval.successRate.toStringAsFixed(1)}%)',
      );
      _writeLine(out, 'Eval output: ${eval.outputDir}');
      if (eval.results.isNotEmpty) {
        _writeLine(out, 'Eval cases:');
        for (final result in eval.results) {
          final status = result.passed ? 'PASS' : 'FAIL';
          final reason = result.reason == null ? '' : ' (${result.reason})';
          _writeLine(out, '- [$status] ${result.id}: ${result.title}$reason');
        }
      }
    }
    final tune = dto.selfTune;
    if (tune != null) {
      _writeLine(
        out,
        'Self-tune: ${tune.applied ? 'applied' : 'no change'} (${tune.successRate.toStringAsFixed(1)}%, ${tune.samples} samples)',
      );
      _writeLine(out, 'Self-tune reason: ${tune.reason}');
      if (tune.applied) {
        _writeLine(out, 'Self-tune before: ${_formatTuneMap(tune.before)}');
        _writeLine(out, 'Self-tune after: ${_formatTuneMap(tune.after)}');
      }
    }
  }

  void writeAutopilotHeal(IOSink out, AutopilotHealDto dto) {
    _writeLine(out, 'Autopilot incident heal completed.');
    _writeLine(out, 'Reason: ${dto.reason}');
    if (dto.detail != null && dto.detail!.trim().isNotEmpty) {
      _writeLine(out, 'Detail: ${dto.detail}');
    }
    _writeLine(out, 'Incident bundle: ${dto.bundlePath}');
    _writeLine(out, 'Recovered: ${dto.recovered}');
    _writeLine(out, 'Executed cycle: ${dto.executedCycle}');
    _writeLine(out, 'Review decision: ${_labelOrNone(dto.reviewDecision)}');
    _writeLine(out, 'Retry count: ${dto.retryCount}');
    _writeLine(out, 'Planned tasks added: ${dto.plannedTasksAdded}');
    _writeLine(out, 'Task blocked: ${dto.taskBlocked}');
    _writeLine(out, 'Activated task: ${dto.activatedTask}');
    _writeLine(out, 'Deactivated task: ${dto.deactivatedTask}');
    if (dto.activeTaskId != null && dto.activeTaskId!.trim().isNotEmpty) {
      _writeLine(out, 'Active task id: ${dto.activeTaskId}');
    }
    if (dto.activeTaskTitle != null && dto.activeTaskTitle!.trim().isNotEmpty) {
      _writeLine(out, 'Active task: ${dto.activeTaskTitle}');
    }
    if (dto.subtaskId != null && dto.subtaskId!.trim().isNotEmpty) {
      _writeLine(out, 'Subtask: ${dto.subtaskId}');
    }
  }

  String _labelOrNone(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '(none)';
    }
    return trimmed;
  }

  String _labelOrUnknown(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '(unknown)';
    }
    return trimmed;
  }

  String _formatTuneMap(Map<String, int> values) {
    if (values.isEmpty) {
      return '(none)';
    }
    final entries = values.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    return entries;
  }

  void _writeHealth(IOSink out, AppHealthSnapshotDto snapshot) {
    _writeLine(out, 'Health agent: ${_healthLine(snapshot.agent)}');
    _writeLine(out, 'Health allowlist: ${_healthLine(snapshot.allowlist)}');
    _writeLine(out, 'Health git: ${_healthLine(snapshot.git)}');
    _writeLine(out, 'Health review: ${_healthLine(snapshot.review)}');
  }

  void _writeTelemetry(
    IOSink out,
    AppRunTelemetryDto telemetry, {
    bool includeHealthSummary = true,
  }) {
    if (telemetry.errorClass != null && telemetry.errorClass!.isNotEmpty) {
      _writeLine(out, 'Last error class: ${telemetry.errorClass}');
    }
    if (telemetry.errorKind != null && telemetry.errorKind!.isNotEmpty) {
      _writeLine(out, 'Last error kind: ${telemetry.errorKind}');
    }
    if (telemetry.errorMessage != null && telemetry.errorMessage!.isNotEmpty) {
      _writeLine(out, 'Last error message: ${telemetry.errorMessage}');
    }
    if (telemetry.agentExitCode != null) {
      _writeLine(out, 'Agent exit code: ${telemetry.agentExitCode}');
    }
    if (telemetry.agentStderrExcerpt != null &&
        telemetry.agentStderrExcerpt!.isNotEmpty) {
      _writeLine(out, 'Agent stderr: ${telemetry.agentStderrExcerpt}');
    }
    if (includeHealthSummary && telemetry.healthSummary != null) {
      final summary = telemetry.healthSummary!;
      final trend = summary.failureTrend;
      _writeLine(
        out,
        'Failure trend: ${trend.direction} (recent=${trend.recentFailures}, previous=${trend.previousFailures}, window=${trend.windowSeconds}s)',
      );
      if (trend.dominantErrorKind != null &&
          trend.dominantErrorKind!.isNotEmpty) {
        _writeLine(out, 'Dominant failure kind: ${trend.dominantErrorKind}');
      }
      final retries = summary.retryDistribution;
      _writeLine(
        out,
        'Retry distribution: samples=${retries.samples}, 0=${retries.retry0}, 1=${retries.retry1}, 2+=${retries.retry2Plus}, max=${retries.maxRetry}',
      );
      final cooldown = summary.cooldown;
      _writeLine(
        out,
        cooldown.active
            ? 'Cooldown: active (${cooldown.remainingSeconds}s remaining of ${cooldown.totalSeconds}s)'
            : 'Cooldown: inactive',
      );
      if (cooldown.reason != null && cooldown.reason!.isNotEmpty) {
        _writeLine(out, 'Cooldown reason: ${cooldown.reason}');
      }
      if (cooldown.until != null && cooldown.until!.isNotEmpty) {
        _writeLine(out, 'Cooldown until: ${cooldown.until}');
      }
    }
    if (telemetry.recentEvents.isNotEmpty) {
      _writeLine(out, 'Recent events:');
      for (final event in telemetry.recentEvents) {
        _writeLine(out, _formatEventLine(event));
      }
    }
  }

  String _healthLine(AppHealthCheckDto check) {
    final status = check.ok ? 'OK' : 'FAIL';
    if (check.message.isEmpty) {
      return status;
    }
    return '$status - ${check.message}';
  }

  String _formatEventLine(AppRunLogEventDto event) {
    final time = event.timestamp ?? '-';
    final details = <String>[
      if (event.eventId != null && event.eventId!.isNotEmpty)
        'event_id=${event.eventId}',
      if (event.correlationId != null && event.correlationId!.isNotEmpty)
        'correlation_id=${event.correlationId}',
    ];
    final data = event.correlation;
    if (data != null) {
      for (final key in const [
        'task_id',
        'subtask_id',
        'step_id',
        'attempt_id',
        'review_id',
      ]) {
        final value = data[key];
        if (value == null) {
          continue;
        }
        final text = value.toString().trim();
        if (text.isEmpty) {
          continue;
        }
        details.add('$key=$text');
      }
    }
    final message = event.message?.trim();
    if (message != null && message.isNotEmpty) {
      details.add(message);
    }
    final suffix = details.isEmpty ? '' : ' - ${details.join(', ')}';
    return '  $time ${event.event}$suffix';
  }

  void _writeLine(IOSink out, Object? value) {
    final text = value?.toString() ?? '';
    out.writeln(_redactionService.sanitizeText(text).value);
  }
}
