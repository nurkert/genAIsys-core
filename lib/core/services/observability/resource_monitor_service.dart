// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../project_layout.dart';
import '../../storage/run_log_store.dart';

/// Result of a disk-space resource check.
class DiskSpaceResult {
  const DiskSpaceResult({
    required this.ok,
    required this.availableBytes,
    required this.level,
    required this.message,
  });

  final bool ok;
  final int availableBytes;

  /// One of `ok`, `warning`, `critical`.
  final String level;
  final String message;
}

/// Service that monitors system resources (currently disk space) to prevent
/// silent failures during long-running unattended autopilot sessions.
class ResourceMonitorService {
  /// Minimum disk space before warning (100 MB).
  static const int warningThresholdBytes = 100 * 1024 * 1024;

  /// Minimum disk space before critical failure (20 MB).
  static const int criticalThresholdBytes = 20 * 1024 * 1024;

  /// Checks available disk space at the project root.
  ///
  /// Returns [DiskSpaceResult] with:
  /// - `ok=true` if sufficient space or on unsupported platforms.
  /// - `ok=false` only when space is critically low (<20 MB).
  /// - `level` of `ok`, `warning`, or `critical`.
  DiskSpaceResult checkDiskSpace(String projectRoot) {
    final availableBytes = _getAvailableBytes(projectRoot);
    if (availableBytes == null) {
      // Cannot determine disk space (unsupported platform) — pass.
      return const DiskSpaceResult(
        ok: true,
        availableBytes: -1,
        level: 'ok',
        message: 'Disk space check not available on this platform.',
      );
    }

    if (availableBytes < criticalThresholdBytes) {
      return DiskSpaceResult(
        ok: false,
        availableBytes: availableBytes,
        level: 'critical',
        message:
            'Critically low disk space: ${_formatBytes(availableBytes)} '
            'available (minimum: ${_formatBytes(criticalThresholdBytes)}).',
      );
    }

    if (availableBytes < warningThresholdBytes) {
      _logWarning(projectRoot, availableBytes);
      return DiskSpaceResult(
        ok: true,
        availableBytes: availableBytes,
        level: 'warning',
        message:
            'Low disk space warning: ${_formatBytes(availableBytes)} '
            'available.',
      );
    }

    return DiskSpaceResult(
      ok: true,
      availableBytes: availableBytes,
      level: 'ok',
      message: 'Disk space OK: ${_formatBytes(availableBytes)} available.',
    );
  }

  /// Returns available bytes at [path], or null if not determinable.
  int? _getAvailableBytes(String path) {
    try {
      final stat = FileStat.statSync(path);
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }
      // Use `df` on macOS/Linux to get available space.
      final result = Process.runSync('df', ['-k', path]);
      if (result.exitCode != 0) {
        return null;
      }
      final output = (result.stdout as String).trim();
      final lines = output.split('\n');
      if (lines.length < 2) {
        return null;
      }
      // df -k output: Filesystem 1K-blocks Used Available Use% Mounted
      // The available column is typically at index 3.
      final fields = lines.last.trim().split(RegExp(r'\s+'));
      if (fields.length < 4) {
        return null;
      }
      final availableKb = int.tryParse(fields[3]);
      if (availableKb == null) {
        return null;
      }
      return availableKb * 1024;
    } catch (_) {
      return null;
    }
  }

  void _logWarning(String projectRoot, int availableBytes) {
    try {
      final layout = ProjectLayout(projectRoot);
      RunLogStore(layout.runLogPath).append(
        event: 'resource_warning',
        message: 'Low disk space detected',
        data: {
          'root': projectRoot,
          'available_bytes': availableBytes,
          'available_human': _formatBytes(availableBytes),
          'error_class': 'resource',
          'error_kind': 'disk_space_low',
        },
      );
    } catch (_) {
      // Best-effort warning logging.
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
