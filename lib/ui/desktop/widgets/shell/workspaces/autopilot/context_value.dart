// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';

class ContextValue extends StatelessWidget {
  const ContextValue({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.space10),
      decoration: UiSurfaceStyles.panel(
        context,
        tone: DesktopSurfaceTone.base,
        elevated: false,
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: UiChromeConfig.space4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
