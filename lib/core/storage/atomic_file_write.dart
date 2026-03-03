// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

class AtomicFileWrite {
  static void writeStringSync(
    String path,
    String content, {
    Encoding encoding = utf8,
  }) {
    final target = File(path);
    target.parent.createSync(recursive: true);
    final temp = File(_tempPath(path));

    try {
      final handle = temp.openSync(mode: FileMode.writeOnly);
      try {
        handle.writeStringSync(content, encoding: encoding);
        handle.flushSync();
      } finally {
        handle.closeSync();
      }
      _replaceFile(temp: temp, target: target);
    } catch (_) {
      // Best-effort: clean up temp file before re-throwing the original error.
      if (temp.existsSync()) {
        temp.deleteSync();
      }
      rethrow;
    }
  }

  static void _replaceFile({required File temp, required File target}) {
    try {
      temp.renameSync(target.path);
      return;
    } on FileSystemException {
      // Best-effort: direct rename failed, fall through to backup-based
      // replacement for filesystems that do not support rename-overwrite.
    }

    final backup = target.existsSync()
        ? target.renameSync(_backupPath(target.path))
        : null;
    try {
      temp.renameSync(target.path);
      if (backup != null && backup.existsSync()) {
        backup.deleteSync();
      }
    } catch (_) {
      // Best-effort: restore backup on failure before re-throwing.
      if (backup != null && backup.existsSync()) {
        backup.renameSync(target.path);
      }
      rethrow;
    } finally {
      if (temp.existsSync()) {
        temp.deleteSync();
      }
      if (backup != null && backup.existsSync()) {
        backup.deleteSync();
      }
    }
  }

  static String _tempPath(String path) {
    final token = '${DateTime.now().microsecondsSinceEpoch}-$pid';
    return '$path.tmp.$token';
  }

  static String _backupPath(String path) {
    final token = '${DateTime.now().microsecondsSinceEpoch}-$pid';
    return '$path.bak.$token';
  }
}
