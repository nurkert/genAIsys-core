// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'project_config.dart';

class ProviderPoolEntry {
  const ProviderPoolEntry({
    required this.provider,
    this.account = defaultAccount,
    this.environment = const {},
    this.quotaCooldown,
  });

  static const String defaultAccount = 'default';

  final String provider;
  final String account;
  final Map<String, String> environment;
  final Duration? quotaCooldown;

  String get key => '$provider@$account';
}

class AgentProfile {
  const AgentProfile({required this.enabled, this.systemPromptPath});

  final bool enabled;
  final String? systemPromptPath;
}

class NativeProviderConfig {
  const NativeProviderConfig({
    required this.apiBase,
    required this.model,
    this.apiKey = '',
    this.temperature = defaultTemperature,
    this.maxTokens = defaultMaxTokens,
    this.maxTurns = defaultMaxTurns,
  });

  final String apiBase;
  final String model;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final int maxTurns;

  static const String defaultApiBase = 'http://localhost:11434/v1';
  static const double defaultTemperature = 0.1;
  static const int defaultMaxTokens = 16384;
  static const int defaultMaxTurns = 20;
}
