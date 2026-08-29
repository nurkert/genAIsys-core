// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_motion_config.dart';

class AnimatedSidebarSlot extends StatelessWidget {
  const AnimatedSidebarSlot({
    super.key,
    required this.visible,
    required this.width,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final double width;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: UiMotionConfig.shellDuration,
      curve: UiMotionConfig.shellCurve,
      width: visible ? width : 0,
      child: ClipRect(
        child: AnimatedOpacity(
          duration: UiMotionConfig.fadeDuration,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: OverflowBox(
              minWidth: width,
              maxWidth: width,
              alignment: alignment,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedSidebarGap extends StatelessWidget {
  const AnimatedSidebarGap({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: UiMotionConfig.shellDuration,
      curve: UiMotionConfig.shellCurve,
      width: visible ? UiChromeConfig.panelGap : 0,
    );
  }
}
