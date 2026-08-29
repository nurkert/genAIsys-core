// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';

class AutopilotTabBar extends StatelessWidget {
  const AutopilotTabBar({
    super.key,
    required this.controller,
    required this.strings,
  });

  final TabController controller;
  final DesktopStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelPadding: const EdgeInsets.symmetric(
          horizontal: UiChromeConfig.space14,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: <Widget>[
          Tab(text: strings.autopilotTabLive),
          Tab(text: strings.autopilotTabTimeline),
          Tab(text: strings.autopilotTabDetails),
        ],
      ),
    );
  }
}
