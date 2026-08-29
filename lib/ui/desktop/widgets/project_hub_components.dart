// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/settings/project_registry.dart';
import '../localization/desktop_strings.dart';
import '../theme/premium_white_bronze_tokens.dart';
import '../theme/ui_chrome_config.dart';
import '../theme/ui_motion_config.dart';
import '../theme/ui_surface_styles.dart';

class ProjectHubCard extends StatefulWidget {
  const ProjectHubCard({
    super.key,
    required this.strings,
    required this.project,
    required this.isLastOpened,
    required this.onOpenProject,
    required this.onDeleteProject,
  });

  final DesktopStrings strings;
  final RegisteredProject project;
  final bool isLastOpened;
  final VoidCallback onOpenProject;
  final VoidCallback onDeleteProject;

  @override
  State<ProjectHubCard> createState() => _ProjectHubCardState();
}

class _ProjectHubCardState extends State<ProjectHubCard> {
  bool _hovered = false;

  static String _formatTimestamp(String iso8601) {
    final DateTime? parsed = DateTime.tryParse(iso8601)?.toLocal();
    if (parsed == null) {
      return iso8601;
    }
    final DateTime now = DateTime.now();
    final String time =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    if (parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day) {
      return 'Today, $time';
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (parsed.year == yesterday.year &&
        parsed.month == yesterday.month &&
        parsed.day == yesterday.day) {
      return 'Yesterday, $time';
    }
    return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color mutedText = UiSurfaceStyles.mutedOnSurface(context);

    final String lastOpenedText = widget.project.lastOpenedAtIso8601 != null
        ? '${widget.strings.hubLastOpenedPrefix} ${_formatTimestamp(widget.project.lastOpenedAtIso8601!)}'
        : widget.strings.neverOpenedLabel;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? (dark
                  ? PremiumWhiteBronzeTokens.darkSurfaceSoft
                  : PremiumWhiteBronzeTokens.surfaceSoft)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
        child: InkWell(
          onTap: widget.onOpenProject,
          borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiChromeConfig.space14,
              vertical: UiChromeConfig.space12,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  PhosphorIconsRegular.folderSimple,
                  size: 20,
                  color: dark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
                      : PremiumWhiteBronzeTokens.onSurface.withValues(
                          alpha: 0.72,
                        ),
                ),
                const SizedBox(width: UiChromeConfig.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.project.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: dark
                                    ? theme.colorScheme.onSurface
                                    : PremiumWhiteBronzeTokens.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: UiChromeConfig.space8),
                          Text(
                            lastOpenedText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: UiChromeConfig.space4),
                      Text(
                        widget.project.rootPath,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: UiChromeConfig.space12),
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: UiMotionConfig.fadeDuration,
                  child: IconButton(
                    tooltip: widget.strings.deleteProjectAction,
                    onPressed: _hovered ? widget.onDeleteProject : null,
                    icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
