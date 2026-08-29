// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../../../core/app/app.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'timeline_row.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key, required this.events});

  final List<AppRunLogEventDto> events;

  @override
  Widget build(BuildContext context) {
    final List<AppRunLogEventDto> reversed = events.reversed.toList(
      growable: false,
    );
    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.space14),
      decoration: UiSurfaceStyles.panel(context, tone: DesktopSurfaceTone.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Execution Timeline',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: UiChromeConfig.space8),
          Expanded(
            child: reversed.isEmpty
                ? Text(
                    'No run-log events yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UiSurfaceStyles.mutedOnSurface(context),
                    ),
                  )
                : ListView.separated(
                    itemBuilder: (BuildContext context, int index) {
                      final AppRunLogEventDto event = reversed[index];
                      return TimelineRow(event: event);
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: UiChromeConfig.space8),
                    itemCount: reversed.length,
                  ),
          ),
        ],
      ),
    );
  }
}
