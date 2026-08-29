// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../controllers/project_workspace_controller.dart';
import '../../models/dashboard_models.dart';
import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_motion_config.dart';
import 'workspaces/autopilot_workspace_view.dart';
import 'workspaces/backlog_workspace_view.dart';
import 'workspaces/chat_workspace_view.dart';
import 'workspaces/dashboard_workspace_view.dart';
import 'workspaces/settings_workspace_view.dart';
import 'workspaces/reports_workspace_view.dart';

/// Manages workspace views with an [IndexedStack] so that switching tabs
/// preserves widget state (scroll position, input text, animation controllers).
///
/// Views are lazily built on first visit and then kept alive.
class MainContentPanel extends StatefulWidget {
  const MainContentPanel({
    super.key,
    required this.controller,
    required this.topCornerRadius,
    required this.leftSidebarVisible,
    required this.rightSidebarVisible,
    required this.selectedSection,
    this.onBacklogCreateRequested,
  });

  final ProjectWorkspaceController controller;
  final double topCornerRadius;
  final bool leftSidebarVisible;
  final bool rightSidebarVisible;
  final DesktopPrimarySection selectedSection;
  final VoidCallback? onBacklogCreateRequested;

  @override
  State<MainContentPanel> createState() => _MainContentPanelState();
}

class _MainContentPanelState extends State<MainContentPanel> {
  /// Tracks which sections have been visited at least once (lazy init).
  final Set<DesktopPrimarySection> _visitedSections = <DesktopPrimarySection>{};

  @override
  void initState() {
    super.initState();
    _visitedSections.add(widget.selectedSection);
  }

  @override
  void didUpdateWidget(covariant MainContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visitedSections.add(widget.selectedSection);
  }

  int _indexFor(DesktopPrimarySection section) => section.index;

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _indexFor(widget.selectedSection);

    // Dashboard gets its own container styling (no _WorkspaceSurfaceFrame).
    // All other views share the same surface frame.
    return IndexedStack(
      index: currentIndex,
      children: <Widget>[
        for (final DesktopPrimarySection section
            in DesktopPrimarySection.values)
          _visitedSections.contains(section)
              ? _buildSectionView(section)
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildSectionView(DesktopPrimarySection section) {
    switch (section) {
      case DesktopPrimarySection.dashboard:
        return DashboardWorkspaceView(
          controller: widget.controller,
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
        );
      case DesktopPrimarySection.chat:
        return _WorkspaceSurfaceFrame(
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
          child: ChatWorkspaceView(controller: widget.controller),
        );
      case DesktopPrimarySection.backlog:
        return _WorkspaceSurfaceFrame(
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
          child: BacklogWorkspaceView(
            controller: widget.controller,
            onCreateTaskRequested: widget.onBacklogCreateRequested,
          ),
        );
      case DesktopPrimarySection.reports:
        return _WorkspaceSurfaceFrame(
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
          child: ReportsWorkspaceView(controller: widget.controller),
        );
      case DesktopPrimarySection.autopilot:
        return _WorkspaceSurfaceFrame(
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
          child: AutopilotWorkspaceView(controller: widget.controller),
        );
      case DesktopPrimarySection.projectSettings:
        return _WorkspaceSurfaceFrame(
          topCornerRadius: widget.topCornerRadius,
          leftSidebarVisible: widget.leftSidebarVisible,
          rightSidebarVisible: widget.rightSidebarVisible,
          child: SettingsWorkspaceView(controller: widget.controller),
        );
    }
  }
}

class _WorkspaceSurfaceFrame extends StatelessWidget {
  const _WorkspaceSurfaceFrame({
    required this.topCornerRadius,
    required this.leftSidebarVisible,
    required this.rightSidebarVisible,
    required this.child,
  });

  final double topCornerRadius;
  final bool leftSidebarVisible;
  final bool rightSidebarVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: UiMotionConfig.shellDuration,
      curve: UiMotionConfig.shellCurve,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(leftSidebarVisible ? topCornerRadius : 0),
          topRight: Radius.circular(rightSidebarVisible ? topCornerRadius : 0),
        ),
      ),
      child: Padding(padding: UiChromeConfig.panelPadding, child: child),
    );
  }
}
