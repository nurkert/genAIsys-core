// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Mutable context threaded across init orchestration pipeline stages.
///
/// This model intentionally uses mutable fields so each stage can write its
/// output into the same context instance.
class InitOrchestrationContext {
  InitOrchestrationContext({
    required this.projectRoot,
    required this.normalizedInputText,
    required this.inputSourcePayload,
    this.isReinit = false,
    this.overwrite = false,
    this.sprintSize = 8,
    this.existingVision,
    this.existingArchitecture,
    this.existingTasks,
    this.existingConfig,
    this.existingRules,
    this.vision,
    this.architecture,
    this.backlog,
    this.config,
    this.rules,
    this.verification,
    this.retryCount = 0,
  });

  final String projectRoot;
  final String normalizedInputText;
  final String inputSourcePayload;

  bool isReinit;
  bool overwrite;
  int sprintSize;

  String? existingVision;
  String? existingArchitecture;
  String? existingTasks;
  String? existingConfig;
  String? existingRules;

  String? vision;
  String? architecture;
  String? backlog;
  String? config;
  String? rules;
  String? verification;

  int retryCount;

  void incrementRetryCount() {
    retryCount += 1;
  }

  void resetRetryCount() {
    retryCount = 0;
  }
}
