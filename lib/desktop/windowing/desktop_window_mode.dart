// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum DesktopWindowMode { projectWorkspace, projectHub, settingsWorkspace }

extension DesktopWindowModeKey on DesktopWindowMode {
  String get key => switch (this) {
    DesktopWindowMode.projectWorkspace => 'project_workspace',
    DesktopWindowMode.projectHub => 'project_hub',
    DesktopWindowMode.settingsWorkspace => 'settings_workspace',
  };
}

class DesktopWindowModeParser {
  const DesktopWindowModeParser._();

  static DesktopWindowMode parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'project_hub':
      case 'hub':
        return DesktopWindowMode.projectHub;
      case 'settings_workspace':
      case 'settings':
        return DesktopWindowMode.settingsWorkspace;
      case 'project_workspace':
      case 'project':
      default:
        return DesktopWindowMode.projectWorkspace;
    }
  }
}
