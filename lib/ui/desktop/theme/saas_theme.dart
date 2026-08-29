// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'metal_palette.dart';
import 'premium_white_bronze_tokens.dart';
import 'ui_chrome_config.dart';

class SaasTheme {
  static ThemeData light() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: PremiumWhiteBronzeTokens.primaryFallback,
          brightness: Brightness.light,
        ).copyWith(
          primary: PremiumWhiteBronzeTokens.primaryFallback,
          secondary: PremiumWhiteBronzeTokens.bronzeMid,
          tertiary: PremiumWhiteBronzeTokens.bronzeHighlight,
          surface: PremiumWhiteBronzeTokens.surface,
          surfaceContainerLowest: PremiumWhiteBronzeTokens.surface,
          surfaceContainerLow: PremiumWhiteBronzeTokens.surfaceSoft,
          surfaceContainer: PremiumWhiteBronzeTokens.surfaceMuted,
          surfaceContainerHigh: PremiumWhiteBronzeTokens.surfaceStrong,
          surfaceContainerHighest: PremiumWhiteBronzeTokens.surfaceAccent,
          onSurface: PremiumWhiteBronzeTokens.onSurface,
          outline: const Color(0x1A000000),
          outlineVariant: const Color(0x14000000),
          onPrimary: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: PremiumWhiteBronzeTokens.appBackground,
      canvasColor: PremiumWhiteBronzeTokens.appBackground,
      textTheme: _textTheme(Brightness.light),
      dividerTheme: const DividerThemeData(color: Color(0x16000000), space: 1),
      cardTheme: CardThemeData(
        color: PremiumWhiteBronzeTokens.surfaceSoft,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: const Color(0x0D000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
        ),
      ),
      inputDecorationTheme: _input(
        fillColor: PremiumWhiteBronzeTokens.surfaceMuted,
        focusColor: PremiumWhiteBronzeTokens.primaryFallback,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          ),
          backgroundColor: PremiumWhiteBronzeTokens.primaryFallback,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide.none,
          backgroundColor: PremiumWhiteBronzeTokens.surfaceMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PremiumWhiteBronzeTokens.surfaceMuted,
        selectedColor: PremiumWhiteBronzeTokens.surfaceAccent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  static ThemeData dark() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: MetalPalette.silver,
          brightness: Brightness.dark,
        ).copyWith(
          primary: PremiumWhiteBronzeTokens.darkPrimaryNeutral,
          secondary: const Color(0xFFD8B87A),
          tertiary: const Color(0xFFBA8458),
          surface: PremiumWhiteBronzeTokens.darkSurface,
          surfaceContainerLowest: PremiumWhiteBronzeTokens.darkSurface,
          surfaceContainerLow: PremiumWhiteBronzeTokens.darkSurfaceSoft,
          surfaceContainer: PremiumWhiteBronzeTokens.darkSurfaceMuted,
          surfaceContainerHigh: PremiumWhiteBronzeTokens.darkSurfaceStrong,
          surfaceContainerHighest: PremiumWhiteBronzeTokens.darkSurfaceAccent,
          onSurface: PremiumWhiteBronzeTokens.darkOnSurface,
          outline: const Color(0x35FFFFFF),
          outlineVariant: const Color(0x24FFFFFF),
          onPrimary: PremiumWhiteBronzeTokens.darkOnPrimaryNeutral,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PremiumWhiteBronzeTokens.darkAppBackground,
      canvasColor: PremiumWhiteBronzeTokens.darkAppBackground,
      textTheme: _textTheme(Brightness.dark),
      dividerTheme: const DividerThemeData(color: Color(0x2FFFFFFF), space: 1),
      cardTheme: CardThemeData(
        color: PremiumWhiteBronzeTokens.darkSurfaceSoft,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
        ),
      ),
      inputDecorationTheme: _input(
        fillColor: PremiumWhiteBronzeTokens.darkSurfaceMuted,
        focusColor: PremiumWhiteBronzeTokens.darkPrimaryNeutral,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          ),
          backgroundColor: PremiumWhiteBronzeTokens.darkPrimaryNeutral,
          foregroundColor: PremiumWhiteBronzeTokens.darkOnPrimaryNeutral,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide.none,
          backgroundColor: PremiumWhiteBronzeTokens.darkSurfaceMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PremiumWhiteBronzeTokens.darkSurfaceMuted,
        selectedColor: PremiumWhiteBronzeTokens.darkSurfaceAccent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final TextTheme base = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static InputDecorationTheme _input({
    required Color fillColor,
    required Color focusColor,
  }) {
    final Color focusBorder = focusColor.withValues(alpha: 0.72);
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        borderSide: BorderSide(color: focusBorder, width: 1.1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        borderSide: BorderSide.none,
      ),
    );
  }
}
