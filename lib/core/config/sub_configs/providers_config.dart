// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all provider-related fields from [ProjectConfig].
class ProvidersConfig {
  const ProvidersConfig({
    required this.primary,
    required this.fallback,
    required this.pool,
    required this.native,
    required this.codexCliConfigOverrides,
    required this.claudeCodeCliConfigOverrides,
    required this.geminiCliConfigOverrides,
    required this.vibeCliConfigOverrides,
    required this.ampCliConfigOverrides,
    required this.reasoningEffortByCategory,
    required this.agentTimeoutByCategory,
    required this.quotaCooldown,
    required this.quotaPause,
    required this.agentTimeout,
    required this.agentProfiles,
  });

  factory ProvidersConfig.fromProjectConfig(ProjectConfig c) => ProvidersConfig(
    primary: c.providersPrimary,
    fallback: c.providersFallback,
    pool: c.providerPool,
    native: c.providersNative,
    codexCliConfigOverrides: c.codexCliConfigOverrides,
    claudeCodeCliConfigOverrides: c.claudeCodeCliConfigOverrides,
    geminiCliConfigOverrides: c.geminiCliConfigOverrides,
    vibeCliConfigOverrides: c.vibeCliConfigOverrides,
    ampCliConfigOverrides: c.ampCliConfigOverrides,
    reasoningEffortByCategory: c.reasoningEffortByCategory,
    agentTimeoutByCategory: c.agentTimeoutByCategory,
    quotaCooldown: c.providerQuotaCooldown,
    quotaPause: c.providerQuotaPause,
    agentTimeout: c.agentTimeout,
    agentProfiles: c.agentProfiles,
  );

  final String? primary;
  final String? fallback;
  final List<ProviderPoolEntry> pool;
  final NativeProviderConfig? native;
  final List<String> codexCliConfigOverrides;
  final List<String> claudeCodeCliConfigOverrides;
  final List<String> geminiCliConfigOverrides;
  final List<String> vibeCliConfigOverrides;
  final List<String> ampCliConfigOverrides;
  final Map<String, String> reasoningEffortByCategory;
  final Map<String, int> agentTimeoutByCategory;
  final Duration quotaCooldown;
  final Duration quotaPause;
  final Duration agentTimeout;
  final Map<String, AgentProfile> agentProfiles;
}
