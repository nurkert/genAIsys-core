// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';

class InteractionParityCheckResult {
  const InteractionParityCheckResult._({
    required this.ok,
    this.errorClass,
    this.errorKind,
    this.message,
  });

  const InteractionParityCheckResult.ok()
    : this._(ok: true, errorClass: null, errorKind: null, message: null);

  const InteractionParityCheckResult.failure({
    required String errorKind,
    required String message,
  }) : this._(
         ok: false,
         errorClass: 'policy',
         errorKind: errorKind,
         message: message,
       );

  final bool ok;
  final String? errorClass;
  final String? errorKind;
  final String? message;
}

class InteractionParityPolicy {
  static final RegExp _interactionTag = RegExp(
    r'\[INTERACTION\]',
    caseSensitive: false,
  );
  static final RegExp _guiParityTag = RegExp(
    r'\[GUI_PARITY\s*:\s*([^\]]+)\]',
    caseSensitive: false,
  );

  static bool isInteractionFacing(Task task) {
    return _interactionTag.hasMatch(task.title);
  }

  static InteractionParityCheckResult evaluate(Task task, List<Task> tasks) {
    if (!isInteractionFacing(task)) {
      return const InteractionParityCheckResult.ok();
    }

    final parityMatch = _guiParityTag.firstMatch(task.title);
    final parityValue = parityMatch?.group(1)?.trim();
    if (parityValue == null || parityValue.isEmpty) {
      return InteractionParityCheckResult.failure(
        errorKind: 'cli_gui_parity_missing',
        message: _missingMetadataMessage(task),
      );
    }

    if (parityValue.toUpperCase() == 'DONE') {
      return const InteractionParityCheckResult.ok();
    }

    final linked = _resolveLinkedTask(
      currentTask: task,
      tasks: tasks,
      rawLink: parityValue,
    );
    if (linked == null) {
      return InteractionParityCheckResult.failure(
        errorKind: 'cli_gui_parity_invalid_link',
        message: _invalidLinkMessage(task, parityValue),
      );
    }

    if (linked.lineIndex == task.lineIndex) {
      return InteractionParityCheckResult.failure(
        errorKind: 'cli_gui_parity_invalid_link',
        message:
            'Policy violation [policy/cli_gui_parity_invalid_link]: '
            'Task "${task.title}" links GUI parity to itself.',
      );
    }

    if (linked.category != TaskCategory.ui) {
      return InteractionParityCheckResult.failure(
        errorKind: 'cli_gui_parity_invalid_link',
        message:
            'Policy violation [policy/cli_gui_parity_invalid_link]: '
            'Linked GUI parity task must be [UI], got [${linked.category.name.toUpperCase()}].',
      );
    }

    if (linked.completion == TaskCompletion.done) {
      return InteractionParityCheckResult.failure(
        errorKind: 'cli_gui_parity_invalid_link',
        message:
            'Policy violation [policy/cli_gui_parity_invalid_link]: '
            'Linked GUI parity task is already done. '
            'Use [GUI_PARITY:DONE] for same-task parity evidence.',
      );
    }

    return const InteractionParityCheckResult.ok();
  }

  static Task? _resolveLinkedTask({
    required Task currentTask,
    required List<Task> tasks,
    required String rawLink,
  }) {
    final byId = tasks.where((task) => task.id == rawLink).toList();
    if (byId.length == 1) {
      return byId.first;
    }
    if (byId.length > 1) {
      return null;
    }

    final normalizedLink = _normalize(rawLink);
    final byTitle = tasks
        .where((task) => _normalize(task.title) == normalizedLink)
        .toList();
    if (byTitle.length != 1) {
      return null;
    }
    return byTitle.first;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static String _missingMetadataMessage(Task task) {
    return 'Policy violation [policy/cli_gui_parity_missing]: '
        'Interaction-facing task "${task.title}" requires GUI parity metadata. '
        'Add [GUI_PARITY:DONE] or [GUI_PARITY:<linked-ui-task-id>].';
  }

  static String _invalidLinkMessage(Task task, String link) {
    return 'Policy violation [policy/cli_gui_parity_invalid_link]: '
        'Interaction-facing task "${task.title}" references missing GUI parity link "$link". '
        'Link must point to exactly one open [UI] task.';
  }
}
