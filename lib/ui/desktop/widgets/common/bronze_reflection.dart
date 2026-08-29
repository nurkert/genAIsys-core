// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class BronzeReflectionOverlay extends StatelessWidget {
  const BronzeReflectionOverlay({
    super.key,
    required this.borderRadius,
    required this.alignment,
    this.intensity = 1.0,
  });

  final double borderRadius;
  final Alignment alignment;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final double clampedIntensity = intensity.clamp(0, 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: RadialGradient(
          center: alignment,
          radius: 1.14,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.25 * clampedIntensity),
            Colors.white.withValues(alpha: 0.11 * clampedIntensity),
            Colors.white.withValues(alpha: 0.03 * clampedIntensity),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.22, 0.58, 1.0],
        ),
      ),
    );
  }
}

/// Shared specular motion layer for metallic surfaces.
///
/// This drives a subtle, non-cursor-dependent highlight loop and reacts to
/// hover/press states so metal elements feel physically alive.
class BronzeSpecularLight extends StatefulWidget {
  const BronzeSpecularLight({
    super.key,
    required this.seed,
    required this.borderRadius,
    required this.hovered,
    required this.pressed,
    this.baseIntensity = 0.76,
  });

  final int seed;
  final double borderRadius;
  final bool hovered;
  final bool pressed;
  final double baseIntensity;

  @override
  State<BronzeSpecularLight> createState() => _BronzeSpecularLightState();
}

class _BronzeSpecularLightState extends State<BronzeSpecularLight>
    with TickerProviderStateMixin {
  late final AnimationController _driftController;
  late final AnimationController _hoverController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 210),
    value: widget.hovered ? 1 : 0,
  );
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 95),
    reverseDuration: const Duration(milliseconds: 140),
    value: widget.pressed ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: _driftDurationFor(widget.seed),
      value: _restPhaseForSeed(widget.seed),
    );
    _updateDriftActivity();
  }

  @override
  void didUpdateWidget(covariant BronzeSpecularLight oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.seed != widget.seed) {
      _driftController.duration = _driftDurationFor(widget.seed);
      if (!_driftController.isAnimating) {
        _driftController.value = _restPhaseForSeed(widget.seed);
      }
    }

    if (oldWidget.hovered != widget.hovered) {
      if (widget.hovered) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
    }

    if (oldWidget.pressed != widget.pressed) {
      if (widget.pressed) {
        _pressController.forward();
      } else {
        _pressController.reverse();
      }
    }

    if (oldWidget.hovered != widget.hovered ||
        oldWidget.pressed != widget.pressed ||
        oldWidget.seed != widget.seed) {
      _updateDriftActivity();
    }
  }

  @override
  void dispose() {
    _driftController.dispose();
    _hoverController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _driftController,
        _hoverController,
        _pressController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final double hoverAmount = Curves.easeOutCubic.transform(
          _hoverController.value,
        );
        final double pressAmount = Curves.easeOutCubic.transform(
          _pressController.value,
        );
        final Alignment alignment = BronzeReflectionPhysics.wanderingAlignment(
          seed: widget.seed,
          progress: _driftController.value,
          hoverAmount: hoverAmount,
          pressAmount: pressAmount,
        );
        final double pulse = BronzeReflectionPhysics.specularPulse(
          seed: widget.seed,
          progress: _driftController.value,
        );
        final double intensity =
            (widget.baseIntensity +
                    (hoverAmount * 0.26) -
                    (pressAmount * 0.18) +
                    (pulse * 0.08))
                .clamp(0.32, 1.6);

        return BronzeReflectionOverlay(
          borderRadius: widget.borderRadius,
          alignment: alignment,
          intensity: intensity,
        );
      },
    );
  }

  Duration _driftDurationFor(int seed) {
    final int normalized = seed.abs();
    return Duration(milliseconds: 8500 + (normalized % 5200));
  }

  double _restPhaseForSeed(int seed) {
    final int normalized = seed.abs();
    return ((normalized % 1000) / 1000).clamp(0.08, 0.92);
  }

  void _updateDriftActivity() {
    final bool shouldAnimate = widget.hovered || widget.pressed;
    if (shouldAnimate) {
      if (!_driftController.isAnimating) {
        _driftController.repeat();
      }
      return;
    }
    if (_driftController.isAnimating) {
      _driftController.stop();
      _driftController.animateTo(
        _restPhaseForSeed(widget.seed),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

class BronzeReflectionPhysics {
  const BronzeReflectionPhysics._();

  static Alignment restingAlignmentForSeed(int seed) {
    final int normalized = seed.abs();
    final double x = ((normalized % 7) - 3) * 0.10;
    final double y = ((normalized % 5) - 2) * 0.06;
    return Alignment(x.clamp(-0.45, 0.45), y.clamp(-0.30, 0.30));
  }

  static Alignment repelledAlignment({
    required Offset localPosition,
    required Size size,
    required Alignment restAlignment,
    double strength = 0.38,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return restAlignment;
    }
    final double normalizedX = ((localPosition.dx / size.width) * 2 - 1).clamp(
      -1.0,
      1.0,
    );
    final double normalizedY = ((localPosition.dy / size.height) * 2 - 1).clamp(
      -1.0,
      1.0,
    );
    return Alignment(
      (restAlignment.x - normalizedX * strength).clamp(-0.96, 0.96),
      (restAlignment.y - normalizedY * strength).clamp(-0.96, 0.96),
    );
  }

  static Alignment wanderingAlignment({
    required int seed,
    required double progress,
    double hoverAmount = 0,
    double pressAmount = 0,
  }) {
    final Alignment rest = restingAlignmentForSeed(seed);
    final double clampedHover = hoverAmount.clamp(0, 1);
    final double clampedPress = pressAmount.clamp(0, 1);
    final double t = progress.clamp(0, 1) * math.pi * 2;
    final double amplitude =
        (0.065 +
            (_seedUnit(seed: seed, salt: 73) * 0.028) +
            (clampedHover * 0.072)) *
        (1 - (clampedPress * 0.40));
    final double x =
        rest.x +
        (math.sin(
              t * (0.7 + _seedUnit(seed: seed, salt: 11)) +
                  (_seedUnit(seed: seed, salt: 17) * math.pi * 2),
            ) *
            amplitude) +
        (math.sin(
              t * (1.45 + _seedUnit(seed: seed, salt: 29)) +
                  (_seedUnit(seed: seed, salt: 41) * math.pi * 2),
            ) *
            amplitude *
            0.48) -
        (clampedHover * 0.10);
    final double y =
        rest.y +
        (math.sin(
              t * (0.92 + _seedUnit(seed: seed, salt: 53)) +
                  (_seedUnit(seed: seed, salt: 59) * math.pi * 2),
            ) *
            amplitude *
            0.62) +
        (math.cos(
              t * (1.7 + _seedUnit(seed: seed, salt: 67)) +
                  (_seedUnit(seed: seed, salt: 71) * math.pi * 2),
            ) *
            amplitude *
            0.34) -
        (clampedHover * 0.042) +
        (clampedPress * 0.028);

    return Alignment(x.clamp(-0.96, 0.96), y.clamp(-0.96, 0.96));
  }

  static double specularPulse({required int seed, required double progress}) {
    final double t = progress.clamp(0, 1) * math.pi * 2;
    final double primaryPhase = _seedUnit(seed: seed, salt: 79) * math.pi * 2;
    final double secondaryPhase = _seedUnit(seed: seed, salt: 83) * math.pi * 2;
    final double primary = math.sin(
      t * (1.2 + _seedUnit(seed: seed, salt: 89)) + primaryPhase,
    );
    final double secondary = math.sin(
      t * (0.58 + _seedUnit(seed: seed, salt: 97)) + secondaryPhase,
    );
    return ((primary * 0.66) + (secondary * 0.34)).clamp(-1.0, 1.0);
  }

  static double _seedUnit({required int seed, required int salt}) {
    final int normalized = seed.abs();
    final int mixed = ((normalized + 1) * (salt + 31)) % 997;
    return mixed / 997;
  }
}
