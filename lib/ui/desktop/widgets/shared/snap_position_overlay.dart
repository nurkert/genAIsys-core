// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

/// Animates a widget from a drop position to its final resting position.
class SnapOverlay extends StatefulWidget {
  const SnapOverlay({
    super.key,
    required this.from,
    required this.to,
    required this.width,
    required this.duration,
    required this.curve,
    required this.onComplete,
    required this.child,
  });

  final Offset from;
  final Offset to;
  final double width;
  final Duration duration;
  final Curve curve;
  final VoidCallback onComplete;
  final Widget child;

  @override
  State<SnapOverlay> createState() => _SnapOverlayState();
}

class _SnapOverlayState extends State<SnapOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _positionAnimation = Tween<Offset>(
      begin: widget.from,
      end: widget.to,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (BuildContext context, Widget? child) {
        final Offset pos = _positionAnimation.value;
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          width: widget.width,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}
