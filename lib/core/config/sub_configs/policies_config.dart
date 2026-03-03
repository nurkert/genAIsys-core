// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all policy-related fields from [ProjectConfig]:
/// diff budget, quality gate, safe write, and shell allowlist.
class PoliciesConfig {
  const PoliciesConfig({
    required this.diffBudgetMaxFiles,
    required this.diffBudgetMaxAdditions,
    required this.diffBudgetMaxDeletions,
    required this.shellAllowlist,
    required this.shellAllowlistProfile,
    required this.safeWriteEnabled,
    required this.safeWriteRoots,
    required this.qualityGateEnabled,
    required this.qualityGateCommands,
    required this.qualityGateTimeout,
    required this.qualityGateAdaptiveByDiff,
    required this.qualityGateSkipTestsForDocsOnly,
    required this.qualityGatePreferDartTestForLibDartOnly,
    required this.qualityGateFlakeRetryCount,
  });

  factory PoliciesConfig.fromProjectConfig(ProjectConfig c) => PoliciesConfig(
    diffBudgetMaxFiles: c.diffBudgetMaxFiles,
    diffBudgetMaxAdditions: c.diffBudgetMaxAdditions,
    diffBudgetMaxDeletions: c.diffBudgetMaxDeletions,
    shellAllowlist: c.shellAllowlist,
    shellAllowlistProfile: c.shellAllowlistProfile,
    safeWriteEnabled: c.safeWriteEnabled,
    safeWriteRoots: c.safeWriteRoots,
    qualityGateEnabled: c.qualityGateEnabled,
    qualityGateCommands: c.qualityGateCommands,
    qualityGateTimeout: c.qualityGateTimeout,
    qualityGateAdaptiveByDiff: c.qualityGateAdaptiveByDiff,
    qualityGateSkipTestsForDocsOnly: c.qualityGateSkipTestsForDocsOnly,
    qualityGatePreferDartTestForLibDartOnly:
        c.qualityGatePreferDartTestForLibDartOnly,
    qualityGateFlakeRetryCount: c.qualityGateFlakeRetryCount,
  );

  final int diffBudgetMaxFiles;
  final int diffBudgetMaxAdditions;
  final int diffBudgetMaxDeletions;
  final List<String> shellAllowlist;
  final String shellAllowlistProfile;
  final bool safeWriteEnabled;
  final List<String> safeWriteRoots;
  final bool qualityGateEnabled;
  final List<String> qualityGateCommands;
  final Duration qualityGateTimeout;
  final bool qualityGateAdaptiveByDiff;
  final bool qualityGateSkipTestsForDocsOnly;
  final bool qualityGatePreferDartTestForLibDartOnly;
  final int qualityGateFlakeRetryCount;
}
