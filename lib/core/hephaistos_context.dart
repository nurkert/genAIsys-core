// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'git/git_service.dart';

class GenaisysContext {
  GenaisysContext({required this.projectRoot, GitService? gitService})
    : gitService = gitService ?? GitService();

  final String projectRoot;
  final GitService gitService;
}
