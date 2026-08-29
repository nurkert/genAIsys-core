// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../../core/app/app.dart';
import 'project_workspace_controller.dart';

/// Manages project configuration loading and saving.
///
/// Extracted from [ProjectWorkspaceController] to isolate config
/// state changes so they don't trigger rebuilds in unrelated views.
class ProjectConfigController {
  ProjectConfigController({
    required String projectRootPath,
    required GenaisysApi api,
  }) : _projectRootPath = projectRootPath,
       _api = api;

  final String _projectRootPath;
  final GenaisysApi _api;

  AppConfigDto? _config;

  AppConfigDto? get config => _config;

  ProjectSettingsDraft? get settingsDraft {
    final AppConfigDto? c = _config;
    if (c == null) {
      return null;
    }
    return ProjectSettingsDraft.fromConfig(c);
  }

  /// Applies a pre-fetched config (e.g. from an isolate) without hitting the API.
  void applyConfig(AppConfigDto config) {
    _config = config;
  }

  /// Fetches config from the API. Returns error message or null.
  Future<String?> refresh() async {
    final AppResult<AppConfigDto> result = await _api.getConfig(
      _projectRootPath,
    );
    if (result.ok && result.data != null) {
      _config = result.data;
      return null;
    }
    return result.error?.message ?? 'Failed to load config.';
  }

  /// Saves settings. Returns the result to let the coordinator handle errors.
  Future<AppResult<ConfigUpdateDto>> save(ProjectSettingsDraft draft) {
    final AppConfigDto updated = draft.toConfig();
    return _api.updateConfig(_projectRootPath, config: updated);
  }

  void dispose() {
    // No notifiers to dispose.
  }
}
