// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

/// Metallic tokens used across light and dark themes.
///
/// We intentionally avoid oversaturated consumer-app colors and instead use
/// nuanced metal-inspired hues for a premium desktop/SaaS identity.
class MetalPalette {
  // Cool metals.
  static const Color silver = Color(0xFFBEBEBE);
  static const Color silverStrong = Color(0xFF969696);
  static const Color platinum = Color(0xFFD8D8D8);
  static const Color titanium = Color(0xFF787878);

  // Warm metals.
  static const Color gold = Color(0xFFD9B56D);
  static const Color goldStrong = Color(0xFFB28A3F);
  static const Color bronze = Color(0xFFB27B52);
  static const Color bronzeStrong = Color(0xFF8D5C38);
  static const Color copper = Color(0xFFC98458);
  static const Color copperStrong = Color(0xFF9B603A);

  // Base neutrals.
  static const Color graphite = Color(0xFF141414);
  static const Color charcoal = Color(0xFF232323);

  // Emissive colors used for subtle "lava/fire reflection" accents.
  // These are intentionally translucent in usage to stay premium, not neon.
  static const Color ember = Color(0xFFFF8A45);
  static const Color lava = Color(0xFFFF5A2A);
  static const Color flare = Color(0xFFFFC169);

  static const List<Color> lightMetalGradient = <Color>[
    Color(0xFFFDFDFE),
    Color(0xFFF8FAFD),
    Color(0xFFF4F7FA),
    Color(0xFFF1E7D4),
    Color(0xFFEBDDC8),
  ];

  static const List<Color> darkMetalGradient = <Color>[
    Color(0xFF111111),
    Color(0xFF1B1B1B),
    Color(0xFF262626),
    Color(0xFF313131),
  ];
}
