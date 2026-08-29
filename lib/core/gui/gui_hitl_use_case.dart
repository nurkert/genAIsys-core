// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../app/contracts/app_result.dart';
import '../app/contracts/genaisys_api.dart';
import '../app/dto/hitl_gate_dto.dart';
import '../app/use_cases/in_process_genaisys_api.dart';

/// Use-case wrapper for Human-in-the-Loop (HITL) gate interactions.
///
/// Keeps GUI layers decoupled from the adapter implementation.
class GuiHitlUseCase {
  GuiHitlUseCase({GenaisysApi? api}) : _api = api ?? InProcessGenaisysApi();

  final GenaisysApi _api;

  /// Returns the currently pending HITL gate for [projectRoot].
  Future<AppResult<HitlGateDto>> getGate(String projectRoot) {
    return _api.getHitlGate(projectRoot);
  }

  /// Approves the pending gate, allowing the autopilot to continue.
  Future<AppResult<void>> approve(String projectRoot, {String? note}) {
    return _api.submitHitlDecision(
      projectRoot,
      decision: 'approve',
      note: note,
    );
  }

  /// Rejects the pending gate, causing the autopilot to terminate cleanly.
  Future<AppResult<void>> reject(String projectRoot, {String? note}) {
    return _api.submitHitlDecision(
      projectRoot,
      decision: 'reject',
      note: note,
    );
  }
}
