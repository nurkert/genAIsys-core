// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'agent_service.dart';

extension _AgentServiceProviderSelection on AgentService {
  List<SelectedAgentRunner> _resolvePoolCandidates(
    String projectRoot, {
    required List<SelectedAgentRunner> pool,
    required bool unattendedMode,
    required Set<String> blockedProviders,
  }) {
    if (!unattendedMode || blockedProviders.isEmpty) {
      return pool;
    }

    final output = <SelectedAgentRunner>[];
    for (final candidate in pool) {
      if (_isBlocked(blockedProviders, candidate.provider)) {
        _appendProviderSkipped(
          projectRoot,
          provider: candidate.provider,
          role: 'pool',
        );
        continue;
      }
      output.add(candidate);
    }

    if (output.isEmpty) {
      _throwProviderExhausted(projectRoot, blockedProviders: blockedProviders);
    }

    return List<SelectedAgentRunner>.unmodifiable(output);
  }

  Set<String> _recoverBlockedProviders(
    String projectRoot, {
    required List<SelectedAgentRunner> pool,
    required AgentRequest request,
    required Set<String> blockedProviders,
  }) {
    if (pool.isEmpty || blockedProviders.isEmpty) {
      return const <String>{};
    }
    final recovered = <String>{};
    for (final candidate in pool) {
      final provider = candidate.provider.trim().toLowerCase();
      if (!blockedProviders.contains(provider)) {
        continue;
      }
      final blockEntry = _providerBlocklistService.entryFor(
        projectRoot,
        provider,
      );
      final blockedKind =
          (blockEntry?['error_kind']?.toString().trim().toLowerCase()) ?? '';
      if (blockedKind != 'agent_unavailable') {
        continue;
      }
      final candidateRequest = _applyCandidateEnvironment(request, candidate);
      final preflight = _preflight(
        candidate.runner,
        environment: candidateRequest.environment,
        request: candidateRequest,
      );
      if (preflight != null) {
        continue;
      }
      final unblocked = _providerBlocklistService.unblockProvider(
        projectRoot,
        provider: provider,
      );
      if (!unblocked) {
        continue;
      }
      recovered.add(provider);
      _appendProviderUnblocked(
        projectRoot,
        provider: provider,
        reason: 'preflight_pass',
      );
    }
    return recovered;
  }

  List<int> _orderedIndexes(int count, int cursor) {
    if (count < 1) {
      return const [];
    }
    var start = cursor;
    if (start < 0) {
      start = 0;
    }
    start = start % count;
    final ordered = <int>[];
    for (var offset = 0; offset < count; offset += 1) {
      ordered.add((start + offset) % count);
    }
    return ordered;
  }

  bool _isBlocked(Set<String> blockedProviders, String provider) {
    final key = provider.trim().toLowerCase();
    if (key.isEmpty) {
      return false;
    }
    return blockedProviders.contains(key);
  }

  ProviderPoolStateSnapshot _recordQuotaFailure(
    String projectRoot, {
    required ProjectConfig config,
    required ProviderPoolStateSnapshot state,
    required SelectedAgentRunner candidate,
    required AgentResponse response,
  }) {
    // Increment quota hit count for exponential backoff.
    var updated = _providerPoolStateService.incrementQuotaHit(
      projectRoot,
      state: state,
      candidateKey: candidate.poolKey,
    );

    var baseCooldown = candidate.quotaCooldown ?? config.providerQuotaCooldown;
    if (baseCooldown.isNegative) {
      baseCooldown = Duration.zero;
    }
    if (baseCooldown == Duration.zero) {
      baseCooldown = config.providerQuotaPause;
    }
    if (baseCooldown == Duration.zero) {
      baseCooldown = const Duration(seconds: 1);
    }

    // Exponential backoff: base * 2^(hitCount-1), capped at 5 minutes.
    final hitCount = _providerPoolStateService.quotaHitCount(
      updated,
      candidate.poolKey,
    );
    final exponent = hitCount <= 1 ? 0 : hitCount - 1;
    const maxCooldownSeconds = 300;
    final multiplied = baseCooldown.inSeconds * (1 << (exponent.clamp(0, 8)));
    final effectiveSeconds = multiplied > maxCooldownSeconds
        ? maxCooldownSeconds
        : multiplied;
    final cooldown = Duration(
      seconds: effectiveSeconds < 1 ? 1 : effectiveSeconds,
    );

    final exhaustedUntil = DateTime.now().toUtc().add(cooldown);
    final reason = _quotaReason(response);
    updated = _providerPoolStateService.setQuotaExhausted(
      projectRoot,
      state: updated,
      candidateKey: candidate.poolKey,
      exhaustedUntil: exhaustedUntil,
      reason: reason,
    );
    _appendProviderQuotaHit(
      projectRoot,
      provider: candidate.provider,
      account: candidate.account,
      exhaustedUntil: exhaustedUntil,
      reason: reason,
    );
    return updated;
  }

  bool _isQuotaFailure(AgentResponse response) {
    if (response.exitCode == 429) {
      return true;
    }
    final combined = '${response.stderr}\n${response.stdout}'.toLowerCase();
    if (combined.isEmpty) {
      return false;
    }
    return combined.contains('rate limit') ||
        combined.contains('rate-limit') ||
        combined.contains('rate_limit') ||
        combined.contains('too many requests') ||
        combined.contains('status code: 429') ||
        combined.contains('status 429') ||
        combined.contains('http 429') ||
        combined.contains('quota exceeded') ||
        combined.contains('insufficient_quota') ||
        combined.contains('resource exhausted') ||
        combined.contains('limit exceeded') ||
        combined.contains('tokens per minute') ||
        combined.contains('rpm limit');
  }

  bool _isProviderUnavailable(AgentResponse response) {
    if (response.exitCode == 124 || response.commandEvent?.timedOut == true) {
      return false;
    }
    if (response.exitCode == 126 || response.exitCode == 127) {
      return true;
    }
    final combined = '${response.stderr}\n${response.stdout}'.toLowerCase();
    if (combined.isEmpty) {
      return false;
    }
    return combined.contains('not found on path') ||
        combined.contains('agent executable not found') ||
        combined.contains('could not be launched') ||
        combined.contains('permission denied') ||
        combined.contains('operation not permitted');
  }

  /// Default number of consecutive failures before a provider is blocked.
  static const int _defaultProviderFailureThreshold = 3;

  ProviderPoolStateSnapshot _blockUnavailableProviderForUnattended(
    String projectRoot, {
    required String provider,
    required String attempt,
    required AgentResponse response,
    required ProviderPoolStateSnapshot poolState,
    required String candidateKey,
    int? providerFailureThreshold,
  }) {
    final threshold =
        providerFailureThreshold ?? _defaultProviderFailureThreshold;
    if (!_isUnattendedMode(projectRoot)) {
      return poolState;
    }
    final key = provider.trim().toLowerCase();
    if (key.isEmpty) {
      return poolState;
    }

    // Increment failure count and only block after threshold is reached.
    var updated = _providerPoolStateService.incrementFailure(
      projectRoot,
      state: poolState,
      candidateKey: candidateKey,
    );
    final failures = _providerPoolStateService.failureCount(
      updated,
      candidateKey,
    );
    if (failures < threshold) {
      _appendProviderFailureIncrement(
        projectRoot,
        provider: key,
        attempt: attempt,
        failures: failures,
        threshold: threshold,
      );
      return updated;
    }

    final reason = _providerUnavailableReason(response);
    final blocked = _providerBlocklistService.blockProvider(
      projectRoot,
      provider: key,
      reason: reason,
      errorKind: 'agent_unavailable',
    );
    if (!blocked) {
      return updated;
    }
    _appendProviderBlocked(
      projectRoot,
      provider: key,
      reason: reason,
      attempt: attempt,
      errorKind: 'agent_unavailable',
    );
    return updated;
  }

  String _providerUnavailableReason(AgentResponse response) {
    final detail = response.stderr.trim().isNotEmpty
        ? response.stderr.trim()
        : response.stdout.trim();
    final collapsed = detail
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (collapsed.isEmpty) {
      return 'Agent provider unavailable (executable missing).';
    }
    const maxLength = 220;
    if (collapsed.length <= maxLength) {
      return collapsed;
    }
    return '${collapsed.substring(0, maxLength)}...';
  }

  String _quotaReason(AgentResponse response) {
    final detail = response.stderr.trim().isNotEmpty
        ? response.stderr.trim()
        : response.stdout.trim();
    final collapsed = detail
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (collapsed.isEmpty) {
      return 'Provider quota or rate limit reached';
    }
    const maxLength = 220;
    if (collapsed.length <= maxLength) {
      return collapsed;
    }
    return '${collapsed.substring(0, maxLength)}...';
  }

  DateTime? _earliestQuotaResume(
    ProviderPoolStateSnapshot state,
    List<SelectedAgentRunner> candidates,
  ) {
    DateTime? earliest;
    for (final candidate in candidates) {
      final quotaUntil = state.quotaUntilFor(candidate.poolKey);
      if (quotaUntil == null) {
        continue;
      }
      earliest = _minTime(earliest, quotaUntil);
    }
    return earliest;
  }

  DateTime? _minTime(DateTime? left, DateTime right) {
    if (left == null) {
      return right;
    }
    return right.isBefore(left) ? right : left;
  }

  QuotaPauseError _buildQuotaPauseError(
    String projectRoot, {
    required ProjectConfig config,
    required List<SelectedAgentRunner> candidates,
    DateTime? resumeAt,
  }) {
    final now = DateTime.now().toUtc();
    Duration pauseFor;
    if (resumeAt != null && resumeAt.isAfter(now)) {
      pauseFor = resumeAt.difference(now);
    } else {
      pauseFor = config.providerQuotaPause;
    }
    if (pauseFor.isNegative || pauseFor == Duration.zero) {
      pauseFor = const Duration(seconds: 1);
    }

    final keys = candidates
        .map((entry) => entry.poolKey)
        .toList(growable: false);
    _appendProviderPoolExhausted(
      projectRoot,
      pauseFor: pauseFor,
      resumeAt: resumeAt,
      candidates: keys,
    );

    final message = StringBuffer(
      'Provider pool exhausted by quota limits. Pausing for ${pauseFor.inSeconds}s.',
    );
    if (resumeAt != null) {
      message.write(
        ' Earliest resume at ${resumeAt.toUtc().toIso8601String()}.',
      );
    }
    return QuotaPauseError(
      message.toString(),
      pauseFor: pauseFor,
      resumeAt: resumeAt,
    );
  }

  void _blockProviderForUnattended(
    String projectRoot, {
    required String provider,
    required String reason,
    required String attempt,
    required String errorKind,
  }) {
    if (!_isUnattendedMode(projectRoot)) {
      return;
    }
    if (!_shouldBlockProvider(errorKind)) {
      return;
    }
    final key = provider.trim().toLowerCase();
    if (key.isEmpty) {
      return;
    }
    final blocked = _providerBlocklistService.blockProvider(
      projectRoot,
      provider: key,
      reason: reason,
      errorKind: errorKind,
    );
    if (!blocked) {
      return;
    }
    _appendProviderBlocked(
      projectRoot,
      provider: key,
      reason: reason,
      attempt: attempt,
      errorKind: errorKind,
    );
  }

  bool _shouldBlockProvider(String errorKind) {
    return errorKind == 'missing_event' || errorKind == 'invalid_event';
  }

  bool _isUnattendedMode(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    return File(layout.autopilotLockPath).existsSync();
  }

  Never _throwProviderExhausted(
    String projectRoot, {
    required Set<String> blockedProviders,
  }) {
    final blocked = blockedProviders.toList(growable: false)..sort();
    _appendProviderExhausted(projectRoot, blockedProviders: blocked);
    final suffix = blocked.isEmpty ? '' : ' Blocked: ${blocked.join(', ')}.';
    throw StateError(
      'Policy violation: unattended provider selection has no eligible provider.$suffix',
    );
  }
}
