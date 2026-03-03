// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class HealthCheck {
  HealthCheck({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class HealthSnapshot {
  HealthSnapshot({
    required this.agent,
    required this.allowlist,
    required this.git,
    required this.review,
  });

  final HealthCheck agent;
  final HealthCheck allowlist;
  final HealthCheck git;
  final HealthCheck review;

  bool get allOk => agent.ok && allowlist.ok && git.ok && review.ok;
}
