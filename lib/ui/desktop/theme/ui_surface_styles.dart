// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import 'premium_white_bronze_tokens.dart';
import 'ui_chrome_config.dart';

/// Shared surface styles so workspace UI uses one palette/depth language.
///
/// This keeps cards, panels, chips, and column containers consistent and avoids
/// per-widget border tuning.
enum DesktopSurfaceTone { base, soft, muted, strong, accent }

class UiSurfaceStyles {
  const UiSurfaceStyles._();

  static Color color(BuildContext context, DesktopSurfaceTone tone) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      DesktopSurfaceTone.base =>
        dark
            ? PremiumWhiteBronzeTokens.darkSurface
            : PremiumWhiteBronzeTokens.surface,
      DesktopSurfaceTone.soft =>
        dark
            ? PremiumWhiteBronzeTokens.darkSurfaceSoft
            : PremiumWhiteBronzeTokens.surfaceSoft,
      DesktopSurfaceTone.muted =>
        dark
            ? PremiumWhiteBronzeTokens.darkSurfaceMuted
            : PremiumWhiteBronzeTokens.surfaceMuted,
      DesktopSurfaceTone.strong =>
        dark
            ? PremiumWhiteBronzeTokens.darkSurfaceStrong
            : PremiumWhiteBronzeTokens.surfaceStrong,
      DesktopSurfaceTone.accent =>
        dark
            ? PremiumWhiteBronzeTokens.darkSurfaceAccent
            : PremiumWhiteBronzeTokens.surfaceAccent,
    };
  }

  static List<BoxShadow> shadow(BuildContext context, {bool elevated = false}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (elevated) {
      return dark
          ? PremiumWhiteBronzeTokens.elevatedSurfaceShadowDark
          : PremiumWhiteBronzeTokens.elevatedSurfaceShadow;
    }
    return dark
        ? PremiumWhiteBronzeTokens.softSurfaceShadowDark
        : PremiumWhiteBronzeTokens.softSurfaceShadow;
  }

  static BoxDecoration panel(
    BuildContext context, {
    DesktopSurfaceTone tone = DesktopSurfaceTone.base,
    BorderRadiusGeometry? borderRadius,
    bool elevated = true,
    bool shadows = true,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: gradient == null ? color(context, tone) : null,
      gradient: gradient,
      borderRadius:
          borderRadius ?? BorderRadius.circular(UiChromeConfig.cardRadius),
      boxShadow: shadows ? shadow(context, elevated: elevated) : null,
    );
  }

  static BoxDecoration pill(
    BuildContext context, {
    DesktopSurfaceTone tone = DesktopSurfaceTone.soft,
  }) {
    return BoxDecoration(
      color: color(context, tone),
      borderRadius: BorderRadius.circular(999),
    );
  }

  static Color mutedOnSurface(
    BuildContext context, {
    double lightAlpha = 0.74,
    double darkAlpha = 0.82,
  }) {
    return Theme.of(context).colorScheme.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark
          ? darkAlpha
          : lightAlpha,
    );
  }

  static Color shellBackground(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? PremiumWhiteBronzeTokens.projectShellBackgroundDark
        : PremiumWhiteBronzeTokens.projectShellBackground;
  }

  static Color sidebarSurface(
    BuildContext context, {
    Color? lightOverride,
    Color? darkOverride,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return darkOverride ?? PremiumWhiteBronzeTokens.sidebarDarkSurface;
    }
    return lightOverride ?? PremiumWhiteBronzeTokens.sidebarLightSurface;
  }

  static Color sidebarBorder(
    BuildContext context, {
    Color? lightOverride,
    Color? darkOverride,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return darkOverride ?? PremiumWhiteBronzeTokens.sidebarDarkBorder;
    }
    return lightOverride ?? PremiumWhiteBronzeTokens.sidebarLightBorder;
  }
}
