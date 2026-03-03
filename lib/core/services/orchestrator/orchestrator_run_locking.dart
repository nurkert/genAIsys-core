// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../orchestrator_run_service.dart';

extension _OrchestratorRunLocking on OrchestratorRunService {
  Duration _resolveLockTtl(String projectRoot) {
    return _loadConfig(projectRoot).autopilotLockTtl;
  }

  bool _isLockStaleWithMetadata(
    File file,
    Duration ttl, {
    required _AutopilotLockMetadata metadata,
  }) {
    if (ttl.inSeconds < 1) {
      return false;
    }
    DateTime? heartbeat = metadata.lastHeartbeat ?? metadata.startedAt;
    if (heartbeat == null) {
      try {
        heartbeat = file.lastModifiedSync().toUtc();
      } catch (_) {}
    }
    if (heartbeat == null) {
      return true;
    }
    final elapsed = DateTime.now().toUtc().difference(heartbeat);
    return elapsed > ttl;
  }

  bool _recoverStaleLock(
    String projectRoot,
    File file,
    Duration ttl, {
    String? context,
  }) {
    if (!file.existsSync()) {
      return false;
    }
    final meta = _readLockMetadata(file);
    final lockPid = _parsePid(meta.pid);
    final pidAlive = lockPid == null ? null : _pidLivenessService.isProcessAlive(lockPid);
    final staleByTtl = _isLockStaleWithMetadata(file, ttl, metadata: meta);
    String? recoveryReason;
    if (lockPid != null && pidAlive == false) {
      recoveryReason = 'pid_not_alive';
    } else if (lockPid != null && pidAlive == true) {
      // TOCTOU protection: if the lock's PID matches ours, the OS may have
      // recycled our PID to a previously-dead process. Compare started_at to
      // distinguish between our own lock and a recycled-PID stale lock.
      final myPid = pidOrNull();
      if (myPid != null && lockPid == myPid) {
        final lockStartedAt = meta.startedAt;
        final myStartedAt = _thisProcessStartedAt;
        if (myStartedAt != null && lockStartedAt != myStartedAt) {
          recoveryReason = 'pid_reused';
        }
        // else: myStartedAt == null (haven't acquired a lock yet) or
        //       lockStartedAt == myStartedAt → this is our own active lock.
      }
      // else: a different process owns the lock and is alive → don't recover.
    } else if (staleByTtl) {
      recoveryReason = 'ttl_expired';
    }
    if (recoveryReason == null) {
      return false;
    }
    try {
      file.deleteSync();
    } catch (_) {}
    _markRunStopped(projectRoot);
    _appendRunLog(
      projectRoot,
      event: 'orchestrator_run_lock_recovered',
      message: 'Recovered stale autopilot lock',
      data: {
        'error_class': 'locking',
        'error_kind': 'lock_recovered',
        'lock_file': file.path,
        'lock_started_at': meta.startedAt?.toIso8601String(),
        'lock_last_heartbeat': meta.lastHeartbeat?.toIso8601String(),
        'lock_pid': meta.pid,
        'lock_pid_alive': pidAlive,
        'recovery_reason': recoveryReason,
        'lock_ttl_seconds': ttl.inSeconds,
        if (context != null && context.trim().isNotEmpty)
          'context': context.trim(),
      },
    );
    return true;
  }

  _AutopilotLockMetadata _readLockMetadata(File file) {
    try {
      final lines = file.readAsLinesSync();
      String? startedAtRaw;
      String? heartbeatRaw;
      String? pidRaw;
      for (final line in lines) {
        if (line.startsWith('started_at=')) {
          startedAtRaw = line.substring('started_at='.length).trim();
        } else if (line.startsWith('last_heartbeat=')) {
          heartbeatRaw = line.substring('last_heartbeat='.length).trim();
        } else if (line.startsWith('pid=')) {
          pidRaw = line.substring('pid='.length).trim();
        }
      }
      return _AutopilotLockMetadata(
        startedAt: _parseIsoTimestamp(startedAtRaw),
        lastHeartbeat: _parseIsoTimestamp(heartbeatRaw),
        pid: pidRaw,
      );
    } catch (_) {
      return const _AutopilotLockMetadata();
    }
  }

  DateTime? _parseIsoTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  int? _parsePid(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  _AutopilotRunLock _acquireRunLock(
    String projectRoot, {
    bool isRetryAfterCorruptRecovery = false,
  }) {
    final layout = ProjectLayout(projectRoot);
    final lockDir = Directory(layout.locksDir);
    lockDir.createSync(recursive: true);
    _clearStopSignal(projectRoot);
    final file = File(layout.autopilotLockPath);
    final ttl = _resolveLockTtl(projectRoot);
    if (file.existsSync()) {
      _recoverStaleLock(projectRoot, file, ttl, context: 'run_start');
    }
    if (file.existsSync()) {
      throw StateError('Autopilot is already running: ${file.path}');
    }

    final raf = file.openSync(mode: FileMode.write);
    try {
      raf.lockSync(FileLock.exclusive);
    } on FileSystemException {
      try {
        raf.closeSync();
      } catch (_) {}
      throw StateError('Autopilot is already running: ${file.path}');
    }

    final startedAt = DateTime.now().toUtc().toIso8601String();
    // Record our lock acquisition time for TOCTOU detection.
    _thisProcessStartedAt ??= DateTime.tryParse(startedAt);
    final pidValue = pidOrNull();
    final pidLabel = pidValue?.toString() ?? 'unknown';
    final lockHandle = _AutopilotRunLock(
      path: file.path,
      raf: raf,
      startedAt: startedAt,
      pid: pidLabel,
      projectRoot: projectRoot,
    );
    try {
      lockHandle.writeHeartbeat(startedAt);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
      rethrow;
    }

    // Validate lock structure after acquisition. If the file is corrupt
    // (missing required pid or started_at fields), release, delete, log
    // a recovery event, and re-acquire once.
    if (!_validateLockStructure(file)) {
      lockHandle.release();
      _appendRunLog(
        projectRoot,
        event: 'lock_corrupt_recovery',
        message: 'Lock file corrupt after acquisition; recovering',
        data: {
          'error_class': 'locking',
          'error_kind': 'lock_corrupt_recovery',
          'lock_file': file.path,
          'is_retry': isRetryAfterCorruptRecovery,
        },
      );
      if (isRetryAfterCorruptRecovery) {
        throw StateError(
          'Lock file corrupt after re-acquisition: ${file.path}',
        );
      }
      return _acquireRunLock(projectRoot, isRetryAfterCorruptRecovery: true);
    }

    return lockHandle;
  }

  /// Returns `true` when the lock file contains the required `pid` and
  /// `started_at` fields with parseable values.
  bool _validateLockStructure(File file) {
    try {
      final meta = _readLockMetadata(file);
      if (meta.pid == null || meta.pid!.trim().isEmpty) {
        return false;
      }
      if (meta.startedAt == null) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _stopRequested(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.autopilotStopPath);
    if (!file.existsSync()) {
      return false;
    }
    // Check for stale stop signals (older than 2 hours).
    try {
      final content = file.readAsStringSync().trim();
      if (content.isNotEmpty) {
        final timestamp = DateTime.tryParse(content);
        if (timestamp != null) {
          final age = DateTime.now().toUtc().difference(timestamp.toUtc());
          if (age > const Duration(hours: 2)) {
            _appendRunLog(
              projectRoot,
              event: 'stale_stop_signal',
              message: 'Ignoring stale stop signal older than 2 hours',
              data: {
                'stop_timestamp': content,
                'age_seconds': age.inSeconds,
              },
            );
            // Remove the stale stop file so we don't re-check it every loop.
            try {
              file.deleteSync();
            } catch (_) {}
            return false;
          }
        }
      }
    } catch (_) {
      // If we cannot read the stop file, treat it as a valid stop request
      // (fail-closed).
    }
    return true;
  }

  void _writeStopSignal(String projectRoot) {
    try {
      final layout = ProjectLayout(projectRoot);
      final file = File(layout.autopilotStopPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        DateTime.now().toUtc().toIso8601String(),
        mode: FileMode.write,
        flush: true,
      );
    } catch (_) {}
  }

  void _clearStopSignal(String projectRoot) {
    try {
      final layout = ProjectLayout(projectRoot);
      final file = File(layout.autopilotStopPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}

class _AutopilotRunLock {
  _AutopilotRunLock({
    required this.path,
    required this.raf,
    required this.startedAt,
    required this.pid,
    required this.projectRoot,
  });

  final String path;
  final RandomAccessFile raf;
  final String startedAt;
  final String pid;
  final String projectRoot;

  void heartbeat({void Function(int failureCount)? onFailure}) {
    try {
      writeHeartbeat();
    } catch (_) {
      // Heartbeat updates should not break loop execution.
      if (onFailure != null) {
        onFailure(1); // Caller tracks the cumulative count.
      }
    }
  }

  void writeHeartbeat([String? heartbeat]) {
    final value = heartbeat ?? DateTime.now().toUtc().toIso8601String();
    _writeAutopilotLockPayload(
      raf,
      startedAt: startedAt,
      heartbeat: value,
      pid: pid,
      projectRoot: projectRoot,
    );
  }

  /// Verifies that the lock file on disk still contains our PID.
  ///
  /// If the lock file is missing or another process has overwritten it with
  /// a different PID, throws [StateError] to abort the current step.
  void verifyOwnership() {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError(
          'Lock file was deleted externally: $path',
        );
      }
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        if (line.startsWith('pid=')) {
          final filePid = line.substring('pid='.length).trim();
          if (filePid != pid) {
            throw StateError(
              'Lock stolen: file contains pid=$filePid, '
              'expected pid=$pid',
            );
          }
          return;
        }
      }
      // No PID line found — lock structure is invalid.
      throw StateError(
        'Lock file missing pid field: $path',
      );
    } on StateError {
      rethrow;
    } catch (e) {
      // File read failures are treated as ownership verification failures
      // (fail-closed).
      throw StateError(
        'Cannot verify lock ownership: $e',
      );
    }
  }

  void release() {
    try {
      raf.unlockSync();
    } catch (e) {
      try {
        stderr.writeln('[AutopilotRunLock] unlockSync failed for $path: $e');
      } catch (_) {}
    }
    try {
      raf.closeSync();
    } catch (e) {
      try {
        stderr.writeln('[AutopilotRunLock] closeSync failed for $path: $e');
      } catch (_) {}
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      try {
        stderr.writeln('[AutopilotRunLock] deleteSync failed for $path: $e');
      } catch (_) {}
    }
  }
}

class _AutopilotLockMetadata {
  const _AutopilotLockMetadata({this.startedAt, this.lastHeartbeat, this.pid});

  final DateTime? startedAt;
  final DateTime? lastHeartbeat;
  final String? pid;
}

void _writeAutopilotLockPayload(
  RandomAccessFile raf, {
  required String startedAt,
  required String heartbeat,
  required String pid,
  required String projectRoot,
}) {
  raf.truncateSync(0);
  final payload = StringBuffer()
    ..writeln('version=1')
    ..writeln('started_at=$startedAt')
    ..writeln('last_heartbeat=$heartbeat')
    ..writeln('pid=$pid')
    ..writeln('project_root=$projectRoot');
  raf.writeStringSync(payload.toString());
  raf.flushSync();
}
