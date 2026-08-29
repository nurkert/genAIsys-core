// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/premium_white_bronze_tokens.dart';
import '../../theme/ui_chrome_config.dart';
import 'bronze_brush_texture.dart';
import 'bronze_reflection.dart';

/// A shared sidebar button with metallic bronze selected-state rendering.
///
/// Used by both the project-window left sidebar and the project-hub sidebar.
/// Selection changes are **instant** (no fade/animation) to eliminate visual
/// intermediate states. Hover and press micro-interactions only activate on
/// the currently selected (metal-active) button.
class MetalSidebarButton extends StatefulWidget {
  const MetalSidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.darkMode,
    required this.onPressed,
    required this.gradientSeed,
    required this.textureSeed,
    this.textureStrength = 0.62,
    this.specularIntensity = 0.72,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool darkMode;
  final VoidCallback onPressed;

  /// Seed for bronze gradient variation per button.
  final int gradientSeed;

  /// Seed for brush-texture variation per button.
  final int textureSeed;

  /// Brush-texture strength (default 0.62).
  final double textureStrength;

  /// Specular-light base intensity (default 0.72).
  final double specularIntensity;

  @override
  State<MetalSidebarButton> createState() => _MetalSidebarButtonState();
}

class _MetalSidebarButtonState extends State<MetalSidebarButton> {
  bool _hovered = false;
  bool _pressed = false;
  late BronzeBrushTexturePainter _texturePainter = _buildTexturePainter();

  BronzeBrushTexturePainter _buildTexturePainter() {
    return BronzeBrushTexturePainter(
      seed: widget.textureSeed,
      strength: widget.textureStrength,
      borderRadius: UiChromeConfig.sidebarItemRadius,
    );
  }

  @override
  void didUpdateWidget(covariant MetalSidebarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textureSeed != widget.textureSeed ||
        oldWidget.textureStrength != widget.textureStrength) {
      _texturePainter = _buildTexturePainter();
    }
    if (oldWidget.selected != widget.selected) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool metal = widget.selected;
    final double scale = !metal
        ? 1
        : (_pressed ? 0.992 : (_hovered ? 1.010 : 1));
    final double yOffset = !metal
        ? 0
        : (_pressed ? 0.75 : (_hovered ? -0.30 : 0));

    final Color iconColor = metal
        ? Colors.white
        : (widget.darkMode
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86)
              : PremiumWhiteBronzeTokens.onSurface);
    final Color textColor = metal
        ? Colors.white
        : (widget.darkMode
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.94)
              : PremiumWhiteBronzeTokens.onSurface);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          onEnter: metal ? (_) => _setHovered(true) : null,
          onExit: metal ? (_) => _setHovered(false) : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, yOffset, 0),
              height: UiChromeConfig.sidebarItemHeight,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Metal surface: instant on/off, no fade.
                  if (metal)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            UiChromeConfig.sidebarItemRadius,
                          ),
                          gradient: PremiumWhiteBronzeTokens.bronzeGradientFor(
                            widget.gradientSeed,
                          ),
                          boxShadow: _resolvedMetalShadow(),
                        ),
                        child: CustomPaint(
                          foregroundPainter: _texturePainter,
                          child: BronzeSpecularLight(
                            seed: widget.gradientSeed,
                            borderRadius: UiChromeConfig.sidebarItemRadius,
                            hovered: _hovered,
                            pressed: _pressed,
                            baseIntensity: widget.specularIntensity,
                          ),
                        ),
                      ),
                    ),
                  // Content: icon + label.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiChromeConfig.sidebarItemHorizontalPadding,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          widget.icon,
                          size: UiChromeConfig.sidebarItemIconSize,
                          color: iconColor,
                          shadows: metal
                              ? PremiumWhiteBronzeTokens.bronzeForegroundShadows
                              : null,
                        ),
                        const SizedBox(
                          width: UiChromeConfig.sidebarItemContentGap,
                        ),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: metal
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  shadows: metal
                                      ? PremiumWhiteBronzeTokens
                                            .bronzeForegroundShadows
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  List<BoxShadow> _resolvedMetalShadow() {
    if (_pressed) {
      return <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    }
    if (_hovered) {
      return <BoxShadow>[
        ...PremiumWhiteBronzeTokens.softSurfaceShadow,
        ...PremiumWhiteBronzeTokens.bronzeGlow,
        const BoxShadow(
          color: Color(0x2FA97658),
          blurRadius: 12,
          offset: Offset(0, 7),
        ),
      ];
    }
    return <BoxShadow>[
      ...PremiumWhiteBronzeTokens.softSurfaceShadow,
      ...PremiumWhiteBronzeTokens.bronzeGlow,
    ];
  }
}
