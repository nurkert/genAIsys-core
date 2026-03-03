// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class FailureReason {
  const FailureReason({required this.errorClass, required this.errorKind});

  final String errorClass;
  final String errorKind;

  static const unknown = FailureReason(
    errorClass: 'unknown',
    errorKind: 'unknown',
  );
}

class FailureReasonMapper {
  static FailureReason normalize({
    String? errorClass,
    String? errorKind,
    String? message,
    String? event,
  }) {
    final normalizedClass = _normalizeToken(errorClass);
    final normalizedKind = _normalizeToken(errorKind);
    final inferredKind =
        normalizedKind ?? _inferKind(message: message, event: event);
    final inferredClass =
        normalizedClass ??
        (inferredKind == null ? null : _classByKind[inferredKind]) ??
        _inferClassFromEvent(event);

    return FailureReason(
      errorClass: inferredClass ?? FailureReason.unknown.errorClass,
      errorKind: inferredKind ?? FailureReason.unknown.errorKind,
    );
  }

  static String? _normalizeToken(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final valid = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!valid.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _inferKind({String? message, String? event}) {
    final normalized = (message ?? '').toLowerCase();
    if (normalized.isNotEmpty) {
      if (normalized.contains('safe_write_scope')) {
        return 'safe_write_scope';
      }
      if (_looksLikeQualityGateFailure(normalized)) {
        if (normalized.contains('dart analyze') ||
            normalized.contains('flutter analyze')) {
          return 'analyze_failed';
        }
        if (normalized.contains('flutter test') ||
            normalized.contains('dart test')) {
          return 'test_failed';
        }
        return 'quality_gate_failed';
      }
      if (normalized.contains('policy violation')) {
        return 'policy_violation';
      }
      if (normalized.contains('unattended') &&
          normalized.contains('not released')) {
        return 'unattended_not_released';
      }
      if (normalized.contains('state.json') && normalized.contains('schema')) {
        return 'state_schema';
      }
      if (normalized.contains('config.yml') && normalized.contains('schema')) {
        return 'config_schema';
      }
      if (normalized.contains('tasks.md') && normalized.contains('schema')) {
        return 'tasks_schema';
      }
      if (normalized.contains('not found')) {
        return 'not_found';
      }
      if (normalized.contains('timeout')) {
        return 'timeout';
      }
      if (normalized.contains('quota') ||
          normalized.contains('rate limit') ||
          normalized.contains('429') ||
          normalized.contains('too many requests') ||
          normalized.contains('resource exhausted')) {
        return 'provider_quota';
      }
      if (normalized.contains('already running') ||
          normalized.contains('autopilot is already running')) {
        return 'lock_held';
      }
      if (normalized.contains('no active task')) {
        return 'no_active_task';
      }
      if (normalized.contains('exit_code 126') ||
          normalized.contains('exit_code 127') ||
          normalized.contains('not found on path') ||
          normalized.contains('could not be launched')) {
        return 'agent_unavailable';
      }
      if (normalized.contains('merge conflict') ||
          normalized.contains('merge in progress')) {
        return 'merge_conflict';
      }
      if (normalized.contains('uncommitted changes') ||
          normalized.contains('dirty repo') ||
          normalized.contains('dirty repository') ||
          normalized.contains('git repo has uncommitted changes')) {
        return 'git_dirty';
      }
      if (normalized.contains('diff_budget')) {
        return 'diff_budget';
      }
    }

    final eventToken = _normalizeToken(event);
    if (eventToken != null) {
      final mapped = _kindByEvent[eventToken];
      if (mapped != null) {
        return mapped;
      }
    }

    return null;
  }

  static bool _looksLikeQualityGateFailure(String normalized) {
    if (!normalized.contains('quality gate') &&
        !normalized.contains('quality_gate')) {
      return false;
    }
    return normalized.contains('quality gate failed') ||
        normalized.contains('quality_gate command failed') ||
        normalized.contains('quality_gate command timed out') ||
        normalized.contains('quality gate rejected');
  }

  static String? _inferClassFromEvent(String? event) {
    final token = _normalizeToken(event);
    if (token == null) {
      return null;
    }
    if (token == 'preflight_failed') {
      return 'preflight';
    }
    if (token == 'orchestrator_run_provider_pause') {
      return 'provider';
    }
    if (token.contains('lock')) {
      return 'locking';
    }
    if (token.contains('quality_gate')) {
      return 'quality_gate';
    }
    if (token.contains('review')) {
      return 'review';
    }
    if (token.contains('release_tag') || token.contains('delivery')) {
      return 'delivery';
    }
    return null;
  }

  static const Map<String, String> _kindByEvent = {
    'preflight_failed': 'preflight_failed',
    'orchestrator_run_provider_pause': 'provider_quota',
    'orchestrator_run_stuck': 'stuck',
    'task_cycle_no_diff': 'no_diff',
    'review_reject': 'review_rejected',
    'quality_gate_reject': 'quality_gate_failed',
    'orchestrator_run_lock_recovered': 'lock_recovered',
  };

  /// Classify a process exit code into a semantic [FailureReason].
  ///
  /// On Unix, exit codes above 128 indicate the process was terminated by a
  /// signal (exit code = 128 + signal number).  Common signals:
  ///   SIGABRT (6)  → 134,  SIGKILL (9)  → 137,  SIGBUS (10) → 138,
  ///   SIGSEGV (11) → 139,  SIGPIPE (13) → 141,  SIGTERM (15) → 143.
  static FailureReason classifyExitCode(int exitCode) {
    if (exitCode == 0) {
      return const FailureReason(errorClass: 'success', errorKind: 'success');
    }
    if (exitCode == 124) {
      return const FailureReason(errorClass: 'pipeline', errorKind: 'timeout');
    }
    if (exitCode == 126 || exitCode == 127) {
      return const FailureReason(
        errorClass: 'provider',
        errorKind: 'agent_unavailable',
      );
    }
    if (exitCode > 128 && exitCode < 192) {
      final signal = exitCode - 128;
      final kind = _signalKinds[signal];
      if (kind != null) {
        return FailureReason(errorClass: 'process', errorKind: kind);
      }
      return FailureReason(errorClass: 'process', errorKind: 'signal_$signal');
    }
    return FailureReason.unknown;
  }

  /// Returns `true` if the exit code indicates a signal-based termination.
  static bool isSignalExit(int exitCode) {
    return exitCode > 128 && exitCode < 192;
  }

  /// Returns the signal number from a signal-based exit code, or `null`.
  static int? signalFromExitCode(int exitCode) {
    if (!isSignalExit(exitCode)) {
      return null;
    }
    return exitCode - 128;
  }

  /// Human-readable label for well-known Unix signals.
  static String signalName(int signal) {
    return _signalNames[signal] ?? 'SIG$signal';
  }

  static const Map<int, String> _signalKinds = {
    6: 'agent_crash_abort', // SIGABRT
    9: 'agent_killed', // SIGKILL
    10: 'agent_crash_bus', // SIGBUS
    11: 'agent_crash_segv', // SIGSEGV
    13: 'agent_pipe', // SIGPIPE
    15: 'agent_terminated', // SIGTERM
  };

  static const Map<int, String> _signalNames = {
    1: 'SIGHUP',
    2: 'SIGINT',
    3: 'SIGQUIT',
    6: 'SIGABRT',
    9: 'SIGKILL',
    10: 'SIGBUS',
    11: 'SIGSEGV',
    13: 'SIGPIPE',
    14: 'SIGALRM',
    15: 'SIGTERM',
  };

  static const Map<String, String> _classByKind = {
    'state_schema': 'state',
    'config_schema': 'state',
    'tasks_schema': 'state',
    'state_missing': 'state',
    'tasks_missing': 'state',
    'state_error': 'state',
    'config_unavailable': 'state',
    'schema_unavailable': 'state',
    'schema_invalid': 'state',
    'planning_audit': 'state',

    'preflight_failed': 'preflight',
    'allowlist': 'preflight',
    'review_unavailable': 'preflight',
    'agent_unavailable': 'provider',

    'provider_credentials_missing': 'provider',
    'provider_quota': 'provider',

    'quality_gate_failed': 'quality_gate',
    'analyze_failed': 'quality_gate',
    'test_failed': 'quality_gate',
    'quality_gate_disabled': 'quality_gate',

    'review_rejected': 'review',
    'no_diff': 'review',

    'git_dirty': 'delivery',
    'merge_conflict': 'delivery',
    'tag_exists': 'delivery',
    'tag_create_failed': 'delivery',
    'tag_push_failed': 'delivery',
    'push_disabled': 'delivery',
    'no_remote': 'delivery',
    'git_no_head': 'delivery',
    'not_git_repo': 'delivery',
    'merge_in_progress': 'delivery',
    'not_base_branch': 'delivery',

    'lock_held': 'locking',
    'lock_recovered': 'locking',

    'policy_violation': 'policy',
    'safe_write_scope': 'policy',
    'diff_budget': 'policy',
    'unattended_not_released': 'policy',
    'spec_required_files_missing': 'policy',

    'stuck': 'pipeline',
    'timeout': 'pipeline',
    'approve_budget': 'pipeline',
    'scope_budget': 'pipeline',
    'no_active_task': 'pipeline',
    'not_found': 'pipeline',

    'agent_crash_abort': 'process',
    'agent_killed': 'process',
    'agent_crash_bus': 'process',
    'agent_crash_segv': 'process',
    'agent_pipe': 'process',
    'agent_terminated': 'process',
  };
}
