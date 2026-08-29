// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../controllers/project_workspace_controller.dart';
import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'collapsible_section.dart';

class CollapsibleControlStrip extends StatelessWidget {
  const CollapsibleControlStrip({
    super.key,
    required this.controller,
    required this.strings,
  });

  final ProjectWorkspaceController controller;
  final DesktopStrings strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.actionInProgressNotifier,
      builder: (BuildContext context, bool busy, Widget? child) {
        return Container(
          padding: const EdgeInsets.all(UiChromeConfig.space10),
          decoration: UiSurfaceStyles.panel(
            context,
            tone: DesktopSurfaceTone.soft,
            elevated: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Primary actions – always visible
              Wrap(
                spacing: UiChromeConfig.space8,
                runSpacing: UiChromeConfig.space8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.runAutopilotStep()),
                    icon: const Icon(PhosphorIconsRegular.play, size: 16),
                    label: Text(strings.autopilotRunStepAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.stopAutopilot()),
                    icon: const Icon(PhosphorIconsRegular.pause, size: 16),
                    label: Text(strings.autopilotStopAction),
                  ),
                ],
              ),
              const SizedBox(height: UiChromeConfig.space8),

              // Task Actions – collapsible
              CollapsibleSection(
                title: strings.autopilotTaskActionsLabel,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.activateNextTask()),
                    icon: const Icon(PhosphorIconsRegular.arrowRight, size: 16),
                    label: Text(strings.autopilotActivateNextAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.markActiveTaskDone()),
                    icon: const Icon(PhosphorIconsRegular.check, size: 16),
                    label: Text(strings.autopilotMarkDoneAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.blockActiveTask()),
                    icon: const Icon(PhosphorIconsRegular.warning, size: 16),
                    label: Text(strings.autopilotBlockActiveAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.deactivateActiveTask()),
                    icon: const Icon(PhosphorIconsRegular.handPalm, size: 16),
                    label: Text(strings.autopilotDeactivateAction),
                  ),
                ],
              ),

              // Review Actions – collapsible
              CollapsibleSection(
                title: strings.autopilotReviewActionsLabel,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.approveReview()),
                    icon: const Icon(PhosphorIconsRegular.sealCheck, size: 16),
                    label: Text(strings.autopilotApproveAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.rejectReview()),
                    icon: const Icon(
                      PhosphorIconsRegular.sealWarning,
                      size: 16,
                    ),
                    label: Text(strings.autopilotRejectAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.clearReview()),
                    icon: const Icon(PhosphorIconsRegular.xCircle, size: 16),
                    label: Text(strings.autopilotClearReviewAction),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
