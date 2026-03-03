// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../git/git_service.dart';
import '../ids/task_slugger.dart';
import '../models/review_bundle.dart';
import '../project_layout.dart';
import '../storage/state_store.dart';

class ReviewBundleService {
  ReviewBundleService({GitService? gitService})
    : _gitService = gitService ?? GitService();

  final GitService _gitService;

  ReviewBundle build(
    String projectRoot, {
    String? testSummary,
    String? sinceCommitSha,
  }) {
    // Use delta diff only when new commits exist since the last reject AND the
    // SHA is still reachable.  After force-push or history-rewrite the SHA may
    // no longer exist, which silently produces an empty diff.  Fall back to
    // the working-tree diff in that case.
    final useDelta = sinceCommitSha != null &&
        _gitService.headCommitSha(projectRoot) != sinceCommitSha &&
        _gitService.isCommitReachable(projectRoot, sinceCommitSha!);
    final diffSummary = useDelta
        ? _gitService.diffSummaryBetween(projectRoot, sinceCommitSha!, 'HEAD')
        : _gitService.diffSummary(projectRoot);
    final diffPatch = useDelta
        ? _gitService.diffPatchBetween(projectRoot, sinceCommitSha!, 'HEAD')
        : _gitService.diffPatch(projectRoot);
    final normalizedTestSummary = _normalizeOptional(testSummary);

    final layout = ProjectLayout(projectRoot);
    final state = StateStore(layout.statePath).read();
    final title = _normalizeOptional(state.activeTaskTitle);
    final loadedSpec = _loadSpec(layout, title);
    final subtask = _normalizeOptional(state.currentSubtask);
    final spec = subtask == null
        ? loadedSpec
        : _decorateSpecForSubtaskReview(loadedSpec, subtask: subtask);

    return ReviewBundle(
      diffSummary: diffSummary,
      diffPatch: diffPatch,
      testSummary: normalizedTestSummary,
      taskTitle: title,
      spec: spec,
      subtaskDescription: subtask,
    );
  }

  String _decorateSpecForSubtaskReview(
    String? loadedSpec, {
    required String subtask,
  }) {
    final buffer = StringBuffer();
    if (loadedSpec != null && loadedSpec.trim().isNotEmpty) {
      buffer.writeln(loadedSpec.trim());
      buffer.writeln('');
    }
    buffer.writeln('---');
    buffer.writeln('Subtask Review Mode (Required)');
    buffer.writeln('- Current subtask:');
    buffer.writeln(subtask.trim());
    buffer.writeln('');
    buffer.writeln(
      'Reviewer instruction: Evaluate this diff ONLY against the current '
      'subtask. Do not require completion of other subtasks yet. Reject only '
      'if the diff does not advance the subtask safely or introduces regression/policy risk.',
    );
    return buffer.toString().trim();
  }

  String? _loadSpec(ProjectLayout layout, String? taskTitle) {
    if (taskTitle == null) {
      return null;
    }
    final slug = TaskSlugger.slug(taskTitle);
    final specPath = _join(layout.taskSpecsDir, '$slug.md');
    final file = File(specPath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
