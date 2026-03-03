// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../app/app.dart';

/// Abstract interface shared by [TextPresenter] and [JsonPresenter].
///
/// Covers every `write*` method whose signature is identical in both
/// implementations.  Methods with presenter-specific signatures
/// (`writeTasks`, `writeNext`/`writeTask`, `writeReviewDecision`,
/// `writeAutopilotSimulation`, `writeError`) remain on the concrete classes.
abstract class CliPresenter {
  // ── Setup ──────────────────────────────────────────────────────────────────

  void writeInit(IOSink out, ProjectInitializationDto dto);
  void writeStatus(IOSink out, AppStatusSnapshotDto dto);

  // ── Task lifecycle ─────────────────────────────────────────────────────────

  void writeCycle(IOSink out, CycleTickDto dto);
  void writeCycleRun(IOSink out, TaskCycleExecutionDto dto);
  void writeActivate(IOSink out, TaskActivationDto dto);
  void writeDeactivate(IOSink out, TaskDeactivationDto dto);
  void writeSpecInit(IOSink out, SpecInitializationDto dto);
  void writeDone(IOSink out, TaskDoneDto dto);
  void writeBlock(IOSink out, TaskBlockedDto dto);

  // ── Review ─────────────────────────────────────────────────────────────────

  void writeReviewStatus(IOSink out, AppReviewStatusDto dto);
  void writeReviewClear(IOSink out, ReviewClearDto dto);

  // ── Autopilot ──────────────────────────────────────────────────────────────

  void writeAutopilotStep(IOSink out, AutopilotStepDto dto);
  void writeAutopilotRun(IOSink out, AutopilotRunDto dto);
  void writeAutopilotCandidate(IOSink out, AutopilotCandidateDto dto);
  void writeAutopilotPilot(IOSink out, AutopilotPilotDto dto);
  void writeAutopilotBranchCleanup(IOSink out, AutopilotBranchCleanupDto dto);
  void writeAutopilotStatus(IOSink out, AutopilotStatusDto dto);
  void writeAutopilotStop(IOSink out, AutopilotStopDto dto);
  void writeAutopilotSmoke(IOSink out, AutopilotSmokeDto dto);
  void writeAutopilotImprove(IOSink out, AutopilotImproveDto dto);
  void writeAutopilotHeal(IOSink out, AutopilotHealDto dto);

  // ── Supervisor ─────────────────────────────────────────────────────────────

  void writeAutopilotSupervisorStart(
    IOSink out,
    AutopilotSupervisorStartDto dto,
  );
  void writeAutopilotSupervisorStop(
    IOSink out,
    AutopilotSupervisorStopDto dto,
  );
  void writeAutopilotSupervisorStatus(
    IOSink out,
    AutopilotSupervisorStatusDto dto,
  );
}
