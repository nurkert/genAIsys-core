// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

import '../config/project_config.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../templates/default_files.dart';

class ConfigUpdate {
  const ConfigUpdate({
    this.gitBaseBranch,
    this.gitFeaturePrefix,
    this.gitAutoStash,
    this.gitAutoStashSkipRejected,
    this.gitAutoStashSkipRejectedUnattended,
    this.safeWriteEnabled,
    this.safeWriteRoots,
    this.shellAllowlist,
    this.shellAllowlistProfile,
    this.qualityGateEnabled,
    this.qualityGateCommands,
    this.qualityGateTimeoutSeconds,
    this.qualityGateAdaptiveByDiff,
    this.qualityGateSkipTestsForDocsOnly,
    this.qualityGatePreferDartTestForLibDartOnly,
    this.qualityGateFlakeRetryCount,
    this.diffBudgetMaxFiles,
    this.diffBudgetMaxAdditions,
    this.diffBudgetMaxDeletions,
    this.autopilotMinOpenTasks,
    this.autopilotMaxPlanAdd,
    this.autopilotStepSleepSeconds,
    this.autopilotIdleSleepSeconds,
    this.autopilotMaxSteps,
    this.autopilotMaxFailures,
    this.autopilotMaxTaskRetries,
    this.autopilotSelectionMode,
    this.autopilotFairnessWindow,
    this.autopilotPriorityWeightP1,
    this.autopilotPriorityWeightP2,
    this.autopilotPriorityWeightP3,
    this.autopilotReactivateBlocked,
    this.autopilotReactivateFailed,
    this.autopilotBlockedCooldownSeconds,
    this.autopilotFailedCooldownSeconds,
    this.autopilotLockTtlSeconds,
    this.autopilotNoProgressThreshold,
    this.autopilotStuckCooldownSeconds,
    this.autopilotSelfRestart,
    this.autopilotScopeMaxFiles,
    this.autopilotScopeMaxAdditions,
    this.autopilotScopeMaxDeletions,
    this.autopilotApproveBudget,
    this.autopilotManualOverride,
    this.autopilotOvernightUnattendedEnabled,
    this.autopilotSelfTuneEnabled,
    this.autopilotSelfTuneWindow,
    this.autopilotSelfTuneMinSamples,
    this.autopilotSelfTuneSuccessPercent,
    this.autopilotReleaseTagOnReady,
    this.autopilotReleaseTagPush,
    this.autopilotReleaseTagPrefix,
    this.reasoningEffortByCategory,
  });

  final String? gitBaseBranch;
  final String? gitFeaturePrefix;
  final bool? gitAutoStash;
  final bool? gitAutoStashSkipRejected;
  final bool? gitAutoStashSkipRejectedUnattended;
  final bool? safeWriteEnabled;
  final List<String>? safeWriteRoots;
  final List<String>? shellAllowlist;
  final String? shellAllowlistProfile;
  final bool? qualityGateEnabled;
  final List<String>? qualityGateCommands;
  final int? qualityGateTimeoutSeconds;
  final bool? qualityGateAdaptiveByDiff;
  final bool? qualityGateSkipTestsForDocsOnly;
  final bool? qualityGatePreferDartTestForLibDartOnly;
  final int? qualityGateFlakeRetryCount;
  final int? diffBudgetMaxFiles;
  final int? diffBudgetMaxAdditions;
  final int? diffBudgetMaxDeletions;
  final int? autopilotMinOpenTasks;
  final int? autopilotMaxPlanAdd;
  final int? autopilotStepSleepSeconds;
  final int? autopilotIdleSleepSeconds;
  final int? autopilotMaxSteps;
  final int? autopilotMaxFailures;
  final int? autopilotMaxTaskRetries;
  final String? autopilotSelectionMode;
  final int? autopilotFairnessWindow;
  final int? autopilotPriorityWeightP1;
  final int? autopilotPriorityWeightP2;
  final int? autopilotPriorityWeightP3;
  final bool? autopilotReactivateBlocked;
  final bool? autopilotReactivateFailed;
  final int? autopilotBlockedCooldownSeconds;
  final int? autopilotFailedCooldownSeconds;
  final int? autopilotLockTtlSeconds;
  final int? autopilotNoProgressThreshold;
  final int? autopilotStuckCooldownSeconds;
  final bool? autopilotSelfRestart;
  final int? autopilotScopeMaxFiles;
  final int? autopilotScopeMaxAdditions;
  final int? autopilotScopeMaxDeletions;
  final int? autopilotApproveBudget;
  final bool? autopilotManualOverride;
  final bool? autopilotOvernightUnattendedEnabled;
  final bool? autopilotSelfTuneEnabled;
  final int? autopilotSelfTuneWindow;
  final int? autopilotSelfTuneMinSamples;
  final int? autopilotSelfTuneSuccessPercent;
  final bool? autopilotReleaseTagOnReady;
  final bool? autopilotReleaseTagPush;
  final String? autopilotReleaseTagPrefix;
  final Map<String, String>? reasoningEffortByCategory;
}

class ConfigService {
  ProjectConfig load(String projectRoot) {
    return ProjectConfig.load(projectRoot);
  }

  ProjectConfig update(String projectRoot, {required ConfigUpdate update}) {
    final layout = ProjectLayout(projectRoot);
    final file = File(layout.configPath);
    if (!file.existsSync()) {
      Directory(layout.genaisysDir).createSync(recursive: true);
      file.writeAsStringSync(DefaultFiles.configYaml());
    }

    final current = ProjectConfig.loadFromFile(layout.configPath);
    final profileHint =
        update.shellAllowlistProfile ??
        (update.shellAllowlist != null
            ? 'custom'
            : current.shellAllowlistProfile);
    final resolvedProfile = ProjectConfig.normalizeShellAllowlistProfile(
      profileHint,
      fallback: current.shellAllowlistProfile,
    );
    final customAllowlist = _normalizeAllowlist(
      update.shellAllowlist ?? current.shellAllowlist,
    );
    final resolvedAllowlist = ProjectConfig.resolveShellAllowlist(
      profile: resolvedProfile,
      customAllowlist: customAllowlist,
    );
    final normalizedSafeWriteRoots = ProjectConfig.normalizeSafeWriteRoots(
      update.safeWriteRoots ?? current.safeWriteRoots,
    );
    final resolvedSafeWriteRoots = normalizedSafeWriteRoots.isEmpty
        ? ProjectConfig.defaultSafeWriteRoots
        : normalizedSafeWriteRoots;
    final normalizedQualityGateCommands =
        ProjectConfig.normalizeQualityGateCommands(
          update.qualityGateCommands ?? current.qualityGateCommands,
        );
    final resolvedQualityGateCommands = normalizedQualityGateCommands.isEmpty
        ? ProjectConfig.defaultQualityGateCommands
        : normalizedQualityGateCommands;

    final merged = ProjectConfig(
      providersPrimary: current.providersPrimary,
      providersFallback: current.providersFallback,
      providerPool: current.providerPool,
      providerQuotaCooldown: current.providerQuotaCooldown,
      providerQuotaPause: current.providerQuotaPause,
      diffBudgetMaxFiles:
          update.diffBudgetMaxFiles ?? current.diffBudgetMaxFiles,
      diffBudgetMaxAdditions:
          update.diffBudgetMaxAdditions ?? current.diffBudgetMaxAdditions,
      diffBudgetMaxDeletions:
          update.diffBudgetMaxDeletions ?? current.diffBudgetMaxDeletions,
      shellAllowlist: resolvedAllowlist,
      shellAllowlistProfile: resolvedProfile,
      safeWriteEnabled: update.safeWriteEnabled ?? current.safeWriteEnabled,
      safeWriteRoots: resolvedSafeWriteRoots,
      qualityGateEnabled:
          update.qualityGateEnabled ?? current.qualityGateEnabled,
      qualityGateCommands: resolvedQualityGateCommands,
      qualityGateTimeout: Duration(
        seconds:
            update.qualityGateTimeoutSeconds ??
            current.qualityGateTimeout.inSeconds,
      ),
      qualityGateAdaptiveByDiff:
          update.qualityGateAdaptiveByDiff ?? current.qualityGateAdaptiveByDiff,
      qualityGateSkipTestsForDocsOnly:
          update.qualityGateSkipTestsForDocsOnly ??
          current.qualityGateSkipTestsForDocsOnly,
      qualityGatePreferDartTestForLibDartOnly:
          update.qualityGatePreferDartTestForLibDartOnly ??
          current.qualityGatePreferDartTestForLibDartOnly,
      qualityGateFlakeRetryCount:
          update.qualityGateFlakeRetryCount ??
          current.qualityGateFlakeRetryCount,
      gitBaseBranch: update.gitBaseBranch ?? current.gitBaseBranch,
      gitFeaturePrefix: update.gitFeaturePrefix ?? current.gitFeaturePrefix,
      gitAutoStash: update.gitAutoStash ?? current.gitAutoStash,
      gitAutoStashSkipRejected:
          update.gitAutoStashSkipRejected ?? current.gitAutoStashSkipRejected,
      gitAutoStashSkipRejectedUnattended:
          update.gitAutoStashSkipRejectedUnattended ??
          current.gitAutoStashSkipRejectedUnattended,
      autopilotMinOpenTasks:
          update.autopilotMinOpenTasks ?? current.autopilotMinOpenTasks,
      autopilotMaxPlanAdd:
          update.autopilotMaxPlanAdd ?? current.autopilotMaxPlanAdd,
      autopilotStepSleep: Duration(
        seconds:
            update.autopilotStepSleepSeconds ??
            current.autopilotStepSleep.inSeconds,
      ),
      autopilotIdleSleep: Duration(
        seconds:
            update.autopilotIdleSleepSeconds ??
            current.autopilotIdleSleep.inSeconds,
      ),
      autopilotMaxSteps: update.autopilotMaxSteps ?? current.autopilotMaxSteps,
      autopilotMaxFailures:
          update.autopilotMaxFailures ?? current.autopilotMaxFailures,
      autopilotMaxTaskRetries:
          update.autopilotMaxTaskRetries ?? current.autopilotMaxTaskRetries,
      autopilotSelectionMode:
          update.autopilotSelectionMode ?? current.autopilotSelectionMode,
      autopilotFairnessWindow:
          update.autopilotFairnessWindow ?? current.autopilotFairnessWindow,
      autopilotPriorityWeightP1:
          update.autopilotPriorityWeightP1 ?? current.autopilotPriorityWeightP1,
      autopilotPriorityWeightP2:
          update.autopilotPriorityWeightP2 ?? current.autopilotPriorityWeightP2,
      autopilotPriorityWeightP3:
          update.autopilotPriorityWeightP3 ?? current.autopilotPriorityWeightP3,
      autopilotReactivateBlocked:
          update.autopilotReactivateBlocked ??
          current.autopilotReactivateBlocked,
      autopilotReactivateFailed:
          update.autopilotReactivateFailed ?? current.autopilotReactivateFailed,
      autopilotBlockedCooldown: Duration(
        seconds:
            update.autopilotBlockedCooldownSeconds ??
            current.autopilotBlockedCooldown.inSeconds,
      ),
      autopilotFailedCooldown: Duration(
        seconds:
            update.autopilotFailedCooldownSeconds ??
            current.autopilotFailedCooldown.inSeconds,
      ),
      autopilotLockTtl: Duration(
        seconds:
            update.autopilotLockTtlSeconds ??
            current.autopilotLockTtl.inSeconds,
      ),
      autopilotNoProgressThreshold:
          update.autopilotNoProgressThreshold ??
          current.autopilotNoProgressThreshold,
      autopilotStuckCooldown: Duration(
        seconds:
            update.autopilotStuckCooldownSeconds ??
            current.autopilotStuckCooldown.inSeconds,
      ),
      autopilotSelfRestart:
          update.autopilotSelfRestart ?? current.autopilotSelfRestart,
      autopilotScopeMaxFiles:
          update.autopilotScopeMaxFiles ?? current.autopilotScopeMaxFiles,
      autopilotScopeMaxAdditions:
          update.autopilotScopeMaxAdditions ??
          current.autopilotScopeMaxAdditions,
      autopilotScopeMaxDeletions:
          update.autopilotScopeMaxDeletions ??
          current.autopilotScopeMaxDeletions,
      autopilotApproveBudget:
          update.autopilotApproveBudget ?? current.autopilotApproveBudget,
      autopilotManualOverride:
          update.autopilotManualOverride ?? current.autopilotManualOverride,
      autopilotOvernightUnattendedEnabled:
          update.autopilotOvernightUnattendedEnabled ??
          current.autopilotOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled:
          update.autopilotSelfTuneEnabled ?? current.autopilotSelfTuneEnabled,
      autopilotSelfTuneWindow:
          update.autopilotSelfTuneWindow ?? current.autopilotSelfTuneWindow,
      autopilotSelfTuneMinSamples:
          update.autopilotSelfTuneMinSamples ??
          current.autopilotSelfTuneMinSamples,
      autopilotSelfTuneSuccessPercent:
          update.autopilotSelfTuneSuccessPercent ??
          current.autopilotSelfTuneSuccessPercent,
      autopilotReleaseTagOnReady:
          update.autopilotReleaseTagOnReady ??
          current.autopilotReleaseTagOnReady,
      autopilotReleaseTagPush:
          update.autopilotReleaseTagPush ?? current.autopilotReleaseTagPush,
      autopilotReleaseTagPrefix:
          update.autopilotReleaseTagPrefix ?? current.autopilotReleaseTagPrefix,
      reasoningEffortByCategory:
          update.reasoningEffortByCategory ?? current.reasoningEffortByCategory,
      agentProfiles: current.agentProfiles,
    );

    final raw = file.readAsStringSync();
    final editor = YamlEditor(raw);
    _applyConfig(editor, merged);
    var updated = editor.toString();
    updated = _patchShellAllowlist(updated, merged.shellAllowlist);
    updated = _patchGitSection(updated, merged);
    updated = _patchReasoningEffortByCategory(
      updated,
      merged.reasoningEffortByCategory,
    );
    file.writeAsStringSync(updated.endsWith('\n') ? updated : '$updated\n');

    RunLogStore(layout.runLogPath).append(
      event: 'config_updated',
      message: 'Updated config settings',
      data: {
        'root': projectRoot,
        'safe_write': merged.safeWriteEnabled,
        'shell_allowlist': merged.shellAllowlist.length,
        'autopilot_min_open': merged.autopilotMinOpenTasks,
      },
    );

    return merged;
  }

  void _applyConfig(YamlEditor editor, ProjectConfig config) {
    _upsert(editor, ['git', 'base_branch'], config.gitBaseBranch);
    _upsert(editor, ['git', 'feature_prefix'], config.gitFeaturePrefix);
    _upsert(editor, ['git', 'auto_stash'], config.gitAutoStash);
    _upsert(editor, [
      'git',
      'auto_stash_skip_rejected',
    ], config.gitAutoStashSkipRejected);
    _upsert(editor, [
      'git',
      'auto_stash_skip_rejected_unattended',
    ], config.gitAutoStashSkipRejectedUnattended);

    _upsert(editor, [
      'policies',
      'safe_write',
      'enabled',
    ], config.safeWriteEnabled);
    _upsert(editor, ['policies', 'safe_write', 'roots'], config.safeWriteRoots);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'enabled',
    ], config.qualityGateEnabled);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'timeout_seconds',
    ], config.qualityGateTimeout.inSeconds);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'commands',
    ], config.qualityGateCommands);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'adaptive_by_diff',
    ], config.qualityGateAdaptiveByDiff);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'skip_tests_for_docs_only',
    ], config.qualityGateSkipTestsForDocsOnly);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'prefer_dart_test_for_lib_dart_only',
    ], config.qualityGatePreferDartTestForLibDartOnly);
    _upsert(editor, [
      'policies',
      'quality_gate',
      'flake_retry_count',
    ], config.qualityGateFlakeRetryCount);
    _upsert(editor, [
      'policies',
      'shell_allowlist_profile',
    ], config.shellAllowlistProfile);

    _upsert(editor, [
      'policies',
      'diff_budget',
      'max_files',
    ], config.diffBudgetMaxFiles);
    _upsert(editor, [
      'policies',
      'diff_budget',
      'max_additions',
    ], config.diffBudgetMaxAdditions);
    _upsert(editor, [
      'policies',
      'diff_budget',
      'max_deletions',
    ], config.diffBudgetMaxDeletions);

    _upsert(editor, [
      'autopilot',
      'selection_mode',
    ], config.autopilotSelectionMode);
    _upsert(editor, [
      'autopilot',
      'fairness_window',
    ], config.autopilotFairnessWindow);
    _upsert(editor, [
      'autopilot',
      'priority_weight_p1',
    ], config.autopilotPriorityWeightP1);
    _upsert(editor, [
      'autopilot',
      'priority_weight_p2',
    ], config.autopilotPriorityWeightP2);
    _upsert(editor, [
      'autopilot',
      'priority_weight_p3',
    ], config.autopilotPriorityWeightP3);
    _upsert(editor, [
      'autopilot',
      'reactivate_blocked',
    ], config.autopilotReactivateBlocked);
    _upsert(editor, [
      'autopilot',
      'reactivate_failed',
    ], config.autopilotReactivateFailed);
    _upsert(editor, [
      'autopilot',
      'blocked_cooldown_seconds',
    ], config.autopilotBlockedCooldown.inSeconds);
    _upsert(editor, [
      'autopilot',
      'failed_cooldown_seconds',
    ], config.autopilotFailedCooldown.inSeconds);
    _upsert(editor, ['autopilot', 'min_open'], config.autopilotMinOpenTasks);
    _upsert(editor, ['autopilot', 'max_plan_add'], config.autopilotMaxPlanAdd);
    if (config.autopilotMaxSteps == null) {
      _removeIfExists(editor, ['autopilot', 'max_steps']);
    } else {
      _upsert(editor, ['autopilot', 'max_steps'], config.autopilotMaxSteps);
    }
    _upsert(editor, [
      'autopilot',
      'step_sleep_seconds',
    ], config.autopilotStepSleep.inSeconds);
    _upsert(editor, [
      'autopilot',
      'idle_sleep_seconds',
    ], config.autopilotIdleSleep.inSeconds);
    _upsert(editor, ['autopilot', 'max_failures'], config.autopilotMaxFailures);
    _upsert(editor, [
      'autopilot',
      'max_task_retries',
    ], config.autopilotMaxTaskRetries);
    _upsert(editor, [
      'autopilot',
      'lock_ttl_seconds',
    ], config.autopilotLockTtl.inSeconds);
    _upsert(editor, [
      'autopilot',
      'no_progress_threshold',
    ], config.autopilotNoProgressThreshold);
    _upsert(editor, [
      'autopilot',
      'stuck_cooldown_seconds',
    ], config.autopilotStuckCooldown.inSeconds);
    _upsert(editor, ['autopilot', 'self_restart'], config.autopilotSelfRestart);
    _upsert(editor, [
      'autopilot',
      'scope_max_files',
    ], config.autopilotScopeMaxFiles);
    _upsert(editor, [
      'autopilot',
      'scope_max_additions',
    ], config.autopilotScopeMaxAdditions);
    _upsert(editor, [
      'autopilot',
      'scope_max_deletions',
    ], config.autopilotScopeMaxDeletions);
    _upsert(editor, [
      'autopilot',
      'approve_budget',
    ], config.autopilotApproveBudget);
    _upsert(editor, [
      'autopilot',
      'manual_override',
    ], config.autopilotManualOverride);
    _upsert(editor, [
      'autopilot',
      'overnight_unattended_enabled',
    ], config.autopilotOvernightUnattendedEnabled);
    _upsert(editor, [
      'autopilot',
      'self_tune_enabled',
    ], config.autopilotSelfTuneEnabled);
    _upsert(editor, [
      'autopilot',
      'self_tune_window',
    ], config.autopilotSelfTuneWindow);
    _upsert(editor, [
      'autopilot',
      'self_tune_min_samples',
    ], config.autopilotSelfTuneMinSamples);
    _upsert(editor, [
      'autopilot',
      'self_tune_success_percent',
    ], config.autopilotSelfTuneSuccessPercent);
    _upsert(editor, [
      'autopilot',
      'release_tag_on_ready',
    ], config.autopilotReleaseTagOnReady);
    _upsert(editor, [
      'autopilot',
      'release_tag_push',
    ], config.autopilotReleaseTagPush);
    _upsert(editor, [
      'autopilot',
      'release_tag_prefix',
    ], config.autopilotReleaseTagPrefix);

    // Persist reasoning effort by category map entry-by-entry so the custom
    // line-based YAML parser can read them back (avoids flow-style `{...}`).
    _ensureMapPath(editor, ['providers', 'reasoning_effort_by_category']);
    for (final entry in config.reasoningEffortByCategory.entries) {
      _upsert(editor, [
        'providers',
        'reasoning_effort_by_category',
        entry.key,
      ], entry.value);
    }
  }

  void _upsert(YamlEditor editor, List<Object> path, Object? value) {
    if (path.isEmpty) {
      try {
        editor.update(path, value);
      } catch (_) {}
      return;
    }
    _ensureMapPath(editor, path.sublist(0, path.length - 1));
    try {
      editor.update(path, value);
    } catch (_) {
      // Ignore when the path is missing or invalid.
    }
  }

  void _removeIfExists(YamlEditor editor, List<Object> path) {
    try {
      editor.remove(path);
    } catch (_) {
      // ignore missing path
    }
  }

  void _ensureMapPath(YamlEditor editor, List<Object> path) {
    if (path.isEmpty) {
      return;
    }
    final current = <Object>[];
    for (final segment in path) {
      current.add(segment);
      final node = _tryParse(editor, current);
      if (node is YamlMap) {
        continue;
      }
      try {
        editor.update(current, <String, Object?>{});
      } catch (_) {
        // If we cannot create the map, stop trying to avoid cascading errors.
        break;
      }
    }
  }

  YamlNode? _tryParse(YamlEditor editor, List<Object> path) {
    try {
      return editor.parseAt(path);
    } catch (_) {
      return null;
    }
  }

  String _patchShellAllowlist(String yaml, List<String> allowlist) {
    final items = _normalizeAllowlist(
      allowlist,
    ).map(_formatAllowlistItem).toList(growable: false);
    final lines = yaml.split('\n');

    final allowIndex = _findKeyLine(lines, 'shell_allowlist');
    if (allowIndex == -1) {
      return _insertAllowlistBlock(lines, items).join('\n');
    }

    final keyIndent = _indentCount(lines[allowIndex]);
    final keyLine = lines[allowIndex];
    if (keyLine.trimRight().contains(': ') ||
        (keyLine.trim().endsWith(':') == false)) {
      lines[allowIndex] = '${' ' * keyIndent}shell_allowlist:';
    }

    final blockStart = allowIndex + 1;
    final blockEnd = _findBlockEnd(lines, blockStart, keyIndent);
    final listInfo = _findListInfo(lines, blockStart, blockEnd, keyIndent);
    final listIndent = listInfo.listIndent;
    final insertAt = listInfo.firstItemIndex ?? blockEnd;

    final result = <String>[];
    var skipping = false;
    var skipIndent = listIndent;
    for (var i = 0; i < lines.length; i++) {
      if (i == insertAt) {
        for (final item in items) {
          result.add('${' ' * listIndent}- $item');
        }
      }
      if (i < blockStart || i >= blockEnd) {
        result.add(lines[i]);
        continue;
      }
      final line = lines[i];
      final trimLeft = line.trimLeft();
      final indent = line.length - trimLeft.length;
      final isBlank = trimLeft.isEmpty;
      final isComment = trimLeft.startsWith('#');
      final isListItem = trimLeft.startsWith('-');

      if (skipping) {
        if (!isBlank && !isComment && indent > skipIndent) {
          continue;
        }
        if (indent > skipIndent) {
          continue;
        }
        skipping = false;
      }

      if (isListItem && indent >= listIndent) {
        skipping = true;
        skipIndent = indent;
        continue;
      }

      result.add(line);
    }

    if (insertAt == lines.length) {
      for (final item in items) {
        result.add('${' ' * listIndent}- $item');
      }
    }

    return result.join('\n');
  }

  String _patchGitSection(String yaml, ProjectConfig config) {
    final lines = yaml.split('\n');
    final gitIndex = _findKeyLine(lines, 'git');
    final keyIndent = gitIndex == -1 ? 0 : _indentCount(lines[gitIndex]);
    final blockLines = <String>[
      '${' ' * keyIndent}git:',
      '${' ' * (keyIndent + 2)}base_branch: ${_formatYamlScalar(config.gitBaseBranch)}',
      '${' ' * (keyIndent + 2)}feature_prefix: ${_formatYamlScalar(config.gitFeaturePrefix)}',
      '${' ' * (keyIndent + 2)}auto_stash: ${config.gitAutoStash}',
      '${' ' * (keyIndent + 2)}auto_stash_skip_rejected: ${config.gitAutoStashSkipRejected}',
      '${' ' * (keyIndent + 2)}auto_stash_skip_rejected_unattended: ${config.gitAutoStashSkipRejectedUnattended}',
    ];

    if (gitIndex == -1) {
      final insertAt = _findKeyLine(lines, 'policies');
      if (insertAt == -1) {
        lines.addAll(blockLines);
      } else {
        lines.insertAll(insertAt, blockLines);
      }
      return lines.join('\n');
    }

    final blockStart = gitIndex + 1;
    final blockEnd = _findBlockEnd(lines, blockStart, keyIndent);
    lines.removeRange(gitIndex, blockEnd);
    lines.insertAll(gitIndex, blockLines);
    return lines.join('\n');
  }

  int _findKeyLine(List<String> lines, String key) {
    final pattern = RegExp('^\\s*${RegExp.escape(key)}\\s*:');
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        return i;
      }
    }
    return -1;
  }

  List<String> _insertAllowlistBlock(List<String> lines, List<String> items) {
    final policyIndex = _findKeyLine(lines, 'policies');
    if (policyIndex == -1) {
      lines.add('policies:');
      return _insertAllowlistAfter(lines, lines.length - 1, 0, items);
    }
    final policyIndent = _indentCount(lines[policyIndex]);
    return _insertAllowlistAfter(lines, policyIndex, policyIndent, items);
  }

  List<String> _insertAllowlistAfter(
    List<String> lines,
    int index,
    int baseIndent,
    List<String> items,
  ) {
    final allowIndent = baseIndent + 2;
    final insertAt = index + 1;
    final block = <String>[
      '${' ' * allowIndent}shell_allowlist:',
      ...items.map((item) => '${' ' * (allowIndent + 2)}- $item'),
    ];
    lines.insertAll(insertAt, block);
    return lines;
  }

  _ListInfo _findListInfo(
    List<String> lines,
    int blockStart,
    int blockEnd,
    int keyIndent,
  ) {
    for (var i = blockStart; i < blockEnd; i++) {
      final line = lines[i];
      final trimLeft = line.trimLeft();
      if (trimLeft.startsWith('-')) {
        final indent = line.length - trimLeft.length;
        return _ListInfo(firstItemIndex: i, listIndent: indent);
      }
    }
    return _ListInfo(firstItemIndex: null, listIndent: keyIndent + 2);
  }

  int _findBlockEnd(List<String> lines, int start, int keyIndent) {
    for (var i = start; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final indent = line.length - trimmed.length;
      if (indent <= keyIndent) {
        return i;
      }
    }
    return lines.length;
  }

  int _indentCount(String line) {
    var count = 0;
    while (count < line.length && line.codeUnitAt(count) == 32) {
      count++;
    }
    return count;
  }

  String _formatAllowlistItem(String value) {
    return _formatYamlScalar(value);
  }

  String _formatYamlScalar(String value) {
    final trimmed = value.trim();
    final needsQuotes =
        trimmed.isEmpty ||
        trimmed != value ||
        RegExp(r'[:#"\n\r\\]').hasMatch(trimmed) ||
        RegExp(r"^[-?:,\[\]\{\}&*!|>%@`]").hasMatch(trimmed);
    if (!needsQuotes) {
      return trimmed;
    }
    return jsonEncode(trimmed);
  }

  List<String> _normalizeAllowlist(List<String> allowlist) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final entry in allowlist) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    for (final required in ProjectConfig.minimalShellAllowlist) {
      if (seen.add(required)) {
        normalized.add(required);
      }
    }
    return normalized;
  }

  /// Rewrites the `providers.reasoning_effort_by_category` section in
  /// block-style YAML. [YamlEditor] may produce flow-style (`{...}`) when
  /// the section is newly created, which the custom line-based parser cannot
  /// read back.
  String _patchReasoningEffortByCategory(
    String yaml,
    Map<String, String> effortMap,
  ) {
    final lines = yaml.split('\n');
    final providersIndex = _findKeyLine(lines, 'providers');
    if (providersIndex == -1) {
      // No providers section at all — append block-style.
      final block = <String>[
        'providers:',
        '  reasoning_effort_by_category:',
        ...effortMap.entries.map((e) => '    ${e.key}: ${e.value}'),
      ];
      lines.addAll(block);
      return lines.join('\n');
    }

    // Check if the providers line itself is flow-style (e.g.,
    // `providers: {reasoning_effort_by_category: {...}}`).
    final providersLine = lines[providersIndex].trim();
    if (providersLine.contains('{')) {
      // Replace the entire flow-style providers line with block-style.
      final provIndent = _indentCount(lines[providersIndex]);
      final childIndent = provIndent + 2;
      final entryIndent = childIndent + 2;
      final block = <String>[
        '${' ' * provIndent}providers:',
        '${' ' * childIndent}reasoning_effort_by_category:',
        ...effortMap.entries.map(
          (e) => '${' ' * entryIndent}${e.key}: ${e.value}',
        ),
      ];
      // Remove the flow-style providers line and any continuation lines.
      final blockEnd = _findBlockEnd(lines, providersIndex + 1, provIndent);
      lines.removeRange(providersIndex, blockEnd);
      lines.insertAll(providersIndex, block);
      return lines.join('\n');
    }

    // Block-style providers section — find and replace
    // reasoning_effort_by_category sub-section.
    final provIndent = _indentCount(lines[providersIndex]);
    final childIndent = provIndent + 2;
    final entryIndent = childIndent + 2;
    final recIndex = _findSubKeyLine(
      lines,
      providersIndex + 1,
      provIndent,
      'reasoning_effort_by_category',
    );
    if (recIndex == -1) {
      // Sub-key missing — insert after providers header.
      final block = <String>[
        '${' ' * childIndent}reasoning_effort_by_category:',
        ...effortMap.entries.map(
          (e) => '${' ' * entryIndent}${e.key}: ${e.value}',
        ),
      ];
      lines.insertAll(providersIndex + 1, block);
      return lines.join('\n');
    }

    // Replace existing sub-section.
    final recLine = lines[recIndex].trim();
    if (recLine.contains('{')) {
      // Flow-style sub-key — replace single line.
      final block = <String>[
        '${' ' * childIndent}reasoning_effort_by_category:',
        ...effortMap.entries.map(
          (e) => '${' ' * entryIndent}${e.key}: ${e.value}',
        ),
      ];
      lines.removeAt(recIndex);
      lines.insertAll(recIndex, block);
      return lines.join('\n');
    }

    // Block-style sub-section — replace entries.
    final subBlockEnd = _findBlockEnd(lines, recIndex + 1, childIndent);
    final block = <String>[
      '${' ' * childIndent}reasoning_effort_by_category:',
      ...effortMap.entries.map(
        (e) => '${' ' * entryIndent}${e.key}: ${e.value}',
      ),
    ];
    lines.removeRange(recIndex, subBlockEnd);
    lines.insertAll(recIndex, block);
    return lines.join('\n');
  }

  /// Finds a sub-key line within a parent section.
  int _findSubKeyLine(
    List<String> lines,
    int start,
    int parentIndent,
    String key,
  ) {
    final pattern = RegExp('^\\s*${RegExp.escape(key)}\\s*:');
    for (var i = start; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final indent = line.length - trimmed.length;
      if (indent <= parentIndent) {
        break; // Left the parent section.
      }
      if (pattern.hasMatch(line)) {
        return i;
      }
    }
    return -1;
  }
}

class _ListInfo {
  const _ListInfo({required this.firstItemIndex, required this.listIndent});

  final int? firstItemIndex;
  final int listIndent;
}
