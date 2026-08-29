// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../localization/desktop_strings.dart';
import '../models/dashboard_models.dart';

class MockDashboardData {
  const MockDashboardData._();

  static const List<(DesktopPrimarySection, IconData, bool)>
  _navSpec = <(DesktopPrimarySection, IconData, bool)>[
    (DesktopPrimarySection.chat, PhosphorIconsRegular.chatCenteredDots, false),
    (DesktopPrimarySection.autopilot, PhosphorIconsRegular.rocketLaunch, false),
    (DesktopPrimarySection.backlog, PhosphorIconsRegular.kanban, false),
    (DesktopPrimarySection.dashboard, PhosphorIconsRegular.chartPie, false),
    (DesktopPrimarySection.reports, PhosphorIconsRegular.chartBar, false),
    (DesktopPrimarySection.projectSettings, PhosphorIconsRegular.gearSix, true),
  ];

  static const List<MetalKind> _statMetals = <MetalKind>[
    MetalKind.silver,
    MetalKind.gold,
    MetalKind.bronze,
  ];

  static List<SidebarNavItem> navItems(DesktopStrings strings) {
    return List<SidebarNavItem>.generate(_navSpec.length, (int index) {
      final (DesktopPrimarySection section, IconData icon, bool pinToBottom) =
          _navSpec[index];
      return SidebarNavItem(
        section: section,
        icon: icon,
        label: strings.navLabels[index],
        pinToBottom: pinToBottom,
      );
    }, growable: false);
  }

  static List<StatCardModel> stats(DesktopStrings strings) {
    return List<StatCardModel>.generate(strings.statCards.length, (int index) {
      final DesktopStatCopy copy = strings.statCards[index];
      return StatCardModel(
        title: copy.title,
        value: copy.value,
        delta: copy.delta,
        metal: _statMetals[index],
      );
    }, growable: false);
  }

  static List<ActivityEntry> activities(DesktopStrings strings) {
    return strings.activities
        .map((DesktopActivityCopy copy) {
          return ActivityEntry(
            avatar: copy.avatar,
            title: copy.title,
            subtitle: copy.subtitle,
          );
        })
        .toList(growable: false);
  }

  static List<TimelineEntry> timeline(DesktopStrings strings) {
    return strings.timelineEntries
        .map((String label) => TimelineEntry(label: label))
        .toList(growable: false);
  }

  static List<String> quickFilters(DesktopStrings strings) {
    return List<String>.of(strings.quickFilterLabels, growable: false);
  }
}
