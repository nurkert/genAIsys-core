// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../../core/app/app.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'mini_tag.dart';

class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.event});

  final AppRunLogEventDto event;

  @override
  Widget build(BuildContext context) {
    final Map<String, Object?> data = event.data ?? const <String, Object?>{};
    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.space10),
      decoration: UiSurfaceStyles.panel(
        context,
        tone: DesktopSurfaceTone.base,
        elevated: false,
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(PhosphorIconsRegular.circle, size: 10),
              const SizedBox(width: UiChromeConfig.space8),
              Expanded(
                child: Text(
                  event.event,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _formatTimestamp(event.timestamp),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (event.message != null &&
              event.message!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: UiChromeConfig.space4),
            Text(
              event.message!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: UiChromeConfig.space6),
          Wrap(
            spacing: UiChromeConfig.space6,
            runSpacing: UiChromeConfig.space6,
            children: <Widget>[
              if (data['step_id'] != null)
                MiniTag(label: 'step ${data['step_id']}'),
              if (data['task_id'] != null)
                MiniTag(label: 'task ${data['task_id']}'),
              if (data['subtask_id'] != null)
                MiniTag(label: 'subtask ${data['subtask_id']}'),
              if (data['decision'] != null)
                MiniTag(label: '${data['decision']}'),
              if (data['error_kind'] != null)
                MiniTag(label: '${data['error_kind']}', error: true),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? value) {
    final DateTime? parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) {
      return value?.trim().isNotEmpty == true ? value!.trim() : '-';
    }
    final DateTime local = parsed.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
