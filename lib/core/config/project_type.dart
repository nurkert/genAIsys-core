// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Detected project type based on build system marker files.
///
/// Used by [ProjectTypeDetectionService] to identify the language/framework
/// of a project, and by [QualityGateProfile] to select sensible defaults
/// for quality gate commands, safe-write roots, and shell allowlist entries.
enum ProjectType {
  dartFlutter,
  node,
  python,
  rust,
  go,
  java,
  unknown;

  /// Returns the config-YAML key for this project type.
  ///
  /// Example: `ProjectType.dartFlutter.configKey` → `'dart_flutter'`.
  String get configKey => switch (this) {
    dartFlutter => 'dart_flutter',
    node => 'node',
    python => 'python',
    rust => 'rust',
    go => 'go',
    java => 'java',
    unknown => 'unknown',
  };

  /// Parses a config-YAML key back to [ProjectType].
  ///
  /// Returns `null` for unrecognized keys.
  static ProjectType? fromConfigKey(String key) =>
      switch (key.trim().toLowerCase()) {
        'dart_flutter' || 'dart' || 'flutter' => dartFlutter,
        'node' || 'nodejs' || 'javascript' || 'typescript' => node,
        'python' => python,
        'rust' => rust,
        'go' || 'golang' => go,
        'java' => java,
        'unknown' => unknown,
        _ => null,
      };
}
