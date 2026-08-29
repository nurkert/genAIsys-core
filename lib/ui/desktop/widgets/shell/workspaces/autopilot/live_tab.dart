// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../../../core/app/app.dart';
import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'autopilot_stage_snapshot.dart';
import 'context_value.dart';
import 'stage_pill.dart';

class LiveTab extends StatelessWidget {
  const LiveTab({
    super.key,
    required this.strings,
    required this.stage,
    required this.running,
    required this.blocked,
    required this.blockerDetail,
    required this.currentTask,
    required this.currentSubtask,
    required this.queue,
    required this.latestEvent,
  });

  final DesktopStrings strings;
  final AutopilotStageSnapshot stage;
  final bool running;
  final bool blocked;
  final String? blockerDetail;
  final String currentTask;
  final String currentSubtask;
  final List<String> queue;
  final AppRunLogEventDto? latestEvent;

  static const List<String> _orderedStages = <String>[
    'Preflight',
    'Planning',
    'Execution',
    'Quality Gate',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final Color muted = UiSurfaceStyles.mutedOnSurface(context);
    final double progress = running
        ? ((stage.index + 1) / _orderedStages.length)
        : 0;
    final int? plannedAdditions = _intOrNull(
      latestEvent?.data?['planned_tasks_added'],
    );
    final String nextQueuedSubtask = queue.isEmpty ? '-' : queue.first;

    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.space14),
      decoration: UiSurfaceStyles.panel(context, tone: DesktopSurfaceTone.soft),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              strings.autopilotTabLive,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: UiChromeConfig.space4),
                            Text(
                              blocked
                                  ? 'Execution is blocked and needs intervention.'
                                  : 'Current execution stage and immediate next work item.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                      StagePill(
                        label: stage.label,
                        blocked: blocked,
                        running: running,
                      ),
                    ],
                  ),
                  const SizedBox(height: UiChromeConfig.space12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(height: UiChromeConfig.space8),
                  Wrap(
                    spacing: UiChromeConfig.space6,
                    runSpacing: UiChromeConfig.space6,
                    children: List<Widget>.generate(_orderedStages.length, (
                      int index,
                    ) {
                      final bool active = stage.index == index && running;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiChromeConfig.space8,
                          vertical: UiChromeConfig.space4,
                        ),
                        decoration: UiSurfaceStyles.pill(
                          context,
                          tone: active
                              ? DesktopSurfaceTone.strong
                              : DesktopSurfaceTone.base,
                        ),
                        child: Text(
                          _orderedStages[index],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      );
                    }),
                  ),
                  if (blocked &&
                      blockerDetail != null &&
                      blockerDetail!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: UiChromeConfig.space10,
                      ),
                      child: Text(
                        blockerDetail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: UiChromeConfig.space12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ContextValue(
                          label: strings.autopilotCurrentTaskLabel,
                          value: currentTask,
                        ),
                      ),
                      const SizedBox(width: UiChromeConfig.space10),
                      Expanded(
                        child: ContextValue(
                          label: strings.autopilotCurrentSubtaskLabel,
                          value: currentSubtask,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiChromeConfig.space8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ContextValue(
                          label: 'Next queued subtask',
                          value: nextQueuedSubtask,
                        ),
                      ),
                      const SizedBox(width: UiChromeConfig.space10),
                      Expanded(
                        child: ContextValue(
                          label: 'Queue depth',
                          value: '${queue.length}',
                          trailing: plannedAdditions != null
                              ? Text(
                                  '+$plannedAdditions planned',
                                  style: Theme.of(context).textTheme.labelSmall,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
