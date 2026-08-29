// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../core/app/app.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../localization/desktop_strings.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../common/bronze_button.dart';
import 'autopilot/autopilot_stage_snapshot.dart';
import 'autopilot/autopilot_tab_bar.dart';
import 'autopilot/collapsible_control_strip.dart';
import 'autopilot/compact_status_bar.dart';
import 'autopilot/details_tab.dart';
import 'autopilot/live_tab.dart';
import 'autopilot/timeline_tab.dart';
import 'workspace_header.dart';

class AutopilotWorkspaceView extends StatefulWidget {
  const AutopilotWorkspaceView({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  State<AutopilotWorkspaceView> createState() => _AutopilotWorkspaceViewState();
}

class _AutopilotWorkspaceViewState extends State<AutopilotWorkspaceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Defer live-sync attachment so the immediate poll doesn't compete
    // with the first-frame layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.attachAutopilotLiveSync();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AutopilotWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.detachAutopilotLiveSync();
    widget.controller.attachAutopilotLiveSync();
  }

  @override
  void dispose() {
    widget.controller.detachAutopilotLiveSync();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DesktopStrings strings = context.strings;
    final ProjectWorkspaceController controller = widget.controller;

    return ValueListenableBuilder<AutopilotStatusDto?>(
      valueListenable: controller.autopilotStatusNotifier,
      builder:
          (BuildContext context, AutopilotStatusDto? status, Widget? child) {
            final AppRunLogEventDto? latestEvent = _latestEvent(status);
            final AutopilotStageSnapshot stage =
                AutopilotStageSnapshot.fromStatus(
                  strings: strings,
                  status: status,
                  latestEvent: latestEvent,
                );
            final String currentTask = _activeTaskLabel(controller, status);
            final String currentSubtask =
                status?.currentSubtask?.trim().isNotEmpty == true
                ? status!.currentSubtask!.trim()
                : _fallback(status?.lastStepSummary?.subtaskId);
            final List<String> queue = status?.subtaskQueue ?? const <String>[];
            final bool running = status?.autopilotRunning ?? false;
            final bool blocked = stage.blocked;
            final String? blockerDetail = _blockerDetail(status, latestEvent);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Header + Play/Pause ──
                Row(
                  children: <Widget>[
                    Expanded(
                      child: WorkspaceHeader(
                        title: strings.autopilotTitle,
                        subtitle: strings.autopilotSubtitle,
                        seed: 81,
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: controller.actionInProgressNotifier,
                      builder:
                          (BuildContext context, bool busy, Widget? child) {
                            return BronzeButton(
                              label: running
                                  ? strings.autopilotPauseAction
                                  : strings.autopilotPlayAction,
                              icon: running
                                  ? PhosphorIconsRegular.pause
                                  : PhosphorIconsRegular.play,
                              onPressed: busy
                                  ? null
                                  : () {
                                      if (running) {
                                        unawaited(controller.stopAutopilot());
                                        return;
                                      }
                                      unawaited(controller.runAutopilotStep());
                                    },
                              glow: true,
                            );
                          },
                    ),
                  ],
                ),
                const SizedBox(height: UiChromeConfig.space12),

                // ── Compact Status Bar ──
                CompactStatusBar(
                  strings: strings,
                  stage: stage,
                  running: running,
                  blocked: blocked,
                  cycleCount: controller.status?.cycleCount ?? 0,
                  retries: status?.consecutiveFailures ?? 0,
                ),
                const SizedBox(height: UiChromeConfig.space12),

                // ── Collapsible Control Strip ──
                CollapsibleControlStrip(
                  controller: controller,
                  strings: strings,
                ),
                const SizedBox(height: UiChromeConfig.space12),

                // ── Tab Bar ──
                AutopilotTabBar(
                  controller: _tabController,
                  strings: strings,
                ),
                const SizedBox(height: UiChromeConfig.space12),

                // ── Tab Content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      LiveTab(
                        strings: strings,
                        stage: stage,
                        running: running,
                        blocked: blocked,
                        blockerDetail: blockerDetail,
                        currentTask: currentTask,
                        currentSubtask: currentSubtask,
                        queue: queue,
                        latestEvent: latestEvent,
                      ),
                      TimelineTab(
                        events:
                            status?.telemetry.recentEvents ??
                            const <AppRunLogEventDto>[],
                      ),
                      DetailsTab(
                        strings: strings,
                        status: status,
                        currentTask: currentTask,
                        currentSubtask: currentSubtask,
                        queue: queue,
                        maxTaskRetries:
                            controller.settingsDraft?.autopilotMaxTaskRetries,
                        maxFailures:
                            controller.settingsDraft?.autopilotMaxFailures,
                        stepSleepSeconds:
                            controller.settingsDraft?.autopilotStepSleepSeconds,
                        idleSleepSeconds:
                            controller.settingsDraft?.autopilotIdleSleepSeconds,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
    );
  }

  AppRunLogEventDto? _latestEvent(AutopilotStatusDto? status) {
    final List<AppRunLogEventDto> events =
        status?.telemetry.recentEvents ?? const <AppRunLogEventDto>[];
    if (events.isEmpty) {
      return null;
    }
    return events.last;
  }

  String _activeTaskLabel(
    ProjectWorkspaceController controller,
    AutopilotStatusDto? status,
  ) {
    final String? fromStatus = controller.status?.activeTaskTitle?.trim();
    if (fromStatus != null && fromStatus.isNotEmpty) {
      return fromStatus;
    }

    final String? taskId = status?.lastStepSummary?.taskId?.trim();
    if (taskId != null && taskId.isNotEmpty) {
      for (final AppTaskDto task in controller.taskList.tasks) {
        if (task.id != taskId) {
          continue;
        }
        if (task.title.trim().isNotEmpty) {
          return task.title.trim();
        }
        break;
      }
    }

    return '-';
  }

  String _fallback(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '-' : normalized;
  }

  String? _blockerDetail(
    AutopilotStatusDto? status,
    AppRunLogEventDto? latestEvent,
  ) {
    final String? stall = status?.stallDetail?.trim();
    if (stall != null && stall.isNotEmpty) {
      return stall;
    }
    final String? reason = status?.stallReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    final String? error = status?.lastError?.trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
    final String? message = latestEvent?.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return null;
  }
}
