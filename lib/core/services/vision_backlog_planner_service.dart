// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/task.dart';
import '../models/task_draft.dart';
import '../project_layout.dart';
import '../storage/atomic_file_write.dart';
import '../storage/task_store.dart';
import 'strategic_planner_service.dart';
import 'vision_alignment_service.dart';

class PlannerSyncResult {
  PlannerSyncResult({
    required this.openBefore,
    required this.openAfter,
    required this.added,
    required this.addedTitles,
  });

  final int openBefore;
  final int openAfter;
  final int added;
  final List<String> addedTitles;
}

class VisionBacklogPlannerService {
  VisionBacklogPlannerService({
    StrategicPlannerService? strategicPlanner,
    VisionAlignmentService? visionAlignmentService,
  }) : _strategicPlanner = strategicPlanner ?? StrategicPlannerService(),
       _visionAlignmentService =
           visionAlignmentService ?? VisionAlignmentService();

  final StrategicPlannerService _strategicPlanner;
  final VisionAlignmentService _visionAlignmentService;

  Future<PlannerSyncResult> syncBacklogStrategically(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) async {
    final layout = ProjectLayout(projectRoot);
    _ensureRequiredFiles(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final openTasks = tasks
        .where(
          (task) => task.completion == TaskCompletion.open && !task.blocked,
        )
        .toList();

    if (openTasks.length >= minOpenTasks) {
      return PlannerSyncResult(
        openBefore: openTasks.length,
        openAfter: openTasks.length,
        added: 0,
        addedTitles: const [],
      );
    }

    // Initial backlog generation: when TASKS.md is completely empty, generate
    // a full backlog from VISION.md + ARCHITECTURE.md in one batch.
    if (tasks.isEmpty) {
      final initial = await _strategicPlanner.generateInitialBacklog(
        projectRoot,
      );
      if (initial.isNotEmpty) {
        final normalizedExisting = _existingTitleKeys(tasks);
        final candidates = _filterDrafts(
          initial,
          normalizedExisting,
          limit: initial.length,
        );
        if (candidates.isNotEmpty) {
          final ranked = _rankByVisionAlignment(projectRoot, candidates);
          _appendTasks(layout.tasksPath, ranked);
          return PlannerSyncResult(
            openBefore: 0,
            openAfter: ranked.length,
            added: ranked.length,
            addedTitles: ranked.map((d) => d.title).toList(),
          );
        }
      }
    }

    final suggestions = await _strategicPlanner.suggestTasks(
      projectRoot,
      count: maxAdd,
    );

    final normalizedExisting = _existingTitleKeys(tasks);
    var candidates = _filterDrafts(
      suggestions,
      normalizedExisting,
      limit: maxAdd,
    );
    if (candidates.isEmpty) {
      final vision = _extractVisionCandidates(layout.visionPath);
      candidates = _filterDrafts(vision, normalizedExisting, limit: maxAdd);
    }
    if (candidates.isEmpty) {
      final fallback = _fallbackDrafts();
      candidates = _filterDrafts(fallback, normalizedExisting, limit: maxAdd);
    }

    if (candidates.isEmpty) {
      return PlannerSyncResult(
        openBefore: openTasks.length,
        openAfter: openTasks.length,
        added: 0,
        addedTitles: const [],
      );
    }

    // Rerank candidates by vision alignment to prioritize goal-aligned tasks.
    candidates = _rankByVisionAlignment(projectRoot, candidates);

    _appendTasks(layout.tasksPath, candidates);

    return PlannerSyncResult(
      openBefore: openTasks.length,
      openAfter: openTasks.length + candidates.length,
      added: candidates.length,
      addedTitles: candidates.map((draft) => draft.title).toList(),
    );
  }

  PlannerSyncResult syncBacklogFromVision(
    String projectRoot, {
    int minOpenTasks = 8,
    int maxAdd = 4,
  }) {
    final normalizedMinOpen = minOpenTasks < 1 ? 1 : minOpenTasks;
    final normalizedMaxAdd = maxAdd < 1 ? 1 : maxAdd;
    final layout = ProjectLayout(projectRoot);
    _ensureRequiredFiles(layout);

    final tasks = TaskStore(layout.tasksPath).readTasks();
    final openBefore = tasks
        .where(
          (task) => task.completion == TaskCompletion.open && !task.blocked,
        )
        .length;
    if (openBefore >= normalizedMinOpen) {
      return PlannerSyncResult(
        openBefore: openBefore,
        openAfter: openBefore,
        added: 0,
        addedTitles: const [],
      );
    }

    final existingTitles = _existingTitleKeys(tasks);
    final candidates = _filterDrafts(
      _extractVisionCandidates(layout.visionPath),
      existingTitles,
      limit: normalizedMaxAdd,
    );

    final needed = normalizedMinOpen - openBefore;
    final limit = needed < normalizedMaxAdd ? needed : normalizedMaxAdd;
    final ranked = _rankByVisionAlignment(projectRoot, candidates);
    final selected = ranked.take(limit).toList();
    if (selected.isEmpty) {
      return PlannerSyncResult(
        openBefore: openBefore,
        openAfter: openBefore,
        added: 0,
        addedTitles: const [],
      );
    }

    _appendTasks(layout.tasksPath, selected);

    return PlannerSyncResult(
      openBefore: openBefore,
      openAfter: openBefore + selected.length,
      added: selected.length,
      addedTitles: selected.map((draft) => draft.title).toList(),
    );
  }

  void _ensureRequiredFiles(ProjectLayout layout) {
    if (!File(layout.tasksPath).existsSync()) {
      throw StateError('No TASKS.md found at: ${layout.tasksPath}');
    }
    if (!File(layout.visionPath).existsSync()) {
      throw StateError('No VISION.md found at: ${layout.visionPath}');
    }
  }

  List<TaskDraft> _extractVisionCandidates(String visionPath) {
    final lines = File(visionPath).readAsLinesSync();
    final candidates = <TaskDraft>[];
    var inCodeFence = false;
    String? section;
    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        inCodeFence = !inCodeFence;
        continue;
      }
      if (inCodeFence || trimmed.isEmpty) {
        continue;
      }
      final headingMatch = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        section = headingMatch.group(1)?.trim();
        continue;
      }
      final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      final numberedMatch = RegExp(r'^\d+\.\s+(.*)$').firstMatch(trimmed);
      final content = bulletMatch?.group(1) ?? numberedMatch?.group(1);
      if (content == null) {
        continue;
      }
      final candidate = _normalizeVisionItem(
        content,
        section: section,
        lines: lines,
        lineIndex: i,
      );
      if (candidate == null) {
        continue;
      }
      candidates.add(candidate.copyWith(source: 'vision'));
    }
    return _uniquePreservingOrder(candidates);
  }

  TaskDraft? _normalizeVisionItem(
    String raw, {
    String? section,
    required List<String> lines,
    required int lineIndex,
  }) {
    final compact = raw
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) {
      return null;
    }
    if (compact == '-' || compact.toLowerCase() == 'tbd') {
      return null;
    }
    if (compact.length < 8) {
      return null;
    }
    if (_looksLikeHeading(compact)) {
      return null;
    }
    if (_isSuppressedSection(section) &&
        !_containsPriorityOrCategory(compact)) {
      return null;
    }

    final defaults = _defaultsForSection(section);
    final draft = TaskDraft.parseLine(
      compact,
      defaultPriority: defaults.priority,
      defaultCategory: defaults.category,
    );
    if (draft == null) {
      return null;
    }

    final acceptanceLines = _collectAcceptanceLines(lines, lineIndex);
    final acceptance = draft.acceptanceCriteria.trim().isNotEmpty
        ? draft.acceptanceCriteria
        : (acceptanceLines.isNotEmpty
              ? acceptanceLines.join(' ')
              : _defaultAcceptance(draft.title));
    final normalizedTitle = _ensureVerbStart(draft.title);
    return draft.copyWith(
      title: normalizedTitle,
      acceptanceCriteria: acceptance,
    );
  }

  bool _looksLikeHeading(String value) {
    final lower = value.toLowerCase();
    return lower == 'goals' ||
        lower == 'constraints' ||
        lower == 'success criteria' ||
        lower == 'roadmap';
  }

  String _ensureVerbStart(String value) {
    final trimmed = value.replaceFirst(RegExp(r'[.;:,]+$'), '').trim();
    if (_startsWithVerb(trimmed)) {
      return trimmed;
    }
    return 'Implement: $trimmed';
  }

  bool _startsWithVerb(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('add ') ||
        lower.startsWith('bootstrap ') ||
        lower.startsWith('implement ') ||
        lower.startsWith('build ') ||
        lower.startsWith('create ') ||
        lower.startsWith('enforce ') ||
        lower.startsWith('introduce ') ||
        lower.startsWith('support ') ||
        lower.startsWith('refactor ') ||
        lower.startsWith('improve ') ||
        lower.startsWith('define ') ||
        lower.startsWith('document ') ||
        lower.startsWith('stabilize ') ||
        lower.startsWith('reduce ') ||
        lower.startsWith('remove ') ||
        lower.startsWith('audit ');
  }

  List<TaskDraft> _uniquePreservingOrder(List<TaskDraft> values) {
    final seen = <String>{};
    final result = <TaskDraft>[];
    for (final value in values) {
      final normalized = value.normalizedKey();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      result.add(value);
    }
    return result;
  }

  Set<String> _existingTitleKeys(List<Task> tasks) {
    return tasks
        .map((task) => TaskDraft.parseLine(task.title)?.normalizedKey())
        .whereType<String>()
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  List<TaskDraft> _filterDrafts(
    List<TaskDraft> drafts,
    Set<String> existingKeys, {
    required int limit,
  }) {
    final filtered = <TaskDraft>[];
    final seen = <String>{...existingKeys};
    for (final draft in drafts) {
      final key = draft.normalizedKey();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      if (!_meetsQuality(draft)) {
        continue;
      }
      seen.add(key);
      filtered.add(draft);
      if (filtered.length >= limit) {
        break;
      }
    }
    return filtered;
  }

  /// Reranks candidates by vision alignment score (highest first).
  ///
  /// Falls back to the original order if no goals are available.
  List<TaskDraft> _rankByVisionAlignment(
    String projectRoot,
    List<TaskDraft> candidates,
  ) {
    if (candidates.length <= 1) return candidates;
    final goals = _visionAlignmentService.extractGoals(projectRoot);
    if (goals.isEmpty) return candidates;

    final scored = candidates.map((draft) {
      final alignment = _visionAlignmentService.scoreAlignment(
        draft.title,
        goals,
      );
      return _ScoredDraft(draft, alignment.score);
    }).toList();

    // Stable sort: higher alignment first, preserve original order on tie.
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.draft).toList();
  }

  bool _meetsQuality(TaskDraft draft) {
    final wordCount = draft.title
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    if (wordCount < 3) {
      return false;
    }
    if (draft.title.length < 12) {
      return false;
    }
    if (draft.acceptanceCriteria.trim().length < 12) {
      return false;
    }
    return true;
  }

  void _appendTasks(String tasksPath, List<TaskDraft> drafts) {
    final file = File(tasksPath);
    final lines = file.readAsLinesSync();
    final insertion = drafts.map((draft) => draft.toTaskLine()).toList();
    final backlogIndex = lines.indexWhere(
      (line) => line.trim().toLowerCase() == '## backlog',
    );

    if (backlogIndex == -1) {
      final updated = <String>[...lines];
      if (updated.isNotEmpty && updated.last.trim().isNotEmpty) {
        updated.add('');
      }
      updated.add('## Backlog');
      updated.addAll(insertion);
      AtomicFileWrite.writeStringSync(
        tasksPath,
        '${updated.join('\n').trimRight()}\n',
      );
      return;
    }

    var insertAt = lines.length;
    for (var i = backlogIndex + 1; i < lines.length; i += 1) {
      if (lines[i].trim().startsWith('## ')) {
        insertAt = i;
        break;
      }
    }

    final updated = <String>[...lines];
    updated.insertAll(insertAt, insertion);
    AtomicFileWrite.writeStringSync(
      tasksPath,
      '${updated.join('\n').trimRight()}\n',
    );
  }

  _DraftDefaults _defaultsForSection(String? section) {
    final label = section?.toLowerCase() ?? '';
    if (label.contains('p1') || label.contains('critical')) {
      return const _DraftDefaults(
        priority: TaskPriority.p1,
        category: TaskCategory.core,
      );
    }
    if (label.contains('p3') || label.contains('later')) {
      return const _DraftDefaults(
        priority: TaskPriority.p3,
        category: TaskCategory.core,
      );
    }
    if (label.contains('ui')) {
      return const _DraftDefaults(
        priority: TaskPriority.p2,
        category: TaskCategory.ui,
      );
    }
    if (label.contains('security') || label.contains('sec')) {
      return const _DraftDefaults(
        priority: TaskPriority.p1,
        category: TaskCategory.security,
      );
    }
    if (label.contains('docs')) {
      return const _DraftDefaults(
        priority: TaskPriority.p3,
        category: TaskCategory.docs,
      );
    }
    return const _DraftDefaults(
      priority: TaskPriority.p2,
      category: TaskCategory.core,
    );
  }

  bool _isSuppressedSection(String? section) {
    final lower = section?.toLowerCase() ?? '';
    return lower == 'constraints' || lower == 'success criteria';
  }

  bool _containsPriorityOrCategory(String value) {
    return RegExp(r'\bP[1-3]\b', caseSensitive: false).hasMatch(value) ||
        RegExp(
          r'\[(UI|SEC|DOCS|ARCH|QA|AGENT|CORE|REF|REFACTOR)\]',
          caseSensitive: false,
        ).hasMatch(value);
  }

  List<String> _collectAcceptanceLines(List<String> lines, int startIndex) {
    final results = <String>[];
    for (var i = startIndex + 1; i < lines.length; i += 1) {
      final raw = lines[i];
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('```')) {
        break;
      }
      if (_isTopLevelBullet(raw) || _isHeading(trimmed)) {
        break;
      }
      if (_looksLikeAcceptance(trimmed)) {
        final content = _stripAcceptancePrefix(trimmed);
        if (content.isNotEmpty) {
          results.add(content);
        }
      }
    }
    return results;
  }

  bool _isHeading(String value) => RegExp(r'^#{1,6}\s+').hasMatch(value);

  bool _isTopLevelBullet(String raw) {
    final indent = _indentCount(raw);
    if (indent > 1) {
      return false;
    }
    final trimmed = raw.trimLeft();
    return RegExp(r'^[-*]\s+').hasMatch(trimmed) ||
        RegExp(r'^\d+\.\s+').hasMatch(trimmed);
  }

  bool _looksLikeAcceptance(String value) {
    return RegExp(
      r'^(?:-|\*|\d+\.)?\s*(AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _stripAcceptancePrefix(String value) {
    return value
        .replaceFirst(
          RegExp(
            r'^(?:-|\*|\d+\.)?\s*(AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  int _indentCount(String line) {
    var count = 0;
    while (count < line.length && line[count] == ' ') {
      count += 1;
    }
    return count;
  }

  String _defaultAcceptance(String title) {
    return 'The change for "$title" is implemented and verified by tests or manual check.';
  }

  List<TaskDraft> _fallbackDrafts() {
    return [
      TaskDraft(
        title: 'Define initial backlog from vision with acceptance criteria',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        acceptanceCriteria:
            'At least 5 backlog tasks exist with priority, category, and AC.',
        source: 'fallback',
      ),
      TaskDraft(
        title: 'Review VISION.md and add missing milestones',
        priority: TaskPriority.p2,
        category: TaskCategory.docs,
        acceptanceCriteria:
            'VISION.md lists goals, constraints, and next milestones clearly.',
        source: 'fallback',
      ),
    ];
  }
}

class _DraftDefaults {
  const _DraftDefaults({required this.priority, required this.category});

  final TaskPriority priority;
  final TaskCategory category;
}

class _ScoredDraft {
  const _ScoredDraft(this.draft, this.score);

  final TaskDraft draft;
  final double score;
}
