// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../localization/desktop_strings.dart';
import '../models/project_hub_models.dart';
import '../theme/premium_white_bronze_tokens.dart';
import '../theme/ui_chrome_config.dart';
import '../theme/ui_surface_styles.dart';
import 'common/glass_panel.dart';
import 'common/metal_sidebar_button.dart';

class ProjectHubSidebar extends StatelessWidget {
  const ProjectHubSidebar({
    super.key,
    required this.cornerRadius,
    required this.strings,
    required this.selectedSection,
    required this.onSelectSection,
    required this.onOpenSettings,
    this.lightGlassColor,
    this.darkGlassColor,
    this.lightBorderColor,
    this.darkBorderColor,
  });

  final double cornerRadius;
  final DesktopStrings strings;
  final ProjectHubSection selectedSection;
  final ValueChanged<ProjectHubSection> onSelectSection;
  final VoidCallback onOpenSettings;
  final Color? lightGlassColor;
  final Color? darkGlassColor;
  final Color? lightBorderColor;
  final Color? darkBorderColor;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
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

    final List<_HubSidebarItem> navItems = <_HubSidebarItem>[
      _HubSidebarItem(
        section: ProjectHubSection.projects,
        icon: PhosphorIconsRegular.folderSimple,
        label: strings.hubNavProjects,
      ),
      _HubSidebarItem(
        section: ProjectHubSection.chat,
        icon: PhosphorIconsRegular.chatCenteredDots,
        label: strings.hubNavChat,
      ),
      _HubSidebarItem(
        section: ProjectHubSection.settings,
        icon: PhosphorIconsRegular.gearSix,
        label: strings.hubNavSettings,
      ),
      _HubSidebarItem(
        section: ProjectHubSection.learn,
        icon: PhosphorIconsRegular.graduationCap,
        label: strings.hubNavLearn,
      ),
    ];

    return GlassPanel(
      borderRadius: cornerRadius,
      lightColor: background,
      darkColor: background,
      lightBorderColor: border,
      darkBorderColor: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: UiChromeConfig.sidebarOuterTopPadding),
          // Navigation items.
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(
                left: UiChromeConfig.sidebarListHorizontalPadding,
                right: UiChromeConfig.sidebarListHorizontalPadding,
                top: UiChromeConfig.space4,
              ),
              itemCount: navItems.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: UiChromeConfig.sidebarItemGap),
              itemBuilder: (BuildContext context, int index) {
                final _HubSidebarItem item = navItems[index];
                return MetalSidebarButton(
                  icon: item.icon,
                  label: item.label,
                  selected: item.section == selectedSection,
                  darkMode: dark,
                  onPressed: () => onSelectSection(item.section),
                  gradientSeed: item.section.index + 401,
                  textureSeed: 600 + item.section.index,
                  textureStrength: 0.52,
                  specularIntensity: 0.70,
                );
              },
            ),
          ),
          // Bottom gear icon for global settings.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiChromeConfig.sidebarListHorizontalPadding,
            ),
            child: IconButton(
              tooltip: strings.generalSettingsAction,
              onPressed: onOpenSettings,
              icon: Icon(
                PhosphorIconsRegular.gearSix,
                size: UiChromeConfig.sidebarItemIconSize,
                color: dark
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.64)
                    : PremiumWhiteBronzeTokens.onSurface.withValues(
                        alpha: 0.64,
                      ),
              ),
            ),
          ),
          const SizedBox(height: UiChromeConfig.sidebarOuterBottomPadding),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar item model
// ---------------------------------------------------------------------------

class _HubSidebarItem {
  const _HubSidebarItem({
    required this.section,
    required this.icon,
    required this.label,
  });

  final ProjectHubSection section;
  final IconData icon;
  final String label;
}
