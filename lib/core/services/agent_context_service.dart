// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_config.dart';
import '../project_layout.dart';

class AgentContextService {
  AgentContextService({ProjectConfig? config}) : _config = config;

  final ProjectConfig? _config;

  String? loadSystemPrompt(String projectRoot, String agentKey) {
    final config = _config ?? ProjectConfig.load(projectRoot);
    final profile = config.agentProfile(agentKey);
    if (profile == null || !profile.enabled) {
      return null;
    }
    return _loadPromptFile(projectRoot, profile);
  }

  /// Load system prompt for coding, ignoring the [enabled] flag.
  ///
  /// Coding persona selection is driven by task category, not by
  /// the agent profile's enabled/disabled status (which controls
  /// whether the agent is used as a standalone audit/review role).
  String? loadCodingPersona(String projectRoot, String agentKey) {
    final config = _config ?? ProjectConfig.load(projectRoot);
    final profile = config.agentProfile(agentKey);
    if (profile == null) {
      return null;
    }
    return _loadPromptFile(projectRoot, profile);
  }

  String? _loadPromptFile(String projectRoot, AgentProfile profile) {
    final path = profile.systemPromptPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    final layout = ProjectLayout(projectRoot);
    final resolved = _resolvePath(layout, path);
    final file = File(resolved);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return null;
    }
    return content;
  }

  String _resolvePath(ProjectLayout layout, String path) {
    if (_isAbsolutePath(path)) {
      return path;
    }
    final normalized = _normalizeRelativePath(path);
    return _join(layout.genaisysDir, normalized);
  }

  bool _isAbsolutePath(String path) {
    if (path.startsWith('/')) {
      return true;
    }
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
  }

  String _normalizeRelativePath(String path) {
    if (path.contains('/') || path.contains('\\')) {
      return path;
    }
    return 'agent_contexts/$path';
  }

  String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
