import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/templates/default_files.dart';

void main() {
  test('ProjectConfig loads providers from config.yml', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync(DefaultFiles.configYaml());

    final config = ProjectConfig.load(temp.path);

    expect(config.providersPrimary, 'codex');
    expect(config.providersFallback, 'gemini');
    expect(config.providerPool.map((entry) => entry.key), [
      'codex@default',
      'gemini@default',
      'claude-code@default',
    ]);
    expect(config.codexCliConfigOverrides, isEmpty);
    expect(config.claudeCodeCliConfigOverrides, isEmpty);
    expect(
      config.providerQuotaCooldown,
      const Duration(
        seconds: ProjectConfig.defaultProviderQuotaCooldownSeconds,
      ),
    );
    expect(
      config.providerQuotaPause,
      const Duration(seconds: ProjectConfig.defaultProviderQuotaPauseSeconds),
    );
    expect(config.gitBaseBranch, 'main');
    expect(config.gitFeaturePrefix, 'feat/');
    expect(config.gitAutoStash, isFalse);
    expect(config.gitAutoStashSkipRejected, isTrue);
    expect(config.gitAutoStashSkipRejectedUnattended, isFalse);
    expect(config.shellAllowlistProfile, 'standard');
    expect(config.shellAllowlist, contains('codex'));
    expect(config.shellAllowlist, contains('gemini'));
    expect(config.shellAllowlist, contains('claude'));
    expect(config.safeWriteRoots, contains('lib'));
    expect(config.safeWriteRoots, contains('.genaisys/agent_contexts'));
    expect(config.qualityGateEnabled, isTrue);
    expect(
      config.qualityGateCommands,
      equals(ProjectConfig.defaultQualityGateCommands),
    );
    expect(
      config.qualityGateTimeout,
      const Duration(seconds: ProjectConfig.defaultQualityGateTimeoutSeconds),
    );
    expect(
      config.qualityGateAdaptiveByDiff,
      ProjectConfig.defaultQualityGateAdaptiveByDiff,
    );
    expect(
      config.qualityGateSkipTestsForDocsOnly,
      ProjectConfig.defaultQualityGateSkipTestsForDocsOnly,
    );
    expect(
      config.qualityGatePreferDartTestForLibDartOnly,
      ProjectConfig.defaultQualityGatePreferDartTestForLibDartOnly,
    );
    expect(
      config.qualityGateFlakeRetryCount,
      ProjectConfig.defaultQualityGateFlakeRetryCount,
    );
    expect(config.diffBudgetMaxFiles, 20);
    expect(config.diffBudgetMaxAdditions, 2000);
    expect(config.diffBudgetMaxDeletions, 1500);
    expect(config.autopilotMinOpenTasks, 8);
    expect(config.autopilotMaxPlanAdd, 4);
    expect(config.autopilotMaxSteps, isNull);
    expect(config.autopilotMaxFailures, 5);
    expect(config.autopilotMaxTaskRetries, 3);
    expect(config.autopilotSelectionMode, 'strict_priority');
    expect(config.autopilotFairnessWindow, 12);
    expect(config.autopilotPriorityWeightP1, 3);
    expect(config.autopilotPriorityWeightP2, 2);
    expect(config.autopilotPriorityWeightP3, 1);
    expect(config.autopilotReactivateBlocked, isFalse);
    expect(config.autopilotReactivateFailed, isTrue);
    expect(config.autopilotBlockedCooldown, Duration.zero);
    expect(config.autopilotFailedCooldown, Duration.zero);
    expect(config.autopilotStepSleep, const Duration(seconds: 2));
    expect(config.autopilotIdleSleep, const Duration(seconds: 30));
    expect(config.autopilotLockTtl, const Duration(seconds: 600));
    expect(
      config.autopilotNoProgressThreshold,
      ProjectConfig.defaultAutopilotNoProgressThreshold,
    );
    expect(
      config.autopilotStuckCooldown,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotStuckCooldownSeconds,
      ),
    );
    expect(
      config.autopilotSelfRestart,
      ProjectConfig.defaultAutopilotSelfRestart,
    );
    expect(
      config.autopilotSelfHealEnabled,
      ProjectConfig.defaultAutopilotSelfHealEnabled,
    );
    expect(
      config.autopilotSelfHealMaxAttempts,
      ProjectConfig.defaultAutopilotSelfHealMaxAttempts,
    );
    expect(
      config.autopilotOvernightUnattendedEnabled,
      ProjectConfig.defaultAutopilotOvernightUnattendedEnabled,
    );
    expect(
      config.autopilotSelfTuneEnabled,
      ProjectConfig.defaultAutopilotSelfTuneEnabled,
    );
    expect(
      config.autopilotSelfTuneWindow,
      ProjectConfig.defaultAutopilotSelfTuneWindow,
    );
    expect(
      config.autopilotSelfTuneMinSamples,
      ProjectConfig.defaultAutopilotSelfTuneMinSamples,
    );
    expect(
      config.autopilotSelfTuneSuccessPercent,
      ProjectConfig.defaultAutopilotSelfTuneSuccessPercent,
    );
    expect(
      config.autopilotPlanningAuditEnabled,
      ProjectConfig.defaultAutopilotPlanningAuditEnabled,
    );
    expect(
      config.autopilotPlanningAuditCadenceSteps,
      ProjectConfig.defaultAutopilotPlanningAuditCadenceSteps,
    );
    expect(
      config.autopilotPlanningAuditMaxAdd,
      ProjectConfig.defaultAutopilotPlanningAuditMaxAdd,
    );
  });

  test('ProjectConfig returns empty when file missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_missing_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final config = ProjectConfig.load(temp.path);

    expect(config.providersPrimary, isNull);
    expect(config.providersFallback, isNull);
    expect(config.providerPool, isEmpty);
    expect(
      config.providerQuotaCooldown,
      const Duration(
        seconds: ProjectConfig.defaultProviderQuotaCooldownSeconds,
      ),
    );
    expect(
      config.providerQuotaPause,
      const Duration(seconds: ProjectConfig.defaultProviderQuotaPauseSeconds),
    );
    expect(config.gitBaseBranch, 'main');
    expect(config.gitFeaturePrefix, 'feat/');
    expect(config.gitAutoStash, isFalse);
    expect(config.gitAutoStashSkipRejected, isTrue);
    expect(config.gitAutoStashSkipRejectedUnattended, isFalse);
    expect(
      config.shellAllowlistProfile,
      ProjectConfig.defaultShellAllowlistProfile,
    );
    expect(config.shellAllowlist, contains('codex'));
    expect(config.shellAllowlist, contains('gemini'));
    expect(config.shellAllowlist, contains('claude'));
    expect(config.safeWriteRoots, isNotEmpty);
    expect(config.safeWriteRoots, contains('.genaisys/agent_contexts'));
    expect(config.qualityGateEnabled, ProjectConfig.defaultQualityGateEnabled);
    expect(
      config.qualityGateCommands,
      equals(ProjectConfig.defaultQualityGateCommands),
    );
    expect(
      config.qualityGateTimeout,
      const Duration(seconds: ProjectConfig.defaultQualityGateTimeoutSeconds),
    );
    expect(
      config.qualityGateAdaptiveByDiff,
      ProjectConfig.defaultQualityGateAdaptiveByDiff,
    );
    expect(
      config.qualityGateSkipTestsForDocsOnly,
      ProjectConfig.defaultQualityGateSkipTestsForDocsOnly,
    );
    expect(
      config.qualityGatePreferDartTestForLibDartOnly,
      ProjectConfig.defaultQualityGatePreferDartTestForLibDartOnly,
    );
    expect(
      config.qualityGateFlakeRetryCount,
      ProjectConfig.defaultQualityGateFlakeRetryCount,
    );
    expect(config.diffBudgetMaxFiles, ProjectConfig.defaultDiffBudgetMaxFiles);
    expect(
      config.diffBudgetMaxAdditions,
      ProjectConfig.defaultDiffBudgetMaxAdditions,
    );
    expect(
      config.diffBudgetMaxDeletions,
      ProjectConfig.defaultDiffBudgetMaxDeletions,
    );
    expect(
      config.autopilotMinOpenTasks,
      ProjectConfig.defaultAutopilotMinOpenTasks,
    );
    expect(
      config.autopilotMaxPlanAdd,
      ProjectConfig.defaultAutopilotMaxPlanAdd,
    );
    expect(config.autopilotMaxSteps, isNull);
    expect(
      config.autopilotMaxFailures,
      ProjectConfig.defaultAutopilotMaxFailures,
    );
    expect(
      config.autopilotMaxTaskRetries,
      ProjectConfig.defaultAutopilotMaxTaskRetries,
    );
    expect(
      config.autopilotSelectionMode,
      ProjectConfig.defaultAutopilotSelectionMode,
    );
    expect(
      config.autopilotFairnessWindow,
      ProjectConfig.defaultAutopilotFairnessWindow,
    );
    expect(
      config.autopilotPriorityWeightP1,
      ProjectConfig.defaultAutopilotPriorityWeightP1,
    );
    expect(
      config.autopilotPriorityWeightP2,
      ProjectConfig.defaultAutopilotPriorityWeightP2,
    );
    expect(
      config.autopilotPriorityWeightP3,
      ProjectConfig.defaultAutopilotPriorityWeightP3,
    );
    expect(
      config.autopilotReactivateBlocked,
      ProjectConfig.defaultAutopilotReactivateBlocked,
    );
    expect(
      config.autopilotReactivateFailed,
      ProjectConfig.defaultAutopilotReactivateFailed,
    );
    expect(
      config.autopilotBlockedCooldown,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotBlockedCooldownSeconds,
      ),
    );
    expect(
      config.autopilotFailedCooldown,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotFailedCooldownSeconds,
      ),
    );
    expect(
      config.autopilotStepSleep,
      const Duration(seconds: ProjectConfig.defaultAutopilotStepSleepSeconds),
    );
    expect(
      config.autopilotIdleSleep,
      const Duration(seconds: ProjectConfig.defaultAutopilotIdleSleepSeconds),
    );
    expect(
      config.autopilotLockTtl,
      const Duration(seconds: ProjectConfig.defaultAutopilotLockTtlSeconds),
    );
    expect(
      config.autopilotNoProgressThreshold,
      ProjectConfig.defaultAutopilotNoProgressThreshold,
    );
    expect(
      config.autopilotStuckCooldown,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotStuckCooldownSeconds,
      ),
    );
    expect(
      config.autopilotSelfRestart,
      ProjectConfig.defaultAutopilotSelfRestart,
    );
    expect(
      config.autopilotSelfHealEnabled,
      ProjectConfig.defaultAutopilotSelfHealEnabled,
    );
    expect(
      config.autopilotSelfHealMaxAttempts,
      ProjectConfig.defaultAutopilotSelfHealMaxAttempts,
    );
    expect(
      config.autopilotOvernightUnattendedEnabled,
      ProjectConfig.defaultAutopilotOvernightUnattendedEnabled,
    );
    expect(
      config.autopilotSelfTuneEnabled,
      ProjectConfig.defaultAutopilotSelfTuneEnabled,
    );
    expect(
      config.autopilotSelfTuneWindow,
      ProjectConfig.defaultAutopilotSelfTuneWindow,
    );
    expect(
      config.autopilotSelfTuneMinSamples,
      ProjectConfig.defaultAutopilotSelfTuneMinSamples,
    );
    expect(
      config.autopilotSelfTuneSuccessPercent,
      ProjectConfig.defaultAutopilotSelfTuneSuccessPercent,
    );
    expect(
      config.autopilotPlanningAuditEnabled,
      ProjectConfig.defaultAutopilotPlanningAuditEnabled,
    );
    expect(
      config.autopilotPlanningAuditCadenceSteps,
      ProjectConfig.defaultAutopilotPlanningAuditCadenceSteps,
    );
    expect(
      config.autopilotPlanningAuditMaxAdd,
      ProjectConfig.defaultAutopilotPlanningAuditMaxAdd,
    );
  });

  test(
    'ProjectConfig loads codex cli config overrides from providers section',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_config_codex_overrides_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  codex_cli_config_overrides:
    - reasoning_effort="medium"
    - model="gpt-5.3-codex"
''');

      final config = ProjectConfig.load(temp.path);
      expect(
        config.codexCliConfigOverrides,
        equals(['reasoning_effort="medium"', 'model="gpt-5.3-codex"']),
      );
    },
  );

  test('ProjectConfig parses rejected auto-stash git toggles', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_git_reject_stash_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
  auto_stash_skip_rejected: false
  auto_stash_skip_rejected_unattended: true
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.gitAutoStash, isTrue);
    expect(config.gitAutoStashSkipRejected, isFalse);
    expect(config.gitAutoStashSkipRejectedUnattended, isTrue);
  });

  test('ProjectConfig loads diff budget from policies.diff_budget', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_diff_budget_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''providers:
  primary: "codex"

policies:
  diff_budget:
    max_files: 4
    max_additions: 200
    max_deletions: 50
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.providersPrimary, 'codex');
    expect(config.diffBudgetMaxFiles, 4);
    expect(config.diffBudgetMaxAdditions, 200);
    expect(config.diffBudgetMaxDeletions, 50);
  });

  test('ProjectConfig loads providers pool and quota settings', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_provider_pool_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
  pool:
    - "codex@main"
    - "gemini@backup"
    - "codex@main"
  quota_cooldown_seconds: 120
  quota_pause_seconds: 45
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.providerPool.map((entry) => entry.key), [
      'codex@main',
      'gemini@backup',
    ]);
    expect(config.providerQuotaCooldown, const Duration(seconds: 120));
    expect(config.providerQuotaPause, const Duration(seconds: 45));
  });

  test('ProjectConfig loads safe_write and shell_allowlist', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_policies_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
policies:
  safe_write:
    enabled: false
  shell_allowlist:
    - flutter test
    - git status
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.safeWriteEnabled, false);
    expect(config.safeWriteRoots, isNotEmpty);
    expect(
      config.shellAllowlist,
      containsAll([
        'flutter test',
        'git status',
        'rg',
        'ls',
        'cat',
        'git diff',
      ]),
    );
  });

  test('ProjectConfig loads quality_gate policy values', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_quality_gate_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
    timeout_seconds: 42
    adaptive_by_diff: false
    skip_tests_for_docs_only: false
    prefer_dart_test_for_lib_dart_only: false
    flake_retry_count: 2
    commands:
      - "dart test --tags=fast"
      - "dart analyze"
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.qualityGateEnabled, isFalse);
    expect(config.qualityGateTimeout, const Duration(seconds: 42));
    expect(config.qualityGateAdaptiveByDiff, isFalse);
    expect(config.qualityGateSkipTestsForDocsOnly, isFalse);
    expect(config.qualityGatePreferDartTestForLibDartOnly, isFalse);
    expect(config.qualityGateFlakeRetryCount, 2);
    expect(
      config.qualityGateCommands,
      equals(['dart test --tags=fast', 'dart analyze']),
    );
  });

  test('ProjectConfig loads autopilot config', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_autopilot_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
autopilot:
  selection_mode: priority
  fairness_window: 6
  priority_weight_p1: 4
  priority_weight_p2: 2
  priority_weight_p3: 1
  reactivate_blocked: true
  reactivate_failed: false
  blocked_cooldown_seconds: 120
  failed_cooldown_seconds: 45
  min_open: 3
  max_plan_add: 2
  max_steps: 12
  max_failures: 4
  max_task_retries: 2
  step_sleep_seconds: 5
  idle_sleep_seconds: 20
  lock_ttl_seconds: 120
  no_progress_threshold: 3
  stuck_cooldown_seconds: 90
  self_restart: false
  self_heal_enabled: false
  self_heal_max_attempts: 3
  overnight_unattended_enabled: true
  self_tune_enabled: false
  self_tune_window: 8
  self_tune_min_samples: 3
  self_tune_success_percent: 75
  release_tag_on_ready: false
  release_tag_push: false
  release_tag_prefix: "release-"
  planning_audit_enabled: false
  planning_audit_cadence_steps: 5
  planning_audit_max_add: 2
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.autopilotMinOpenTasks, 3);
    expect(config.autopilotMaxPlanAdd, 2);
    expect(config.autopilotMaxSteps, 12);
    expect(config.autopilotMaxFailures, 4);
    expect(config.autopilotMaxTaskRetries, 2);
    expect(config.autopilotSelectionMode, 'priority');
    expect(config.autopilotFairnessWindow, 6);
    expect(config.autopilotPriorityWeightP1, 4);
    expect(config.autopilotPriorityWeightP2, 2);
    expect(config.autopilotPriorityWeightP3, 1);
    expect(config.autopilotReactivateBlocked, isTrue);
    expect(config.autopilotReactivateFailed, isFalse);
    expect(config.autopilotBlockedCooldown, const Duration(seconds: 120));
    expect(config.autopilotFailedCooldown, const Duration(seconds: 45));
    expect(config.autopilotStepSleep, const Duration(seconds: 5));
    expect(config.autopilotIdleSleep, const Duration(seconds: 20));
    expect(config.autopilotLockTtl, const Duration(seconds: 120));
    expect(config.autopilotNoProgressThreshold, 3);
    expect(config.autopilotStuckCooldown, const Duration(seconds: 90));
    expect(config.autopilotSelfRestart, isFalse);
    expect(config.autopilotSelfHealEnabled, isFalse);
    expect(config.autopilotSelfHealMaxAttempts, 3);
    expect(config.autopilotOvernightUnattendedEnabled, isTrue);
    expect(config.autopilotSelfTuneEnabled, isFalse);
    expect(config.autopilotSelfTuneWindow, 8);
    expect(config.autopilotSelfTuneMinSamples, 3);
    expect(config.autopilotSelfTuneSuccessPercent, 75);
    expect(config.autopilotReleaseTagOnReady, isFalse);
    expect(config.autopilotReleaseTagPush, isFalse);
    expect(config.autopilotReleaseTagPrefix, 'release-');
    expect(config.autopilotPlanningAuditEnabled, isFalse);
    expect(config.autopilotPlanningAuditCadenceSteps, 5);
    expect(config.autopilotPlanningAuditMaxAdd, 2);
  });

  test('ProjectConfig applies shell allowlist profile', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_allowlist_profile_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
policies:
  shell_allowlist_profile: minimal
  shell_allowlist:
    - flutter test
''');

    final config = ProjectConfig.load(temp.path);

    expect(config.shellAllowlistProfile, 'minimal');
    expect(config.shellAllowlist, contains('rg'));
    expect(config.shellAllowlist, contains('codex'));
    expect(config.shellAllowlist, contains('gemini'));
    expect(config.shellAllowlist, contains('claude'));
    expect(config.shellAllowlist, isNot(contains('flutter test')));
  });

  test(
    'ProjectConfig loads claude code cli config overrides from providers section',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_config_claude_overrides_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  claude_code_cli_config_overrides:
    - "--model=claude-sonnet-4-5-20250929"
    - "--max-turns=10"
''');

      final config = ProjectConfig.load(temp.path);
      expect(
        config.claudeCodeCliConfigOverrides,
        equals(['--model=claude-sonnet-4-5-20250929', '--max-turns=10']),
      );
    },
  );

  test(
    'All shell allowlist profiles include claude alongside codex and gemini',
    () {
      for (final profile in ['minimal', 'standard', 'extended']) {
        final resolved = ProjectConfig.resolveShellAllowlist(
          profile: profile,
          customAllowlist: const [],
        );
        expect(
          resolved,
          contains('claude'),
          reason: '$profile profile must include claude',
        );
        expect(
          resolved,
          contains('codex'),
          reason: '$profile profile must include codex',
        );
        expect(
          resolved,
          contains('gemini'),
          reason: '$profile profile must include gemini',
        );
      }
    },
  );

  test('ProjectConfig loads agent profiles', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_agents_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
agents:
  core:
    enabled: true
    system_prompt: "agent_contexts/core.md"
  ui:
    enabled: false
    system_prompt: "agent_contexts/ui.md"
  review_security:
    enabled: true
    system_prompt: "agent_contexts/review_security.md"
''');

    final config = ProjectConfig.load(temp.path);

    final core = config.agentProfile('core');
    expect(core, isNotNull);
    expect(core!.enabled, isTrue);
    expect(core.systemPromptPath, 'agent_contexts/core.md');

    final ui = config.agentProfile('ui');
    expect(ui, isNotNull);
    expect(ui!.enabled, isFalse);
    expect(ui.systemPromptPath, 'agent_contexts/ui.md');

    final review = config.agentProfile('review_security');
    expect(review, isNotNull);
    expect(review!.enabled, isTrue);
    expect(review.systemPromptPath, 'agent_contexts/review_security.md');
  });

  test(
    'ProjectConfig loads agent timeout from policies.timeouts.agent_seconds',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_config_agent_timeout_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
policies:
  timeouts:
    agent_seconds: 123
''');

      final config = ProjectConfig.load(temp.path);
      expect(config.agentTimeout.inSeconds, 123);
    },
  );

  test('ProjectConfig parses pipeline section', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
pipeline:
  context_injection_enabled: false
  context_injection_max_tokens: 4000
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.pipelineContextInjectionEnabled, isFalse);
    expect(config.pipelineContextInjectionMaxTokens, 4000);
  });

  test('ProjectConfig uses pipeline defaults when section absent', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('');

    final config = ProjectConfig.load(temp.path);
    expect(
      config.pipelineContextInjectionEnabled,
      ProjectConfig.defaultPipelineContextInjectionEnabled,
    );
    expect(
      config.pipelineContextInjectionMaxTokens,
      ProjectConfig.defaultPipelineContextInjectionMaxTokens,
    );
  });

  test('ProjectConfig parses git sync fields', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
git:
  sync_between_loops: true
  sync_strategy: "pull_ff"
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.gitSyncBetweenLoops, isTrue);
    expect(config.gitSyncStrategy, 'pull_ff');
  });

  test('ProjectConfig parses review section', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
review:
  fresh_context: false
  strictness: "strict"
  max_rounds: 5
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.reviewFreshContext, isFalse);
    expect(config.reviewStrictness, 'strict');
    expect(config.reviewMaxRounds, 5);
  });

  test('ProjectConfig parses reflection section', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
reflection:
  enabled: false
  trigger_mode: "task_count"
  trigger_loop_count: 20
  trigger_task_count: 8
  trigger_hours: 6
  min_samples: 10
  max_optimization_tasks: 5
  optimization_task_priority: "P1"
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.reflectionEnabled, isFalse);
    expect(config.reflectionTriggerMode, 'task_count');
    expect(config.reflectionTriggerLoopCount, 20);
    expect(config.reflectionTriggerTaskCount, 8);
    expect(config.reflectionTriggerHours, 6);
    expect(config.reflectionMinSamples, 10);
    expect(config.reflectionMaxOptimizationTasks, 5);
    expect(config.reflectionOptimizationPriority, 'P1');
  });

  test('ProjectConfig parses supervisor section', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_config_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
supervisor:
  reflection_on_halt: false
  max_interventions_per_hour: 10
  check_interval_seconds: 60
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.supervisorReflectionOnHalt, isFalse);
    expect(config.supervisorMaxInterventionsPerHour, 10);
    expect(config.supervisorCheckInterval.inSeconds, 60);
  });

  test('ProjectConfig parses workflow section', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_workflow_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
workflow:
  auto_push: false
  auto_merge: false
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.workflowAutoPush, isFalse);
    expect(config.workflowAutoMerge, isFalse);
  });

  test('ProjectConfig uses workflow defaults when section absent', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_workflow_defaults_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.workflowAutoPush, isTrue);
    expect(config.workflowAutoMerge, isTrue);
  });

  test('ProjectConfig new autopilot hardening keys use defaults', () {
    final config = ProjectConfig.empty();

    expect(
      config.autopilotMaxWallclockHours,
      ProjectConfig.defaultAutopilotMaxWallclockHours,
    );
    expect(
      config.autopilotMaxSelfRestarts,
      ProjectConfig.defaultAutopilotMaxSelfRestarts,
    );
    expect(
      config.autopilotMaxIterationsSafetyLimit,
      ProjectConfig.defaultAutopilotMaxIterationsSafetyLimit,
    );
    expect(
      config.autopilotPreflightTimeout,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotPreflightTimeoutSeconds,
      ),
    );
    expect(
      config.autopilotSubtaskQueueMax,
      ProjectConfig.defaultAutopilotSubtaskQueueMax,
    );
    expect(
      config.reviewEvidenceMinLength,
      ProjectConfig.defaultReviewEvidenceMinLength,
    );
  });

  test('ProjectConfig parses new autopilot hardening keys from config', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_hardening_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
autopilot:
  max_wallclock_hours: 12
  max_self_restarts: 3
  max_iterations_safety_limit: 500
  preflight_timeout_seconds: 60
  subtask_queue_max: 50
review:
  evidence_min_length: 100
''');

    final config = ProjectConfig.load(temp.path);
    expect(config.autopilotMaxWallclockHours, 12);
    expect(config.autopilotMaxSelfRestarts, 3);
    expect(config.autopilotMaxIterationsSafetyLimit, 500);
    expect(config.autopilotPreflightTimeout, const Duration(seconds: 60));
    expect(config.autopilotSubtaskQueueMax, 50);
    expect(config.reviewEvidenceMinLength, 100);
  });

  test('ProjectConfig rejects invalid values for new hardening keys', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_config_hardening_invalid_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
autopilot:
  max_wallclock_hours: -1
  max_self_restarts: -5
  max_iterations_safety_limit: 0
  preflight_timeout_seconds: 0
  subtask_queue_max: 0
review:
  evidence_min_length: -10
''');

    final config = ProjectConfig.load(temp.path);
    expect(
      config.autopilotMaxWallclockHours,
      ProjectConfig.defaultAutopilotMaxWallclockHours,
    );
    expect(
      config.autopilotMaxSelfRestarts,
      ProjectConfig.defaultAutopilotMaxSelfRestarts,
    );
    expect(
      config.autopilotMaxIterationsSafetyLimit,
      ProjectConfig.defaultAutopilotMaxIterationsSafetyLimit,
    );
    expect(
      config.autopilotPreflightTimeout,
      const Duration(
        seconds: ProjectConfig.defaultAutopilotPreflightTimeoutSeconds,
      ),
    );
    expect(
      config.autopilotSubtaskQueueMax,
      ProjectConfig.defaultAutopilotSubtaskQueueMax,
    );
    expect(
      config.reviewEvidenceMinLength,
      ProjectConfig.defaultReviewEvidenceMinLength,
    );
  });
}
