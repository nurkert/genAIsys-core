// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../../../core/app/app.dart';
import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'health_check_row.dart';
import 'summary_row.dart';

class DetailsTab extends StatelessWidget {
  const DetailsTab({
    super.key,
    required this.strings,
    required this.status,
    required this.currentTask,
    required this.currentSubtask,
    required this.queue,
    required this.maxTaskRetries,
    required this.maxFailures,
    required this.stepSleepSeconds,
    required this.idleSleepSeconds,
  });

  final DesktopStrings strings;
  final AutopilotStatusDto? status;
  final String currentTask;
  final String currentSubtask;
  final List<String> queue;
  final int? maxTaskRetries;
  final int? maxFailures;
  final int? stepSleepSeconds;
  final int? idleSleepSeconds;

  @override
  Widget build(BuildContext context) {
    final AutopilotStepSummaryDto? step = status?.lastStepSummary;
    final AppHealthSnapshotDto? health = status?.health;

    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.space14),
      decoration: UiSurfaceStyles.panel(
        context,
        tone: DesktopSurfaceTone.muted,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.autopilotRuntimeSummaryTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UiChromeConfig.space12),
            SummaryRow(label: 'Current task', value: currentTask),
            SummaryRow(label: 'Current subtask', value: currentSubtask),
            SummaryRow(label: 'Queue size', value: '${queue.length}'),
            SummaryRow(label: 'PID', value: status?.pid?.toString() ?? '-'),
            SummaryRow(label: 'Started at', value: _time(status?.startedAt)),
            SummaryRow(label: 'Last loop', value: _time(status?.lastLoopAt)),
            SummaryRow(
              label: 'Last decision',
              value: _fallback(step?.decision),
            ),
            SummaryRow(label: 'Last event', value: _fallback(step?.event)),
            SummaryRow(label: 'Last step', value: _fallback(step?.stepId)),
            const SizedBox(height: UiChromeConfig.space10),
            Text(
              strings.autopilotHealthChecksTitle,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UiChromeConfig.space8),
            HealthCheckRow(label: 'Agent', ok: health?.agent.ok ?? false),
            HealthCheckRow(
              label: 'Allowlist',
              ok: health?.allowlist.ok ?? false,
            ),
            HealthCheckRow(label: 'Git', ok: health?.git.ok ?? false),
            HealthCheckRow(label: 'Review', ok: health?.review.ok ?? false),
            const SizedBox(height: UiChromeConfig.space10),
            Text(
              strings.autopilotLoopConfigTitle,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UiChromeConfig.space8),
            SummaryRow(label: 'Step sleep', value: _seconds(stepSleepSeconds)),
            SummaryRow(label: 'Idle sleep', value: _seconds(idleSleepSeconds)),
            SummaryRow(label: 'Max retries', value: _int(maxTaskRetries)),
            SummaryRow(label: 'Max failures', value: _int(maxFailures)),
            const SizedBox(height: UiChromeConfig.space10),
            Text(
              strings.autopilotLastErrorTitle,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UiChromeConfig.space6),
            Text(
              _fallback(status?.lastError),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _time(String? value) {
    final DateTime? parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) {
      return _fallback(value);
    }
    final DateTime local = parsed.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _fallback(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '-' : normalized;
  }

  String _seconds(int? value) {
    if (value == null) {
      return '-';
    }
    return '${value}s';
  }

  String _int(int? value) {
    if (value == null) {
      return '-';
    }
    return '$value';
  }
}
