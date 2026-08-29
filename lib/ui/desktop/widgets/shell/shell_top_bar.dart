// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../localization/desktop_localization.dart';
import '../../theme/platform_window_controls_profile.dart';
import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_motion_config.dart';

class ShellTopBar extends StatefulWidget {
  const ShellTopBar({
    super.key,
    required this.height,
    required this.fullscreen,
    required this.projectDisplayName,
    required this.showLeftToggle,
    required this.showRightToggle,
    required this.leftHidden,
    required this.rightVisible,
    required this.onToggleLeftVisibility,
    required this.onToggleRightVisibility,
    required this.windowControlsProfile,
    this.foregroundColor,
  });

  final double height;
  final bool fullscreen;
  final String projectDisplayName;
  final bool showLeftToggle;
  final bool showRightToggle;
  final bool leftHidden;
  final bool rightVisible;
  final VoidCallback onToggleLeftVisibility;
  final VoidCallback onToggleRightVisibility;
  final PlatformWindowControlsProfile windowControlsProfile;
  final Color? foregroundColor;

  @override
  State<ShellTopBar> createState() => _ShellTopBarState();
}

class _ShellTopBarState extends State<ShellTopBar> {
  Timer? _fullscreenDelayTimer;
  late bool _visualFullscreen = widget.fullscreen;

  @override
  void didUpdateWidget(covariant ShellTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreen == widget.fullscreen) {
      return;
    }

    final TargetPlatform platform = Theme.of(context).platform;
    final bool isMac = platform == TargetPlatform.macOS;
    _fullscreenDelayTimer?.cancel();

    if (!isMac) {
      setState(() {
        _visualFullscreen = widget.fullscreen;
      });
      return;
    }

    _fullscreenDelayTimer = Timer(UiMotionConfig.fullscreenStartDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visualFullscreen = widget.fullscreen;
      });
    });
  }

  @override
  void dispose() {
    _fullscreenDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    final bool isMac = platform == TargetPlatform.macOS;
    final bool controlsOnLeft =
        widget.windowControlsProfile.side == DesktopWindowControlsSide.left;
    final strings = context.strings;
    final double controlsInset = widget.windowControlsProfile.insetFor(
      fullscreen: _visualFullscreen,
    );
    final double targetLeadingInset = controlsOnLeft
        ? controlsInset
        : UiChromeConfig.topBarEdgeInset;
    final double targetTrailingInset = controlsOnLeft
        ? UiChromeConfig.topBarEdgeInset
        : controlsInset;
    final bool isToolbarExpanding = _visualFullscreen;
    final Duration animationDuration =
        widget.windowControlsProfile.animatesWithFullscreen &&
            isToolbarExpanding
        ? UiMotionConfig.fullscreenExpandDuration
        : UiMotionConfig.fullscreenCollapseDuration;

    return TweenAnimationBuilder<_TopBarInsets>(
      tween: _TopBarInsetsTween(
        end: _TopBarInsets(
          leadingInset: targetLeadingInset,
          trailingInset: targetTrailingInset,
        ),
      ),
      duration: animationDuration,
      curve: UiMotionConfig.fullscreenCurve,
      builder:
          (BuildContext context, _TopBarInsets animatedInsets, Widget? child) {
            final double animatedLeadingInset = animatedInsets.leadingInset;
            final double animatedTrailingInset = animatedInsets.trailingInset;
            final double progress = isMac
                ? ((animatedLeadingInset -
                              UiChromeConfig
                                  .topBarWindowControlsInsetMacFullscreen) /
                          (UiChromeConfig.topBarWindowControlsInsetMac -
                              UiChromeConfig
                                  .topBarWindowControlsInsetMacFullscreen))
                      .clamp(0, 1)
                : 1;
            final double leftClusterShift = isMac ? (1 - progress) * 6 : 0;

            return SizedBox(
              height: widget.height,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          key: const Key('desktop.topbar.leadingInset'),
                          width: animatedLeadingInset,
                        ),
                        if (widget.showLeftToggle)
                          Transform.translate(
                            offset: Offset(-leftClusterShift, 0),
                            child: _FlatToolbarIcon(
                              key: const Key('desktop.topbar.toggleLeft'),
                              tooltip: widget.leftHidden
                                  ? strings.tooltipShowLeftSidebar
                                  : strings.tooltipHideLeftSidebar,
                              icon: PhosphorIconsRegular.sidebarSimple,
                              onPressed: widget.onToggleLeftVisibility,
                              color: widget.foregroundColor,
                            ),
                          ),
                        const Spacer(),
                        if (widget.showRightToggle)
                          _FlatToolbarIcon(
                            key: const Key('desktop.topbar.toggleRight'),
                            tooltip: widget.rightVisible
                                ? strings.tooltipHideRightSidebar
                                : strings.tooltipShowRightSidebar,
                            icon: PhosphorIconsRegular.layout,
                            onPressed: widget.onToggleRightVisibility,
                            color: widget.foregroundColor,
                          ),
                        SizedBox(
                          key: const Key('desktop.topbar.trailingInset'),
                          width: animatedTrailingInset,
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: IgnorePointer(
                        child: Text(
                          widget.projectDisplayName,
                          key: const Key('desktop.topbar.projectName'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.foregroundColor,
                                shadows: widget.foregroundColor == null
                                    ? null
                                    : <Shadow>[
                                        const Shadow(
                                          blurRadius: 10,
                                          color: Color(0x33000000),
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}

@immutable
class _TopBarInsets {
  const _TopBarInsets({
    required this.leadingInset,
    required this.trailingInset,
  });

  final double leadingInset;
  final double trailingInset;
}

class _TopBarInsetsTween extends Tween<_TopBarInsets> {
  _TopBarInsetsTween({required super.end});

  @override
  _TopBarInsets lerp(double t) {
    final beginInsets = begin ?? end!;
    final endInsets = end!;
    return _TopBarInsets(
      leadingInset:
          beginInsets.leadingInset +
          (endInsets.leadingInset - beginInsets.leadingInset) * t,
      trailingInset:
          beginInsets.trailingInset +
          (endInsets.trailingInset - beginInsets.trailingInset) * t,
    );
  }
}

class _FlatToolbarIcon extends StatelessWidget {
  const _FlatToolbarIcon({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: UiChromeConfig.toolbarIconButtonSize,
          height: UiChromeConfig.toolbarIconButtonSize,
        ),
        splashRadius: UiChromeConfig.toolbarIconSplashRadius,
        iconSize: UiChromeConfig.toolbarIconSize,
        color: color,
        icon: Icon(icon, color: color),
      ),
    );
  }
}
