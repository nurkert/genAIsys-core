// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

/// Platform-specific corner strategy for desktop shells.
class PlatformCornerProfile {
  const PlatformCornerProfile({
    required this.mainTopRadius,
    required this.sidebarRadius,
  });

  final double mainTopRadius;
  final double sidebarRadius;

  static PlatformCornerProfile resolve() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        // macOS 26 visual language: stronger unified-window rounding.
        return const PlatformCornerProfile(
          mainTopRadius: 26,
          sidebarRadius: 20,
        );
      case TargetPlatform.windows:
        // Windows 11 recommendation: rounded top-level window corners.
        return const PlatformCornerProfile(mainTopRadius: 8, sidebarRadius: 8);
      case TargetPlatform.linux:
        // Unified Linux default across desktop environments.
        return const PlatformCornerProfile(mainTopRadius: 8, sidebarRadius: 8);
      default:
        return const PlatformCornerProfile(mainTopRadius: 8, sidebarRadius: 8);
    }
  }
}
