// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../import_graph_service.dart';

/// Severity of an architecture violation.
enum ArchViolationSeverity {
  /// Critical violations that must block the pipeline.
  critical,

  /// Warnings that should be reported but do not block.
  warning,
}

/// An architecture violation detected in the import graph.
class ArchViolation {
  const ArchViolation({
    required this.type,
    required this.file,
    required this.importedFile,
    required this.severity,
    required this.message,
  });

  /// Type of violation (e.g. 'layer_violation', 'circular_dependency').
  final String type;

  /// The file containing the violating import.
  final String file;

  /// The file being imported in violation of rules.
  final String importedFile;

  /// Severity of the violation.
  final ArchViolationSeverity severity;

  /// Human-readable description.
  final String message;

  Map<String, Object?> toJson() => {
    'type': type,
    'file': file,
    'imported_file': importedFile,
    'severity': severity.name,
    'message': message,
  };
}

/// Result of an architecture health check.
class ArchitectureHealthReport {
  const ArchitectureHealthReport({
    required this.violations,
    required this.warnings,
    required this.score,
  });

  /// Critical violations that block the pipeline.
  final List<ArchViolation> violations;

  /// Non-blocking warnings.
  final List<ArchViolation> warnings;

  /// Architecture health score (0.0 to 1.0, where 1.0 = no violations).
  final double score;

  /// Whether the report passes (no critical violations).
  bool get passed => violations.isEmpty;

  /// Total number of issues (violations + warnings).
  int get totalIssues => violations.length + warnings.length;

  Map<String, Object?> toJson() => {
    'passed': passed,
    'score': score,
    'violation_count': violations.length,
    'warning_count': warnings.length,
    'violations': violations.map((v) => v.toJson()).toList(),
    'warnings': warnings.map((w) => w.toJson()).toList(),
  };
}

/// Checks architecture health by analysing the import graph for layer
/// violations, circular dependencies, and excessive coupling.
///
/// Layer rules (one-way dependency):
/// - `core` may import `core` and `cli` (cli lives under core/cli/)
/// - `cli` may import `core` and `cli`
/// - `app` may import `core` and `app`
/// - `ui` may import `core`, `app`, `ui`, and `desktop` (ui/desktop/
///   widgets use desktop adapter interfaces)
/// - `desktop` may import `core`, `app`, and `desktop`
class ArchitectureHealthService {
  ArchitectureHealthService({ImportGraphService? importGraphService})
    : _importGraphService = importGraphService ?? ImportGraphService();

  final ImportGraphService _importGraphService;

  /// Allowed import directions per layer.
  ///
  /// Key: source layer → Value: set of layers it may import from.
  /// Note: `core` may import `cli` because `lib/core/cli/` is structurally
  /// under core and shares the core layer boundary (e.g. legacy adapters).
  /// `ui` may import `desktop` because `lib/ui/desktop/` widgets
  /// legitimately use desktop adapter interfaces.
  static const Map<String, Set<String>> _allowedImports = {
    'core': {'core', 'cli'},
    'cli': {'core', 'cli'},
    'app': {'core', 'app'},
    'ui': {'core', 'app', 'ui', 'desktop'},
    'desktop': {'core', 'app', 'desktop'},
  };

  /// Runs a full architecture health check on the project.
  ArchitectureHealthReport check(
    String projectRoot, {
    int fanOutThreshold = ImportGraphService.defaultFanOutThreshold,
  }) {
    final graph = _importGraphService.buildGraph(projectRoot);
    final violations = <ArchViolation>[];
    final warnings = <ArchViolation>[];

    // Check layer violations.
    _checkLayerViolations(graph, violations);

    // Check circular dependencies.
    _checkCircularDependencies(graph, warnings);

    // Check fan-out.
    _checkFanOut(graph, warnings, threshold: fanOutThreshold);

    // Compute score.
    final score = _computeScore(
      graph: graph,
      violationCount: violations.length,
      warningCount: warnings.length,
    );

    return ArchitectureHealthReport(
      violations: List.unmodifiable(violations),
      warnings: List.unmodifiable(warnings),
      score: score,
    );
  }

  /// Checks for layer boundary violations in the import graph.
  ///
  /// A violation occurs when a file in layer X imports a file from layer Y
  /// that is not in X's allowed imports set.
  void _checkLayerViolations(
    ImportGraph graph,
    List<ArchViolation> violations,
  ) {
    for (final entry in graph.forward.entries) {
      final sourceFile = entry.key;
      final sourceLayer = _importGraphService.layerOf(sourceFile);

      // Skip files in unknown layers (not under lib/).
      if (sourceLayer == 'unknown') continue;

      final allowed = _allowedImports[sourceLayer];
      if (allowed == null) continue;

      for (final importedFile in entry.value) {
        final importedLayer = _importGraphService.layerOf(importedFile);
        if (importedLayer == 'unknown') continue;

        if (!allowed.contains(importedLayer)) {
          violations.add(
            ArchViolation(
              type: 'layer_violation',
              file: sourceFile,
              importedFile: importedFile,
              severity: ArchViolationSeverity.critical,
              message:
                  'Layer "$sourceLayer" must not import from '
                  '"$importedLayer": $sourceFile → $importedFile',
            ),
          );
        }
      }
    }
  }

  /// Checks for circular dependencies in the import graph.
  ///
  /// Circular dependencies are reported as warnings (not critical violations)
  /// because Dart allows them but they indicate coupling issues.
  void _checkCircularDependencies(
    ImportGraph graph,
    List<ArchViolation> warnings,
  ) {
    final cycles = _importGraphService.circularDependencies(graph);
    for (final cycle in cycles) {
      if (cycle.length < 2) continue;
      final first = cycle.first;
      final second = cycle.length > 1 ? cycle[1] : first;
      warnings.add(
        ArchViolation(
          type: 'circular_dependency',
          file: first,
          importedFile: second,
          severity: ArchViolationSeverity.warning,
          message:
              'Circular dependency detected: '
              '${cycle.join(' → ')}',
        ),
      );
    }
  }

  /// Checks for files with excessive fan-out (too many imports).
  void _checkFanOut(
    ImportGraph graph,
    List<ArchViolation> warnings, {
    required int threshold,
  }) {
    final highFanOut = _importGraphService.highFanOutFiles(
      graph,
      threshold: threshold,
    );
    for (final entry in highFanOut.entries) {
      warnings.add(
        ArchViolation(
          type: 'high_fan_out',
          file: entry.key,
          importedFile: '',
          severity: ArchViolationSeverity.warning,
          message:
              'File has high fan-out: ${entry.value} imports '
              '(threshold: $threshold): ${entry.key}',
        ),
      );
    }
  }

  /// Computes a health score between 0.0 and 1.0.
  ///
  /// Each violation deducts 0.1, each warning deducts 0.02.
  /// Score is clamped to [0.0, 1.0].
  double _computeScore({
    required ImportGraph graph,
    required int violationCount,
    required int warningCount,
  }) {
    if (graph.allFiles.isEmpty) return 1.0;
    final penalty = violationCount * 0.1 + warningCount * 0.02;
    final score = 1.0 - penalty;
    return score.clamp(0.0, 1.0);
  }
}
