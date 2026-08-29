// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

import '../../../core/settings/project_registry.dart';
import '../../../core/settings/project_registry_service.dart';
import '../models/project_hub_models.dart';

class ProjectHubController extends ChangeNotifier {
  ProjectHubController({required ProjectRegistryService registryService})
    : _registryService = registryService;

  final ProjectRegistryService _registryService;

  ProjectRegistry _registry = ProjectRegistry.empty;
  bool _isLoading = false;
  String _searchQuery = '';
  ProjectHubSection _activeSection = ProjectHubSection.projects;

  ProjectRegistry get registry => _registry;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  ProjectHubSection get activeSection => _activeSection;
  List<RegisteredProject> get projects => _registry.projects;
  String? get lastOpenedProjectId => _registry.lastOpenedProjectId;

  List<RegisteredProject> get filteredProjects {
    if (_searchQuery.isEmpty) {
      return projects;
    }
    final String query = _searchQuery.toLowerCase();
    return projects
        .where(
          (RegisteredProject p) =>
              p.name.toLowerCase().contains(query) ||
              p.rootPath.toLowerCase().contains(query),
        )
        .toList();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void selectSection(ProjectHubSection section) {
    if (_activeSection == section) {
      return;
    }
    _activeSection = section;
    notifyListeners();
  }

  Future<void> load() async {
    await _runWithLoading(() async {
      _registry = await _registryService.load();
    });
  }

  Future<void> registerProject({
    required String projectName,
    required String projectRootPath,
    bool markAsLastOpened = false,
  }) async {
    await _runWithLoading(() async {
      _registry = await _registryService.registerProject(
        name: projectName,
        rootPath: projectRootPath,
        markAsLastOpened: markAsLastOpened,
      );
    });
  }

  Future<void> markProjectOpened(String projectId) async {
    await _runWithLoading(() async {
      _registry = await _registryService.markProjectOpened(projectId);
    });
  }

  Future<void> deleteProject(String projectId) async {
    await _runWithLoading(() async {
      _registry = await _registryService.deleteProject(projectId);
    });
  }

  Future<void> _runWithLoading(Future<void> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
