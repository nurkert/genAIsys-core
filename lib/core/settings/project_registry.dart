// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:meta/meta.dart';

@immutable
class RegisteredProject {
  const RegisteredProject({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.createdAtIso8601,
    this.lastOpenedAtIso8601,
  });

  final String id;
  final String name;
  final String rootPath;
  final String createdAtIso8601;
  final String? lastOpenedAtIso8601;

  RegisteredProject copyWith({
    String? id,
    String? name,
    String? rootPath,
    String? createdAtIso8601,
    Object? lastOpenedAtIso8601 = _noChange,
  }) {
    return RegisteredProject(
      id: id ?? this.id,
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
      createdAtIso8601: createdAtIso8601 ?? this.createdAtIso8601,
      lastOpenedAtIso8601: identical(lastOpenedAtIso8601, _noChange)
          ? this.lastOpenedAtIso8601
          : lastOpenedAtIso8601 as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'root_path': rootPath,
      'created_at': createdAtIso8601,
      'last_opened_at': lastOpenedAtIso8601,
    };
  }

  static RegisteredProject fromJson(Map<String, Object?> json) {
    return RegisteredProject(
      id: _stringOrDefault(json['id'], ''),
      name: _stringOrDefault(json['name'], ''),
      rootPath: _stringOrDefault(json['root_path'], ''),
      createdAtIso8601: _stringOrDefault(json['created_at'], ''),
      lastOpenedAtIso8601: _nullableString(json['last_opened_at']),
    );
  }

  static String _stringOrDefault(Object? raw, String fallback) {
    if (raw is! String) {
      return fallback;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  static String? _nullableString(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RegisteredProject &&
        other.id == id &&
        other.name == name &&
        other.rootPath == rootPath &&
        other.createdAtIso8601 == createdAtIso8601 &&
        other.lastOpenedAtIso8601 == lastOpenedAtIso8601;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, rootPath, createdAtIso8601, lastOpenedAtIso8601);
}

@immutable
class ProjectRegistry {
  const ProjectRegistry({
    required this.projects,
    required this.lastOpenedProjectId,
  });

  static const ProjectRegistry empty = ProjectRegistry(
    projects: <RegisteredProject>[],
    lastOpenedProjectId: null,
  );

  final List<RegisteredProject> projects;
  final String? lastOpenedProjectId;

  ProjectRegistry copyWith({
    List<RegisteredProject>? projects,
    Object? lastOpenedProjectId = _noChange,
  }) {
    return ProjectRegistry(
      projects: List<RegisteredProject>.unmodifiable(projects ?? this.projects),
      lastOpenedProjectId: identical(lastOpenedProjectId, _noChange)
          ? this.lastOpenedProjectId
          : lastOpenedProjectId as String?,
    );
  }

  RegisteredProject? get lastOpenedProject {
    final String? id = lastOpenedProjectId;
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    for (final RegisteredProject project in projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'last_opened_project_id': lastOpenedProjectId,
      'projects': projects
          .map((RegisteredProject entry) => entry.toJson())
          .toList(),
    };
  }

  static ProjectRegistry fromJson(Map<String, Object?> json) {
    final Object? rawProjects = json['projects'];
    final List<RegisteredProject> decodedProjects = <RegisteredProject>[];
    if (rawProjects is List) {
      for (final Object? item in rawProjects) {
        if (item is! Map) {
          continue;
        }
        final Map<String, Object?> mapped = Map<String, Object?>.from(
          item.cast<String, Object?>(),
        );
        final RegisteredProject project = RegisteredProject.fromJson(mapped);
        if (project.id.isEmpty ||
            project.name.isEmpty ||
            project.rootPath.isEmpty) {
          continue;
        }
        decodedProjects.add(project);
      }
    }

    final String? lastOpenedId = _nullableString(
      json['last_opened_project_id'],
    );
    return ProjectRegistry(
      projects: List<RegisteredProject>.unmodifiable(decodedProjects),
      lastOpenedProjectId: lastOpenedId,
    );
  }

  static String? _nullableString(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ProjectRegistry &&
        _listEquals(other.projects, projects) &&
        other.lastOpenedProjectId == lastOpenedProjectId;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(projects), lastOpenedProjectId);
}

const Object _noChange = Object();

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
