// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'autopilot_stage_snapshot.dart';
import 'stage_pill.dart';

class CompactStatusBar extends StatelessWidget {
  const CompactStatusBar({
    super.key,
    required this.strings,
    required this.stage,
    required this.running,
    required this.blocked,
    required this.cycleCount,
    required this.retries,
  });

  final DesktopStrings strings;
  final AutopilotStageSnapshot stage;
  final bool running;
  final bool blocked;
  final int cycleCount;
  final int retries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = UiSurfaceStyles.mutedOnSurface(context);

    final IconData statusIcon = blocked
        ? PhosphorIconsRegular.warning
        : (running
              ? PhosphorIconsRegular.playCircle
              : PhosphorIconsRegular.pauseCircle);
    final String statusText = blocked
        ? 'Blocked'
        : (running
              ? strings.autopilotStatusRunning
              : strings.autopilotStatusPaused);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space12,
        vertical: UiChromeConfig.space10,
      ),
      decoration: UiSurfaceStyles.panel(
        context,
        tone: blocked ? DesktopSurfaceTone.accent : DesktopSurfaceTone.soft,
        elevated: false,
      ),
      child: Row(
        children: <Widget>[
          Icon(statusIcon, size: 18),
          const SizedBox(width: UiChromeConfig.space8),
          Text(
            statusText,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: UiChromeConfig.space12),
          StagePill(label: stage.label, blocked: blocked, running: running),
          const Spacer(),
          Text(
            '${strings.autopilotCycleLabel}: $cycleCount',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(width: UiChromeConfig.space14),
          Text(
            '${strings.autopilotRetriesLabel}: $retries',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
