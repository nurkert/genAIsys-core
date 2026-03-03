// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../config/project_config.dart';
import '../../git/git_service.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../build_test_runner_service.dart';
import '../orchestrator_step_service.dart';

/// Standalone service responsible for creating release tags after successful
/// autopilot steps.
///
/// Extracted from the `_OrchestratorRunReleaseTag` extension on
/// `OrchestratorRunService` to reduce god-class complexity.
class AutopilotReleaseTagService {
  AutopilotReleaseTagService({
    GitService? gitService,
    BuildTestRunnerService? buildTestRunnerService,
  }) : _gitService = gitService ?? GitService(),
       _buildTestRunnerService =
           buildTestRunnerService ?? BuildTestRunnerService();

  final GitService _gitService;
  final BuildTestRunnerService _buildTestRunnerService;

  /// Attempts to create (and optionally push) a release tag.
  ///
  /// Returns `true` if the tag was created successfully, `false` if tag
  /// creation was skipped or failed. Failures are recorded in the run log
  /// with `error_kind: 'release_tag_failed'` but are never thrown so that the
  /// autopilot loop is not crashed by a tagging issue.
  Future<bool> maybeCreateReleaseTag(
    String projectRoot, {
    required ProjectConfig config,
    required OrchestratorStepResult stepResult,
    required String stepId,
    required int stepIndex,
  }) async {
    if (!config.autopilotReleaseTagOnReady) {
      return false;
    }
    if (!_gitService.isGitRepo(projectRoot)) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: project is not a git repository',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'not_git_repo',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }
    if (_gitService.hasMergeInProgress(projectRoot)) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: merge in progress',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'merge_in_progress',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    final branch = _gitService.currentBranch(projectRoot);
    final baseBranch = config.gitBaseBranch.trim().isEmpty
        ? 'main'
        : config.gitBaseBranch.trim();
    if (branch != baseBranch) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: not on base branch',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'not_base_branch',
          'current_branch': branch,
          'base_branch': baseBranch,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    if (!_gitService.isClean(projectRoot)) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: repository has uncommitted changes',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'git_dirty',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    BuildTestRunnerOutcome gate;
    try {
      gate = await _buildTestRunnerService.run(projectRoot);
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_failed',
        message: 'Release tag failed: quality gate error',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'quality_gate',
          'error_kind': 'release_tag_failed',
          'error': error.toString(),
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }
    if (!gate.executed) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: quality gate is disabled',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_kind': 'quality_gate_disabled',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    final version = _readProjectVersion(projectRoot);
    final shortSha = _headShortSha(projectRoot);
    if (shortSha == null || shortSha.isEmpty) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: unable to read commit hash',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'git_no_head',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    final prefix = sanitizeTagPart(
      config.autopilotReleaseTagPrefix,
      fallback: ProjectConfig.defaultAutopilotReleaseTagPrefix,
    );
    final safeVersion = sanitizeTagPart(version, fallback: '0.0.0');
    final tag = '$prefix$safeVersion-$shortSha';

    if (_gitService.tagExists(projectRoot, tag)) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_skip',
        message: 'Release tag skipped: tag already exists',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'tag_exists',
          'tag': tag,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    final tagMessage =
        'Genaisys release-ready candidate after autopilot step $stepIndex';
    try {
      _gitService.createAnnotatedTag(projectRoot, tag, message: tagMessage);
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_failed',
        message: 'Release tag creation failed',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'release_tag_failed',
          'error': error.toString(),
          'tag': tag,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }

    _appendRunLog(
      projectRoot,
      event: 'release_tag_created',
      message: 'Release tag created',
      data: {
        'step_id': stepId,
        'step_index': stepIndex,
        'tag': tag,
        'version': safeVersion,
        'commit': shortSha,
        if (stepResult.activeTaskId != null &&
            stepResult.activeTaskId!.isNotEmpty)
          'task_id': stepResult.activeTaskId,
      },
    );

    if (!config.autopilotReleaseTagPush) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_push_skip',
        message: 'Release tag push skipped by config',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'tag': tag,
          'error_class': 'delivery',
          'error_kind': 'push_disabled',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return true;
    }

    final remote = _gitService.defaultRemote(projectRoot);
    if (remote == null || remote.trim().isEmpty) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_push_skip',
        message: 'Release tag push skipped: no remote configured',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'tag': tag,
          'error_class': 'delivery',
          'error_kind': 'no_remote',
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return true;
    }

    try {
      _gitService.pushTag(projectRoot, remote, tag);
      _appendRunLog(
        projectRoot,
        event: 'release_tag_pushed',
        message: 'Release tag pushed to remote',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'tag': tag,
          'remote': remote,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
    } catch (error) {
      _appendRunLog(
        projectRoot,
        event: 'release_tag_failed',
        message: 'Release tag push failed',
        data: {
          'step_id': stepId,
          'step_index': stepIndex,
          'error_class': 'delivery',
          'error_kind': 'release_tag_failed',
          'error': error.toString(),
          'tag': tag,
          'remote': remote,
          if (stepResult.activeTaskId != null &&
              stepResult.activeTaskId!.isNotEmpty)
            'task_id': stepResult.activeTaskId,
        },
      );
      return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _readProjectVersion(String projectRoot) {
    final pubspec = File('$projectRoot${Platform.pathSeparator}pubspec.yaml');
    if (!pubspec.existsSync()) {
      return '0.0.0';
    }
    final content = pubspec.readAsStringSync();
    final match = RegExp(
      r'^\s*version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) {
      return '0.0.0';
    }
    return match.group(1)?.trim() ?? '0.0.0';
  }

  String? _headShortSha(String projectRoot) {
    try {
      final value = _gitService.headCommitSha(projectRoot, short: true);
      if (value.isEmpty) {
        return null;
      }
      return sanitizeTagPart(value, fallback: '');
    } catch (_) {
      return null;
    }
  }

  /// Sanitizes a raw string for use as a git tag component by replacing
  /// invalid characters with hyphens.
  String sanitizeTagPart(String raw, {required String fallback}) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[.-]+'), '')
        .replaceAll(RegExp(r'[.-]+$'), '');
    if (cleaned.isEmpty) {
      return fallback;
    }
    return cleaned;
  }

  void _appendRunLog(
    String projectRoot, {
    required String event,
    required String message,
    required Map<String, Object?> data,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: event,
      message: message,
      data: {'root': projectRoot, ...data},
    );
  }
}
