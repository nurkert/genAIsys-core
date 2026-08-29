// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Central design tokens for the "Premium White & Bronze" visual identity.
///
/// Keep all key values here so the full desktop shell can be tuned from one
/// place without touching feature widgets.
class PremiumWhiteBronzeTokens {
  const PremiumWhiteBronzeTokens._();

  static const Color appBackground = Color(0xFFF5F5F7);
  // Former acrylic/milkglass shell areas now use explicit neutral grays.
  static const Color projectShellBackground = Color(0xFFE9EBEE);
  static const Color projectShellBackgroundDark = Color(0xFF2A2A2D);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8F6F3);
  static const Color surfaceMuted = Color(0xFFF1EEE8);
  static const Color surfaceStrong = Color(0xFFE7E2DA);
  static const Color surfaceAccent = Color(0xFFEFE5DA);
  static const Color onSurface = Color(0xFF333333);
  static const Color primaryFallback = Color(0xFF8F694F);
  static const Color darkAppBackground = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceSoft = Color(0xFF202020);
  static const Color darkSurfaceMuted = Color(0xFF272727);
  static const Color darkSurfaceStrong = Color(0xFF313131);
  static const Color darkSurfaceAccent = Color(0xFF322A24);
  static const Color darkInputFill = Color(0xFF171717);
  static const Color darkOnSurface = Color(0xFFE6E6E6);
  static const Color darkPrimaryNeutral = Color(0xFFC6C6C6);
  static const Color darkOnPrimaryNeutral = Color(0xFF141414);

  static const Color bronzeDark = Color(0xFF6B4A38);
  static const Color bronzeHighlight = Color(0xFFB88A63);
  static const Color bronzeMid = Color(0xFF9A6E52);
  static const Color silverDark = Color(0xFF8D8D91);
  static const Color silverHighlight = Color(0xFFE4E4E7);
  static const Color silverMid = Color(0xFFB8B8BD);
  static const Color silverDarkModeDark = Color(0xFF3E3E41);
  static const Color silverDarkModeHighlight = Color(0xFF727276);
  static const Color silverDarkModeMid = Color(0xFF58585C);

  static const Color softBorder = Color(0x18000000);
  static const Color lightTrack = Color(0xFFEEEEEE);

  // Toggle switch tokens (used by BronzeSwitch).
  static const Color toggleOffTrackLight = Color(0xFFE8E8EB);
  static const Color toggleOffBorderLight = Color(0x18000000);
  static const Color toggleOffTrackDark = Color(0xFF2A2A2A);
  static const Color toggleOffBorderDark = Color(0x38FFFFFF);

  static const Color toggleOnBorderLight = Color(0x2EFFFFFF);
  static const Color toggleOnBorderDark = Color(0x26FFFFFF);

  static const Color toggleThumbLight = Color(0xFFFFFFFF);
  static const Color toggleThumbBorderLight = Color(0x14000000);
  static const Color toggleThumbDark = Color(0xFF161616);
  static const Color toggleThumbBorderDark = Color(0x24FFFFFF);

  static const List<BoxShadow> toggleThumbShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> toggleTrackShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6)),
  ];

  static const LinearGradient bronzeGradient = LinearGradient(
    colors: <Color>[bronzeDark, bronzeHighlight, bronzeMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Returns a subtly varied bronze gradient so accents feel related but not
  /// copy-pasted across the window.
  static LinearGradient bronzeGradientFor(int seed) {
    final int normalized = seed.abs();
    final double phase = (normalized % 9) / 9;
    final double verticalShift = ((normalized % 3) - 1) * 0.04;
    final double middleStopShift = ((normalized % 5) - 2) * 0.008;

    final Color dark = _tone(
      bronzeDark,
      lightnessDelta: -0.01 + phase * 0.012,
      saturationDelta: -0.02,
    );
    final Color highlight = _tone(
      bronzeHighlight,
      lightnessDelta: -0.04 + phase * 0.015,
      saturationDelta: -0.04,
    );
    final Color mid = _tone(
      bronzeMid,
      lightnessDelta: -0.01 + phase * 0.01,
      saturationDelta: -0.03,
    );

    return LinearGradient(
      colors: <Color>[dark, highlight, mid],
      stops: <double>[0, (0.50 + middleStopShift).clamp(0.46, 0.54), 1],
      begin: Alignment(-1, -0.9 + verticalShift),
      end: Alignment(1, 0.9 + verticalShift),
    );
  }

  /// Silver gradient variant used for OFF-state metallic toggles.
  static LinearGradient silverGradientFor(int seed) {
    final int normalized = seed.abs();
    final double phase = (normalized % 11) / 11;
    final double verticalShift = ((normalized % 3) - 1) * 0.04;
    final double middleStopShift = ((normalized % 5) - 2) * 0.01;

    final Color dark = _tone(
      silverDark,
      lightnessDelta: -0.02 + phase * 0.014,
      saturationDelta: -0.03,
    );
    final Color highlight = _tone(
      silverHighlight,
      lightnessDelta: -0.03 + phase * 0.012,
      saturationDelta: -0.03,
    );
    final Color mid = _tone(
      silverMid,
      lightnessDelta: -0.02 + phase * 0.01,
      saturationDelta: -0.02,
    );

    return LinearGradient(
      colors: <Color>[dark, highlight, mid],
      stops: <double>[0, (0.5 + middleStopShift).clamp(0.45, 0.55), 1],
      begin: Alignment(-1, -0.9 + verticalShift),
      end: Alignment(1, 0.9 + verticalShift),
    );
  }

  /// Dark-mode silver variant. Keeps the same metal language without blue cast.
  static LinearGradient silverGradientDarkFor(int seed) {
    final int normalized = seed.abs();
    final double phase = (normalized % 9) / 9;
    final double verticalShift = ((normalized % 3) - 1) * 0.05;
    final double middleStopShift = ((normalized % 7) - 3) * 0.008;

    final Color dark = _tone(
      silverDarkModeDark,
      lightnessDelta: -0.015 + phase * 0.01,
      saturationDelta: -0.02,
    );
    final Color highlight = _tone(
      silverDarkModeHighlight,
      lightnessDelta: -0.02 + phase * 0.012,
      saturationDelta: -0.02,
    );
    final Color mid = _tone(
      silverDarkModeMid,
      lightnessDelta: -0.015 + phase * 0.01,
      saturationDelta: -0.02,
    );

    return LinearGradient(
      colors: <Color>[dark, highlight, mid],
      stops: <double>[0, (0.5 + middleStopShift).clamp(0.46, 0.54), 1],
      begin: Alignment(-1, -0.88 + verticalShift),
      end: Alignment(1, 0.88 + verticalShift),
    );
  }

  /// Brushed-metal texture with horizontal streaks (lines run left -> right).
  /// The gradient varies top->bottom to produce those horizontal lanes.
  static LinearGradient horizontalGrainOverlay({
    required int seed,
    double strength = 0.16,
  }) {
    final int normalized = seed.abs();
    const int bands = 18;
    final List<Color> colors = <Color>[];
    final List<double> stops = <double>[];

    for (int i = 0; i <= bands; i++) {
      final double t = i / bands;
      final bool brightLine = (i + normalized).isEven;
      final double noise = _noise01(normalized + (i * 37));
      final double alpha = (0.012 + noise * strength).clamp(0.012, 0.11);
      final Color lineColor = brightLine
          ? Colors.white.withValues(alpha: alpha)
          : Colors.black.withValues(alpha: alpha * 0.82);
      colors.add(lineColor);
      stops.add(t);
    }

    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static const List<BoxShadow> softSurfaceShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> softSurfaceShadowDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x38000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> elevatedSurfaceShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 26,
      spreadRadius: 0,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> elevatedSurfaceShadowDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x46000000),
      blurRadius: 30,
      spreadRadius: 0,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> bronzeGlow = <BoxShadow>[
    BoxShadow(
      color: Color(0x33B88A63),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
  ];

  /// Subtle embossed shadow stack for white glyphs on metallic surfaces.
  static const List<Shadow> bronzeForegroundShadows = <Shadow>[
    Shadow(color: Color(0x52000000), offset: Offset(0, 1.1), blurRadius: 1.4),
    Shadow(color: Color(0x1FFFFFFF), offset: Offset(0, -0.4), blurRadius: 0.8),
  ];

  static const double glassBlur = 10;
  static const Color glassLight = Color(0xB3FFFFFF);
  static const Color glassDark = Color(0x66181818);
  // Former acrylic zones now use explicit neutral grays for stable rendering.
  static const Color sidebarLightSurface = Color(0xFFE2E5E9);
  static const Color sidebarDarkSurface = Color(0xFF343438);
  static const Color sidebarLightBorder = Color(0x14000000);
  static const Color sidebarDarkBorder = Color(0x00000000);

  static Color _tone(
    Color color, {
    double lightnessDelta = 0,
    double saturationDelta = 0,
  }) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + saturationDelta).clamp(0.0, 1.0))
        .toColor();
  }

  static double _noise01(int value) {
    final double raw = math.sin(value * 12.9898) * 43758.5453;
    return raw - raw.floorToDouble();
  }
}
