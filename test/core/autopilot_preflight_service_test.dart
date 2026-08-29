import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/observability/resource_monitor_service.dart';
import 'package:genaisys/core/services/step_schema_validation_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('AutopilotPreflightService blocks dirty repo without auto-stash', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_dirty_block_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: false
''');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);
    File(
      '${temp.path}${Platform.pathSeparator}tracked.txt',
    ).writeAsStringSync('dirty\n');

    final env = _buildHealthEnv(temp.path);
    final result = AutopilotPreflightService().check(
      temp.path,
      environment: env,
    );
    expect(result.ok, isFalse);
    expect(result.reason, 'git');
    expect(result.errorKind, 'git_dirty');
  });

  test(
    'AutopilotPreflightService allows dirty repo when auto-stash can apply',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_dirty_autostash_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: true
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);
      File(
        '${temp.path}${Platform.pathSeparator}tracked.txt',
      ).writeAsStringSync('dirty\n');

      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      expect(result.ok, isTrue);
    },
  );

  test('AutopilotPreflightService blocks when review is rejected', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_review_block_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(
          id: 'task-1',
          title: 'Task 1',
          reviewStatus: 'rejected',
        ),
      ),
    );

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    final result = AutopilotPreflightService().check(temp.path);
    expect(result.ok, isFalse);
    expect(result.reason, 'review');
    expect(result.errorKind, 'review_rejected');
  });

  test(
    'AutopilotPreflightService allows rejected review in autopilot mode when config permits retry',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_review_autopilot_allow_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: true
  auto_stash_skip_rejected_unattended: false
''');
      // Simulate autopilot mode with rejected review (clean repo).
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Task 1',
            reviewStatus: 'rejected',
          ),
          autopilotRun: const AutopilotRunState(
            running: true,
            currentMode: 'autopilot_run',
          ),
        ),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      // Review policy should allow retry in autopilot mode with
      // auto_stash_skip_rejected_unattended: false.
      expect(result.errorKind, isNot('review_rejected'));
    },
  );

  test(
    'AutopilotPreflightService blocks rejected review in autopilot mode when config blocks retry',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_review_autopilot_block_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: true
  auto_stash_skip_rejected_unattended: true
''');
      // Simulate autopilot mode with rejected review (clean repo).
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Task 1',
            reviewStatus: 'rejected',
          ),
          autopilotRun: const AutopilotRunState(
            running: true,
            currentMode: 'autopilot_run',
          ),
        ),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final result = AutopilotPreflightService().check(temp.path);
      expect(result.ok, isFalse);
      expect(result.reason, 'review');
      expect(result.errorKind, 'review_rejected');
    },
  );

  test(
    'AutopilotPreflightService blocks active interaction task without GUI parity metadata',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_parity_missing_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
''');
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] [INTERACTION] Add CLI status command
''');

      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            title: '[INTERACTION] Add CLI status command',
          ),
        ),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final fakeBin = Directory.systemTemp.createTempSync(
        'genaisys_preflight_parity_missing_env_',
      );
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
      });
      final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
        ..writeAsStringSync('#!/bin/sh\necho codex\n');
      Process.runSync('chmod', ['+x', codex.path]);
      final env = {'PATH': fakeBin.path, 'OPENAI_API_KEY': 'test-key'};
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      expect(result.ok, isFalse);
      expect(result.reason, 'policy');
      expect(result.errorClass, 'policy');
      expect(result.errorKind, 'cli_gui_parity_missing');
    },
  );

  test(
    'AutopilotPreflightService allows active interaction task with deferred GUI parity link',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_parity_linked_ui_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
''');
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P2] [UI] Build GUI status controls
- [ ] [P1] [CORE] [INTERACTION] [GUI_PARITY:build-gui-status-controls-3] Add CLI status command
''');

      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            title:
                '[INTERACTION] [GUI_PARITY:build-gui-status-controls-3] Add CLI status command',
          ),
        ),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final fakeBin = Directory.systemTemp.createTempSync(
        'genaisys_preflight_parity_linked_env_',
      );
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
      });
      final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
        ..writeAsStringSync('#!/bin/sh\necho codex\n');
      Process.runSync('chmod', ['+x', codex.path]);
      final env = {'PATH': fakeBin.path, 'OPENAI_API_KEY': 'test-key'};
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      expect(result.ok, isTrue);
    },
  );

  test(
    'AutopilotPreflightService blocks premature post-stabilization unfreeze while open P1 tasks remain',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_stabilization_exit_gate_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
''');
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Close remaining stabilization bug

### Post-Stabilization Feature Wave 1: Native Agent Runtime (Internal)
- [ ] [P2] [ARCH] Define native runtime architecture
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final result = AutopilotPreflightService().check(temp.path);
      expect(result.ok, isFalse);
      expect(result.reason, 'policy');
      expect(result.errorClass, 'preflight');
      expect(result.errorKind, 'stabilization_exit_gate');
      expect(result.message, contains('open P1 tasks=1'));
    },
  );

  test('AutopilotPreflightService blocks when rebase is in progress', () {
    if (Platform.isWindows) {
      return; // Rebase fixture assumes POSIX git behavior.
    }

    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_rebase_conflict_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: false
''');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['config', 'commit.gpgsign', 'false']);

    final conflictFile = File(
      '${temp.path}${Platform.pathSeparator}conflict.txt',
    );
    conflictFile.writeAsStringSync('base\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    _runGit(temp.path, ['checkout', '-b', 'feat/rebase']);
    conflictFile.writeAsStringSync('feature\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'feature']);

    _runGit(temp.path, ['checkout', 'main']);
    conflictFile.writeAsStringSync('main\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'main']);

    _runGit(temp.path, ['checkout', 'feat/rebase']);
    final rebase = Process.runSync('git', [
      'rebase',
      'main',
    ], workingDirectory: temp.path);
    expect(rebase.exitCode, isNot(0), reason: 'rebase should conflict');

    final env = _buildHealthEnv(temp.path);
    final result = AutopilotPreflightService().check(
      temp.path,
      environment: env,
    );
    expect(result.ok, isFalse);
    expect(result.reason, 'git');
    expect(result.errorKind, 'merge_conflict');
    expect(result.message, contains('Rebase in progress'));
  });

  test(
    'AutopilotPreflightService allows gemini without API key env vars (session auth)',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_provider_missing_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: gemini
policies:
  quality_gate:
    enabled: false
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final fakeBin = Directory.systemTemp.createTempSync(
        'genaisys_preflight_provider_missing_env_',
      );
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
      });
      final gemini = File('${fakeBin.path}${Platform.pathSeparator}gemini')
        ..writeAsStringSync('#!/bin/sh\necho gemini\n');
      Process.runSync('chmod', ['+x', gemini.path]);
      final env = {'PATH': fakeBin.path};
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      // Gemini uses session auth — no API key env var is required.
      expect(result.ok, isTrue);
    },
  );

  test(
    'AutopilotPreflightService allows codex when no env credentials are set',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_provider_unreadable_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: codex
policies:
  quality_gate:
    enabled: false
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final fakeBin = Directory.systemTemp.createTempSync(
        'genaisys_preflight_provider_unreadable_env_',
      );
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
      });
      final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
        ..writeAsStringSync('#!/bin/sh\necho codex\n');
      Process.runSync('chmod', ['+x', codex.path]);
      final env = {'PATH': fakeBin.path};
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      expect(result.ok, isTrue);
    },
  );

  test('AutopilotPreflightService blocks quality gate misconfiguration', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_quality_misconfig_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: true
    commands:
      - "dart analyze && rm -rf /"
''');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    final fakeBin = Directory.systemTemp.createTempSync(
      'genaisys_preflight_quality_env_',
    );
    addTearDown(() {
      fakeBin.deleteSync(recursive: true);
    });
    final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
      ..writeAsStringSync('#!/bin/sh\necho codex\n');
    Process.runSync('chmod', ['+x', codex.path]);
    final env = {'PATH': fakeBin.path, 'OPENAI_API_KEY': 'test-key'};
    final result = AutopilotPreflightService().check(
      temp.path,
      environment: env,
    );
    expect(result.ok, isFalse);
    expect(result.reason, 'policy');
    expect(result.errorKind, 'config_schema');
    expect(
      result.message,
      contains('Quality gate command is not parseable'),
    );
  });

  test('AutopilotPreflightService blocks malformed STATE.json schema', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_schema_state_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    File(layout.statePath).writeAsStringSync('''
{
  "last_updated": "2026-02-08T00:00:00Z",
  "cycle_count": "broken"
}
''');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    final result = AutopilotPreflightService().check(temp.path);
    expect(result.ok, isFalse);
    expect(result.reason, 'state');
    expect(result.errorKind, 'state_schema');
    expect(result.message, contains('STATE.json'));
  });

  test(
    'AutopilotPreflightService blocks when disk space is critically low',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_resource_critical_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
autopilot:
  resource_check_enabled: true
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final fakeMonitor = _CriticalResourceMonitor();
      final result = AutopilotPreflightService(
        resourceMonitorService: fakeMonitor,
      ).check(temp.path);
      expect(result.ok, isFalse);
      expect(result.reason, 'resource');
      expect(result.errorKind, 'disk_space_critical');
      expect(result.message, contains('Critically'));
    },
  );

  test(
    'AutopilotPreflightService skips resource check when disabled in config',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_resource_disabled_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
autopilot:
  resource_check_enabled: false
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      // Even with a critical monitor, disabled check should pass resource guard.
      final fakeMonitor = _CriticalResourceMonitor();
      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService(
        resourceMonitorService: fakeMonitor,
      ).check(temp.path, environment: env);
      // Resource check should be skipped — other checks might still fail,
      // but the reason should NOT be 'resource'.
      expect(result.reason, isNot('resource'));
    },
  );

  test(
    'AutopilotPreflightService allows dirty repo with rejected review in autopilot mode',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_dirty_rejected_unattended_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: true
  auto_stash_skip_rejected_unattended: false
''');
      // Simulate autopilot mode with rejected review + dirty repo.
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Task 1',
            reviewStatus: 'rejected',
          ),
          autopilotRun: const AutopilotRunState(
            running: true,
            currentMode: 'autopilot_run',
          ),
        ),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);
      // Make repo dirty.
      File(
        '${temp.path}${Platform.pathSeparator}dirty.txt',
      ).writeAsStringSync('dirty\n');

      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
      );
      // Should pass git guard — auto-stash allowed in unattended mode.
      expect(result.errorKind, isNot('git_dirty'));
    },
  );

  test('AutopilotPreflightService blocks malformed config.yml schema', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_schema_config_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    File(layout.configPath).writeAsStringSync('''
autopilot:
  max_failures: "broken"
''');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    final result = AutopilotPreflightService().check(temp.path);
    expect(result.ok, isFalse);
    expect(result.reason, 'state');
    expect(result.errorKind, 'config_schema');
    expect(result.message, contains('config.yml'));
  });

  test(
    'AutopilotPreflightService blocks when .genaisys/ directory is missing',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_missing_dir_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      // Do NOT call ProjectInitializer — leave .genaisys/ absent.
      final result = AutopilotPreflightService().check(temp.path);
      expect(result.ok, isFalse);
      expect(result.reason, 'state');
      expect(result.errorKind, 'state_missing');
      expect(result.message, contains('.genaisys'));
    },
  );

  test('AutopilotPreflightService blocks when config.yml is unparseable', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_config_garbage_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    // Write garbage that is not valid YAML.
    File(layout.configPath).writeAsStringSync(':::{{not valid yaml at all:::');

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    final result = AutopilotPreflightService().check(temp.path);
    expect(result.ok, isFalse);
    // The exact reason depends on where it fails: schema validation or
    // config loading. Both should block.
    expect(result.reason, isNotNull);
  });

  test('AutopilotPreflightService blocks when TASKS.md is missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_preflight_missing_tasks_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    // Delete TASKS.md after initialization.
    File(layout.tasksPath).deleteSync();

    final result = AutopilotPreflightService().check(temp.path);
    expect(result.ok, isFalse);
    expect(result.reason, 'state');
    expect(result.errorKind, 'tasks_missing');
    expect(result.message, contains('TASKS.md'));
  });

  test(
    'AutopilotPreflightService returns state_corrupt when TASKS.md is unreadable during parity check',
    () {
      if (Platform.isWindows) {
        return; // chmod not applicable on Windows.
      }
      // Root ignores chmod 000 — permission-based test is meaningless in CI
      // containers that run as root.
      final uid = Process.runSync('id', ['-u']).stdout.toString().trim();
      if (uid == '0') return;

      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_state_corrupt_',
      );
      addTearDown(() {
        // Restore permissions before cleanup.
        final tasksFile = File(ProjectLayout(temp.path).tasksPath);
        if (tasksFile.existsSync()) {
          Process.runSync('chmod', ['644', tasksFile.path]);
        }
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      // Enable auto_stash so the chmod-caused dirty worktree is allowed
      // through the git guard (chmod changes the file mode, making git
      // status report a modification).
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
git:
  auto_stash: true
''');

      // Set an active task so _checkActiveTaskParity attempts to read TASKS.md.
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(activeTask: const ActiveTaskState(id: 'task-1')),
      );

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      // Make TASKS.md unreadable so TaskStore.readTasks() throws.
      Process.runSync('chmod', ['000', layout.tasksPath]);

      // Use a no-op schema validator so schema check does not read TASKS.md.
      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService(
        schemaValidationService: _NoOpSchemaValidator(),
      ).check(temp.path, environment: env);
      expect(result.ok, isFalse);
      expect(result.reason, 'state');
      expect(result.errorKind, 'state_corrupt');
    },
  );

  test(
    'AutopilotPreflightService returns preflight_timeout when checks exceed timeout',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_timeout_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      // Use Duration.zero override so the first elapsed-time check after
      // config loading always triggers the timeout.
      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService().check(
        temp.path,
        environment: env,
        preflightTimeoutOverride: Duration.zero,
      );
      expect(result.ok, isFalse);
      expect(result.reason, 'timeout');
      expect(result.errorClass, 'preflight');
      expect(result.errorKind, 'preflight_timeout');
      expect(result.message, contains('exceeded timeout'));
    },
  );

  test(
    'AutopilotPreflightService returns push_check_crash on ProcessException during push dry-run',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_preflight_push_crash_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: false
''');

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      // Use a fake GitService where pushDryRun throws ProcessException
      // to simulate the git binary crashing.
      final env = _buildHealthEnv(temp.path);
      final result = AutopilotPreflightService(
        gitService: _FakeGitServiceForPush(),
      ).check(
        temp.path,
        environment: env,
        requirePushReadiness: true,
      );
      expect(result.ok, isFalse);
      expect(result.reason, 'git');
      expect(result.errorClass, 'preflight');
      expect(result.errorKind, 'push_check_crash');
      expect(result.message, contains('Push dry-run process crashed'));
    },
  );
}

Map<String, String> _buildHealthEnv(String root) {
  final fakeBin = Directory('$root${Platform.pathSeparator}bin')
    ..createSync(recursive: true);
  final codex = File('${fakeBin.path}${Platform.pathSeparator}codex')
    ..writeAsStringSync('#!/bin/sh\necho codex\n');
  Process.runSync('chmod', ['+x', codex.path]);

  return {'PATH': fakeBin.path};
}

/// A fake [ResourceMonitorService] that always returns critical disk space.
class _CriticalResourceMonitor extends ResourceMonitorService {
  @override
  DiskSpaceResult checkDiskSpace(String projectRoot) {
    return const DiskSpaceResult(
      ok: false,
      availableBytes: 5 * 1024 * 1024,
      level: 'critical',
      message:
          'Critically low disk space: 5.0 MB available (minimum: 20.0 MB).',
    );
  }
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode == 0) {
    return;
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: ${result.stderr}',
  );
}

/// A no-op [StepSchemaValidationService] that skips all validation.
class _NoOpSchemaValidator extends StepSchemaValidationService {
  @override
  void validateLayout(ProjectLayout layout) {
    // Intentionally empty — skip schema validation.
  }
}

/// A fake [GitService] for push-readiness tests that provides controlled
/// responses for all GitService methods used by the preflight check and
/// throws [ProcessException] from [pushDryRun] to simulate the git binary
/// crashing or being unavailable.
class _FakeGitServiceForPush implements GitService {
  @override
  bool isGitRepo(String path) => true;

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool hasRebaseInProgress(String path) => false;

  @override
  bool isClean(String path) => true;

  @override
  String? defaultRemote(String path) => 'origin';

  @override
  String currentBranch(String path) => 'main';

  @override
  String repoRoot(String path) => path;

  @override
  bool hasChanges(String path) => false;

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) {
    throw const ProcessException(
      'git',
      ['push', '--dry-run', 'origin', 'main'],
      'No such file or directory',
      2,
    );
  }

  @override
  bool isCommitReachable(String path, String sha) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}
