// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Hover-reveal circular delete badge for card corners.
class AnimatedDeleteButton extends StatelessWidget {
  const AnimatedDeleteButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  static const double _badgeSize = 22;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    // Light mode: light-grey background, dark-grey X.
    // Dark mode: dark-grey background, light X.
    final Color circleColor = brightness == Brightness.light
        ? const Color(0xFFD8D8D8)
        : const Color(0xFF4A4A4A);
    final Color iconColor = brightness == Brightness.light
        ? const Color(0xFF555555)
        : const Color(0xFFCCCCCC);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: visible ? 1 : 0.6,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: onPressed,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Delete',
                child: Container(
                  width: _badgeSize,
                  height: _badgeSize,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(PhosphorIconsBold.x, size: 12, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
