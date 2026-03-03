// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../git/git_service.dart';
import '../ids/task_slugger.dart';
import '../models/review_bundle.dart';
import '../policy/diff_budget_policy.dart';
import '../project_layout.dart';
import '../services/review_bundle_service.dart';
import '../storage/run_log_store.dart';
import '../storage/state_store.dart';

enum AuditEntryKind { review, outcome }

class AuditTrailService {
  AuditTrailService({
    GitService? gitService,
    ReviewBundleService? reviewBundleService,
  }) : _gitService = gitService ?? GitService(),
       _reviewBundleService = reviewBundleService ?? ReviewBundleService();

  final GitService _gitService;
  final ReviewBundleService _reviewBundleService;

  void recordReviewDecision(
    String projectRoot, {
    required String decision,
    String? note,
    String? testSummary,
  }) {
    _record(
      projectRoot,
      kind: AuditEntryKind.review,
      decision: decision,
      note: note,
      testSummary: testSummary,
    );
  }

  void recordOutcome(
    String projectRoot, {
    required String outcome,
    String? reason,
  }) {
    _record(
      projectRoot,
      kind: AuditEntryKind.outcome,
      outcome: outcome,
      reason: reason,
    );
  }

  void _record(
    String projectRoot, {
    required AuditEntryKind kind,
    String? decision,
    String? note,
    String? testSummary,
    String? outcome,
    String? reason,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }

    final state = _readState(layout);
    final taskTitle = state.activeTaskTitle?.trim();
    final taskSlug = taskTitle == null || taskTitle.isEmpty
        ? 'unknown-task'
        : TaskSlugger.slug(taskTitle);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final entryDir = _buildEntryDir(layout, taskSlug, timestamp, kind);

    try {
      Directory(entryDir).createSync(recursive: true);

      ReviewBundle? diffBundle;
      if (kind == AuditEntryKind.review) {
        try {
          diffBundle = _reviewBundleService.build(
            projectRoot,
            testSummary: testSummary,
          );
        } catch (e) {
          RunLogStore(layout.runLogPath).append(
            event: 'audit_diff_bundle_failed',
            message: 'Review bundle build failed during audit recording',
            data: {
              'root': projectRoot,
              'task': taskTitle ?? '',
              'decision': decision ?? '',
              'error': e.toString(),
              'error_class': 'audit',
              'error_kind': 'review_bundle_build_failed',
            },
          );
          diffBundle = null;
        }
      }
      final diffStats = _safeDiffStats(projectRoot);

      final diffSummaryPath = _writeTextFile(
        entryDir,
        'diff_summary.txt',
        diffBundle?.diffSummary.trim().isNotEmpty == true
            ? diffBundle!.diffSummary.trim()
            : '(none)',
      );
      final diffPatchPath = _writeTextFile(
        entryDir,
        'diff_patch.diff',
        diffBundle?.diffPatch.trim().isNotEmpty == true
            ? diffBundle!.diffPatch.trim()
            : '(none)',
      );
      final specPath = diffBundle?.spec == null
          ? null
          : _writeTextFile(entryDir, 'spec.md', diffBundle!.spec!.trim());

      final configSnapshot = _copyIfExists(
        layout.configPath,
        _join(entryDir, 'config_snapshot.yml'),
      );
      final stateSnapshot = _copyIfExists(
        layout.statePath,
        _join(entryDir, 'state_snapshot.json'),
      );
      final attemptSnapshot = _copyLatestAttempt(layout, entryDir);
      final runLogExcerpt = _writeRunLogExcerpt(layout, entryDir);

      final summary = <String, Object?>{
        'timestamp': timestamp,
        'kind': kind.name,
        'task': taskTitle ?? '',
        'task_id': state.activeTaskId ?? '',
        'subtask': state.currentSubtask ?? '',
        'decision': ?decision,
        'note': ?note,
        'outcome': ?outcome,
        'reason': ?reason,
        'test_summary': ?testSummary,
        'diff_stats': diffStats == null
            ? null
            : {
                'files_changed': diffStats.filesChanged,
                'additions': diffStats.additions,
                'deletions': diffStats.deletions,
              },
        'files': {
          'diff_summary': diffSummaryPath == null ? null : 'diff_summary.txt',
          'diff_patch': diffPatchPath == null ? null : 'diff_patch.diff',
          'spec': specPath == null ? null : 'spec.md',
          'config_snapshot': configSnapshot == null
              ? null
              : 'config_snapshot.yml',
          'state_snapshot': stateSnapshot == null
              ? null
              : 'state_snapshot.json',
          'attempt_snapshot': attemptSnapshot,
          'run_log_excerpt': runLogExcerpt,
        },
        'definition_of_done': kind == AuditEntryKind.review
            ? _definitionOfDoneChecklist(decision)
            : null,
        'git': _gitMetadata(projectRoot),
      };

      final summaryPath = _join(entryDir, 'summary.json');
      File(
        summaryPath,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

      RunLogStore(layout.runLogPath).append(
        event: 'audit_recorded',
        message: 'Captured audit trail',
        data: {
          'root': projectRoot,
          'kind': kind.name,
          'task': taskTitle ?? '',
          'path': entryDir,
        },
      );
    } catch (error) {
      RunLogStore(layout.runLogPath).append(
        event: 'audit_failed',
        message: 'Failed to capture audit trail',
        data: {
          'root': projectRoot,
          'kind': kind.name,
          'task': taskTitle ?? '',
          'error': error.toString(),
        },
      );
    }
  }

  String _buildEntryDir(
    ProjectLayout layout,
    String taskSlug,
    String timestamp,
    AuditEntryKind kind,
  ) {
    return _join(_join(layout.auditDir, taskSlug), '${timestamp}_${kind.name}');
  }

  _AuditState _readState(ProjectLayout layout) {
    try {
      final store = StateStore(layout.statePath);
      final state = store.read();
      return _AuditState(
        activeTaskId: state.activeTaskId,
        activeTaskTitle: state.activeTaskTitle,
        currentSubtask: state.currentSubtask,
      );
    } catch (_) {
      return const _AuditState();
    }
  }

  DiffStats? _safeDiffStats(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return null;
    }
    try {
      return _gitService.diffStats(projectRoot);
    } catch (_) {
      return null;
    }
  }

  String? _writeTextFile(String dir, String name, String content) {
    try {
      final path = _join(dir, name);
      File(
        path,
      ).writeAsStringSync(content.endsWith('\n') ? content : '$content\n');
      return path;
    } catch (_) {
      return null;
    }
  }

  String? _copyIfExists(String source, String dest) {
    final file = File(source);
    if (!file.existsSync()) {
      return null;
    }
    try {
      file.copySync(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  String? _copyLatestAttempt(ProjectLayout layout, String entryDir) {
    final dir = Directory(layout.attemptsDir);
    if (!dir.existsSync()) {
      return null;
    }
    final files = dir.listSync().whereType<File>().toList(growable: false);
    if (files.isEmpty) {
      return null;
    }
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    final latest = files.last;
    final dest = _join(entryDir, 'attempt_snapshot.txt');
    try {
      latest.copySync(dest);
      return 'attempt_snapshot.txt';
    } catch (_) {
      return null;
    }
  }

  String? _writeRunLogExcerpt(ProjectLayout layout, String entryDir) {
    final logFile = File(layout.runLogPath);
    if (!logFile.existsSync()) {
      return null;
    }
    try {
      final lines = logFile.readAsLinesSync();
      final start = lines.length > 20 ? lines.length - 20 : 0;
      final excerpt = lines.sublist(start).join('\n');
      final path = _join(entryDir, 'run_log_excerpt.jsonl');
      File(
        path,
      ).writeAsStringSync(excerpt.endsWith('\n') ? excerpt : '$excerpt\n');
      return 'run_log_excerpt.jsonl';
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _gitMetadata(String projectRoot) {
    if (!_gitService.isGitRepo(projectRoot)) {
      return const {};
    }
    try {
      return {
        'branch': _gitService.currentBranch(projectRoot),
        'clean': _gitService.isClean(projectRoot),
      };
    } catch (_) {
      return const {};
    }
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }

  Map<String, Object> _definitionOfDoneChecklist(String? decision) {
    final approved = _isApprovedDecision(decision);
    return <String, Object>{
      'implementation_completed': approved,
      'tests_added_or_updated': approved,
      'analyze_green': approved,
      'relevant_tests_green': approved,
      'runlog_status_checked_if_affected': approved,
      'docs_updated_if_behavior_changed': approved,
      'tasks_updated_same_slice': approved,
    };
  }

  bool _isApprovedDecision(String? decision) {
    final normalized = decision?.trim().toLowerCase();
    return normalized == 'approve' || normalized == 'approved';
  }
}

class _AuditState {
  const _AuditState({
    this.activeTaskId,
    this.activeTaskTitle,
    this.currentSubtask,
  });

  final String? activeTaskId;
  final String? activeTaskTitle;
  final String? currentSubtask;
}
