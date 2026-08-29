// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../controllers/project_workspace_controller.dart';
import '../../models/dashboard_models.dart';
import '../../theme/ui_surface_styles.dart';
import '../common/glass_panel.dart';
import 'right_sidebar_panels.dart';

class RightSidebar extends StatelessWidget {
  const RightSidebar({
    super.key,
    required this.cornerRadius,
    required this.selectedSection,
    required this.controller,
    this.lightGlassColor,
    this.darkGlassColor,
    this.lightBorderColor,
    this.darkBorderColor,
  });

  final double cornerRadius;
  final DesktopPrimarySection selectedSection;
  final ProjectWorkspaceController controller;
  final Color? lightGlassColor;
  final Color? darkGlassColor;
  final Color? lightBorderColor;
  final Color? darkBorderColor;

  @override
  Widget build(BuildContext context) {
    final Color background = UiSurfaceStyles.sidebarSurface(
      context,
      lightOverride: lightGlassColor,
      darkOverride: darkGlassColor,
    );
    final Color border = UiSurfaceStyles.sidebarBorder(
      context,
      lightOverride: lightBorderColor,
      darkOverride: darkBorderColor,
    );

    return GlassPanel(
      borderRadius: cornerRadius,
      lightColor: background,
      darkColor: background,
      lightBorderColor: border,
      darkBorderColor: border,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: SectionSidebarContent(
          key: ValueKey<DesktopPrimarySection>(selectedSection),
          section: selectedSection,
          controller: controller,
        ),
      ),
    );
  }
}
