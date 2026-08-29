// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pre-computed segment for a single brushed-metal stroke.
class _BrushSegment {
  const _BrushSegment(
    this.start,
    this.end,
    this.bright,
    this.thickness,
    this.alpha,
  );

  final Offset start;
  final Offset end;
  final bool bright;
  final double thickness;
  final double alpha;
}

/// Paints subtle, irregular brushed-metal streaks.
///
/// The streaks are horizontal (left -> right), with small varying gaps so they
/// do not look like a uniform interference pattern.
///
/// Segments are pre-computed once per [seed]/[strength] combination and cached.
/// The [paint] method only iterates over cached segments, avoiding per-frame
/// [Random] instantiation and computation.
class BronzeBrushTexturePainter extends CustomPainter {
  BronzeBrushTexturePainter({
    required this.seed,
    required this.strength,
    required this.borderRadius,
  });

  final int seed;
  final double strength;
  final double borderRadius;

  List<_BrushSegment>? _cachedSegments;
  double _cachedWidth = -1;
  double _cachedHeight = -1;

  List<_BrushSegment> _buildSegments(Size size) {
    final math.Random random = math.Random(seed);
    final List<_BrushSegment> segments = <_BrushSegment>[];

    double y = 0.25 + random.nextDouble() * 0.45;
    while (y < size.height + 1) {
      final bool brightLane = random.nextBool();
      final double laneThickness = 0.35 + random.nextDouble() * 0.75;
      final double laneAlpha =
          (0.014 + random.nextDouble() * 0.09) * strength.clamp(0.2, 1.3);

      double x = -size.width * 0.03 + random.nextDouble() * 10;
      while (x < size.width + 8) {
        final double segmentLength = (10 + random.nextDouble() * 72) * 2.0;
        final double gapLength = 4 + random.nextDouble() * 20;

        final bool drawSegment = random.nextDouble() > 0.22;
        if (drawSegment) {
          final double endX = math.min(size.width + 6, x + segmentLength);
          final double yJitter = (random.nextDouble() - 0.5) * 0.55;
          final double tilt = (random.nextDouble() - 0.5) * 0.32;
          segments.add(
            _BrushSegment(
              Offset(x, y + yJitter),
              Offset(endX, y + yJitter + tilt),
              brightLane,
              laneThickness,
              brightLane ? laneAlpha : laneAlpha * 0.88,
            ),
          );
        }

        x += segmentLength + gapLength;
      }

      y += laneThickness + 0.16 + random.nextDouble() * 0.72;
    }

    return segments;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || strength <= 0) {
      return;
    }

    if (_cachedSegments == null ||
        _cachedWidth != size.width ||
        _cachedHeight != size.height) {
      _cachedSegments = _buildSegments(size);
      _cachedWidth = size.width;
      _cachedHeight = size.height;
    }

    final RRect clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    canvas.save();
    canvas.clipRRect(clip);

    for (final _BrushSegment seg in _cachedSegments!) {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = seg.thickness
        ..color = (seg.bright ? Colors.white : Colors.black).withValues(
          alpha: seg.alpha,
        );
      canvas.drawLine(seg.start, seg.end, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BronzeBrushTexturePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.strength != strength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
