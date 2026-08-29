// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../common/metal_sidebar_button.dart';

/// Left-sidebar navigation button for the project-window shell.
///
/// Delegates all rendering to the shared [MetalSidebarButton].
class LeftSidebarItemButton extends StatelessWidget {
  const LeftSidebarItemButton({
    super.key,
    required this.item,
    required this.index,
    required this.selected,
    required this.darkMode,
    required this.onPressed,
  });

  final SidebarNavItem item;
  final int index;
  final bool selected;
  final bool darkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MetalSidebarButton(
      icon: item.icon,
      label: item.label,
      selected: selected,
      darkMode: darkMode,
      onPressed: onPressed,
      gradientSeed: 100 + index,
      textureSeed: 300 + index,
    );
  }
}
