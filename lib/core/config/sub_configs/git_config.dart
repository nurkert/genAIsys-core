// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_config.dart';

/// A grouped view of all git-related fields from [ProjectConfig].
class GitConfig {
  const GitConfig({
    required this.baseBranch,
    required this.featurePrefix,
    required this.autoDeleteRemoteMergedBranches,
    required this.autoStash,
    required this.autoStashSkipRejected,
    required this.autoStashSkipRejectedUnattended,
    required this.syncBetweenLoops,
    required this.syncStrategy,
  });

  factory GitConfig.fromProjectConfig(ProjectConfig c) => GitConfig(
    baseBranch: c.gitBaseBranch,
    featurePrefix: c.gitFeaturePrefix,
    autoDeleteRemoteMergedBranches: c.gitAutoDeleteRemoteMergedBranches,
    autoStash: c.gitAutoStash,
    autoStashSkipRejected: c.gitAutoStashSkipRejected,
    autoStashSkipRejectedUnattended: c.gitAutoStashSkipRejectedUnattended,
    syncBetweenLoops: c.gitSyncBetweenLoops,
    syncStrategy: c.gitSyncStrategy,
  );

  final String baseBranch;
  final String featurePrefix;
  final bool autoDeleteRemoteMergedBranches;
  final bool autoStash;
  final bool autoStashSkipRejected;
  final bool autoStashSkipRejectedUnattended;
  final bool syncBetweenLoops;
  final String syncStrategy;
}
