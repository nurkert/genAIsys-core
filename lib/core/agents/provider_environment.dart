// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'agent_environment_requirements.dart';

List<String> requiredEnvironmentVariablesForProvider(String provider) {
  return AgentEnvironmentRequirements.flattenedForProvider(provider);
}
