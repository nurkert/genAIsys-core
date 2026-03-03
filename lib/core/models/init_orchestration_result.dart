// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Result DTO returned by [InitOrchestratorService] after a completed run.
class InitOrchestrationResult {
  InitOrchestrationResult({
    required this.projectRoot,
    required this.writtenPaths,
    required this.retryCount,
    required this.isReinit,
  });

  final String projectRoot;

  /// Absolute paths of files written during this orchestration run.
  final List<String> writtenPaths;

  /// Number of full pipeline retries performed (0 = succeeded on first pass).
  final int retryCount;

  final bool isReinit;
}
