// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all HITL (Human-in-the-Loop) fields from [ProjectConfig].
class HitlConfig {
  const HitlConfig({
    required this.enabled,
    required this.timeoutMinutes,
    required this.gateAfterTaskDone,
    required this.gateBeforeSprint,
    required this.gateBeforeHalt,
  });

  factory HitlConfig.fromProjectConfig(ProjectConfig c) => HitlConfig(
    enabled: c.hitlEnabled,
    timeoutMinutes: c.hitlTimeoutMinutes,
    gateAfterTaskDone: c.hitlGateAfterTaskDone,
    gateBeforeSprint: c.hitlGateBeforeSprint,
    gateBeforeHalt: c.hitlGateBeforeHalt,
  );

  final bool enabled;
  final int timeoutMinutes;
  final bool gateAfterTaskDone;
  final bool gateBeforeSprint;
  final bool gateBeforeHalt;

  /// The effective poll timeout, or `null` for unlimited.
  Duration? get timeout =>
      timeoutMinutes == 0 ? null : Duration(minutes: timeoutMinutes);
}
