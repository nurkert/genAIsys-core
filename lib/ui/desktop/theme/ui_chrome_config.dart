// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

/// Single source of truth for shell geometry/chrome values.
///
/// Change values here to update the full desktop shell consistently.
class UiChromeConfig {
  const UiChromeConfig._();

  // 4pt base spacing scale.
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space18 = 18;
  static const double space20 = 20;
  static const double space22 = 22;
  static const double space24 = 24;

  static const double windowInset = 14;
  static const double panelRadius = 20;
  static const double sidebarRadius = 18;
  static const double cardRadius = 16;
  static const double controlRadius = 12;

  static const double panelGap = 14;
  static const double rightSidebarWidth = 292;
  static const double leftSidebarExpandedWidth = 238;

  static const EdgeInsets panelPadding = EdgeInsets.all(space22);

  static const double topInsetMac = 10;
  static const double topBarHeightMac = 32;
  static const double topBarHeightDesktop = 40;
  static const double topBarHorizontalInsetDesktop = windowInset;
  static const double topBarEdgeInset = 6;

  static const double topBarWindowControlsInsetMac = 84;
  static const double topBarWindowControlsInsetMacFullscreen = topBarEdgeInset;
  static const double topBarWindowControlsInsetWindows = 138;
  static const double topBarWindowControlsInsetLinux = 116;
  static const double topBarWindowControlsInsetDesktop = 100;

  static const double toolbarIconButtonSize = 28;
  static const double toolbarIconSize = 18;
  static const double toolbarIconSpacing = 8;
  static const double toolbarIconSplashRadius = 16;

  // Toggle switch geometry (desktop custom switch).
  static const double toggleSwitchWidth = 46;
  static const double toggleSwitchHeight = 28;
  static const double toggleSwitchPadding = 3;
  static const Duration toggleSwitchDuration = Duration(milliseconds: 220);
  static const Curve toggleSwitchCurve = Curves.easeOutCubic;

  static const double sidebarOuterTopPadding = 12;
  static const double sidebarOuterBottomPadding = 10;
  static const double sidebarListHorizontalPadding = 12;
  static const double sidebarItemGap = 6;
  static const double sidebarItemHeight = 40;
  static const double sidebarItemHorizontalPadding = 10;
  static const double sidebarItemRadius = 10;
  static const double sidebarItemIconSize = 18;
  static const double sidebarItemContentGap = 10;
  static const double sidebarPanelPadding = 14;

  static const double dashboardSectionGap = 18;
  static const double dashboardSplitGap = 14;
  static const double dashboardStatsGap = 12;
  static const double dashboardStatsCompactGap = 10;
  static const double dashboardStatCardMinHeight = 90;
  static const double dashboardStatCardPadding = 14;
  static const double dashboardStatTitleGap = 6;
  static const double dashboardStatDeltaGap = 8;
  static const double dashboardHeaderWrapSpacing = 12;
  static const double dashboardHeaderWrapRunSpacing = 10;
  static const double dashboardHeaderSubtitleGap = 4;
  static const double dashboardActivityItemVerticalPadding = 6;
  static const double dashboardListCardPadding = 12;
  static const double dashboardFormCardPadding = 12;
  static const double dashboardFormFieldGap = 8;
  static const double dashboardFormActionGap = 10;

  static double topInsetFor(TargetPlatform platform) {
    return platform == TargetPlatform.macOS ? topInsetMac : windowInset;
  }

  static double topBarHeightFor(TargetPlatform platform) {
    return platform == TargetPlatform.macOS
        ? topBarHeightMac
        : topBarHeightDesktop;
  }

  static double topBarLeadingInsetFor({
    required TargetPlatform platform,
    required bool fullscreen,
  }) {
    if (platform != TargetPlatform.macOS) {
      return topBarEdgeInset;
    }
    return fullscreen
        ? topBarWindowControlsInsetMacFullscreen
        : topBarWindowControlsInsetMac;
  }

  // Kanban board geometry.
  static const double kanbanCardGap = 8;
  static const double kanbanEdgeGap = 4;
  static const double kanbanAutoScrollZone = 40;
  static const double kanbanAutoScrollMaxSpeed = 300;
  static const double kanbanInsertionHysteresisRatio = 0.25;

  static double topBarHorizontalInsetFor({
    required TargetPlatform platform,
    required bool fullscreen,
  }) {
    if (platform == TargetPlatform.macOS && fullscreen) {
      return topBarHorizontalInsetDesktop;
    }
    return topBarHorizontalInsetDesktop;
  }

  // ── Settings surface ──────────────────────────────────────────────────
  /// Width of the settings group rail.
  static const double settingsGroupRailWidth = 176;

  /// Below this content width the group rail is replaced by a dropdown, so the
  /// setting rows keep enough room for their controls.
  static const double settingsRailBreakpoint = 760;

  /// Below this row width a setting's control moves onto its own line.
  static const double settingsRowStackBreakpoint = 460;

  static const double settingsControlWidth = 190;
  static const double settingsNumericControlWidth = 130;

  /// Reserved width for the per-setting restore button, kept even when the
  /// button is absent so controls stay on one vertical line.
  static const double settingsResetSlotWidth = 32;
}
