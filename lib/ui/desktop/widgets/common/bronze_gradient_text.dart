// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/premium_white_bronze_tokens.dart';

class BronzeGradientText extends StatelessWidget {
  const BronzeGradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
    this.seed = 0,
  });

  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final TextStyle fallback =
        Theme.of(context).textTheme.headlineSmall ??
        const TextStyle(fontSize: 30, fontWeight: FontWeight.w700);
    final Gradient resolvedGradient =
        gradient ?? PremiumWhiteBronzeTokens.bronzeGradientFor(seed);

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => resolvedGradient.createShader(bounds),
      child: Text(text, style: style ?? fallback),
    );
  }
}
