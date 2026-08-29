// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

import '../../../desktop/services/window_service_interface.dart';
import '../models/dashboard_models.dart';

/// Local UI controller for desktop shell concerns.
///
/// Uses separate [ValueNotifier]s so that changing the selected section does NOT
/// trigger a rebuild of the sidebar visibility slot (and vice versa).
class DesktopShellController {
  DesktopShellController({required this.windowService});

  final WindowServiceInterface windowService;

  final ValueNotifier<DesktopPrimarySection> selectedSection =
      ValueNotifier<DesktopPrimarySection>(DesktopPrimarySection.chat);

  final ValueNotifier<bool> rightSidebarVisible = ValueNotifier<bool>(false);

  /// Provided for backward compatibility -- fires on ANY change.
  DesktopPrimarySection get selectedSectionValue => selectedSection.value;
  bool get rightSidebarVisibleValue => rightSidebarVisible.value;

  Future<void> toggleLeftSidebar() async {
    await windowService.setSidebarHidden(!windowService.sidebarHidden.value);
  }

  void toggleRightSidebar() {
    rightSidebarVisible.value = !rightSidebarVisible.value;
  }

  void showRightSidebar() {
    if (rightSidebarVisible.value) {
      return;
    }
    rightSidebarVisible.value = true;
  }

  void selectSection(DesktopPrimarySection section) {
    if (selectedSection.value == section) {
      return;
    }
    selectedSection.value = section;
  }

  void dispose() {
    selectedSection.dispose();
    rightSidebarVisible.dispose();
  }
}
