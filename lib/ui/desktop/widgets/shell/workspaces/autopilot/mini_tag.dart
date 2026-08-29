// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';

class MiniTag extends StatelessWidget {
  const MiniTag({super.key, required this.label, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space8,
        vertical: UiChromeConfig.space4,
      ),
      decoration: UiSurfaceStyles.pill(
        context,
        tone: error ? DesktopSurfaceTone.accent : DesktopSurfaceTone.muted,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
