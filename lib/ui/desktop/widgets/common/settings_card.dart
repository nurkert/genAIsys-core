// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/ui_chrome_config.dart';

/// Standardized settings surface card used across windows.
///
/// Keeping this centralized ensures typography and padding remain consistent
/// when we add more settings surfaces (project hub, project workspace, etc.).
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Color subdued = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.72);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UiChromeConfig.space14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (description != null) ...<Widget>[
              const SizedBox(height: UiChromeConfig.space4),
              Text(
                description!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: subdued),
              ),
            ],
            const SizedBox(height: UiChromeConfig.space10),
            ...children,
          ],
        ),
      ),
    );
  }
}
