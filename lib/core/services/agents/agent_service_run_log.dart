// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'agent_service.dart';

extension _AgentServiceRunLog on AgentService {
  void _appendPolicyViolation(
    String projectRoot, {
    required String provider,
    required String attempt,
    required String reason,
    required String errorKind,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'agent_command_policy_violation',
      message: 'Agent command event policy violation',
      data: {
        'root': projectRoot,
        'runner': provider,
        'provider': provider,
        'attempt': attempt,
        'reason': reason,
        'error_class': 'policy',
        'error_kind': errorKind,
      },
    );
  }

  void _appendProviderBlocked(
    String projectRoot, {
    required String provider,
    required String reason,
    required String attempt,
    required String errorKind,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'unattended_provider_blocked',
      message: 'Blocked provider for unattended execution',
      data: {
        'root': projectRoot,
        'provider': provider,
        'attempt': attempt,
        'reason': reason,
        'error_class': 'policy',
        'error_kind': errorKind,
      },
    );
  }

  void _appendProviderFailureIncrement(
    String projectRoot, {
    required String provider,
    required String attempt,
    required int failures,
    required int threshold,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'unattended_provider_failure_increment',
      message: 'Provider failure $failures/$threshold (not yet blocked)',
      data: {
        'root': projectRoot,
        'provider': provider,
        'attempt': attempt,
        'consecutive_failures': failures,
        'failure_threshold': threshold,
        'error_class': 'provider',
        'error_kind': 'transient_failure',
      },
    );
  }

  void _appendProviderSkipped(
    String projectRoot, {
    required String provider,
    required String role,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    final blocked = _providerBlocklistService.entryFor(projectRoot, provider);
    RunLogStore(layout.runLogPath).append(
      event: 'unattended_provider_skipped',
      message: 'Skipped blocked provider for unattended execution',
      data: {
        'root': projectRoot,
        'provider': provider,
        'role': role,
        if (blocked != null) ...blocked,
      },
    );
  }

  void _appendProviderUnblocked(
    String projectRoot, {
    required String provider,
    required String reason,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'unattended_provider_unblocked',
      message: 'Recovered blocked provider for unattended execution',
      data: {
        'root': projectRoot,
        'provider': provider,
        'reason': reason,
        'error_class': 'policy',
        'error_kind': 'provider_recovered',
      },
    );
  }

  void _appendProviderExhausted(
    String projectRoot, {
    required List<String> blockedProviders,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'unattended_provider_exhausted',
      message: 'No eligible provider left for unattended execution',
      data: {
        'root': projectRoot,
        'blocked_providers': blockedProviders,
        'error_class': 'policy',
        'error_kind': 'provider_unavailable',
      },
    );
  }

  void _appendProviderQuotaHit(
    String projectRoot, {
    required String provider,
    required String account,
    required DateTime exhaustedUntil,
    required String reason,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'provider_pool_quota_hit',
      message: 'Provider quota hit, rotating to next pool entry',
      data: {
        'root': projectRoot,
        'provider': provider,
        'account': account,
        'quota_exhausted_until': exhaustedUntil.toUtc().toIso8601String(),
        'error_kind': 'provider_quota',
        'reason': reason,
      },
    );
  }

  void _appendProviderQuotaSkip(
    String projectRoot, {
    required String provider,
    required String account,
    required DateTime quotaUntil,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'provider_pool_quota_skip',
      message: 'Skipped provider pool entry due to active quota cooldown',
      data: {
        'root': projectRoot,
        'provider': provider,
        'account': account,
        'quota_exhausted_until': quotaUntil.toUtc().toIso8601String(),
        'error_kind': 'provider_quota',
      },
    );
  }

  void _appendProviderRotated(
    String projectRoot, {
    required String fromProvider,
    required String fromAccount,
    required String toProvider,
    required String toAccount,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'provider_pool_rotated',
      message: 'Rotated provider pool entry',
      data: {
        'root': projectRoot,
        'from_provider': fromProvider,
        'from_account': fromAccount,
        'to_provider': toProvider,
        'to_account': toAccount,
      },
    );
  }

  void _appendProviderPoolExhausted(
    String projectRoot, {
    required Duration pauseFor,
    required DateTime? resumeAt,
    required List<String> candidates,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'provider_pool_exhausted',
      message: 'Provider pool exhausted by quota limits',
      data: {
        'root': projectRoot,
        'pause_seconds': pauseFor.inSeconds,
        'resume_at': resumeAt?.toUtc().toIso8601String(),
        'candidates': candidates,
        'error_class': 'transient',
        'error_kind': 'provider_quota',
      },
    );
  }

  void _appendProviderPoolEntryUnresolved(
    String projectRoot, {
    required String provider,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    RunLogStore(layout.runLogPath).append(
      event: 'provider_pool_entry_unresolved',
      message: 'Pool entry could not be resolved to a registered runner',
      data: {
        'root': projectRoot,
        'provider': provider,
        'error_class': 'config',
        'error_kind': 'provider_not_registered',
      },
    );
  }

  void _appendAgentCommandStart(
    String projectRoot, {
    required String provider,
    required String account,
    required String attempt,
    required String runner,
    required int? timeoutSeconds,
    required String workingDirectory,
  }) {
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'agent_command_start',
      message: 'Agent command started',
      data: {
        'root': projectRoot,
        'provider': provider,
        'account': account,
        'attempt': attempt,
        'runner': runner,
        'timeout_seconds': timeoutSeconds,
        'working_directory': workingDirectory,
      },
    );
  }

  void _appendAgentCommandHeartbeat(
    String projectRoot, {
    required String provider,
    required String account,
    required String attempt,
    required String runner,
    required int count,
  }) {
    final layout = ProjectLayout(projectRoot);
    RunLogStore(layout.runLogPath).append(
      event: 'agent_command_heartbeat',
      message: 'Agent command still running',
      data: {
        'root': projectRoot,
        'provider': provider,
        'account': account,
        'attempt': attempt,
        'runner': runner,
        'heartbeat_count': count,
      },
    );
  }
}
