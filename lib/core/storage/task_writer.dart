// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../models/task.dart';
import 'atomic_file_write.dart';

class TaskWriter {
  TaskWriter(this.tasksPath);

  final String tasksPath;

  bool markDone(Task task) {
    return _updateLine(task, completed: true, blocked: false, reason: null);
  }

  bool markBlocked(Task task, {String? reason}) {
    return _updateLine(task, completed: false, blocked: true, reason: reason);
  }

  bool _updateLine(
    Task task, {
    required bool completed,
    required bool blocked,
    String? reason,
  }) {
    final file = File(tasksPath);
    if (!file.existsSync()) {
      return false;
    }
    final lines = file.readAsLinesSync();
    if (task.lineIndex < 0 || task.lineIndex >= lines.length) {
      return false;
    }

    var line = lines[task.lineIndex];
    if (!line.trimLeft().startsWith('- [')) {
      return false;
    }

    line = line.replaceFirst(
      RegExp(r'- \[( |x|X)\]'),
      completed ? '- [x]' : '- [ ]',
    );

    if (blocked) {
      if (!line.contains('[BLOCKED]')) {
        line = line.replaceFirst('- [ ]', '- [ ] [BLOCKED]');
      }
      if (reason != null &&
          reason.trim().isNotEmpty &&
          !line.contains('Reason:')) {
        line = '$line (Reason: ${reason.trim()})';
      }
    } else {
      line = line.replaceAll(' [BLOCKED]', '');
    }

    lines[task.lineIndex] = line;
    AtomicFileWrite.writeStringSync(tasksPath, lines.join('\n'));
    return true;
  }
}
