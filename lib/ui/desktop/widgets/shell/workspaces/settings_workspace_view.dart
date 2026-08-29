// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../controllers/config_settings_controller.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../theme/ui_chrome_config.dart';
import 'project_settings_workspace_view.dart';
import 'settings/config_settings_view.dart';
import 'workspace_header.dart';

/// The project's settings surface.
///
/// **All settings** is generated from the config field registry and therefore
/// covers every scalar config key the engine knows about — it stays complete as
/// keys are added.
///
/// **Paths & allowlist** holds the list-valued settings (safe-write roots, the
/// shell allowlist) that the scalar registry cannot express yet, and which are
/// edited as a batch with an explicit save.
class SettingsWorkspaceView extends StatefulWidget {
  const SettingsWorkspaceView({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  State<SettingsWorkspaceView> createState() => _SettingsWorkspaceViewState();
}

class _SettingsWorkspaceViewState extends State<SettingsWorkspaceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ConfigSettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _settingsController = ConfigSettingsController(
      projectRoot: widget.controller.projectRootPath,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.all(UiChromeConfig.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WorkspaceHeader(
            title: strings.projectSettingsTitle,
            subtitle: strings.projectSettingsSubtitle,
            seed: 91,
          ),
          const SizedBox(height: UiChromeConfig.space16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: <Widget>[
              Tab(text: strings.settingsAllTabLabel),
              Tab(text: strings.settingsListsTabLabel),
            ],
          ),
          const SizedBox(height: UiChromeConfig.space16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                ConfigSettingsView(
                  controller: _settingsController,
                  strings: strings,
                ),
                ProjectSettingsWorkspaceView(controller: widget.controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
