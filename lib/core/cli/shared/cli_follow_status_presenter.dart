// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../app/app.dart';
import '../output/cli_output.dart';

String formatCliFollowStatus(
  AutopilotStatusDto dto, {
  CliOutput? output,
  DateTime? nowUtc,
}) {
  final o = output ?? CliOutput.plain;
  final ts = o.timestamp(nowUtc ?? DateTime.now().toLocal());

  if (o.isRich) {
    final running =
        dto.autopilotRunning ? o.bold('RUNNING') : o.dim('STOPPED');
    final active = dto.lastStepSummary?.taskId ?? '-';
    final hitl =
        dto.hitlGatePending ? '  ${o.yellow('⏸ HITL')}' : '';
    return '$ts  $running  ${o.bullet}  $active'
        '  ${o.bullet}  ${dto.consecutiveFailures} failures$hitl';
  } else {
    final running = dto.autopilotRunning ? 'RUNNING' : 'STOPPED';
    final lastLoop = o.parseTimestamp(dto.lastLoopAt);
    final active =
        dto.lastStepSummary?.taskId ?? dto.lastStepSummary?.stepId ?? '-';
    final lastError = dto.lastError ?? dto.telemetry.errorMessage ?? '';
    final errorPart = lastError.trim().isEmpty
        ? ''
        : ' error="${lastError.trim()}"';
    final hitlPart =
        dto.hitlGatePending ? ' hitl_pending=true' : '';
    return '$ts status=$running last_loop=$lastLoop'
        ' active="$active" failures=${dto.consecutiveFailures}$errorPart$hitlPart';
  }
}

void writeCliFollowStatus(
  IOSink out,
  AutopilotStatusDto dto, {
  CliOutput? output,
  DateTime? nowUtc,
}) {
  out.writeln(formatCliFollowStatus(dto, output: output, nowUtc: nowUtc));
}
