// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../theme/ui_chrome_config.dart';
import '../../../theme/ui_surface_styles.dart';

class WorkspaceFeedbackBanner extends StatelessWidget {
  const WorkspaceFeedbackBanner({
    super.key,
    required this.errorMessage,
    required this.infoMessage,
    required this.onDismiss,
  });

  final String? errorMessage;
  final String? infoMessage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final String? message = errorMessage ?? infoMessage;
    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isError = errorMessage != null;
    final Color background = isError
        ? const Color(0x36B71C1C)
        : UiSurfaceStyles.color(context, DesktopSurfaceTone.accent);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space12,
        vertical: UiChromeConfig.space10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        boxShadow: UiSurfaceStyles.shadow(context),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: UiChromeConfig.space8),
          IconButton(
            tooltip: 'Dismiss message',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
