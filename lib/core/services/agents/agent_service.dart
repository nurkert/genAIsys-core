// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_error_hints.dart';
import '../../agents/agent_runner.dart';
import '../../agents/agent_selector.dart';
import '../../agents/amp_runner.dart';
import '../../agents/claude_code_runner.dart';
import '../../agents/codex_runner.dart';
import '../../agents/executable_resolver.dart';
import '../../agents/gemini_runner.dart';
import '../../agents/vibe_runner.dart';
import '../../config/project_config.dart';
import '../../errors/operation_errors.dart';
import '../../policy/shell_allowlist_policy.dart';
import '../../project_layout.dart';
import '../../storage/run_log_store.dart';
import '../agent_command_audit_service.dart';
import '../provider_pool_state_service.dart';
import '../autopilot/unattended_provider_blocklist_service.dart';

part 'agent_service_environment.dart';
part 'agent_service_provider_selection.dart';
part 'agent_service_run_log.dart';

class AgentServiceResult {
  const AgentServiceResult({
    required this.response,
    required this.usedFallback,
  });

  final AgentResponse response;
  final bool usedFallback;
}

class AgentService {
  AgentService({
    AgentSelector? selector,
    AgentCommandAuditService? commandAuditService,
    UnattendedProviderBlocklistService? providerBlocklistService,
    ProviderPoolStateService? providerPoolStateService,
    Duration commandHeartbeatInterval = const Duration(seconds: 30),
    int commandHeartbeatMaxCount = 10,
  }) : _selector = selector ?? AgentSelector(),
       _commandAuditService = commandAuditService ?? AgentCommandAuditService(),
       _providerBlocklistService =
           providerBlocklistService ?? UnattendedProviderBlocklistService(),
       _providerPoolStateService =
           providerPoolStateService ?? ProviderPoolStateService(),
       _commandHeartbeatInterval = commandHeartbeatInterval,
       _commandHeartbeatMaxCount = commandHeartbeatMaxCount < 0
           ? 0
           : commandHeartbeatMaxCount;

  final AgentSelector _selector;
  final AgentCommandAuditService _commandAuditService;
  final UnattendedProviderBlocklistService _providerBlocklistService;
  final ProviderPoolStateService _providerPoolStateService;
  final Duration _commandHeartbeatInterval;
  final int _commandHeartbeatMaxCount;

  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    final config = ProjectConfig.load(projectRoot);
    final unattendedMode = _isUnattendedMode(projectRoot);
    final normalizedRequest = _normalizeEnvironment(
      request,
      timeout: request.timeout ?? config.agentTimeout,
      unattendedMode: unattendedMode,
    );
    final poolResult = _selector.selectPoolSelections(projectRoot);
    final pool = poolResult.selections;
    for (final provider in poolResult.unresolvedProviders) {
      _appendProviderPoolEntryUnresolved(projectRoot, provider: provider);
    }
    var blockedProviders = unattendedMode
        ? _providerBlocklistService.blockedProviders(projectRoot)
        : const <String>{};
    if (unattendedMode && blockedProviders.isNotEmpty) {
      final recovered = _recoverBlockedProviders(
        projectRoot,
        pool: pool,
        request: normalizedRequest,
        blockedProviders: blockedProviders,
      );
      if (recovered.isNotEmpty) {
        blockedProviders = _providerBlocklistService.blockedProviders(
          projectRoot,
        );
      }
    }
    final candidates = _resolvePoolCandidates(
      projectRoot,
      pool: pool,
      unattendedMode: unattendedMode,
      blockedProviders: blockedProviders,
    );
    if (candidates.isEmpty) {
      throw StateError('No eligible provider configured.');
    }

    final candidateKeys = candidates
        .map((candidate) => candidate.poolKey)
        .toList(growable: false);
    var poolState = _providerPoolStateService.load(
      projectRoot,
      candidateKeys: candidateKeys,
    );

    final now = DateTime.now().toUtc();
    final orderedIndexes = _orderedIndexes(candidates.length, poolState.cursor);
    final availableAttempts = <_CandidateAttempt>[];
    DateTime? nextQuotaResumeAt;
    for (final index in orderedIndexes) {
      final candidate = candidates[index];
      final quotaUntil = poolState.quotaUntilFor(candidate.poolKey);
      if (quotaUntil != null && quotaUntil.isAfter(now)) {
        nextQuotaResumeAt = _minTime(nextQuotaResumeAt, quotaUntil);
        _appendProviderQuotaSkip(
          projectRoot,
          provider: candidate.provider,
          account: candidate.account,
          quotaUntil: quotaUntil,
        );
        continue;
      }
      availableAttempts.add(
        _CandidateAttempt(index: index, candidate: candidate),
      );
    }

    if (availableAttempts.isEmpty) {
      throw _buildQuotaPauseError(
        projectRoot,
        config: config,
        candidates: candidates,
        resumeAt: nextQuotaResumeAt,
      );
    }

    AgentResponse? lastFailure;
    var lastUsedFallback = false;

    for (var attempt = 0; attempt < availableAttempts.length; attempt += 1) {
      final current = availableAttempts[attempt];
      final candidate = current.candidate;
      final usedFallback = attempt > 0;
      final runAttempt = usedFallback ? 'fallback' : 'primary';
      final candidateRequest = _applyCandidateEnvironment(
        normalizedRequest,
        candidate,
      );

      final preflight = _preflight(
        candidate.runner,
        environment: candidateRequest.environment,
        request: candidateRequest,
      );
      if (preflight != null) {
        _recordCommandAudit(
          projectRoot,
          config: config,
          provider: candidate.provider,
          request: candidateRequest,
          response: preflight,
          attempt: runAttempt,
          usedFallback: usedFallback,
        );

        if (_isQuotaFailure(preflight)) {
          poolState = _recordQuotaFailure(
            projectRoot,
            config: config,
            state: poolState,
            candidate: candidate,
            response: preflight,
          );
          continue;
        }
        if (_isProviderUnavailable(preflight)) {
          poolState = _blockUnavailableProviderForUnattended(
            projectRoot,
            provider: candidate.provider,
            attempt: runAttempt,
            response: preflight,
            poolState: poolState,
            candidateKey: candidate.poolKey,
            providerFailureThreshold:
                config.autopilotProviderFailureThreshold,
          );
          lastFailure = preflight;
          lastUsedFallback = usedFallback;
          continue;
        }

        lastFailure = preflight;
        lastUsedFallback = usedFallback;
        continue;
      }

      _appendAgentCommandStart(
        projectRoot,
        provider: candidate.provider,
        account: candidate.account,
        attempt: runAttempt,
        runner: candidate.runner.runtimeType.toString(),
        timeoutSeconds: candidateRequest.timeout?.inSeconds,
        workingDirectory: candidateRequest.workingDirectory ?? projectRoot,
      );

      Timer? heartbeatTimer;
      var heartbeatCount = 0;
      if (_commandHeartbeatInterval.inMilliseconds > 0 &&
          _commandHeartbeatMaxCount > 0) {
        heartbeatTimer = Timer.periodic(_commandHeartbeatInterval, (_) {
          heartbeatCount += 1;
          if (heartbeatCount > _commandHeartbeatMaxCount) {
            heartbeatTimer?.cancel();
            return;
          }
          _appendAgentCommandHeartbeat(
            projectRoot,
            provider: candidate.provider,
            account: candidate.account,
            attempt: runAttempt,
            runner: candidate.runner.runtimeType.toString(),
            count: heartbeatCount,
          );
        });
      }

      AgentResponse response;
      try {
        response = await candidate.runner.run(candidateRequest);
      } finally {
        heartbeatTimer?.cancel();
      }
      _recordCommandAudit(
        projectRoot,
        config: config,
        provider: candidate.provider,
        request: candidateRequest,
        response: response,
        attempt: runAttempt,
        usedFallback: usedFallback,
      );

      if (response.ok) {
        poolState = _providerPoolStateService.clearQuota(
          projectRoot,
          state: poolState,
          candidateKey: candidate.poolKey,
        );
        poolState = _providerPoolStateService.clearFailures(
          projectRoot,
          state: poolState,
          candidateKey: candidate.poolKey,
        );
        poolState = _providerPoolStateService.setCursor(
          projectRoot,
          state: poolState,
          cursor: current.index + 1,
          candidateCount: candidates.length,
        );
        if (usedFallback) {
          _appendProviderRotated(
            projectRoot,
            fromProvider: availableAttempts.first.candidate.provider,
            fromAccount: availableAttempts.first.candidate.account,
            toProvider: candidate.provider,
            toAccount: candidate.account,
          );
        }
        return AgentServiceResult(
          response: response,
          usedFallback: usedFallback,
        );
      }

      if (_isQuotaFailure(response)) {
        poolState = _recordQuotaFailure(
          projectRoot,
          config: config,
          state: poolState,
          candidate: candidate,
          response: response,
        );
        continue;
      }
      if (_isProviderUnavailable(response)) {
        poolState = _blockUnavailableProviderForUnattended(
          projectRoot,
          provider: candidate.provider,
          attempt: runAttempt,
          response: response,
          poolState: poolState,
          candidateKey: candidate.poolKey,
          providerFailureThreshold:
              config.autopilotProviderFailureThreshold,
        );
      }

      lastFailure = response;
      lastUsedFallback = usedFallback;
    }

    if (lastFailure != null) {
      return AgentServiceResult(
        response: lastFailure,
        usedFallback: lastUsedFallback,
      );
    }

    final resumeAt = _earliestQuotaResume(poolState, candidates);
    throw _buildQuotaPauseError(
      projectRoot,
      config: config,
      candidates: candidates,
      resumeAt: resumeAt,
    );
  }
}

class _CandidateAttempt {
  const _CandidateAttempt({required this.index, required this.candidate});

  final int index;
  final SelectedAgentRunner candidate;
}
