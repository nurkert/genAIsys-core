// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';

class StagePill extends StatelessWidget {
  const StagePill({
    super.key,
    required this.label,
    required this.blocked,
    required this.running,
  });

  final String label;
  final bool blocked;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final DesktopSurfaceTone tone = blocked
        ? DesktopSurfaceTone.accent
        : (running ? DesktopSurfaceTone.strong : DesktopSurfaceTone.base);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space10,
        vertical: UiChromeConfig.space6,
      ),
      decoration: UiSurfaceStyles.pill(context, tone: tone),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
