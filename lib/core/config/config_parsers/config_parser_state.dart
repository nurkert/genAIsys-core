// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Mutable accumulator for non-registry config fields during parsing.
///
/// Registry-driven scalar fields (git, workflow, autopilot, pipeline, review,
/// reflection, supervisor, vision_evaluation, and most policies scalars) are
/// stored in [ConfigValuesMap] instead. This class only holds:
///   - Parser position/section tracking state
///   - Complex fields (lists, maps, nested objects) not in the registry
class ConfigParserState {
  // — Section tracking —
  String? currentSection;
  String? currentProvidersListKey;
  String? currentPoliciesSection;
  String? currentPoliciesListKey;
  String? currentAgentsSection;
  String? currentNativeSubsection;
  String? currentCategoryMapKey;

  // — Project —
  String? projectType;

  // — Providers (complex — not in registry) —
  String? primary;
  String? fallback;
  var providerPoolRaw = <String>[];
  String? nativeApiBase;
  String? nativeModel;
  String? nativeApiKey;
  double? nativeTemperature;
  int? nativeMaxTokens;
  int? nativeMaxTurns;
  var codexCliConfigOverrides = <String>[];
  var claudeCodeCliConfigOverrides = <String>[];
  var geminiCliConfigOverrides = <String>[];
  var vibeCliConfigOverrides = <String>[];
  var ampCliConfigOverrides = <String>[];

  // — Policies (list-based — not in registry) —
  var shellAllowlist = <String>[];
  var safeWriteRoots = <String>[];
  var qualityGateCommands = <String>[];

  // — Category maps —
  var reasoningEffortByCategory = <String, String>{};
  var agentTimeoutByCategory = <String, int>{};
  var contextInjectionMaxTokensByCategory = <String, int>{};

  // — Agents —
  final agentEnabled = <String, bool>{};
  final agentPromptPaths = <String, String>{};
}
