// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../security/redaction_service.dart';

class RunLogRetentionPolicy {
  const RunLogRetentionPolicy({
    this.maxBytes = 2 * 1024 * 1024,
    this.maxArchives = 8,
    this.archiveDirectoryPath,
  }) : assert(maxBytes > 0),
       assert(maxArchives > 0);

  final int maxBytes;
  final int maxArchives;
  final String? archiveDirectoryPath;
}

class RunLogStore {
  RunLogStore(
    this.logPath, {
    RedactionService? redactionService,
    RunLogRetentionPolicy? retentionPolicy,
  }) : _redactionService = redactionService ?? RedactionService.shared,
       _retentionPolicy = retentionPolicy ?? const RunLogRetentionPolicy(),
       _eventSequence = _seedSequence(logPath);

  final String logPath;
  final RedactionService _redactionService;
  final RunLogRetentionPolicy _retentionPolicy;

  int _eventSequence;

  /// Seed the event sequence counter from the last line of an existing log.
  static int _seedSequence(String logPath) {
    try {
      final file = File(logPath);
      if (!file.existsSync()) return 0;
      final length = file.lengthSync();
      if (length == 0) return 0;

      // Read the last chunk to find the final event_id.
      final raf = file.openSync(mode: FileMode.read);
      try {
        const chunkSize = 4096;
        final start = length > chunkSize ? length - chunkSize : 0;
        raf.setPositionSync(start);
        final bytes = raf.readSync(length - start);
        final text = utf8.decode(bytes, allowMalformed: true);
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
        if (lines.isEmpty) return 0;
        final last = lines.last.trim();
        final decoded = jsonDecode(last);
        if (decoded is Map) {
          final eventId = decoded['event_id']?.toString() ?? '';
          // Format: evt-<micros>-<seq>
          final parts = eventId.split('-');
          if (parts.length >= 3) {
            return (int.tryParse(parts.last) ?? 0) % 1000000;
          }
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      // Best-effort: start from 0 if log is unreadable or malformed.
    }
    return 0;
  }

  void append({
    required String event,
    String? message,
    Map<String, Object?>? data,
  }) {
    final file = File(logPath);
    final now = DateTime.now().toUtc();
    final sanitizedEvent = _redactionService.sanitizeText(event);
    final sanitizedMessage = message == null
        ? null
        : _redactionService.sanitizeText(message);
    final sanitizedData = data == null
        ? const RedactionResult<Object?>(
            value: null,
            report: RedactionReport.none,
          )
        : _redactionService.sanitizeObject(data);
    final report = _mergeReports(
      sanitizedEvent.report,
      sanitizedMessage?.report,
      sanitizedData.report,
    );
    final sanitizedDataMap = _toStringKeyedMap(sanitizedData.value);
    final eventId = _nextEventId(now);
    final correlation = _buildCorrelation(sanitizedDataMap);
    final correlationId = _correlationId(correlation, eventId);
    final payload = <String, Object?>{
      'timestamp': now.toIso8601String(),
      'event_id': eventId,
      'correlation_id': correlationId,
      'event': sanitizedEvent.value,
      if (sanitizedMessage != null && sanitizedMessage.value.isNotEmpty)
        'message': sanitizedMessage.value,
      if (correlation.isNotEmpty) 'correlation': correlation,
      if (sanitizedDataMap != null && sanitizedDataMap.isNotEmpty)
        'data': sanitizedDataMap,
      if (report.applied) 'redaction': _redactionService.buildMetadata(report),
    };
    final line = '${jsonEncode(payload)}\n';
    try {
      _rotateIfNeeded(file, incomingBytes: utf8.encode(line).length);
    } catch (_) {
      // Best-effort: rotation should never block event append.
    }
    try {
      file.writeAsStringSync(line, mode: FileMode.append);
    } catch (e) {
      // Run log is the final persistence layer — stderr is the only safe
      // fallback when the log file itself cannot be written.
      try {
        stderr.writeln('[RunLogStore] Failed to append event "$event": $e');
      } catch (_) {
        // Best-effort: stderr is the ultimate fallback.
      }
    }
  }

  RedactionReport _mergeReports(
    RedactionReport first,
    RedactionReport? second,
    RedactionReport third,
  ) {
    final total =
        first.replacementCount +
        (second?.replacementCount ?? 0) +
        third.replacementCount;
    if (total == 0) {
      return RedactionReport.none;
    }
    final types = <String>{
      ...first.types,
      ...?second?.types,
      ...third.types,
    }.toList()..sort();
    return RedactionReport(
      applied: true,
      replacementCount: total,
      types: types,
    );
  }

  Map<String, Object?>? _toStringKeyedMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final result = <String, Object?>{};
    value.forEach((key, entryValue) {
      final normalized = key.toString().trim();
      if (normalized.isEmpty) {
        return;
      }
      result[normalized] = entryValue;
    });
    return result;
  }

  String _nextEventId(DateTime now) {
    _eventSequence = (_eventSequence + 1) % 1000000;
    final micros = now.microsecondsSinceEpoch;
    return 'evt-$micros-$_eventSequence';
  }

  Map<String, String> _buildCorrelation(Map<String, Object?>? data) {
    if (data == null || data.isEmpty) {
      return const <String, String>{};
    }
    final correlation = <String, String>{};
    _putCorrelation(correlation, 'task_id', data['task_id']);
    _putCorrelation(correlation, 'subtask_id', data['subtask_id']);
    _putCorrelation(correlation, 'step_id', data['step_id']);
    _putCorrelation(correlation, 'attempt_id', data['attempt_id']);
    _putCorrelation(correlation, 'review_id', data['review_id']);
    return correlation;
  }

  void _putCorrelation(
    Map<String, String> correlation,
    String key,
    Object? value,
  ) {
    if (value == null) {
      return;
    }
    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return;
    }
    correlation[key] = normalized;
  }

  String _correlationId(Map<String, String> correlation, String fallback) {
    if (correlation.isEmpty) {
      return fallback;
    }
    const order = <String>[
      'step_id',
      'attempt_id',
      'review_id',
      'task_id',
      'subtask_id',
    ];
    final parts = <String>[];
    for (final key in order) {
      final value = correlation[key];
      if (value == null || value.isEmpty) {
        continue;
      }
      parts.add('$key:$value');
    }
    if (parts.isEmpty) {
      return fallback;
    }
    return parts.join('|');
  }

  void _rotateIfNeeded(File file, {required int incomingBytes}) {
    if (!file.existsSync()) {
      return;
    }
    final currentBytes = _safeLength(file);
    if (currentBytes <= 0) {
      return;
    }
    final projectedBytes = currentBytes + incomingBytes;
    if (projectedBytes <= _retentionPolicy.maxBytes) {
      return;
    }
    final archiveDirectory = Directory(_archiveDirectory(file));
    archiveDirectory.createSync(recursive: true);
    final archiveFile = _nextArchiveFile(file, archiveDirectory);
    try {
      file.renameSync(archiveFile.path);
    } on FileSystemException {
      // Best-effort: rename failed (cross-device?), fallback to copy+delete.
      file.copySync(archiveFile.path);
      file.deleteSync();
    }
    _pruneArchives(file, archiveDirectory);
  }

  int _safeLength(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      // Best-effort: file may be inaccessible; treat as empty.
      return 0;
    }
  }

  String _archiveDirectory(File file) {
    if (_retentionPolicy.archiveDirectoryPath != null &&
        _retentionPolicy.archiveDirectoryPath!.trim().isNotEmpty) {
      return _retentionPolicy.archiveDirectoryPath!;
    }
    return '${file.parent.path}${Platform.pathSeparator}logs${Platform.pathSeparator}run_log_archive';
  }

  File _nextArchiveFile(File sourceFile, Directory archiveDirectory) {
    final baseName = _baseName(sourceFile.path);
    final dot = baseName.lastIndexOf('.');
    final stem = dot > 0 ? baseName.substring(0, dot) : baseName;
    final ext = dot > 0 ? baseName.substring(dot) : '';
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    var attempt = 0;
    while (true) {
      final suffix = attempt == 0 ? '' : '-$attempt';
      final candidatePath =
          '${archiveDirectory.path}${Platform.pathSeparator}$stem-$stamp$suffix$ext';
      final candidate = File(candidatePath);
      if (!candidate.existsSync()) {
        return candidate;
      }
      attempt += 1;
    }
  }

  void _pruneArchives(File sourceFile, Directory archiveDirectory) {
    final baseName = _baseName(sourceFile.path);
    final dot = baseName.lastIndexOf('.');
    final stem = dot > 0 ? baseName.substring(0, dot) : baseName;
    final ext = dot > 0 ? baseName.substring(dot) : '';

    final archives = archiveDirectory
        .listSync()
        .whereType<File>()
        .where((entry) {
          final name = _baseName(entry.path);
          return name.startsWith('$stem-') && name.endsWith(ext);
        })
        .toList(growable: false);
    if (archives.length <= _retentionPolicy.maxArchives) {
      return;
    }
    final sorted = archives.toList()
      ..sort((a, b) => _safeModified(b).compareTo(_safeModified(a)));
    final stale = sorted.skip(_retentionPolicy.maxArchives);
    for (final entry in stale) {
      try {
        entry.deleteSync();
      } on FileSystemException {
        // Best-effort: retention pruning should not block operations.
      }
    }
  }

  DateTime _safeModified(File file) {
    try {
      return file.lastModifiedSync().toUtc();
    } catch (_) {
      // Best-effort: fallback to epoch for inaccessible files.
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
  }

  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last;
  }

  /// Read the last [maxLines] lines from a JSONL file efficiently.
  ///
  /// Uses reverse-seek from the end of the file to avoid loading the entire
  /// file into memory. Returns an empty list if the file does not exist or
  /// is empty.
  static List<String> readTailLines(String path, {int maxLines = 2000}) {
    final file = File(path);
    if (!file.existsSync()) {
      return const <String>[];
    }

    final length = file.lengthSync();
    if (length == 0) {
      return const <String>[];
    }

    // For small files, just read the entire thing — simpler and fast enough.
    const smallFileThreshold = 256 * 1024; // 256 KB
    if (length <= smallFileThreshold) {
      try {
        final lines = file
            .readAsLinesSync()
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.length <= maxLines) {
          return lines;
        }
        return lines.sublist(lines.length - maxLines);
      } catch (_) {
        // Best-effort: file read failed; return empty.
        return const <String>[];
      }
    }

    // For larger files, read chunks from the end to find enough newlines.
    RandomAccessFile? raf;
    try {
      raf = file.openSync(mode: FileMode.read);
      const chunkSize = 64 * 1024; // 64 KB chunks
      var position = length;
      final collectedBytes = <int>[];
      var newlineCount = 0;

      while (position > 0 && newlineCount <= maxLines) {
        final readSize = position < chunkSize ? position : chunkSize;
        position -= readSize;
        raf.setPositionSync(position);
        final chunk = raf.readSync(readSize);
        // Count newlines in this chunk.
        for (var i = chunk.length - 1; i >= 0; i--) {
          if (chunk[i] == 0x0A) {
            // '\n'
            newlineCount++;
            if (newlineCount > maxLines) {
              // We have enough; take only from this point forward.
              collectedBytes.insertAll(0, chunk.sublist(i + 1));
              position = -1; // Signal to stop outer loop.
              break;
            }
          }
        }
        if (position >= 0) {
          collectedBytes.insertAll(0, chunk);
        }
      }

      raf.closeSync();
      raf = null;

      final text = utf8.decode(collectedBytes, allowMalformed: true);
      final lines = text.split('\n');
      // Remove empty trailing/leading entries from split.
      final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
      if (nonEmpty.length <= maxLines) {
        return nonEmpty;
      }
      return nonEmpty.sublist(nonEmpty.length - maxLines);
    } catch (_) {
      // Best-effort: reverse-seek failed; try full read as fallback.
      raf?.closeSync();
      try {
        final lines = file.readAsLinesSync();
        if (lines.length <= maxLines) {
          return lines;
        }
        return lines.sublist(lines.length - maxLines);
      } catch (_) {
        // Best-effort: ultimate fallback returns empty.
        return const <String>[];
      }
    }
  }
}
