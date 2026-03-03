// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import '../../agents/agent_environment_requirements.dart';
import '../../agents/agent_registry.dart';
import '../../agents/codex_runner.dart';
import '../../agents/executable_resolver.dart';
import '../../agents/gemini_runner.dart';
import '../../config/project_config.dart';
import '../../models/health_snapshot.dart';
import '../../policy/shell_allowlist_policy.dart';
import '../../project_layout.dart';
import '../../storage/state_store.dart';
import '../../git/git_service.dart';

class ProviderCredentialCheck {
  const ProviderCredentialCheck({
    required this.ok,
    required this.provider,
    required this.message,
    this.errorKind,
  });

  final bool ok;
  final String provider;
  final String message;
  final String? errorKind;
}

class HealthCheckService {
  Map<String, String> _resolveEnvironment(Map<String, String>? environment) {
    if (environment != null) {
      return environment;
    }

    final zoneEnv = Zone.current[#genaisys_test_env];
    if (zoneEnv is Map) {
      final merged = <String, String>{...Platform.environment};
      for (final entry in zoneEnv.entries) {
        final key = entry.key;
        if (key is! String) {
          continue;
        }
        final value = entry.value;
        if (value == null) {
          continue;
        }
        merged[key] = value.toString();
      }
      return merged;
    }

    return Platform.environment;
  }

  HealthSnapshot check(String projectRoot, {Map<String, String>? environment}) {
    final config = ProjectConfig.load(projectRoot);
    final env = _resolveEnvironment(environment);
    final agent = _checkAgents(config, env);
    final allowlist = _checkAllowlist(config, env);
    final git = _checkGit(projectRoot, config);
    final review = _checkReview(projectRoot);

    return HealthSnapshot(
      agent: agent,
      allowlist: allowlist,
      git: git,
      review: review,
    );
  }

  HealthCheck _checkAgents(ProjectConfig config, Map<String, String> env) {
    final registry = AgentRegistry();
    final primaryKey = _normalizeProvider(config.providersPrimary) ?? 'codex';
    final fallbackKey = _normalizeProvider(config.providersFallback);

    final primaryRunner = registry.resolveOrDefault(primaryKey);
    final primaryOk = _runnerAvailable(primaryRunner, env);
    if (!primaryOk) {
      return HealthCheck(
        ok: false,
        message: 'Primary provider not available: $primaryKey',
      );
    }
    final missingPrimary = _missingProviderEnv(primaryKey, env);
    if (missingPrimary.isNotEmpty) {
      final credentials = _checkProviderCredentials(
        provider: primaryKey,
        env: env,
        roleLabel: 'Primary',
      );
      return HealthCheck(ok: false, message: credentials.message);
    }

    if (fallbackKey != null) {
      final missingFallback = _missingProviderEnv(fallbackKey, env);
      if (missingFallback.isNotEmpty) {
        return HealthCheck(
          ok: true,
          message:
              'Primary OK; missing required environment variables for fallback provider '
              '$fallbackKey: ${missingFallback.join(', ')}.',
        );
      }

      final fallbackRunner = registry.resolve(fallbackKey);
      if (fallbackRunner == null) {
        return HealthCheck(
          ok: true,
          message: 'Primary OK; unknown fallback provider: $fallbackKey',
        );
      }
      if (!_runnerAvailable(fallbackRunner, env)) {
        return HealthCheck(
          ok: true,
          message: 'Primary OK; fallback unavailable: $fallbackKey',
        );
      }
    }

    return HealthCheck(ok: true, message: 'Agent executables available.');
  }

  HealthCheck _checkAllowlist(ProjectConfig config, Map<String, String> env) {
    final required = ProjectConfig.minimalShellAllowlist;
    final missing = <String>[];
    final allowlist = config.shellAllowlist.toSet();
    for (final entry in required) {
      if (!allowlist.contains(entry)) {
        missing.add(entry);
      }
    }
    if (missing.isNotEmpty) {
      return HealthCheck(
        ok: false,
        message: 'Missing allowlist entries: ${missing.join(', ')}',
      );
    }
    final qualityGate = _validateQualityGate(config, env);
    if (qualityGate != null) {
      return qualityGate;
    }
    return HealthCheck(ok: true, message: 'Allowlist ok.');
  }

  HealthCheck? _validateQualityGate(
    ProjectConfig config,
    Map<String, String> env,
  ) {
    if (!config.qualityGateEnabled) {
      return null;
    }

    final commands = ProjectConfig.normalizeQualityGateCommands(
      config.qualityGateCommands,
    );
    if (commands.isEmpty) {
      return HealthCheck(
        ok: false,
        message:
            'Quality gate is enabled but has no commands configured '
            '(policies.quality_gate.commands).',
      );
    }

    final policy = ShellAllowlistPolicy(
      allowedPrefixes: config.shellAllowlist,
      enabled: true,
    );
    for (final command in commands) {
      final parsed = ShellCommandTokenizer.tryParse(command);
      if (parsed == null) {
        return HealthCheck(
          ok: false,
          message:
              'Quality gate command is invalid or contains shell operators: '
              '"$command".',
        );
      }
      if (!policy.allows(command)) {
        return HealthCheck(
          ok: false,
          message:
              'Quality gate command blocked by shell allowlist: "$command".',
        );
      }

      final executable = parsed.executable.trim();
      if (executable != 'dart' && executable != 'flutter') {
        continue;
      }
      if (!_executableAvailable(executable, env)) {
        return HealthCheck(
          ok: false,
          message: 'Quality gate executable not found on PATH: "$executable".',
        );
      }
    }

    return null;
  }

  HealthCheck _checkGit(String projectRoot, ProjectConfig config) {
    final git = GitService();
    if (!git.isGitRepo(projectRoot)) {
      return HealthCheck(ok: false, message: 'Not a git repository.');
    }
    if (git.hasMergeInProgress(projectRoot)) {
      return HealthCheck(ok: false, message: 'Merge in progress.');
    }
    try {
      final clean = git.isClean(projectRoot);
      if (!clean) {
        return HealthCheck(
          ok: false,
          message: 'Repository has uncommitted changes.',
        );
      }
    } catch (_) {
      return HealthCheck(ok: false, message: 'Git status unavailable.');
    }
    return HealthCheck(ok: true, message: 'Git ok.');
  }

  HealthCheck _checkReview(String projectRoot) {
    try {
      final layout = ProjectLayout(projectRoot);
      if (!File(layout.statePath).existsSync()) {
        return HealthCheck(ok: false, message: 'STATE.json missing.');
      }
      final state = StateStore(layout.statePath).read();
      final status = state.reviewStatus?.trim().toLowerCase();
      if (status == 'rejected') {
        return HealthCheck(ok: false, message: 'Review rejected.');
      }
      return HealthCheck(ok: true, message: 'Review ok.');
    } catch (_) {
      return HealthCheck(ok: false, message: 'Review status unavailable.');
    }
  }

  bool _runnerAvailable(Object runner, Map<String, String> env) {
    if (runner is CodexRunner) {
      return _executableAvailable(runner.executable, env);
    }
    if (runner is GeminiRunner) {
      return _executableAvailable(runner.executable, env);
    }
    return true;
  }

  bool _executableAvailable(String executable, Map<String, String> env) {
    final resolved = resolveExecutable(
      executable,
      environment: env,
      extraSearchPaths: defaultSearchPaths(),
    );
    return resolved != null;
  }

  String? _normalizeProvider(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.toLowerCase();
  }

  ProviderCredentialCheck checkPrimaryProviderCredentials(
    String projectRoot, {
    Map<String, String>? environment,
  }) {
    final config = ProjectConfig.load(projectRoot);
    final env = _resolveEnvironment(environment);
    final primaryKey = _normalizeProvider(config.providersPrimary) ?? 'codex';
    return _checkProviderCredentials(
      provider: primaryKey,
      env: env,
      roleLabel: 'Primary',
    );
  }

  List<String> _missingProviderEnv(String provider, Map<String, String> env) {
    final key = provider.trim().toLowerCase();
    if (key.isEmpty) {
      return const [];
    }
    final groups = AgentEnvironmentRequirements.byProvider[key];
    if (groups == null || groups.isEmpty) {
      return const [];
    }
    final missing = <String>[];
    for (final group in groups) {
      if (_groupSatisfied(group, env)) {
        continue;
      }
      final label = _formatGroup(group);
      if (label.isNotEmpty) {
        missing.add(label);
      }
    }
    return missing;
  }

  bool _groupSatisfied(List<String> group, Map<String, String> env) {
    for (final key in group) {
      final value = env[key];
      if (value != null && value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String _formatGroup(List<String> group) {
    if (group.isEmpty) {
      return '';
    }
    if (group.length == 1) {
      return group.first;
    }
    return group.join(' or ');
  }

  ProviderCredentialCheck _checkProviderCredentials({
    required String provider,
    required Map<String, String> env,
    required String roleLabel,
  }) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const ProviderCredentialCheck(
        ok: false,
        provider: '',
        message: 'Provider is empty.',
        errorKind: 'provider_credentials_missing',
      );
    }

    final missing = _missingProviderEnv(normalized, env);
    if (missing.isEmpty) {
      return ProviderCredentialCheck(
        ok: true,
        provider: normalized,
        message: '$roleLabel provider credentials available for $normalized.',
      );
    }

    return ProviderCredentialCheck(
      ok: false,
      provider: normalized,
      message:
          'Missing required environment variables for $normalized: '
          '${missing.join(', ')}.',
      errorKind: 'provider_credentials_missing',
    );
  }
}
