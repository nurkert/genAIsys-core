// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/premium_white_bronze_tokens.dart';
import 'bronze_brush_texture.dart';
import 'bronze_reflection.dart';

class BronzeButton extends StatefulWidget {
  const BronzeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.borderRadius = 10,
    this.glow = false,
    this.seed,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool glow;
  final int? seed;

  @override
  State<BronzeButton> createState() => _BronzeButtonState();
}

class _BronzeButtonState extends State<BronzeButton> {
  bool _hovered = false;
  bool _pressed = false;

  int get _resolvedSeed => widget.seed ?? widget.label.hashCode;

  @override
  void didUpdateWidget(covariant BronzeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(widget.borderRadius);
    final bool enabled = widget.onPressed != null;
    final double scale = !enabled
        ? 1
        : (_pressed ? 0.987 : (_hovered ? 1.014 : 1));
    final double verticalOffset = !enabled
        ? 0
        : (_pressed ? 1.15 : (_hovered ? -0.55 : 0));

    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, verticalOffset, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: _resolvedShadow(enabled: enabled),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              canRequestFocus: false,
              autofocus: false,
              onTap: widget.onPressed,
              onHover: enabled ? _setHovered : null,
              onHighlightChanged: enabled ? _setPressed : null,
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  foregroundPainter: BronzeBrushTexturePainter(
                    seed: _resolvedSeed,
                    strength: 1.0,
                    borderRadius: widget.borderRadius,
                  ),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: PremiumWhiteBronzeTokens.bronzeGradientFor(
                        _resolvedSeed,
                      ),
                      border: Border.all(
                        color: const Color(0x2EFFFFFF),
                        width: 0.9,
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: BronzeSpecularLight(
                              seed: _resolvedSeed,
                              borderRadius: widget.borderRadius,
                              hovered: _hovered,
                              pressed: _pressed,
                              baseIntensity: 0.80,
                            ),
                          ),
                        ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (widget.icon != null) ...<Widget>[
                                Icon(
                                  widget.icon,
                                  color: Colors.white,
                                  size: 16,
                                  shadows: PremiumWhiteBronzeTokens
                                      .bronzeForegroundShadows,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      shadows: PremiumWhiteBronzeTokens
                                          .bronzeForegroundShadows,
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

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  List<BoxShadow> _resolvedShadow({required bool enabled}) {
    final List<BoxShadow> base = widget.glow
        ? <BoxShadow>[
            ...PremiumWhiteBronzeTokens.softSurfaceShadow,
            ...PremiumWhiteBronzeTokens.bronzeGlow,
          ]
        : PremiumWhiteBronzeTokens.softSurfaceShadow;

    if (!enabled) {
      return base;
    }

    if (_pressed) {
      return <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: widget.glow ? 0.20 : 0.14),
          blurRadius: widget.glow ? 12 : 9,
          offset: const Offset(0, 4),
        ),
      ];
    }

    if (_hovered) {
      return <BoxShadow>[
        ...base,
        BoxShadow(
          color: const Color(0x38A97658),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ];
    }

    return base;
  }
}
