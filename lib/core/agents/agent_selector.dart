// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../config/project_config.dart';
import 'agent_registry.dart';
import 'agent_runner.dart';
import 'native_agent_loop_runner.dart';
import 'native_http_runner.dart';

class PoolSelectionResult {
  const PoolSelectionResult({
    required this.selections,
    this.unresolvedProviders = const [],
  });

  final List<SelectedAgentRunner> selections;
  final List<String> unresolvedProviders;
}

class SelectedAgentRunner {
  const SelectedAgentRunner({
    required this.provider,
    required this.runner,
    this.account = ProviderPoolEntry.defaultAccount,
    this.environment = const {},
    this.quotaCooldown,
  });

  final String provider;
  final AgentRunner runner;
  final String account;
  final Map<String, String> environment;
  final Duration? quotaCooldown;

  String get poolKey =>
      '${provider.trim().toLowerCase()}@${account.trim().toLowerCase()}';
}

class AgentSelector {
  AgentSelector({AgentRegistry? registry})
    : _registry = registry ?? AgentRegistry();

  final AgentRegistry _registry;

  PoolSelectionResult selectPoolSelections(String projectRoot) {
    final config = ProjectConfig.load(projectRoot);
    final poolEntries = config.providerPool;
    if (poolEntries.isNotEmpty) {
      final output = <SelectedAgentRunner>[];
      final unresolved = <String>[];
      for (final entry in poolEntries) {
        var runner = _registry.resolve(entry.provider);
        if (runner == null && entry.provider.trim().toLowerCase() == 'native') {
          runner = _resolveNativeRunner(config);
        }
        if (runner == null) {
          unresolved.add(entry.provider);
          continue;
        }
        output.add(
          SelectedAgentRunner(
            provider: entry.provider,
            runner: runner,
            account: entry.account,
            environment: entry.environment,
            quotaCooldown: entry.quotaCooldown,
          ),
        );
      }
      if (output.isNotEmpty) {
        return PoolSelectionResult(
          selections: List<SelectedAgentRunner>.unmodifiable(output),
          unresolvedProviders: List<String>.unmodifiable(unresolved),
        );
      }
    }

    final primary = selectPrimarySelection(projectRoot);
    final fallback = selectFallbackSelection(projectRoot);
    if (fallback == null) {
      return PoolSelectionResult(
        selections: List<SelectedAgentRunner>.unmodifiable([primary]),
      );
    }
    return PoolSelectionResult(
      selections: List<SelectedAgentRunner>.unmodifiable([primary, fallback]),
    );
  }

  SelectedAgentRunner selectPrimarySelection(String projectRoot) {
    final config = ProjectConfig.load(projectRoot);
    final configured = _normalizeProvider(config.providersPrimary);
    if (configured != null) {
      var runner = _registry.resolve(configured);
      if (runner == null && configured == 'native') {
        runner = _resolveNativeRunner(config);
      }
      if (runner != null) {
        return SelectedAgentRunner(provider: configured, runner: runner);
      }
    }
    final fallbackRunner = _registry.resolveOrDefault(configured);
    return SelectedAgentRunner(
      provider: _providerKeyForRunner(fallbackRunner),
      runner: fallbackRunner,
    );
  }

  SelectedAgentRunner? selectFallbackSelection(String projectRoot) {
    final config = ProjectConfig.load(projectRoot);
    final fallback = _normalizeProvider(config.providersFallback);
    if (fallback == null) {
      return null;
    }
    var runner = _registry.resolve(fallback);
    if (runner == null && fallback == 'native') {
      runner = _resolveNativeRunner(config);
    }
    if (runner == null) {
      return null;
    }
    return SelectedAgentRunner(provider: fallback, runner: runner);
  }

  AgentRunner selectPrimary(String projectRoot) {
    return selectPrimarySelection(projectRoot).runner;
  }

  AgentRunner? selectFallback(String projectRoot) {
    return selectFallbackSelection(projectRoot)?.runner;
  }

  AgentRunner? _resolveNativeRunner(ProjectConfig config) {
    final native_ = config.providersNative;
    if (native_ == null || native_.model.trim().isEmpty) return null;
    final httpRunner = NativeHttpRunner(
      apiBase: native_.apiBase,
      model: native_.model,
      apiKey: native_.apiKey,
      temperature: native_.temperature,
      maxTokens: native_.maxTokens,
    );
    return NativeAgentLoopRunner(
      httpRunner: httpRunner,
      maxTurns: native_.maxTurns,
      safeWriteEnabled: config.safeWriteEnabled,
      safeWriteRoots: config.safeWriteRoots,
      shellAllowlist: config.shellAllowlist,
    );
  }

  String _providerKeyForRunner(AgentRunner runner) {
    final codex = _registry.resolve('codex');
    if (codex != null && identical(runner, codex)) {
      return 'codex';
    }
    final gemini = _registry.resolve('gemini');
    if (gemini != null && identical(runner, gemini)) {
      return 'gemini';
    }
    return runner.runtimeType.toString();
  }

  String? _normalizeProvider(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
