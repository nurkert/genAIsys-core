// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

/// A directed import graph for Dart source files.
///
/// Stores both forward dependencies (file → what it imports) and reverse
/// dependencies (file → who imports it).
class ImportGraph {
  ImportGraph({required this.forward, required this.reverse});

  /// Forward dependencies: file path → set of imported file paths.
  final Map<String, Set<String>> forward;

  /// Reverse dependencies: file path → set of files that import it.
  final Map<String, Set<String>> reverse;

  /// All files in the graph.
  Set<String> get allFiles => {...forward.keys, ...reverse.keys};
}

/// Builds and analyses a Dart import graph for a project.
///
/// Scans `lib/` recursively for `.dart` files, extracts import statements,
/// and constructs a directed dependency graph. Provides impact analysis
/// (reverse-transitive closure), circular dependency detection, and
/// layer classification.
class ImportGraphService {
  /// Regex for Dart import/export statements (package-relative and relative).
  static final _importRegex = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]\s*;''',
    multiLine: true,
  );

  /// Fan-out threshold: files importing more than this many others generate
  /// a warning.
  static const int defaultFanOutThreshold = 15;

  /// Builds the import graph by scanning all `.dart` files under `lib/`.
  ///
  /// Only resolves relative imports and `package:` imports that point into
  /// the same project's `lib/` directory. External packages are ignored.
  ImportGraph buildGraph(String projectRoot) {
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      return ImportGraph(forward: const {}, reverse: const {});
    }

    final forward = <String, Set<String>>{};
    final reverse = <String, Set<String>>{};

    // Detect the package name from pubspec.yaml for package: import resolution.
    final packageName = _detectPackageName(projectRoot);

    List<File> dartFiles;
    try {
      dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    } catch (_) {
      return ImportGraph(forward: const {}, reverse: const {});
    }

    for (final file in dartFiles) {
      final relativePath = file.path.substring(projectRoot.length + 1);
      forward.putIfAbsent(relativePath, () => <String>{});

      String content;
      try {
        content = file.readAsStringSync();
      } catch (_) {
        continue;
      }

      final matches = _importRegex.allMatches(content);
      for (final match in matches) {
        final importUri = match.group(1);
        if (importUri == null) continue;

        final resolved = _resolveImport(importUri, relativePath, packageName);
        if (resolved == null) continue;

        forward[relativePath]!.add(resolved);
        reverse.putIfAbsent(resolved, () => <String>{});
        reverse[resolved]!.add(relativePath);
      }
    }

    // Ensure all files appear in both maps.
    for (final file in forward.keys) {
      reverse.putIfAbsent(file, () => <String>{});
    }
    for (final file in reverse.keys) {
      forward.putIfAbsent(file, () => <String>{});
    }

    return ImportGraph(forward: forward, reverse: reverse);
  }

  /// Returns all files that directly import the given [filePath].
  Set<String> reverseDependencies(ImportGraph graph, String filePath) {
    return graph.reverse[filePath] ?? const {};
  }

  /// Computes the transitive impact radius for a set of target files.
  ///
  /// Returns all files that transitively depend on any of the [targetFiles]
  /// (i.e. the reverse-transitive closure). Does not include the target files
  /// themselves unless they are also dependents of another target.
  Set<String> impactRadius(ImportGraph graph, List<String> targetFiles) {
    if (targetFiles.isEmpty) return const {};

    final visited = <String>{};
    final queue = <String>[...targetFiles];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (visited.contains(current)) continue;
      visited.add(current);

      final dependents = graph.reverse[current];
      if (dependents == null) continue;
      for (final dep in dependents) {
        if (!visited.contains(dep)) {
          queue.add(dep);
        }
      }
    }

    // Remove the original targets from the result (they are not "impacted",
    // they ARE the change).
    visited.removeAll(targetFiles);
    return visited;
  }

  /// Detects circular dependencies in the import graph.
  ///
  /// Returns a list of cycles, where each cycle is a list of file paths
  /// forming a loop. Uses iterative DFS with explicit stack.
  List<List<String>> circularDependencies(ImportGraph graph) {
    final cycles = <List<String>>[];
    final visited = <String>{};
    final inStack = <String>{};
    final pathMap = <String, List<String>>{};

    for (final node in graph.forward.keys) {
      if (visited.contains(node)) continue;
      _dfsIterative(graph, node, visited, inStack, pathMap, cycles);
    }

    return cycles;
  }

  /// Classifies a file path into an architectural layer.
  ///
  /// Returns one of: 'core', 'cli', 'app', 'ui', 'desktop', 'unknown'.
  String layerOf(String filePath) {
    // Order matters: more specific paths first.
    if (filePath.startsWith('lib/core/cli/')) return 'cli';
    if (filePath.startsWith('lib/core/')) return 'core';
    if (filePath.startsWith('lib/app/')) return 'app';
    if (filePath.startsWith('lib/ui/')) return 'ui';
    if (filePath.startsWith('lib/desktop/')) return 'desktop';
    if (filePath.startsWith('lib/')) return 'unknown';
    return 'unknown';
  }

  /// Returns files whose forward dependency count exceeds [threshold].
  Map<String, int> highFanOutFiles(
    ImportGraph graph, {
    int threshold = defaultFanOutThreshold,
  }) {
    final result = <String, int>{};
    for (final entry in graph.forward.entries) {
      if (entry.value.length > threshold) {
        result[entry.key] = entry.value.length;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Iterative DFS for cycle detection.
  void _dfsIterative(
    ImportGraph graph,
    String start,
    Set<String> visited,
    Set<String> inStack,
    Map<String, List<String>> pathMap,
    List<List<String>> cycles,
  ) {
    // Stack of (node, iterator-index) pairs for iterative DFS.
    final stack = <_DfsFrame>[_DfsFrame(start, 0)];
    pathMap[start] = [start];
    inStack.add(start);

    while (stack.isNotEmpty) {
      final frame = stack.last;
      final node = frame.node;
      final neighbors = graph.forward[node]?.toList() ?? const <String>[];

      if (frame.index < neighbors.length) {
        final next = neighbors[frame.index];
        frame.index += 1;

        if (inStack.contains(next)) {
          // Found a cycle.
          final path = pathMap[node] ?? [node];
          final cycleStart = path.indexOf(next);
          if (cycleStart >= 0) {
            final cycle = path.sublist(cycleStart)..add(next);
            // Only add if we haven't already found this cycle (normalized).
            if (!_isDuplicateCycle(cycles, cycle)) {
              cycles.add(cycle);
            }
          }
        } else if (!visited.contains(next)) {
          inStack.add(next);
          pathMap[next] = [
            ...(pathMap[node] ?? [node]),
            next,
          ];
          stack.add(_DfsFrame(next, 0));
        }
      } else {
        // Backtrack.
        stack.removeLast();
        inStack.remove(node);
        visited.add(node);
      }
    }
  }

  /// Checks if a cycle is a duplicate of an already found cycle.
  bool _isDuplicateCycle(List<List<String>> existing, List<String> candidate) {
    if (candidate.length < 2) return true;
    // Normalize: use the cycle without the trailing repeated node.
    final normalized = candidate.sublist(0, candidate.length - 1).toSet();
    for (final cycle in existing) {
      final existingNorm = cycle.sublist(0, cycle.length - 1).toSet();
      if (normalized.length == existingNorm.length &&
          normalized.containsAll(existingNorm)) {
        return true;
      }
    }
    return false;
  }

  /// Resolves an import URI to a project-relative file path.
  ///
  /// Returns `null` for external packages or unresolvable imports.
  String? _resolveImport(
    String importUri,
    String currentFilePath,
    String? packageName,
  ) {
    // Handle package: imports for the same package.
    if (importUri.startsWith('package:')) {
      if (packageName == null) return null;
      final prefix = 'package:$packageName/';
      if (!importUri.startsWith(prefix)) return null;
      return 'lib/${importUri.substring(prefix.length)}';
    }

    // Handle relative imports.
    if (!importUri.startsWith('dart:') && !importUri.startsWith('package:')) {
      // Resolve relative to the importing file's directory.
      final importerDir = currentFilePath.contains('/')
          ? currentFilePath.substring(0, currentFilePath.lastIndexOf('/'))
          : '.';
      final resolved = _normalizePath('$importerDir/$importUri');
      // Only include if it's within lib/.
      if (resolved.startsWith('lib/')) {
        return resolved;
      }
    }

    return null;
  }

  /// Normalizes a path by resolving `.` and `..` segments.
  String _normalizePath(String path) {
    final parts = path.split('/');
    final normalized = <String>[];
    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..' && normalized.isNotEmpty) {
        normalized.removeLast();
      } else if (part != '..') {
        normalized.add(part);
      }
    }
    return normalized.join('/');
  }

  /// Detects the package name from pubspec.yaml.
  String? _detectPackageName(String projectRoot) {
    final pubspec = File('$projectRoot/pubspec.yaml');
    if (!pubspec.existsSync()) return null;
    try {
      final lines = pubspec.readAsLinesSync();
      for (final line in lines) {
        final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Internal frame for iterative DFS traversal.
class _DfsFrame {
  _DfsFrame(this.node, this.index);

  final String node;
  int index;
}
