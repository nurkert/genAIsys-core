// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../git/git_service.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'health_score_service.dart';
import 'readiness_gate_service.dart';

/// Manifest describing a release candidate build.
class ReleaseCandidateManifest {
  const ReleaseCandidateManifest({
    required this.version,
    required this.gitCommitSha,
    required this.buildTimestamp,
    required this.checksums,
  });

  final String version;
  final String gitCommitSha;
  final String buildTimestamp;

  /// SHA-256 checksums keyed by relative file name.
  final Map<String, String> checksums;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'git_commit_sha': gitCommitSha,
      'build_timestamp': buildTimestamp,
      'checksums': checksums,
    };
  }

  factory ReleaseCandidateManifest.fromJson(Map<String, dynamic> json) {
    final rawChecksums = json['checksums'];
    final checksums = <String, String>{};
    if (rawChecksums is Map) {
      for (final entry in rawChecksums.entries) {
        checksums[entry.key.toString()] = entry.value.toString();
      }
    }
    return ReleaseCandidateManifest(
      version: (json['version'] ?? '').toString(),
      gitCommitSha: (json['git_commit_sha'] ?? '').toString(),
      buildTimestamp: (json['build_timestamp'] ?? '').toString(),
      checksums: checksums,
    );
  }
}

/// Result of a promotion attempt.
class PromoteResult {
  const PromoteResult({
    required this.promoted,
    required this.version,
    required this.reason,
  });

  final bool promoted;
  final String version;
  final String reason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'promoted': promoted,
      'version': version,
      'reason': reason,
    };
  }
}

class ReleaseCandidateBuilderService {
  ReleaseCandidateBuilderService({
    ReadinessGateService? readinessGateService,
    GitService? gitService,
  }) : _readinessGateService = readinessGateService ?? ReadinessGateService(),
       _gitService = gitService ?? GitService();

  final ReadinessGateService _readinessGateService;
  final GitService _gitService;

  /// Build a release candidate manifest from the project at [projectRoot].
  ReleaseCandidateManifest build(String projectRoot) {
    final layout = ProjectLayout(projectRoot);

    // Read version from pubspec.yaml.
    final pubspecFile = File(_join(projectRoot, 'pubspec.yaml'));
    final version = _readVersion(pubspecFile);

    // Get git HEAD SHA.
    final gitCommitSha = _gitService.headCommitSha(projectRoot);

    // Compute SHA-256 checksums of key files.
    final checksums = <String, String>{};
    final filesToChecksum = <String, String>{
      'pubspec.yaml': _join(projectRoot, 'pubspec.yaml'),
      'pubspec.lock': _join(projectRoot, 'pubspec.lock'),
      'STATE.json': layout.statePath,
    };
    for (final entry in filesToChecksum.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        checksums[entry.key] = _computeChecksum(entry.value);
      }
    }

    final buildTimestamp = DateTime.now().toUtc().toIso8601String();

    final manifest = ReleaseCandidateManifest(
      version: version,
      gitCommitSha: gitCommitSha,
      buildTimestamp: buildTimestamp,
      checksums: checksums,
    );

    // Persist manifest to candidates dir.
    final candidatesDir = Directory(layout.releaseCandidatesDir);
    if (!candidatesDir.existsSync()) {
      candidatesDir.createSync(recursive: true);
    }
    final manifestPath = _join(layout.releaseCandidatesDir, '$version.json');
    File(manifestPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );

    // Emit event.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'release_candidate_built',
        message: 'Release candidate $version built',
        data: manifest.toJson(),
      );
    }

    return manifest;
  }

  /// Promote a release candidate to stable.
  PromoteResult promote(
    String projectRoot, {
    required String version,
    required HealthReport healthReport,
  }) {
    final layout = ProjectLayout(projectRoot);

    // Evaluate readiness.
    final verdict = _readinessGateService.evaluate(
      projectRoot,
      healthReport: healthReport,
    );

    if (!verdict.promotable) {
      // Blocked.
      if (Directory(layout.genaisysDir).existsSync()) {
        RunLogStore(layout.runLogPath).append(
          event: 'release_candidate_promotion_blocked',
          message: 'Promotion of $version blocked',
          data: <String, Object?>{
            'version': version,
            'blocking_reasons': verdict.blockingReasons,
          },
        );
      }
      return PromoteResult(
        promoted: false,
        version: version,
        reason: verdict.blockingReasons.isNotEmpty
            ? verdict.blockingReasons.first
            : 'readiness_gate_blocked',
      );
    }

    // Copy manifest to stable dir.
    final candidatePath = _join(layout.releaseCandidatesDir, '$version.json');
    final candidateFile = File(candidatePath);
    if (!candidateFile.existsSync()) {
      return PromoteResult(
        promoted: false,
        version: version,
        reason: 'candidate_manifest_not_found',
      );
    }

    final stableDir = Directory(layout.releaseStableDir);
    if (!stableDir.existsSync()) {
      stableDir.createSync(recursive: true);
    }
    final stablePath = _join(layout.releaseStableDir, '$version.json');
    candidateFile.copySync(stablePath);

    // Emit event.
    if (Directory(layout.genaisysDir).existsSync()) {
      RunLogStore(layout.runLogPath).append(
        event: 'release_candidate_promoted',
        message: 'Release candidate $version promoted to stable',
        data: <String, Object?>{'version': version},
      );
    }

    return PromoteResult(promoted: true, version: version, reason: 'promoted');
  }

  /// Load a candidate manifest by version. Returns null if not found.
  ReleaseCandidateManifest? loadManifest(
    String projectRoot, {
    required String version,
  }) {
    final layout = ProjectLayout(projectRoot);
    final manifestPath = _join(layout.releaseCandidatesDir, '$version.json');
    final file = File(manifestPath);
    if (!file.existsSync()) {
      return null;
    }
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return ReleaseCandidateManifest.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// List all candidate versions.
  List<String> listCandidates(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final dir = Directory(layout.releaseCandidatesDir);
    if (!dir.existsSync()) {
      return const <String>[];
    }
    final versions = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final name = entity.uri.pathSegments.last;
        versions.add(name.replaceAll('.json', ''));
      }
    }
    versions.sort();
    return versions;
  }

  String _readVersion(File pubspecFile) {
    if (!pubspecFile.existsSync()) {
      return 'unknown';
    }
    final content = pubspecFile.readAsStringSync();
    final match = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) {
      return 'unknown';
    }
    return match.group(1)!.trim();
  }

  String _computeChecksum(String path) {
    final result = Process.runSync('shasum', ['-a', '256', path]);
    final output = (result.stdout as String).trim();
    // shasum output: "<hash>  <path>"
    final parts = output.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  static String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
