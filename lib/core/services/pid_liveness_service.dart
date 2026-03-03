// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

/// Consolidates PID liveness checks and process termination into a single
/// service, eliminating duplicate `Process.runSync('kill', ...)` /
/// `Process.runSync('tasklist', ...)` implementations across the codebase.
class PidLivenessService {
  /// Returns `true` when the operating system reports that [pidValue] refers
  /// to a running process.  Returns `false` for invalid PIDs (< 1), dead
  /// processes, or when the check itself fails.
  bool isProcessAlive(int pidValue) {
    if (pidValue < 1) {
      return false;
    }
    try {
      if (Platform.isWindows) {
        final result =
            Process.runSync('tasklist', ['/FI', 'PID eq $pidValue']);
        if (result.exitCode != 0) {
          return false;
        }
        final output = result.stdout.toString();
        if (output.trim().isEmpty) {
          return false;
        }
        final lower = output.toLowerCase();
        if (lower.contains('no tasks are running')) {
          return false;
        }
        return RegExp('\\b$pidValue\\b').hasMatch(output);
      }
      final result = Process.runSync('kill', ['-0', '$pidValue']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Attempts to terminate the process with [pidValue] by sending SIGTERM
  /// followed by SIGKILL.  Best-effort: failures are silently ignored.
  void terminateProcess(int pidValue) {
    try {
      Process.killPid(pidValue, ProcessSignal.sigterm);
    } catch (_) {}
    try {
      Process.killPid(pidValue, ProcessSignal.sigkill);
    } catch (_) {}
  }
}
