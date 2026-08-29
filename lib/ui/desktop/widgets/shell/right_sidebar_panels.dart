// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/app/app.dart';
import '../../controllers/project_workspace_controller.dart';
import '../../data/mock_dashboard_data.dart';
import '../../localization/desktop_localization.dart';
import '../../models/dashboard_models.dart';
import '../../models/workspace_models.dart';
import '../../theme/ui_chrome_config.dart';
import '../common/bronze_button.dart';

class SectionSidebarContent extends StatelessWidget {
  const SectionSidebarContent({
    super.key,
    required this.section,
    required this.controller,
  });

  final DesktopPrimarySection section;
  final ProjectWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return switch (section) {
      DesktopPrimarySection.chat => SimpleSidebarPanel(
        title: strings.chatTitle,
        subtitle: strings.chatSubtitle,
        body: Text(strings.chatWelcomeMessage),
      ),
      DesktopPrimarySection.backlog => BacklogSidebarPanel(
        controller: controller,
      ),
      DesktopPrimarySection.dashboard => const DashboardSidebarPanel(),
      DesktopPrimarySection.reports => SimpleSidebarPanel(
        title: strings.reportsTitle,
        subtitle: strings.reportsSubtitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.reportsRunLogTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UiChromeConfig.space8),
            Text(strings.reportsRunLogSearchHint),
          ],
        ),
      ),
      DesktopPrimarySection.autopilot => AutopilotSidebarPanel(
        controller: controller,
      ),
      DesktopPrimarySection.projectSettings => SimpleSidebarPanel(
        title: strings.projectSettingsTitle,
        subtitle: strings.projectSettingsSubtitle,
        body: Text(strings.projectSettingsPoliciesSubtitle),
      ),
    };
  }
}

class SimpleSidebarPanel extends StatelessWidget {
  const SimpleSidebarPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(UiChromeConfig.sidebarPanelPadding),
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: UiChromeConfig.space6),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: UiChromeConfig.space14),
        body,
      ],
    );
  }
}

class DashboardSidebarPanel extends StatelessWidget {
  const DashboardSidebarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final List<TimelineEntry> timelineItems = MockDashboardData.timeline(
      strings,
    );
    final List<String> quickFilterItems = MockDashboardData.quickFilters(
      strings,
    );
    return ListView(
      padding: const EdgeInsets.all(UiChromeConfig.sidebarPanelPadding),
      children: <Widget>[
        Text(strings.inspector, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: UiChromeConfig.sidebarItemGap),
        Text(strings.timeline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: UiChromeConfig.space8),
        for (final TimelineEntry item in timelineItems)
          MiniEvent(label: item.label),
        const Divider(height: UiChromeConfig.space24),
        Text(
          strings.quickFilters,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UiChromeConfig.space8),
        Wrap(
          spacing: UiChromeConfig.space8,
          runSpacing: UiChromeConfig.space8,
          children: quickFilterItems
              .map((String label) => Chip(label: Text(label)))
              .toList(growable: false),
        ),
        const SizedBox(height: UiChromeConfig.space16),
        BronzeButton(
          onPressed: () {},
          label: strings.runAction,
          icon: PhosphorIconsRegular.lightning,
          glow: true,
        ),
      ],
    );
  }
}

class BacklogSidebarPanel extends StatefulWidget {
  const BacklogSidebarPanel({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  State<BacklogSidebarPanel> createState() => _BacklogSidebarPanelState();
}

class _BacklogSidebarPanelState extends State<BacklogSidebarPanel> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  BacklogTaskPriority _priority = BacklogTaskPriority.p2;

  @override
  void initState() {
    super.initState();
    widget.controller.backlogComposerFocusRequestNotifier.addListener(
      _handleFocusRequest,
    );
    _handleFocusRequest();
  }

  @override
  void dispose() {
    widget.controller.backlogComposerFocusRequestNotifier.removeListener(
      _handleFocusRequest,
    );
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleFocusRequest() {
    if (!widget.controller.consumeBacklogComposerFocusRequest()) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_titleFocusNode);
    });
  }

  String _priorityLabel(BuildContext context, BacklogTaskPriority priority) {
    final strings = context.strings;
    return switch (priority) {
      BacklogTaskPriority.p1 => strings.backlogPriorityP1,
      BacklogTaskPriority.p2 => strings.backlogPriorityP2,
      BacklogTaskPriority.p3 => strings.backlogPriorityP3,
    };
  }

  Future<void> _createTask() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    await widget.controller.createTask(title: title, priority: _priority);
    if (!mounted) {
      return;
    }
    if (widget.controller.errorMessage == null) {
      _titleController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.actionInProgressNotifier,
      builder: (BuildContext context, bool busy, Widget? _) {
        return ValueListenableBuilder<({String? error, String? info})>(
          valueListenable: widget.controller.feedbackNotifier,
          builder:
              (
                BuildContext context,
                ({String? error, String? info}) feedback,
                Widget? _,
              ) {
                return ListView(
                  padding: const EdgeInsets.all(
                    UiChromeConfig.sidebarPanelPadding,
                  ),
                  children: <Widget>[
                    Text(
                      strings.backlogTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: UiChromeConfig.space6),
                    Text(
                      strings.backlogSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: UiChromeConfig.space14),
                    TextField(
                      key: const Key('rightSidebar.backlog.taskTitle'),
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: strings.backlogTaskTitleLabel,
                        hintText: strings.description,
                      ),
                      onSubmitted: (_) => unawaited(_createTask()),
                    ),
                    const SizedBox(height: UiChromeConfig.space10),
                    DropdownButtonFormField<BacklogTaskPriority>(
                      key: const Key('rightSidebar.backlog.priority'),
                      isExpanded: true,
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: strings.backlogPriorityLabel,
                      ),
                      items: BacklogTaskPriority.values
                          .map(
                            (BacklogTaskPriority priority) =>
                                DropdownMenuItem<BacklogTaskPriority>(
                                  value: priority,
                                  child: Text(
                                    _priorityLabel(context, priority),
                                  ),
                                ),
                          )
                          .toList(growable: false),
                      onChanged: busy
                          ? null
                          : (BacklogTaskPriority? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _priority = value;
                              });
                            },
                    ),
                    const SizedBox(height: UiChromeConfig.space12),
                    BronzeButton(
                      key: const Key('rightSidebar.backlog.createTask'),
                      onPressed: busy ? null : () => unawaited(_createTask()),
                      label: strings.create,
                      icon: PhosphorIconsRegular.plus,
                      glow: true,
                    ),
                    const SizedBox(height: UiChromeConfig.space12),
                    if (feedback.error != null)
                      Text(
                        feedback.error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (feedback.info != null)
                      Text(
                        feedback.info!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                );
              },
        );
      },
    );
  }
}

class AutopilotSidebarPanel extends StatelessWidget {
  const AutopilotSidebarPanel({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ValueListenableBuilder<AutopilotStatusDto?>(
      valueListenable: controller.autopilotStatusNotifier,
      builder: (BuildContext context, AutopilotStatusDto? status, Widget? _) {
        final bool running = status?.autopilotRunning ?? false;
        return ValueListenableBuilder<bool>(
          valueListenable: controller.actionInProgressNotifier,
          builder: (BuildContext context, bool busy, Widget? _) {
            return ListView(
              padding: const EdgeInsets.all(UiChromeConfig.sidebarPanelPadding),
              children: <Widget>[
                Text(
                  strings.autopilotTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: UiChromeConfig.space6),
                Text(
                  strings.autopilotSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: UiChromeConfig.space14),
                Text(
                  '${strings.autopilotStateLabel}: '
                  '${running ? strings.autopilotStatusRunning : strings.autopilotStatusPaused}',
                ),
                const SizedBox(height: UiChromeConfig.space8),
                Text(
                  '${strings.autopilotCurrentSubtaskLabel}: '
                  '${status?.currentSubtask ?? '-'}',
                ),
                const SizedBox(height: UiChromeConfig.space14),
                BronzeButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (running) {
                            unawaited(controller.stopAutopilot());
                            return;
                          }
                          unawaited(controller.runAutopilotStep());
                        },
                  label: running
                      ? strings.autopilotPauseAction
                      : strings.autopilotPlayAction,
                  icon: running
                      ? PhosphorIconsRegular.pause
                      : PhosphorIconsRegular.play,
                  glow: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MiniEvent extends StatelessWidget {
  const MiniEvent({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UiChromeConfig.space4),
      child: Row(
        children: <Widget>[
          const Icon(PhosphorIconsRegular.circle, size: UiChromeConfig.space10),
          const SizedBox(width: UiChromeConfig.space10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
