// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/premium_white_bronze_tokens.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    required this.borderRadius,
    this.lightColor = PremiumWhiteBronzeTokens.glassLight,
    this.darkColor = PremiumWhiteBronzeTokens.glassDark,
    this.lightBorderColor = const Color(0x2AFFFFFF),
    this.darkBorderColor = const Color(0x33FFFFFF),
  });

  final Widget child;
  final double borderRadius;
  final Color lightColor;
  final Color darkColor;
  final Color lightBorderColor;
  final Color darkBorderColor;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color background = dark ? darkColor : lightColor;
    final Color border = dark ? darkBorderColor : lightBorderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
