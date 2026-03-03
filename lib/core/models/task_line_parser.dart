// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'task.dart';

/// Cached RegExp patterns and shared parsing utilities for task lines.
///
/// Both [Task.parseLine] and [TaskDraft.parseLine] delegate to these
/// to avoid duplicating patterns and re-creating RegExp objects per call.
class TaskLineParser {
  TaskLineParser._();

  static final RegExp checkboxLine = RegExp(r'^- \[( |x|X)\]\s+(.*)$');
  static final RegExp blockedTag = RegExp(
    r'\[BLOCKED\]',
    caseSensitive: false,
  );
  static final RegExp priorityTag = RegExp(
    r'\[P([1-3])\]|\(P([1-3])\)|\bP([1-3])\b',
  );
  static final RegExp priorityTagAnchored = RegExp(
    r'^(?:\[P([1-3])\]|\(P([1-3])\)|P([1-3])\s*:\s*)',
  );
  static final RegExp categoryTag = RegExp(
    r'\[(UI|SEC|DOCS|ARCH|QA|AGENT|CORE|REF|REFACTOR)\]',
    caseSensitive: false,
  );
  static final RegExp listPrefix = RegExp(r'^[-*]\s+');
  static final RegExp numberedPrefix = RegExp(r'^\d+\.\s+');
  static final RegExp acceptancePattern = RegExp(
    r'(?:^|[|()])\s*(?:AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]\s*(.+)$',
    caseSensitive: false,
  );
  static final RegExp stripAcceptancePattern = RegExp(
    r'\s*[|()]?\s*(?:AC|Acceptance(?:\s+Criteria)?|Criteria)\s*[:\-]\s*.+$',
    caseSensitive: false,
  );
  static final RegExp stripPriorityTag = RegExp(
    r'\[P[1-3]\]|\(P[1-3]\)|\bP[1-3]\b',
    caseSensitive: false,
  );
  static final RegExp whitespace = RegExp(r'\s+');
  static final RegExp leadingPunctuation = RegExp(r'^[\-\|:]+');
  static final RegExp trailingPunctuation = RegExp(r'[.;:,]+$');
  static final RegExp titleNormalize = RegExp(r'[^a-z0-9]+');
  static final RegExp blockedReasonPattern = RegExp(
    r'\(\s*Reason\s*:\s*(.+?)\s*\)\s*$',
    caseSensitive: false,
  );

  /// Extracts a [TaskPriority] from a tag like `[P1]`, `(P2)`, or `P3`.
  static TaskPriority? extractPriority(String value) {
    final match = priorityTag.firstMatch(value);
    final level = match?.group(1) ?? match?.group(2) ?? match?.group(3);
    switch (level) {
      case '1':
        return TaskPriority.p1;
      case '2':
        return TaskPriority.p2;
      case '3':
        return TaskPriority.p3;
    }
    return null;
  }

  /// Extracts a [TaskCategory] from a tag like `[CORE]`, `[SEC]`, etc.
  static TaskCategory? extractCategory(String value) {
    final match = categoryTag.firstMatch(value);
    final tag = match?.group(1)?.toUpperCase();
    switch (tag) {
      case 'UI':
        return TaskCategory.ui;
      case 'SEC':
        return TaskCategory.security;
      case 'DOCS':
        return TaskCategory.docs;
      case 'ARCH':
        return TaskCategory.architecture;
      case 'QA':
        return TaskCategory.qa;
      case 'AGENT':
        return TaskCategory.agent;
      case 'CORE':
        return TaskCategory.core;
      case 'REF':
      case 'REFACTOR':
        return TaskCategory.refactor;
    }
    return null;
  }
}
