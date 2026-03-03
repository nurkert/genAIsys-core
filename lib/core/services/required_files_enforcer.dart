// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

/// Required file targets act as a scope guard. Spec-level targets are enforced
/// as "any-of" (touch at least one target), while explicit subtask targets are
/// enforced as "all-of" (touch every listed target).
///
/// This avoids autonomy deadlocks where a spec lists many files but the smallest
/// safe slice only touches one of them.
enum RequiredFilesMode { allOf, anyOf }

class SpecFileEntry {
  const SpecFileEntry({required this.path, required this.optional});

  final String path;
  final bool optional;
}

/// Pure text/path manipulation service for parsing spec-required file targets
/// and validating that changed paths satisfy them.
///
/// Zero external dependencies — all logic is deterministic string/path matching.
class RequiredFilesEnforcer {
  List<String> requiredFilesFromSpec(String? specText) {
    final entries = filesSectionEntries(specText);
    final required = <String>[];
    for (final entry in entries) {
      if (entry.optional) {
        continue;
      }
      if (entry.path.trim().isEmpty) {
        continue;
      }
      required.add(entry.path.trim());
    }
    return List<String>.unmodifiable(required);
  }

  List<String>? requiredFilesFromSubtask(String? subtask) {
    final text = subtask?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final matches = RegExp(r'`([^`]+)`').allMatches(text);
    final paths = <String>[];
    for (final match in matches) {
      final value = match.group(1);
      if (value == null) {
        continue;
      }
      final candidate = value.trim();
      if (candidate.isEmpty) {
        continue;
      }
      if (!looksLikeRepoPath(candidate)) {
        continue;
      }
      paths.add(candidate);
    }
    if (paths.isEmpty) {
      return null;
    }
    return List<String>.unmodifiable(paths.toSet().toList()..sort());
  }

  List<String> missingRequiredFiles(
    List<String> requiredFiles,
    List<String> changedPaths,
  ) {
    if (requiredFiles.isEmpty) {
      return const <String>[];
    }
    final normalizedChanged = changedPaths
        .map((path) => path.replaceAll('\\', '/').trim())
        .where((path) => path.isNotEmpty)
        .toSet();

    final missing = <String>[];
    for (final required in requiredFiles) {
      final normalized = required.replaceAll('\\', '/').trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (!matchesRequiredTarget(normalized, normalizedChanged)) {
        missing.add(required);
      }
    }
    return List<String>.unmodifiable(missing);
  }

  bool hasAnyRequiredFile(
    List<String> requiredFiles,
    List<String> changedPaths,
  ) {
    if (requiredFiles.isEmpty) {
      return true;
    }
    final normalizedChanged = changedPaths
        .map((path) => path.replaceAll('\\', '/').trim())
        .where((path) => path.isNotEmpty)
        .toSet();

    for (final required in requiredFiles) {
      final normalized = required.replaceAll('\\', '/').trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (matchesRequiredTarget(normalized, normalizedChanged)) {
        return true;
      }
    }
    return false;
  }

  /// Detects spec-required files that appear in [changedPaths] but have been
  /// deleted from disk (status D). A required file being deleted is a policy
  /// violation — the agent should modify or add required targets, not delete
  /// them.
  List<String> deletedRequiredFiles(
    String projectRoot,
    List<String> requiredFiles,
    List<String> changedPaths,
  ) {
    if (requiredFiles.isEmpty) {
      return const <String>[];
    }
    final normalizedChanged = changedPaths
        .map((p) => p.replaceAll('\\', '/').trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    final deleted = <String>[];
    for (final required in requiredFiles) {
      final normalized = required.replaceAll('\\', '/').trim();
      if (normalized.isEmpty) continue;
      // Only check concrete paths that are in the diff.
      if (_isGlobRequiredTarget(normalized)) continue;
      if (!matchesRequiredTarget(normalized, normalizedChanged)) continue;
      // The file is in the diff — check if it was deleted (no longer on disk).
      final fullPath = _join(projectRoot, normalized);
      if (!File(fullPath).existsSync() && !Directory(fullPath).existsSync()) {
        deleted.add(required);
      }
    }
    return List<String>.unmodifiable(deleted);
  }

  /// Returns true if every required file already exists on disk at
  /// [projectRoot].  Used as a fallback when required files are not in the
  /// diff — they may already exist and not need changes.
  bool allRequiredFilesExistOnDisk(
    String projectRoot,
    List<String> requiredFiles,
  ) {
    for (final required in requiredFiles) {
      final normalized = required.replaceAll('\\', '/').trim();
      if (normalized.isEmpty) continue;
      // Skip glob patterns — disk existence check is only for concrete paths.
      if (_isGlobRequiredTarget(normalized)) return false;
      final path = _join(projectRoot, normalized);
      if (!File(path).existsSync() && !Directory(path).existsSync()) {
        return false;
      }
    }
    return requiredFiles.isNotEmpty;
  }

  bool matchesRequiredTarget(String normalizedRequired, Set<String> changed) {
    if (changed.contains(normalizedRequired)) {
      return true;
    }
    if (_isGlobRequiredTarget(normalizedRequired)) {
      return changed.any(
        (path) => _matchesRequiredTargetGlob(normalizedRequired, path),
      );
    }
    final prefix = normalizedRequired.endsWith('/')
        ? normalizedRequired
        : '$normalizedRequired/';
    return changed.any((path) => path.startsWith(prefix));
  }

  List<SpecFileEntry> filesSectionEntries(String? specText) {
    final text = specText?.trim();
    if (text == null || text.isEmpty) {
      return const <SpecFileEntry>[];
    }
    final lines = text.split('\n');
    var inFiles = false;
    final entries = <SpecFileEntry>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (!inFiles) {
        if (trimmed.toLowerCase() == '## files') {
          inFiles = true;
        }
        continue;
      }
      if (trimmed.startsWith('## ')) {
        break;
      }
      if (!trimmed.startsWith('-')) {
        continue;
      }
      final isOptional = trimmed.toLowerCase().contains('optional');
      final path =
          _extractBacktickedPath(trimmed) ?? _extractAfterDash(trimmed);
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      if (!looksLikeRepoPath(path.trim())) {
        continue;
      }
      entries.add(SpecFileEntry(path: path.trim(), optional: isOptional));
    }
    return List<SpecFileEntry>.unmodifiable(entries);
  }

  bool looksLikeRepoPath(String candidate) {
    var value = candidate.trim().replaceAll('\\', '/');
    if (value.isEmpty) {
      return false;
    }
    if (value.contains(RegExp(r'\\s'))) {
      return false;
    }
    if (value.endsWith(':')) {
      return false;
    }
    if (value.startsWith('./')) {
      value = value.substring(2);
    }

    const allowedPrefixes = <String>[
      'lib/',
      'test/',
      'docs/',
      'bin/',
      'scripts/',
      '.genaisys/',
      '.github/',
    ];
    if (allowedPrefixes.any(value.startsWith)) {
      return true;
    }

    // Root-level files (README.md, pubspec.yaml, etc).
    if (!value.contains('/')) {
      if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value)) {
        return false;
      }
      const allowedRootFiles = <String>{
        'README.md',
        'pubspec.yaml',
        'pubspec.lock',
        'analysis_options.yaml',
        'AGENTS.md',
        'GEMINI.md',
        '.gitignore',
        'LICENSE',
        'CHANGELOG.md',
      };
      return allowedRootFiles.contains(value);
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  bool _isGlobRequiredTarget(String target) =>
      target.contains('*') || target.contains('?');

  bool _matchesRequiredTargetGlob(String pattern, String path) {
    final normalizedPattern = pattern.replaceAll('\\', '/').trim();
    final normalizedPath = path.replaceAll('\\', '/').trim();
    if (normalizedPattern.isEmpty || normalizedPath.isEmpty) {
      return false;
    }
    final patternSegments = normalizedPattern
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final pathSegments = normalizedPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (patternSegments.isEmpty || pathSegments.isEmpty) {
      return false;
    }
    final memo = <String, bool>{};

    bool matchFrom(int patternIndex, int pathIndex) {
      final key = '$patternIndex:$pathIndex';
      final cached = memo[key];
      if (cached != null) {
        return cached;
      }

      final hasPattern = patternIndex < patternSegments.length;
      final hasPath = pathIndex < pathSegments.length;
      late final bool matched;

      if (!hasPattern) {
        matched = !hasPath;
      } else {
        final patternSegment = patternSegments[patternIndex];
        if (patternSegment == '**') {
          if (patternIndex == patternSegments.length - 1) {
            matched = true;
          } else {
            var found = false;
            for (
              var nextPathIndex = pathIndex;
              nextPathIndex <= pathSegments.length;
              nextPathIndex++
            ) {
              if (matchFrom(patternIndex + 1, nextPathIndex)) {
                found = true;
                break;
              }
            }
            matched = found;
          }
        } else if (!hasPath) {
          matched = false;
        } else {
          matched =
              _matchesRequiredTargetGlobSegment(
                patternSegment,
                pathSegments[pathIndex],
              ) &&
              matchFrom(patternIndex + 1, pathIndex + 1);
        }
      }

      memo[key] = matched;
      return matched;
    }

    return matchFrom(0, 0);
  }

  bool _matchesRequiredTargetGlobSegment(String patternSegment, String path) {
    final escaped = RegExp.escape(
      patternSegment,
    ).replaceAll(r'\*', '[^/]*').replaceAll(r'\?', '[^/]');
    return RegExp('^$escaped\$').hasMatch(path);
  }

  String? _extractBacktickedPath(String line) {
    final start = line.indexOf('`');
    if (start < 0) {
      return null;
    }
    final end = line.indexOf('`', start + 1);
    if (end <= start) {
      return null;
    }
    return line.substring(start + 1, end);
  }

  String? _extractAfterDash(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('-')) {
      return null;
    }
    final value = trimmed.substring(1).trim();
    if (value.isEmpty) {
      return null;
    }
    final withoutMeta = value.split('(').first.trim();
    return withoutMeta.isEmpty ? null : withoutMeta;
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
