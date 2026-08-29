// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/premium_white_bronze_tokens.dart';
import '../../theme/ui_chrome_config.dart';
import 'bronze_brush_texture.dart';
import 'bronze_reflection.dart';

/// Desktop-first switch styled for the Premium White & Bronze identity.
///
/// Why custom?
/// - Material's `Switch` only supports solid colors via `SwitchThemeData`.
/// - Our "bronze" accent is a gradient + brushed-metal overlay (the "sh" effect).
/// - This keeps the effect consistent across the app without importing any
///   third-party UI packages.
class BronzeSwitch extends StatefulWidget {
  const BronzeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.seed,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Controls subtle gradient variation so multiple toggles do not look cloned.
  ///
  /// Keep it stable across rebuilds. If null, we derive a seed from the widget
  /// identity which is stable for a given element instance.
  final int? seed;

  final String? semanticLabel;

  @override
  State<BronzeSwitch> createState() => _BronzeSwitchState();
}

class _BronzeSwitchState extends State<BronzeSwitch> {
  static const Key _trackKey = ValueKey<String>('desktop.bronzeSwitch.track');
  static const Key _thumbKey = ValueKey<String>('desktop.bronzeSwitch.thumb');

  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onChanged != null;

  int get _resolvedSeed {
    if (widget.seed != null) {
      return widget.seed!;
    }
    // Element identity is stable while mounted and prevents "jumping" seeds
    // from using hashCode on changing inputs.
    return identityHashCode(widget);
  }

  void _toggle() {
    if (!_enabled) {
      return;
    }
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    final double width = UiChromeConfig.toggleSwitchWidth;
    final double height = UiChromeConfig.toggleSwitchHeight;
    final double padding = UiChromeConfig.toggleSwitchPadding;
    final double radius = height / 2;

    final Color offBorder = dark
        ? PremiumWhiteBronzeTokens.toggleOffBorderDark
        : PremiumWhiteBronzeTokens.toggleOffBorderLight;

    final Color thumbColor = dark
        ? PremiumWhiteBronzeTokens.toggleThumbDark
        : PremiumWhiteBronzeTokens.toggleThumbLight;
    final Color thumbBorder = dark
        ? PremiumWhiteBronzeTokens.toggleThumbBorderDark
        : PremiumWhiteBronzeTokens.toggleThumbBorderLight;

    final double thumbSize = height - padding * 2;
    final double thumbTravel = width - thumbSize - padding * 2;
    final bool on = widget.value;
    final Color onBorder = dark
        ? PremiumWhiteBronzeTokens.toggleOnBorderDark
        : PremiumWhiteBronzeTokens.toggleOnBorderLight;
    final LinearGradient silverGradient = dark
        ? PremiumWhiteBronzeTokens.silverGradientDarkFor(_resolvedSeed)
        : PremiumWhiteBronzeTokens.silverGradientFor(_resolvedSeed);
    final LinearGradient bronzeGradient =
        PremiumWhiteBronzeTokens.bronzeGradientFor(_resolvedSeed);

    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: _enabled,
      button: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (bool value) {
          setState(() => _hovered = value);
        },
        onShowFocusHighlight: (bool value) {
          setState(() => _focused = value);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          onTapDown: (_) {
            if (_pressed) {
              return;
            }
            setState(() {
              _pressed = true;
            });
          },
          onTapUp: (_) {
            if (!_pressed) {
              return;
            }
            setState(() {
              _pressed = false;
            });
          },
          onTapCancel: () {
            if (!_pressed) {
              return;
            }
            setState(() {
              _pressed = false;
            });
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _enabled ? 1 : 0.55,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: AnimatedContainer(
                      key: _trackKey,
                      duration: UiChromeConfig.toggleSwitchDuration,
                      curve: UiChromeConfig.toggleSwitchCurve,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: on ? onBorder : offBorder,
                          width: 1,
                        ),
                        boxShadow: _hovered || _focused
                            ? PremiumWhiteBronzeTokens.bronzeGlow
                            : PremiumWhiteBronzeTokens.toggleTrackShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: silverGradient,
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: on ? 1 : 0,
                              duration: UiChromeConfig.toggleSwitchDuration,
                              curve: UiChromeConfig.toggleSwitchCurve,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: bronzeGradient,
                                ),
                              ),
                            ),
                            CustomPaint(
                              foregroundPainter: BronzeBrushTexturePainter(
                                seed: _resolvedSeed + 17,
                                strength: on ? 0.42 : 0.88,
                                borderRadius: radius,
                              ),
                              child: const SizedBox.expand(),
                            ),
                            AnimatedOpacity(
                              opacity: on ? 1 : 0,
                              duration: UiChromeConfig.toggleSwitchDuration,
                              curve: UiChromeConfig.toggleSwitchCurve,
                              child: CustomPaint(
                                foregroundPainter: BronzeBrushTexturePainter(
                                  seed: _resolvedSeed,
                                  strength: on ? 0.98 : 0.2,
                                  borderRadius: radius,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            IgnorePointer(
                              child: BronzeSpecularLight(
                                seed: _resolvedSeed + 37,
                                borderRadius: radius,
                                hovered: _hovered || _focused,
                                pressed: _pressed,
                                baseIntensity: on ? 0.56 : 0.34,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: UiChromeConfig.toggleSwitchDuration,
                    curve: UiChromeConfig.toggleSwitchCurve,
                    top: padding,
                    left: on ? (padding + thumbTravel) : padding,
                    child: Container(
                      key: _thumbKey,
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        borderRadius: BorderRadius.circular(thumbSize / 2),
                        border: Border.all(color: thumbBorder, width: 0.8),
                        boxShadow: PremiumWhiteBronzeTokens.toggleThumbShadow,
                      ),
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
}

/// Drop-in replacement for `SwitchListTile` that uses [BronzeSwitch].
class BronzeSwitchTile extends StatelessWidget {
  const BronzeSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.dense = true,
    this.contentPadding = EdgeInsets.zero,
    this.seed,
  });

  final Widget title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool dense;
  final EdgeInsetsGeometry contentPadding;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;

    return InkWell(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
      child: Padding(
        padding: contentPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: dense ? 36 : 44),
          child: Row(
            children: <Widget>[
              Expanded(child: title),
              const SizedBox(width: UiChromeConfig.space12),
              BronzeSwitch(value: value, onChanged: onChanged, seed: seed),
            ],
          ),
        ),
      ),
    );
  }
}
