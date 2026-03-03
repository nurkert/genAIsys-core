// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'project_config.dart';
import 'project_type.dart';

/// Language-specific quality gate profile with sensible defaults.
///
/// Each [ProjectType] maps to a profile that defines:
/// - [qualityGateCommands]: format, lint, and test commands
/// - [safeWriteRoots]: allowed write roots for the safe-write policy
/// - [shellAllowlistExtensions]: language-specific commands to add on top
///   of the base shell allowlist
/// - [dependencyBootstrapCommand]: optional command to run before quality gate
/// - [adaptiveByDiff]: whether adaptive diff scoping is supported (Dart only)
class QualityGateProfile {
  const QualityGateProfile({
    required this.projectType,
    required this.qualityGateCommands,
    required this.safeWriteRoots,
    required this.shellAllowlistExtensions,
    this.dependencyBootstrapCommand,
    this.adaptiveByDiff = false,
  });

  final ProjectType projectType;

  /// Commands to run as quality gate (format, lint, test).
  final List<String> qualityGateCommands;

  /// Allowed write roots for the safe-write policy.
  final List<String> safeWriteRoots;

  /// Language-specific shell allowlist entries, appended to the base allowlist.
  final List<String> shellAllowlistExtensions;

  /// Optional command to bootstrap dependencies before quality gate runs.
  final String? dependencyBootstrapCommand;

  /// Whether adaptive diff scoping is supported for this language.
  ///
  /// Currently only Dart/Flutter projects support narrowing format/analyze/test
  /// commands based on changed file paths.
  final bool adaptiveByDiff;

  /// Returns the built-in profile for a given [ProjectType].
  static QualityGateProfile forProjectType(ProjectType type) => switch (type) {
    ProjectType.dartFlutter => _dartFlutterProfile,
    ProjectType.node => _nodeProfile,
    ProjectType.python => _pythonProfile,
    ProjectType.rust => _rustProfile,
    ProjectType.go => _goProfile,
    ProjectType.java => _javaProfile,
    ProjectType.unknown => _unknownProfile,
  };

  /// Base shell allowlist entries shared across all language profiles.
  ///
  /// These are the minimum commands any Genaisys project needs for
  /// orchestration (search, git status, agent CLIs).
  static const List<String> baseShellAllowlist = [
    'rg',
    'ls',
    'cat',
    'codex',
    'gemini',
    'claude',
    'native',
    'git status',
    'git diff',
    'git log',
    'git show',
    'git branch',
    'git rev-parse',
  ];
}

// ---------------------------------------------------------------------------
// Built-in profiles
// ---------------------------------------------------------------------------

/// Dart/Flutter profile — references [ProjectConfig] constants directly
/// to guarantee backward compatibility.
const _dartFlutterProfile = QualityGateProfile(
  projectType: ProjectType.dartFlutter,
  qualityGateCommands: ProjectConfig.defaultQualityGateCommands,
  safeWriteRoots: ProjectConfig.defaultSafeWriteRoots,
  shellAllowlistExtensions: [
    'flutter test',
    'dart test',
    'dart format',
    'dart analyze',
    'flutter pub get',
  ],
  dependencyBootstrapCommand: 'flutter pub get',
  adaptiveByDiff: true,
);

const _nodeProfile = QualityGateProfile(
  projectType: ProjectType.node,
  qualityGateCommands: ['npx prettier --check .', 'npx eslint .', 'npm test'],
  safeWriteRoots: [
    'src',
    'lib',
    'test',
    'tests',
    '__tests__',
    'scripts',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'package.json',
    'package-lock.json',
    'tsconfig.json',
    '.eslintrc.json',
    '.prettierrc',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: ['npm', 'npx', 'node'],
  dependencyBootstrapCommand: 'npm install',
);

const _pythonProfile = QualityGateProfile(
  projectType: ProjectType.python,
  qualityGateCommands: ['ruff format --check .', 'ruff check .', 'pytest'],
  safeWriteRoots: [
    'src',
    'lib',
    'tests',
    'test',
    'scripts',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: ['pip', 'pytest', 'ruff', 'python', 'python3'],
);

const _rustProfile = QualityGateProfile(
  projectType: ProjectType.rust,
  qualityGateCommands: [
    'cargo fmt --check',
    'cargo clippy -- -D warnings',
    'cargo test',
  ],
  safeWriteRoots: [
    'src',
    'tests',
    'benches',
    'examples',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'Cargo.toml',
    'Cargo.lock',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: ['cargo', 'rustc', 'rustfmt'],
);

const _goProfile = QualityGateProfile(
  projectType: ProjectType.go,
  qualityGateCommands: ['gofmt -l .', 'golangci-lint run', 'go test ./...'],
  safeWriteRoots: [
    'cmd',
    'internal',
    'pkg',
    'test',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'go.mod',
    'go.sum',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: ['go', 'golangci-lint', 'gofmt'],
);

const _javaProfile = QualityGateProfile(
  projectType: ProjectType.java,
  qualityGateCommands: ['mvn compile', 'mvn test'],
  safeWriteRoots: [
    'src',
    'test',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: ['mvn', 'gradle', 'java', 'javac'],
);

const _unknownProfile = QualityGateProfile(
  projectType: ProjectType.unknown,
  qualityGateCommands: [],
  safeWriteRoots: [
    'src',
    'lib',
    'test',
    'docs',
    '.genaisys/agent_contexts',
    '.github',
    'README.md',
    '.gitignore',
    'CHANGELOG.md',
  ],
  shellAllowlistExtensions: [],
);
