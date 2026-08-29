// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/widgets.dart';

enum MetalKind { silver, gold, bronze }

enum DesktopPrimarySection {
  chat,
  backlog,
  dashboard,
  reports,
  autopilot,
  projectSettings,
}

class SidebarNavItem {
  const SidebarNavItem({
    required this.section,
    required this.icon,
    required this.label,
    this.pinToBottom = false,
  });

  final DesktopPrimarySection section;
  final IconData icon;
  final String label;
  final bool pinToBottom;
}

class StatCardModel {
  const StatCardModel({
    required this.title,
    required this.value,
    required this.delta,
    required this.metal,
  });

  final String title;
  final String value;
  final String delta;
  final MetalKind metal;
}

class ActivityEntry {
  const ActivityEntry({
    required this.avatar,
    required this.title,
    required this.subtitle,
  });

  final String avatar;
  final String title;
  final String subtitle;
}

class TimelineEntry {
  const TimelineEntry({required this.label});

  final String label;
}
