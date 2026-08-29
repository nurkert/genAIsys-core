// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/animation.dart';

/// Motion tokens for desktop shell transitions.
class UiMotionConfig {
  const UiMotionConfig._();

  static const Duration shellDuration = Duration(milliseconds: 230);
  static const Duration fadeDuration = Duration(milliseconds: 160);
  static const Duration fullscreenStartDelay = Duration(milliseconds: 380);
  static const Duration fullscreenCollapseDuration = Duration(
    milliseconds: 420,
  );
  static const Duration fullscreenExpandDuration = Duration(milliseconds: 560);
  static const Duration fullscreenDuration = fullscreenCollapseDuration;
  static const Curve shellCurve = Curves.easeOutCubic;
  static const Curve fullscreenCurve = Curves.easeInOutCubic;

  // Kanban drag-and-drop motion tokens.
  static const Duration kanbanGapOpenDuration = Duration(milliseconds: 200);
  static const Duration kanbanGapCloseDuration = Duration(milliseconds: 160);
  static const Duration kanbanSettleMinDuration = Duration(milliseconds: 180);
  static const Duration kanbanSettleMaxDuration = Duration(milliseconds: 280);
  static const Duration kanbanSourceShrinkDuration = Duration(
    milliseconds: 150,
  );
  static const Curve kanbanGapCurve = Curves.easeOutCubic;
  static const Curve kanbanSettleCurve = Curves.easeOutCubic;

  /// Minimum pixel distance to trigger a snap animation; below this the card
  /// simply appears instantly at its final position.
  static const double kanbanSnapMinDistance = 20;

  /// Maximum pixel distance used to scale the snap animation duration.
  /// Drops farther than this get [kanbanSettleMaxDuration].
  static const double kanbanSnapMaxDistance = 600;
}
