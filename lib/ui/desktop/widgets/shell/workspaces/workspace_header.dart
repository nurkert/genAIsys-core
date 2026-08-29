// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../theme/ui_chrome_config.dart';
import '../../common/bronze_gradient_text.dart';

/// Shared title/subtitle header used by desktop workspace views.
///
/// This keeps typography, spacing, and muted subtitle treatment consistent
/// across all primary workspaces while still allowing a custom trailing action.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.seed,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final int seed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final String? subtitleText = subtitle;
    final bool hasSubtitle =
        subtitleText != null && subtitleText.trim().isNotEmpty;
    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BronzeGradientText(
          title,
          seed: seed,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (hasSubtitle) ...<Widget>[
          const SizedBox(height: UiChromeConfig.space6),
          Text(
            subtitleText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
        ],
      ],
    );

    final Widget? trailingWidget = trailing;
    if (trailingWidget == null) {
      return titleBlock;
    }

    return Row(
      children: <Widget>[
        Expanded(child: titleBlock),
        const SizedBox(width: UiChromeConfig.space12),
        trailingWidget,
      ],
    );
  }
}
