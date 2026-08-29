// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../core/app/app.dart';
import '../core/gui/gui_activate_task_use_case.dart';
import '../core/gui/gui_block_task_use_case.dart';
import '../core/gui/gui_config_use_case.dart';
import '../core/gui/gui_deactivate_task_use_case.dart';
import '../core/gui/gui_done_task_use_case.dart';
import '../core/gui/gui_initialize_project_use_case.dart';
import '../core/gui/gui_review_actions_use_case.dart';
import '../core/gui/gui_review_status_use_case.dart';
import '../core/gui/gui_spec_artifacts_use_case.dart';
import '../core/gui/gui_task_refinement_use_case.dart';
import '../core/gui/gui_task_write_use_case.dart';
import '../core/gui/gui_tasks_use_case.dart';

class AppServices {
  factory AppServices({
    GenaisysApi? api,
    AutopilotStatusUseCase? autopilotStatus,
    AutopilotStopUseCase? autopilotStop,
    AutopilotRunUseCase? autopilotRun,
    AutopilotStepUseCase? autopilotStep,
  }) {
    final resolvedApi = api ?? InProcessGenaisysApi();
    return AppServices._internal(
      resolvedApi,
      autopilotStatus: autopilotStatus,
      autopilotStop: autopilotStop,
      autopilotRun: autopilotRun,
      autopilotStep: autopilotStep,
    );
  }

  AppServices._internal(
    this.api, {
    AutopilotStatusUseCase? autopilotStatus,
    AutopilotStopUseCase? autopilotStop,
    AutopilotRunUseCase? autopilotRun,
    AutopilotStepUseCase? autopilotStep,
  }) : dashboard = GetDashboardUseCase(api: api),
       status = GetStatusUseCase(api: api),
       autopilotStatus = autopilotStatus ?? AutopilotStatusUseCase(),
       autopilotStop = autopilotStop ?? AutopilotStopUseCase(),
       autopilotRun = autopilotRun ?? AutopilotRunUseCase(),
       autopilotStep = autopilotStep ?? AutopilotStepUseCase(),
       initializeProject = GuiInitializeProjectUseCase(api: api),
       reviewStatus = GuiReviewStatusUseCase(api: api),
       tasks = GuiTasksUseCase(api: api),
       activateTask = GuiActivateTaskUseCase(api: api),
       deactivateTask = GuiDeactivateTaskUseCase(api: api),
       doneTask = GuiDoneTaskUseCase(api: api),
       blockTask = GuiBlockTaskUseCase(api: api),
       reviewActions = GuiReviewActionsUseCase(api: api),
       specArtifacts = GuiSpecArtifactsUseCase(api: api),
       config = GuiConfigUseCase(api: api),
       taskWriter = GuiTaskWriteUseCase(api: api),
       taskRefinement = GuiTaskRefinementUseCase(api: api);

  final GenaisysApi api;
  final GetDashboardUseCase dashboard;
  final GetStatusUseCase status;
  final AutopilotStatusUseCase autopilotStatus;
  final AutopilotStopUseCase autopilotStop;
  final AutopilotRunUseCase autopilotRun;
  final AutopilotStepUseCase autopilotStep;
  final GuiInitializeProjectUseCase initializeProject;
  final GuiReviewStatusUseCase reviewStatus;
  final GuiTasksUseCase tasks;
  final GuiActivateTaskUseCase activateTask;
  final GuiDeactivateTaskUseCase deactivateTask;
  final GuiDoneTaskUseCase doneTask;
  final GuiBlockTaskUseCase blockTask;
  final GuiReviewActionsUseCase reviewActions;
  final GuiSpecArtifactsUseCase specArtifacts;
  final GuiConfigUseCase config;
  final GuiTaskWriteUseCase taskWriter;
  final GuiTaskRefinementUseCase taskRefinement;
}
