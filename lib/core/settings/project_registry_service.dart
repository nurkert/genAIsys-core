// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'project_registry.dart';
import 'project_registry_repository.dart';

class ProjectRegistryService {
  ProjectRegistryService({ProjectRegistryRepository? repository})
    : _repository = repository ?? FileProjectRegistryRepository();

  final ProjectRegistryRepository _repository;

  Future<ProjectRegistry> load() {
    return _repository.read();
  }

  Future<ProjectRegistry> registerProject({
    required String name,
    required String rootPath,
    bool markAsLastOpened = false,
    DateTime? now,
  }) async {
    final String normalizedPath = _normalizePath(rootPath);
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(rootPath, 'rootPath', 'must not be empty');
    }
    _ensureProjectDirectoryExists(normalizedPath);

    final String normalizedName = _normalizeName(
      name,
      fallbackPath: normalizedPath,
    );
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    final String timestampIso = timestamp.toIso8601String();

    final ProjectRegistry registry = await _repository.read();
    final String projectId = _projectIdForPath(normalizedPath);

    final List<RegisteredProject> updatedProjects = <RegisteredProject>[];
    var existed = false;
    for (final RegisteredProject project in registry.projects) {
      if (project.id != projectId) {
        updatedProjects.add(project);
        continue;
      }
      existed = true;
      updatedProjects.add(
        project.copyWith(
          name: normalizedName,
          rootPath: normalizedPath,
          lastOpenedAtIso8601: markAsLastOpened
              ? timestampIso
              : project.lastOpenedAtIso8601,
        ),
      );
    }

    if (!existed) {
      updatedProjects.add(
        RegisteredProject(
          id: projectId,
          name: normalizedName,
          rootPath: normalizedPath,
          createdAtIso8601: timestampIso,
          lastOpenedAtIso8601: markAsLastOpened ? timestampIso : null,
        ),
      );
    }

    final ProjectRegistry nextRegistry = _normalizedRegistry(
      registry.copyWith(
        projects: updatedProjects,
        lastOpenedProjectId: markAsLastOpened
            ? projectId
            : registry.lastOpenedProjectId,
      ),
    );

    await _repository.write(nextRegistry);
    return nextRegistry;
  }

  Future<ProjectRegistry> markProjectOpened(
    String projectId, {
    DateTime? now,
  }) async {
    final String normalizedId = projectId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'must not be empty');
    }

    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    final String timestampIso = timestamp.toIso8601String();
    final ProjectRegistry registry = await _repository.read();
    final List<RegisteredProject> updatedProjects = <RegisteredProject>[];
    var found = false;

    for (final RegisteredProject project in registry.projects) {
      if (project.id != normalizedId) {
        updatedProjects.add(project);
        continue;
      }
      found = true;
      updatedProjects.add(project.copyWith(lastOpenedAtIso8601: timestampIso));
    }

    if (!found) {
      return registry;
    }

    final ProjectRegistry nextRegistry = _normalizedRegistry(
      registry.copyWith(
        projects: updatedProjects,
        lastOpenedProjectId: normalizedId,
      ),
    );
    await _repository.write(nextRegistry);
    return nextRegistry;
  }

  Future<ProjectRegistry> deleteProject(String projectId) async {
    final String normalizedId = projectId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'must not be empty');
    }
    final ProjectRegistry registry = await _repository.read();
    final List<RegisteredProject> remaining = registry.projects
        .where((RegisteredProject project) => project.id != normalizedId)
        .toList(growable: false);
    if (remaining.length == registry.projects.length) {
      return registry;
    }

    final String? nextLastOpened = registry.lastOpenedProjectId == normalizedId
        ? null
        : registry.lastOpenedProjectId;
    final ProjectRegistry nextRegistry = _normalizedRegistry(
      registry.copyWith(
        projects: remaining,
        lastOpenedProjectId: nextLastOpened,
      ),
    );
    await _repository.write(nextRegistry);
    return nextRegistry;
  }

  Future<RegisteredProject?> resolveLastOpenedProject() async {
    final ProjectRegistry registry = await _repository.read();
    final RegisteredProject? project = registry.lastOpenedProject;
    if (project == null) {
      return null;
    }
    final String normalizedPath = project.rootPath.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }
    if (!Directory(normalizedPath).existsSync()) {
      return null;
    }
    return project;
  }

  ProjectRegistry _normalizedRegistry(ProjectRegistry registry) {
    final List<RegisteredProject> sorted = List<RegisteredProject>.from(
      registry.projects,
    )..sort(_compareProjectOrder);

    final String? lastOpenedProjectId = registry.lastOpenedProjectId;
    if (lastOpenedProjectId == null || lastOpenedProjectId.isEmpty) {
      return registry.copyWith(projects: sorted, lastOpenedProjectId: null);
    }
    final bool hasLastOpened = sorted.any(
      (RegisteredProject project) => project.id == lastOpenedProjectId,
    );
    return registry.copyWith(
      projects: sorted,
      lastOpenedProjectId: hasLastOpened ? lastOpenedProjectId : null,
    );
  }

  int _compareProjectOrder(RegisteredProject a, RegisteredProject b) {
    final DateTime? aOpened = _parseIso(a.lastOpenedAtIso8601);
    final DateTime? bOpened = _parseIso(b.lastOpenedAtIso8601);
    if (aOpened != null && bOpened != null) {
      final int byLastOpened = bOpened.compareTo(aOpened);
      if (byLastOpened != 0) {
        return byLastOpened;
      }
    } else if (aOpened != null && bOpened == null) {
      return -1;
    } else if (aOpened == null && bOpened != null) {
      return 1;
    }

    final DateTime? aCreated = _parseIso(a.createdAtIso8601);
    final DateTime? bCreated = _parseIso(b.createdAtIso8601);
    if (aCreated != null && bCreated != null) {
      final int byCreated = bCreated.compareTo(aCreated);
      if (byCreated != 0) {
        return byCreated;
      }
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  DateTime? _parseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  String _projectIdForPath(String normalizedPath) {
    return normalizedPath;
  }

  String _normalizeName(String raw, {required String fallbackPath}) {
    final String trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final List<String> segments = fallbackPath
        .split(RegExp(r'[\\/]'))
        .where((String segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return 'Untitled Project';
    }
    return segments.last;
  }

  String _normalizePath(String rawPath) {
    final String expanded = _expandHome(rawPath.trim());
    if (expanded.isEmpty) {
      return '';
    }
    return Directory(expanded).absolute.path;
  }

  void _ensureProjectDirectoryExists(String normalizedPath) {
    final Directory directory = Directory(normalizedPath);
    if (directory.existsSync()) {
      return;
    }
    directory.createSync(recursive: true);
  }

  String _expandHome(String rawPath) {
    if (!rawPath.startsWith('~')) {
      return rawPath;
    }
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.trim().isEmpty) {
      return rawPath;
    }
    if (rawPath == '~') {
      return home;
    }
    if (rawPath.startsWith('~/') || rawPath.startsWith('~\\')) {
      return '$home${rawPath.substring(1)}';
    }
    return rawPath;
  }
}
