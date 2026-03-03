// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_type.dart';

/// Detects the project type by scanning for build system marker files.
///
/// Detection uses file existence only (no content parsing) and follows a
/// fixed priority order. When multiple markers are present (e.g. a Flutter
/// project with both `pubspec.yaml` and `package.json`), the highest-priority
/// match wins.
///
/// Priority order:
/// 1. Dart/Flutter (`pubspec.yaml`)
/// 2. Node.js (`package.json`)
/// 3. Python (`pyproject.toml`, `requirements.txt`, `setup.py`)
/// 4. Rust (`Cargo.toml`)
/// 5. Go (`go.mod`)
/// 6. Java (`pom.xml`, `build.gradle`, `build.gradle.kts`)
/// 7. Unknown (no recognized marker)
class ProjectTypeDetectionService {
  /// Detects the project type at [projectRoot].
  ///
  /// Returns [ProjectType.unknown] when no recognized marker file is found.
  ProjectType detect(String projectRoot) {
    for (final entry in _markerTable) {
      for (final marker in entry.markers) {
        if (File(_join(projectRoot, marker)).existsSync()) {
          return entry.type;
        }
      }
    }
    return ProjectType.unknown;
  }

  static String _join(String root, String child) {
    if (root.endsWith(Platform.pathSeparator)) {
      return '$root$child';
    }
    return '$root${Platform.pathSeparator}$child';
  }
}

/// Marker table in priority order. First match wins.
const _markerTable = [
  _Marker(ProjectType.dartFlutter, ['pubspec.yaml']),
  _Marker(ProjectType.node, ['package.json']),
  _Marker(ProjectType.python, [
    'pyproject.toml',
    'requirements.txt',
    'setup.py',
  ]),
  _Marker(ProjectType.rust, ['Cargo.toml']),
  _Marker(ProjectType.go, ['go.mod']),
  _Marker(ProjectType.java, ['pom.xml', 'build.gradle', 'build.gradle.kts']),
];

class _Marker {
  const _Marker(this.type, this.markers);
  final ProjectType type;
  final List<String> markers;
}
