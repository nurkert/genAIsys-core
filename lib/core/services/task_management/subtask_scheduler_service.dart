// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../ids/task_slugger.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

class SubtaskCandidateDecision {
  const SubtaskCandidateDecision({
    required this.subtask,
    required this.queuePosition,
    required this.dependencyReady,
    required this.unresolvedDependencies,
    required this.priorityRank,
    required this.priorityLabel,
    required this.categoryRank,
    required this.categoryLabel,
    required this.stableSubtaskKey,
    required this.stableFinalKey,
  });

  final String subtask;
  final int queuePosition;
  final bool dependencyReady;
  final List<String> unresolvedDependencies;
  final int priorityRank;
  final String priorityLabel;
  final int categoryRank;
  final String categoryLabel;
  final String stableSubtaskKey;
  final String stableFinalKey;

  Map<String, Object?> toJson() {
    return {
      'subtask': subtask,
      'queue_position': queuePosition,
      'dependency_ready': dependencyReady,
      'unresolved_dependencies': unresolvedDependencies,
      'priority_rank': priorityRank,
      'priority': priorityLabel,
      'category_rank': categoryRank,
      'category': categoryLabel,
      'stable_subtask_key': stableSubtaskKey,
      'stable_final_key': stableFinalKey,
    };
  }
}

class SubtaskSelection {
  const SubtaskSelection({
    required this.selectedSubtask,
    required this.remainingQueue,
    required this.dependencyAware,
    required this.cycleFallback,
    required this.candidates,
    required this.selectedCandidate,
    required this.tieBreakerFields,
    this.skippedSubtasks = const [],
  });

  final String selectedSubtask;
  final List<String> remainingQueue;
  final bool dependencyAware;
  final bool cycleFallback;
  final List<SubtaskCandidateDecision> candidates;
  final SubtaskCandidateDecision selectedCandidate;
  final List<String> tieBreakerFields;

  /// Subtasks that were removed from the queue because they could not be found
  /// in the task spec file. Each entry is the original queue text that was
  /// skipped together with a machine-readable reason.
  final List<SkippedSubtask> skippedSubtasks;
}

class SkippedSubtask {
  const SkippedSubtask({required this.subtask, required this.reason});

  final String subtask;

  /// Machine-readable reason: `spec_file_missing` or `not_in_spec`.
  final String reason;

  Map<String, Object?> toJson() => {'subtask': subtask, 'reason': reason};
}

class SubtaskSchedulerService {
  static const List<String> tieBreakerFields = [
    'dependency_ready',
    'priority_rank',
    'category_rank',
    'queue_position',
    'stable_final_key',
  ];

  static final RegExp _verificationSubtaskPattern = RegExp(
    r'^\s*(verify(\s+and\s+gate)?|gate|self-?review)\b|'
    r'\brun\s+`dart\s+analyze`\b|\bflutter\s+analyze\b|\bfull\s+tests\b',
    caseSensitive: false,
  );

  bool isVerificationSubtask(String input) {
    return _isVerificationSubtask(input);
  }

  SubtaskSelection selectNext(
    String projectRoot, {
    required String activeTaskTitle,
    String? activeTaskId,
    required List<String> queue,
  }) {
    final normalizedQueue = _normalizeQueue(queue);
    if (normalizedQueue.isEmpty) {
      throw StateError('Cannot select next subtask from an empty queue.');
    }

    // --- Spec-file validation: prune queue entries not found in spec. ---
    final layout = ProjectLayout(projectRoot);
    final specKeys = _loadSpecSubtaskKeys(
      layout,
      activeTaskTitle: activeTaskTitle,
    );
    final skipped = <SkippedSubtask>[];
    List<String> validatedQueue;
    if (specKeys == null) {
      // No spec file on disk -- skip validation (cannot verify).
      validatedQueue = normalizedQueue;
    } else if (specKeys.isEmpty) {
      // Spec file exists but has no parseable subtask entries. Treat every
      // queue entry as unverifiable and skip all of them.
      for (final entry in normalizedQueue) {
        skipped.add(
          SkippedSubtask(subtask: entry, reason: 'not_in_spec'),
        );
      }
      validatedQueue = const [];
    } else {
      validatedQueue = <String>[];
      for (final entry in normalizedQueue) {
        final key = _normalizedKey(entry);
        if (key.isEmpty || specKeys.contains(key)) {
          validatedQueue.add(entry);
        } else {
          skipped.add(
            SkippedSubtask(subtask: entry, reason: 'not_in_spec'),
          );
        }
      }
    }

    // Log skipped entries.
    if (skipped.isNotEmpty) {
      try {
        RunLogStore(layout.runLogPath).append(
          event: 'subtask_spec_not_found',
          message: 'Subtask(s) removed from queue: not found in spec file',
          data: {
            'task': activeTaskTitle,
            if (activeTaskId != null && activeTaskId.isNotEmpty)
              'task_id': activeTaskId,
            'skipped': skipped
                .map((entry) => entry.toJson())
                .toList(growable: false),
            'error_class': 'scheduler',
            'error_kind': 'subtask_spec_not_found',
          },
        );
      } catch (_) {
        // Run-log write failure must not block scheduling.
      }
    }

    if (validatedQueue.isEmpty) {
      throw StateError(
        'Cannot select next subtask: all queue entries were pruned '
        '(not found in spec file).',
      );
    }
    // --- End spec-file validation ---

    final dependencies = _loadDependencies(
      projectRoot,
      activeTaskTitle: activeTaskTitle,
    );
    final queueKeys = validatedQueue
        .map(_normalizedKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    final taskKey = _taskKey(activeTaskId, activeTaskTitle: activeTaskTitle);
    final candidates = <SubtaskCandidateDecision>[];
    for (var i = 0; i < validatedQueue.length; i += 1) {
      final subtask = validatedQueue[i];
      final normalizedSubtaskKey = _normalizedKey(subtask);
      final deps = dependencies[normalizedSubtaskKey] ?? const <String>{};
      final unresolved =
          deps
              .where(
                (dep) => dep != normalizedSubtaskKey && queueKeys.contains(dep),
              )
              .toList(growable: false)
            ..sort();
      final priorityRank = _priorityRank(subtask);
      final categoryRank = _categoryRank(subtask);
      final stableSubtaskKey = _stableSubtaskKey(
        subtask,
        normalizedSubtaskKey: normalizedSubtaskKey,
      );
      final stableFinalKey = '$taskKey|$stableSubtaskKey';
      candidates.add(
        SubtaskCandidateDecision(
          subtask: subtask,
          queuePosition: i,
          dependencyReady: unresolved.isEmpty,
          unresolvedDependencies: unresolved,
          priorityRank: priorityRank,
          priorityLabel: _priorityLabel(priorityRank),
          categoryRank: categoryRank,
          categoryLabel: _categoryLabel(categoryRank),
          stableSubtaskKey: stableSubtaskKey,
          stableFinalKey: stableFinalKey,
        ),
      );
    }

    final sorted = _sortedCandidates(candidates);
    final selectedCandidate = sorted.first;
    final selected = selectedCandidate.subtask;
    final remaining = <String>[];
    var removedSelected = false;
    for (final entry in validatedQueue) {
      if (!removedSelected && entry == selected) {
        removedSelected = true;
        continue;
      }
      remaining.add(entry);
    }
    final readyCount = sorted
        .where((candidate) => candidate.dependencyReady)
        .length;
    final cycleFallback = readyCount == 0;
    final dependencyAware =
        dependencies.isNotEmpty ||
        candidates.any(
          (candidate) => candidate.unresolvedDependencies.isNotEmpty,
        );
    return SubtaskSelection(
      selectedSubtask: selected,
      remainingQueue: remaining,
      dependencyAware: dependencyAware,
      cycleFallback: cycleFallback,
      candidates: sorted,
      selectedCandidate: selectedCandidate,
      tieBreakerFields: tieBreakerFields,
      skippedSubtasks: skipped,
    );
  }

  SubtaskCandidateDecision replaySelection({
    required List<SubtaskCandidateDecision> candidates,
  }) {
    if (candidates.isEmpty) {
      throw StateError('Cannot replay subtask selection without candidates.');
    }
    final sorted = _sortedCandidates(candidates);
    return sorted.first;
  }

  List<String> _normalizeQueue(List<String> queue) {
    final output = <String>[];
    for (final raw in queue) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      output.add(trimmed);
    }
    return output;
  }

  /// Returns the spec file path for the given task title.
  String _specFilePath(ProjectLayout layout, String activeTaskTitle) {
    final slug = TaskSlugger.slug(activeTaskTitle);
    return '${layout.taskSpecsDir}${Platform.pathSeparator}$slug-subtasks.md';
  }

  /// Loads the set of normalized subtask keys from the spec file.
  ///
  /// Returns `null` if the spec file does not exist (i.e. no validation is
  /// possible). Returns an empty set if the file exists but contains no
  /// parseable subtask entries.
  Set<String>? _loadSpecSubtaskKeys(
    ProjectLayout layout, {
    required String activeTaskTitle,
  }) {
    final path = _specFilePath(layout, activeTaskTitle);
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    try {
      final lines = file.readAsLinesSync();
      final records = _parseSubtaskRecords(lines);
      return records.map((record) => record.normalizedText).toSet();
    } catch (_) {
      return null;
    }
  }

  Map<String, Set<String>> _loadDependencies(
    String projectRoot, {
    required String activeTaskTitle,
  }) {
    final layout = ProjectLayout(projectRoot);
    final path = _specFilePath(layout, activeTaskTitle);
    final file = File(path);
    if (!file.existsSync()) {
      return const {};
    }
    try {
      final lines = file.readAsLinesSync();
      return _parseDependencies(lines);
    } catch (_) {
      return const {};
    }
  }

  List<_SubtaskRecord> _parseSubtaskRecords(List<String> lines) {
    final records = <_SubtaskRecord>[];
    var inSection = false;
    var order = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('## Subtasks')) {
        inSection = true;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        inSection = false;
        continue;
      }
      if (!inSection) {
        continue;
      }
      final match = RegExp(r'^(?:(\d+)[.)]|[-*])\s+(.*)').firstMatch(trimmed);
      if (match == null) {
        continue;
      }
      order += 1;
      final rawNumber = match.group(1);
      final numericId = rawNumber == null ? order : int.tryParse(rawNumber);
      final extraction = _extractDependencyHints(match.group(2)?.trim() ?? '');
      final normalizedText = _normalizedKey(extraction.description);
      if (normalizedText.isEmpty) {
        continue;
      }
      records.add(
        _SubtaskRecord(
          order: order,
          numericId: numericId,
          normalizedText: normalizedText,
          rawDependencyRefs: extraction.dependencies,
        ),
      );
    }
    return records;
  }

  Map<String, Set<String>> _parseDependencies(List<String> lines) {
    final records = _parseSubtaskRecords(lines);
    if (records.isEmpty) {
      return const {};
    }

    final keyByNumber = <String, String>{};
    for (final record in records) {
      keyByNumber['#${record.order}'] = record.normalizedText;
      if (record.numericId != null && record.numericId! > 0) {
        keyByNumber['#${record.numericId}'] = record.normalizedText;
      }
    }

    final output = <String, Set<String>>{};
    for (final record in records) {
      final deps = <String>{};
      for (final ref in record.rawDependencyRefs) {
        final key = _normalizeDependencyRef(ref);
        if (key == null) {
          continue;
        }
        final byNumber = keyByNumber[key];
        if (byNumber != null && byNumber != record.normalizedText) {
          deps.add(byNumber);
          continue;
        }
        if (!key.startsWith('#')) {
          final normalized = _normalizedKey(key);
          if (normalized.isNotEmpty && normalized != record.normalizedText) {
            deps.add(normalized);
          }
        }
      }
      output[record.normalizedText] = deps;
    }
    return output;
  }

  _DependencyExtraction _extractDependencyHints(String input) {
    var description = input.trim();
    final refs = <String>{};
    final bracketPattern = RegExp(
      r'[\(\[]\s*(?:depends\s+on|dependency|dependencies|deps?)\s*:\s*([^\)\]]+)[\)\]]',
      caseSensitive: false,
    );
    for (final match in bracketPattern.allMatches(description)) {
      final chunk = match.group(1);
      if (chunk == null) {
        continue;
      }
      refs.addAll(_splitDependencyChunk(chunk));
    }
    description = description.replaceAll(bracketPattern, '').trim();

    final inlinePattern = RegExp(
      r'(?:depends\s+on|dependency|dependencies|deps?)\s*:\s*([^.;]+)',
      caseSensitive: false,
    );
    final inlineMatch = inlinePattern.firstMatch(description);
    if (inlineMatch != null) {
      final chunk = inlineMatch.group(1);
      if (chunk != null) {
        refs.addAll(_splitDependencyChunk(chunk));
      }
      description = description.replaceFirst(inlinePattern, '').trim();
    }

    return _DependencyExtraction(
      description: description,
      dependencies: refs.toList(growable: false),
    );
  }

  Iterable<String> _splitDependencyChunk(String chunk) sync* {
    for (final raw in chunk.split(
      RegExp(r'[,;/]|(?:\band\b)', caseSensitive: false),
    )) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        yield trimmed;
      }
    }
  }

  String? _normalizeDependencyRef(String raw) {
    final token = raw.trim().toLowerCase();
    if (token.isEmpty) {
      return null;
    }
    final number = int.tryParse(token);
    if (number != null && number > 0) {
      return '#$number';
    }
    final sNumber = RegExp(r'^s(\d+)$', caseSensitive: false).firstMatch(token);
    if (sNumber != null) {
      final parsed = int.tryParse(sNumber.group(1)!);
      if (parsed != null && parsed > 0) {
        return '#$parsed';
      }
    }
    final cleaned = token
        .replaceAll(RegExp(r'^task\s+'), '')
        .replaceAll(RegExp(r'^subtask\s+'), '')
        .trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  String _normalizedKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<SubtaskCandidateDecision> _sortedCandidates(
    List<SubtaskCandidateDecision> candidates,
  ) {
    final sorted = [...candidates];
    sorted.sort((left, right) {
      final leftReadyRank = left.dependencyReady ? 0 : 1;
      final rightReadyRank = right.dependencyReady ? 0 : 1;
      final readyCompare = leftReadyRank.compareTo(rightReadyRank);
      if (readyCompare != 0) {
        return readyCompare;
      }
      final priorityCompare = left.priorityRank.compareTo(right.priorityRank);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final categoryCompare = left.categoryRank.compareTo(right.categoryRank);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      final queueCompare = left.queuePosition.compareTo(right.queuePosition);
      if (queueCompare != 0) {
        return queueCompare;
      }
      return left.stableFinalKey.compareTo(right.stableFinalKey);
    });
    return sorted;
  }

  String _taskKey(String? activeTaskId, {required String activeTaskTitle}) {
    final normalizedId = activeTaskId?.trim();
    if (normalizedId != null && normalizedId.isNotEmpty) {
      return normalizedId.toLowerCase();
    }
    return TaskSlugger.slug(activeTaskTitle).toLowerCase();
  }

  int _priorityRank(String text) {
    // "Verify and gate" items are almost always end-of-queue gates. If they are
    // scheduled before any implementation/baseline work, the agent tends to
    // thrash (no diff) or burn time. Deprioritize them deterministically.
    if (_isVerificationSubtask(text)) {
      return 999;
    }
    final priority = RegExp(
      r'\bP([1-3])\b',
      caseSensitive: false,
    ).firstMatch(text);
    final marker = priority?.group(1);
    if (marker == '1') {
      return 1;
    }
    if (marker == '2') {
      return 2;
    }
    if (marker == '3') {
      return 3;
    }
    return 99;
  }

  String _priorityLabel(int rank) {
    if (rank == 1) {
      return 'p1';
    }
    if (rank == 2) {
      return 'p2';
    }
    if (rank == 3) {
      return 'p3';
    }
    return 'unknown';
  }

  int _categoryRank(String text) {
    // Verification-only subtasks must always be selected last within a task.
    // This prevents "verify/gate" from being executed before there is anything
    // to verify, which is a common unattended timeout/no-diff failure mode.
    if (_isVerificationSubtask(text)) {
      return 999;
    }
    final category = RegExp(
      r'\[(CORE|SEC|UI|DOCS|ARCH|QA|AGENT|REF|REFACTOR)\]',
      caseSensitive: false,
    ).firstMatch(text);
    final marker = (category?.group(1) ?? '').toUpperCase();
    const order = {
      'CORE': 1,
      'SEC': 2,
      'QA': 3,
      'ARCH': 4,
      'REF': 5,
      'REFACTOR': 5,
      'AGENT': 6,
      'DOCS': 7,
      'UI': 8,
    };
    return order[marker] ?? 99;
  }

  String _categoryLabel(int rank) {
    switch (rank) {
      case 1:
        return 'core';
      case 2:
        return 'security';
      case 3:
        return 'qa';
      case 4:
        return 'architecture';
      case 5:
        return 'refactor';
      case 6:
        return 'agent';
      case 7:
        return 'docs';
      case 8:
        return 'ui';
      default:
        return 'unknown';
    }
  }

  String _stableSubtaskKey(
    String subtask, {
    required String normalizedSubtaskKey,
  }) {
    final numberPrefix = RegExp(r'^\s*(\d+)(?:[.):\s-]|$)').firstMatch(subtask);
    if (numberPrefix != null) {
      final parsed = int.tryParse(numberPrefix.group(1)!);
      if (parsed != null) {
        final padded = parsed.toString().padLeft(8, '0');
        return 'n$padded|$normalizedSubtaskKey';
      }
    }
    final sPrefix = RegExp(
      r'^\s*s(\d+)(?:[.):\s-]|$)',
      caseSensitive: false,
    ).firstMatch(subtask);
    if (sPrefix != null) {
      final parsed = int.tryParse(sPrefix.group(1)!);
      if (parsed != null) {
        final padded = parsed.toString().padLeft(8, '0');
        return 's$padded|$normalizedSubtaskKey';
      }
    }
    return 't|$normalizedSubtaskKey';
  }

  bool _isVerificationSubtask(String input) {
    return _verificationSubtaskPattern.hasMatch(input);
  }
}

class _SubtaskRecord {
  const _SubtaskRecord({
    required this.order,
    required this.numericId,
    required this.normalizedText,
    required this.rawDependencyRefs,
  });

  final int order;
  final int? numericId;
  final String normalizedText;
  final List<String> rawDependencyRefs;
}

class _DependencyExtraction {
  const _DependencyExtraction({
    required this.description,
    required this.dependencies,
  });

  final String description;
  final List<String> dependencies;
}
