// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../data/mock_dashboard_data.dart';
import '../../localization/desktop_localization.dart';
import '../../models/dashboard_models.dart';
import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_surface_styles.dart';
import '../common/glass_panel.dart';
import 'left_sidebar_item_button.dart';

class LeftSidebar extends StatelessWidget {
  const LeftSidebar({
    super.key,
    required this.cornerRadius,
    required this.selectedSection,
    required this.onSelectSection,
    this.lightGlassColor,
    this.darkGlassColor,
    this.lightBorderColor,
    this.darkBorderColor,
  });

  final double cornerRadius;
  final DesktopPrimarySection selectedSection;
  final ValueChanged<DesktopPrimarySection> onSelectSection;
  final Color? lightGlassColor;
  final Color? darkGlassColor;
  final Color? lightBorderColor;
  final Color? darkBorderColor;

  @override
  Widget build(BuildContext context) {
    final List<SidebarNavItem> navItems = MockDashboardData.navItems(
      context.strings,
    );
    final List<(int, SidebarNavItem)> topItems = navItems.indexed
        .where(((int, SidebarNavItem) entry) => !entry.$2.pinToBottom)
        .toList(growable: false);
    final List<(int, SidebarNavItem)> bottomItems = navItems.indexed
        .where(((int, SidebarNavItem) entry) => entry.$2.pinToBottom)
        .toList(growable: false);
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

    return GlassPanel(
      borderRadius: cornerRadius,
      lightColor: background,
      darkColor: background,
      lightBorderColor: border,
      darkBorderColor: border,
      child: Column(
        children: <Widget>[
          const SizedBox(height: UiChromeConfig.sidebarOuterTopPadding),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: UiChromeConfig.sidebarListHorizontalPadding,
              ),
              itemCount: topItems.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: UiChromeConfig.sidebarItemGap),
              itemBuilder: (BuildContext context, int index) {
                final (int itemIndex, SidebarNavItem item) = topItems[index];
                return LeftSidebarItemButton(
                  item: item,
                  index: itemIndex,
                  selected: selectedSection == item.section,
                  darkMode: dark,
                  onPressed: () => onSelectSection(item.section),
                );
              },
            ),
          ),
          if (bottomItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: UiChromeConfig.space8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UiChromeConfig.sidebarListHorizontalPadding,
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < bottomItems.length; i++) ...<Widget>[
                    Builder(
                      builder: (BuildContext context) {
                        final (int itemIndex, SidebarNavItem item) =
                            bottomItems[i];
                        // Settings item: render as a simple gear icon button
                        if (item.section ==
                            DesktopPrimarySection.projectSettings) {
                          final bool isSelected =
                              selectedSection == item.section;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Tooltip(
                              message: item.label,
                              child: IconButton(
                                icon: Icon(
                                  PhosphorIconsRegular.gearSix,
                                  size: 22,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : UiSurfaceStyles.mutedOnSurface(context),
                                ),
                                style: IconButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.08)
                                      : Colors.transparent,
                                ),
                                onPressed: () => onSelectSection(item.section),
                              ),
                            ),
                          );
                        }
                        return LeftSidebarItemButton(
                          item: item,
                          index: itemIndex,
                          selected: selectedSection == item.section,
                          darkMode: dark,
                          onPressed: () => onSelectSection(item.section),
                        );
                      },
                    ),
                    if (i != bottomItems.length - 1)
                      const SizedBox(height: UiChromeConfig.sidebarItemGap),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: UiChromeConfig.sidebarOuterBottomPadding),
        ],
      ),
    );
  }
}
