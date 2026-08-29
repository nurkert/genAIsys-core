import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/config/project_config.dart';

AppConfigDto _baseConfig({
  String? gitBaseBranch,
  String? gitFeaturePrefix,
  bool? gitAutoStash,
  List<String>? safeWriteRoots,
  List<String>? shellAllowlist,
  String? shellAllowlistProfile,
  String? selectionMode,
  int? diffBudgetMaxFiles,
  bool? autopilotOvernightUnattendedEnabled,
}) {
  final defaults = ProjectConfig.empty();
  return AppConfigDto(
    gitBaseBranch: gitBaseBranch ?? defaults.gitBaseBranch,
    gitFeaturePrefix: gitFeaturePrefix ?? defaults.gitFeaturePrefix,
    gitAutoStash: gitAutoStash ?? defaults.gitAutoStash,
    safeWriteEnabled: defaults.safeWriteEnabled,
    safeWriteRoots: safeWriteRoots ?? defaults.safeWriteRoots,
    shellAllowlist: shellAllowlist ?? defaults.shellAllowlist,
    shellAllowlistProfile:
        shellAllowlistProfile ?? defaults.shellAllowlistProfile,
    diffBudgetMaxFiles: diffBudgetMaxFiles ?? defaults.diffBudgetMaxFiles,
    diffBudgetMaxAdditions: defaults.diffBudgetMaxAdditions,
    diffBudgetMaxDeletions: defaults.diffBudgetMaxDeletions,
    autopilotMinOpenTasks: defaults.autopilotMinOpenTasks,
    autopilotMaxPlanAdd: defaults.autopilotMaxPlanAdd,
    autopilotStepSleepSeconds: defaults.autopilotStepSleep.inSeconds,
    autopilotIdleSleepSeconds: defaults.autopilotIdleSleep.inSeconds,
    autopilotMaxSteps: defaults.autopilotMaxSteps,
    autopilotMaxFailures: defaults.autopilotMaxFailures,
    autopilotMaxTaskRetries: defaults.autopilotMaxTaskRetries,
    autopilotSelectionMode: selectionMode ?? defaults.autopilotSelectionMode,
    autopilotFairnessWindow: defaults.autopilotFairnessWindow,
    autopilotPriorityWeightP1: defaults.autopilotPriorityWeightP1,
    autopilotPriorityWeightP2: defaults.autopilotPriorityWeightP2,
    autopilotPriorityWeightP3: defaults.autopilotPriorityWeightP3,
    autopilotReactivateBlocked: defaults.autopilotReactivateBlocked,
    autopilotReactivateFailed: defaults.autopilotReactivateFailed,
    autopilotBlockedCooldownSeconds:
        defaults.autopilotBlockedCooldown.inSeconds,
    autopilotFailedCooldownSeconds: defaults.autopilotFailedCooldown.inSeconds,
    autopilotLockTtlSeconds: defaults.autopilotLockTtl.inSeconds,
    autopilotNoProgressThreshold: defaults.autopilotNoProgressThreshold,
    autopilotStuckCooldownSeconds: defaults.autopilotStuckCooldown.inSeconds,
    autopilotSelfRestart: defaults.autopilotSelfRestart,
    autopilotScopeMaxFiles: defaults.autopilotScopeMaxFiles,
    autopilotScopeMaxAdditions: defaults.autopilotScopeMaxAdditions,
    autopilotScopeMaxDeletions: defaults.autopilotScopeMaxDeletions,
    autopilotApproveBudget: defaults.autopilotApproveBudget,
    autopilotManualOverride: defaults.autopilotManualOverride,
    autopilotOvernightUnattendedEnabled:
        autopilotOvernightUnattendedEnabled ??
        defaults.autopilotOvernightUnattendedEnabled,
    autopilotSelfTuneEnabled: defaults.autopilotSelfTuneEnabled,
    autopilotSelfTuneWindow: defaults.autopilotSelfTuneWindow,
    autopilotSelfTuneMinSamples: defaults.autopilotSelfTuneMinSamples,
    autopilotSelfTuneSuccessPercent: defaults.autopilotSelfTuneSuccessPercent,
  );
}

void main() {
  test('updateConfig normalizes allowlist and selection mode', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_cfg_api_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final api = InProcessGenaisysApi();
    final config = _baseConfig(
      gitBaseBranch: ' main ',
      gitFeaturePrefix: ' feat/ ',
      shellAllowlist: const [' flutter test ', 'flutter test', 'dart format'],
      shellAllowlistProfile: 'custom',
      selectionMode: 'Fairness',
    );

    final result = await api.updateConfig(temp.path, config: config);

    expect(result.ok, isTrue);
    expect(result.data, isNotNull);
    final updated = result.data!.config;
    expect(updated.gitBaseBranch, 'main');
    expect(updated.gitFeaturePrefix, 'feat/');
    expect(updated.autopilotSelectionMode, 'fair');
    expect(updated.autopilotOvernightUnattendedEnabled, isFalse);
    expect(updated.shellAllowlist, [
      'flutter test',
      'dart format',
      'rg',
      'ls',
      'cat',
      'codex',
      'gemini',
      'claude',
      'vibe',
      'amp',
      'native',
      'git status',
      'git diff',
    ]);
  });

  test(
    'updateConfig invalid input returns AppErrorKind.invalidInput',
    () async {
      final temp = Directory.systemTemp.createTempSync('genaisys_cfg_bad_');
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final api = InProcessGenaisysApi();
      final config = _baseConfig(gitBaseBranch: '');

      final result = await api.updateConfig(temp.path, config: config);

      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.kind, AppErrorKind.invalidInput);
      expect(result.error!.code, 'invalid_input');
    },
  );

  test('updateConfig persists overnight unattended release flag', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cfg_unattended_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final api = InProcessGenaisysApi();
    final config = _baseConfig(autopilotOvernightUnattendedEnabled: true);

    final result = await api.updateConfig(temp.path, config: config);

    expect(result.ok, isTrue);
    expect(result.data!.config.autopilotOvernightUnattendedEnabled, isTrue);
  });
}
