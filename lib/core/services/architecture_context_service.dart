// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../git/git_service.dart';
import '../project_layout.dart';
import 'import_graph_service.dart';

/// Assembles architecture context for injection into coding agent prompts.
///
/// Gathers project structure, architecture rules, and recent changes to give
/// the coding agent awareness of the codebase layout and conventions. The
/// assembled context is trimmed to a configurable character budget.
class ArchitectureContextService {
  ArchitectureContextService({
    GitService? gitService,
    ImportGraphService? importGraphService,
  }) : _gitService = gitService ?? GitService(),
       _importGraphService = importGraphService ?? ImportGraphService();

  final GitService _gitService;
  final ImportGraphService _importGraphService;

  /// Assembles a markdown context string containing project structure,
  /// architecture rules from agent_contexts/architecture.md, and recent
  /// git commits. The result is trimmed to [maxChars].
  String assemble(
    String projectRoot, {
    int maxChars = 8000,
    int recentCommitCount = 20,
  }) {
    final buffer = StringBuffer();

    final structure = _assembleProjectStructure(projectRoot);
    if (structure.isNotEmpty) {
      buffer.writeln('### Project Structure');
      buffer.writeln(structure);
      buffer.writeln();
    }

    final rules = _assembleArchitectureRules(projectRoot);
    if (rules.isNotEmpty) {
      buffer.writeln('### Architecture Rules');
      buffer.writeln(rules);
      buffer.writeln();
    }

    final recentChanges = _assembleRecentChanges(
      projectRoot,
      count: recentCommitCount,
    );
    if (recentChanges.isNotEmpty) {
      buffer.writeln('### Recent Changes');
      buffer.writeln(recentChanges);
      buffer.writeln();
    }

    final result = buffer.toString();
    if (result.length <= maxChars) {
      return result.trim();
    }
    return result.substring(0, maxChars).trim();
  }

  /// Assembles an impact analysis context for the given target files.
  ///
  /// Uses the import graph to compute which modules depend on the target files
  /// and formats the result as a markdown section. The result is trimmed to
  /// [maxChars]. Returns an empty string if no target files are provided or
  /// if the import graph cannot be built.
  String assembleImpactContext(
    String projectRoot,
    List<String> targetFiles, {
    int maxChars = 1500,
    int? maxFiles,
  }) {
    if (targetFiles.isEmpty) {
      return '';
    }
    try {
      final effectiveMaxFiles =
          maxFiles ??
          ProjectConfig.load(projectRoot).pipelineImpactContextMaxFiles;
      final graph = _importGraphService.buildGraph(projectRoot);
      final impacted = _importGraphService.impactRadius(graph, targetFiles);
      if (impacted.isEmpty) {
        return '';
      }

      final buffer = StringBuffer();

      // Target files summary.
      buffer.writeln('**Target files:**');
      for (final f in targetFiles) {
        buffer.writeln('- `$f`');
      }
      buffer.writeln();

      // Dependent modules (limited to configured maximum).
      final sortedImpacted = impacted.toList()..sort();
      final limitedImpacted = sortedImpacted.length > effectiveMaxFiles
          ? sortedImpacted.take(effectiveMaxFiles).toList()
          : sortedImpacted;
      final omitted = sortedImpacted.length - limitedImpacted.length;
      buffer.writeln('**Dependent modules (${sortedImpacted.length}):**');
      for (final dep in limitedImpacted) {
        buffer.writeln('- `$dep`');
        if (buffer.length >= maxChars) break;
      }
      if (omitted > 0) {
        buffer.writeln('- _...and $omitted more_');
      }

      // Layer boundary analysis.
      final targetLayers = targetFiles.map(_importGraphService.layerOf).toSet();
      final impactedLayers = sortedImpacted
          .map(_importGraphService.layerOf)
          .toSet();
      final crossedLayers = impactedLayers.difference(targetLayers);
      if (crossedLayers.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(
          '**Layer boundaries crossed:** ${crossedLayers.join(', ')}',
        );
      }

      final result = buffer.toString().trim();
      if (result.length <= maxChars) {
        return result;
      }
      return result.substring(0, maxChars).trim();
    } catch (_) {
      return '';
    }
  }

  String _assembleProjectStructure(String projectRoot) {
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      return '';
    }
    try {
      final entries =
          libDir
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path.substring(projectRoot.length + 1))
              .where((p) => p.endsWith('.dart'))
              .toList()
            ..sort();
      if (entries.isEmpty) {
        return '';
      }
      return entries.join('\n');
    } catch (_) {
      return '';
    }
  }

  String _assembleArchitectureRules(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final buffer = StringBuffer();

    // Read architecture agent context if available.
    final archFile = File('${layout.agentContextsDir}/architecture.md');
    if (archFile.existsSync()) {
      try {
        final content = archFile.readAsStringSync().trim();
        if (content.isNotEmpty) {
          buffer.writeln(content);
        }
      } catch (_) {}
    }

    // Read project rules (first 50 lines) if available.
    final rulesFile = File(layout.rulesPath);
    if (rulesFile.existsSync()) {
      try {
        final lines = rulesFile.readAsLinesSync();
        final subset = lines.take(50).join('\n').trim();
        if (subset.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.writeln(subset);
        }
      } catch (_) {}
    }

    return buffer.toString().trim();
  }

  String _assembleRecentChanges(String projectRoot, {int count = 20}) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) {
        return '';
      }
      final lines = _gitService.recentCommitMessages(
        projectRoot,
        count: count,
      );
      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }
}
