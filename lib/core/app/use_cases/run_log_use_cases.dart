// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../project_layout.dart';
import '../contracts/app_error.dart';
import '../contracts/app_result.dart';
import '../dto/run_log_dto.dart';
import '../dto/telemetry_dto.dart';

/// Reads entries from `.genaisys/RUN_LOG.jsonl` in a paged fashion.
///
/// This use-case is intentionally UI-agnostic. It is safe for CLI and GUI
/// consumers alike and can be swapped with a remote implementation later.
class ReadRunLogPageUseCase {
  ReadRunLogPageUseCase({RunLogPageReader? reader})
    : _reader = reader ?? const RunLogPageReader();

  final RunLogPageReader _reader;

  Future<AppResult<AppRunLogPageDto>> run(
    String projectRoot, {
    int limit = 200,
    int? beforeOffset,
  }) async {
    if (projectRoot.trim().isEmpty) {
      return AppResult.failure(
        AppError.invalidInput('Project root must not be empty.'),
      );
    }
    if (limit < 1) {
      return AppResult.success(
        const AppRunLogPageDto(events: <AppRunLogEventDto>[]),
      );
    }

    try {
      final layout = ProjectLayout(projectRoot);
      final page = _reader.read(
        layout.runLogPath,
        limit: limit,
        beforeOffset: beforeOffset,
      );
      return AppResult.success(page);
    } catch (error, stackTrace) {
      return AppResult.failure(
        AppError.ioFailure(
          'Failed to read run log.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

/// Low-level reader that pages a JSONL file from the end using byte offsets.
///
/// This is a separate class so it can be unit-tested in isolation and swapped
/// without impacting the use-case contract.
class RunLogPageReader {
  const RunLogPageReader();

  static const int _newline = 0x0A;
  static const int _chunkSize = 8 * 1024;

  AppRunLogPageDto read(
    String runLogPath, {
    required int limit,
    int? beforeOffset,
  }) {
    final file = File(runLogPath);
    if (!file.existsSync()) {
      return const AppRunLogPageDto(events: <AppRunLogEventDto>[]);
    }

    final raf = file.openSync(mode: FileMode.read);
    try {
      final int length = raf.lengthSync();
      final int end = beforeOffset == null
          ? length
          : beforeOffset.clamp(0, length);
      if (end <= 0) {
        return const AppRunLogPageDto(events: <AppRunLogEventDto>[]);
      }

      final List<int> newlines = <int>[];
      int position = end;
      final int target = limit + 1;
      while (position > 0 && newlines.length < target) {
        final int readSize = min(_chunkSize, position);
        position -= readSize;
        raf.setPositionSync(position);
        final List<int> bytes = raf.readSync(readSize);
        for (
          int i = bytes.length - 1;
          i >= 0 && newlines.length < target;
          i -= 1
        ) {
          if (bytes[i] == _newline) {
            newlines.add(position + i);
          }
        }
      }

      final int startOffset;
      final int? nextBeforeOffset;
      if (newlines.length >= target) {
        startOffset = newlines[limit] + 1;
        nextBeforeOffset = startOffset <= 0 ? null : startOffset;
      } else {
        startOffset = 0;
        nextBeforeOffset = null;
      }

      if (startOffset >= end) {
        return const AppRunLogPageDto(events: <AppRunLogEventDto>[]);
      }

      raf.setPositionSync(startOffset);
      final List<int> sliceBytes = raf.readSync(end - startOffset);
      final String slice = utf8.decode(sliceBytes, allowMalformed: true);
      final List<AppRunLogEventDto> events = _parseJsonLines(slice);

      // The file is chronological (oldest->newest). For the UI we expose
      // newest->oldest to keep pagination and reverse list rendering simple.
      final List<AppRunLogEventDto> ordered = events.reversed.toList(
        growable: false,
      );

      return AppRunLogPageDto(
        events: ordered,
        nextBeforeOffset: nextBeforeOffset,
      );
    } finally {
      raf.closeSync();
    }
  }

  List<AppRunLogEventDto> _parseJsonLines(String slice) {
    final lines = slice.split('\n');
    final events = <AppRunLogEventDto>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          continue;
        }
        final event = decoded['event']?.toString() ?? '';
        if (event.isEmpty) {
          continue;
        }
        final Object? data = decoded['data'];
        events.add(
          AppRunLogEventDto(
            timestamp: decoded['timestamp']?.toString(),
            event: event,
            message: decoded['message']?.toString(),
            data: data is Map ? Map<String, Object?>.from(data) : null,
          ),
        );
      } catch (_) {
        // Ignore malformed lines: RUN_LOG.jsonl is best-effort, and partial
        // writes should not break the viewer.
      }
    }
    return events;
  }
}
