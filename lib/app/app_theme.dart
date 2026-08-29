// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

class AppTheme {
  static const _fontFamily = 'IBM Plex Sans';
  static const _headlineFont = 'Space Grotesk';

  static ThemeData light() {
    const seed = Color(0xFF0B6E4F);
    const surface = Color(0xFFF5F3EE);
    const background = Color(0xFFF9F7F2);
    const onSurface = Color(0xFF1C1C1C);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          surface: surface,
          onSurface: onSurface,
          secondary: const Color(0xFF2C3E50),
          tertiary: const Color(0xFFE27D60),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: _fontFamily,
      fontFamilyFallback: const [
        'Space Grotesk',
        'Avenir Next',
        'Fira Sans',
        'Noto Sans',
      ],
      textTheme: const TextTheme(),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontFamily: _headlineFont,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontFamily: _headlineFont,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: _headlineFont,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: _headlineFont,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}
