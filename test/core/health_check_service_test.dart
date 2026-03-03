import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/observability/health_check_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('HealthCheckService reports dirty git repository as not ok', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_health_git_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'health@genaisys.local']);
    _runGit(temp.path, ['config', 'user.name', 'Genaisys Health']);

    final tracked = File('${temp.path}${Platform.pathSeparator}tracked.txt');
    tracked.writeAsStringSync('base\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'chore: base']);

    tracked.writeAsStringSync('dirty\n');

    final snapshot = HealthCheckService().check(temp.path);
    expect(snapshot.git.ok, isFalse);
    expect(snapshot.git.message, contains('uncommitted changes'));
  });

  test('HealthCheckService reports clean git repository as ok', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_health_git_clean_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'health@genaisys.local']);
    _runGit(temp.path, ['config', 'user.name', 'Genaisys Health']);

    final tracked = File('${temp.path}${Platform.pathSeparator}tracked.txt');
    tracked.writeAsStringSync('base\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'chore: base']);

    final snapshot = HealthCheckService().check(temp.path);
    expect(snapshot.git.ok, isTrue);
    expect(snapshot.git.message, 'Git ok.');
  });

  test(
    'HealthCheckService reports dirty git repo as not ok even with auto-stash',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_health_git_autostash_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'health@genaisys.local']);
      _runGit(temp.path, ['config', 'user.name', 'Genaisys Health']);

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
git:
  auto_stash: true
''');

      final tracked = File('${temp.path}${Platform.pathSeparator}tracked.txt');
      tracked.writeAsStringSync('base\n');
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'chore: base']);
      tracked.writeAsStringSync('dirty\n');

      final snapshot = HealthCheckService().check(temp.path);
      expect(snapshot.git.ok, isFalse);
      expect(snapshot.git.message, contains('uncommitted changes'));
    },
  );

  test(
    'HealthCheckService allows gemini without API key env vars (session auth)',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_health_env_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(
        layout.configPath,
      ).writeAsStringSync('providers:\n  primary: gemini\n');

      final fakeBin = Directory('${temp.path}${Platform.pathSeparator}bin')
        ..createSync(recursive: true);
      final fakeGemini = File('${fakeBin.path}${Platform.pathSeparator}gemini')
        ..writeAsStringSync('#!/bin/sh\necho gemini\n');
      Process.runSync('chmod', ['+x', fakeGemini.path]);

      // Gemini uses session auth — no API key env var is required.
      final snapshot = HealthCheckService().check(
        temp.path,
        environment: {'PATH': fakeBin.path},
      );
      expect(snapshot.agent.ok, isTrue);
    },
  );

  test(
    'HealthCheckService allows gemini without required credentials (session auth)',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_health_primary_missing_gemini_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(
        layout.configPath,
      ).writeAsStringSync('providers:\n  primary: gemini\n');

      final check = HealthCheckService().checkPrimaryProviderCredentials(
        temp.path,
        environment: const {},
      );
      expect(check.ok, isTrue);
      expect(check.errorKind, isNull);
      expect(
        check.message,
        'Primary provider credentials available for gemini.',
      );
    },
  );

  test(
    'HealthCheckService allows codex without required environment credentials',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_health_primary_missing_codex_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(
        layout.configPath,
      ).writeAsStringSync('providers:\n  primary: codex\n');

      final check = HealthCheckService().checkPrimaryProviderCredentials(
        temp.path,
        environment: const {},
      );
      expect(check.ok, isTrue);
      expect(check.errorKind, isNull);
      expect(
        check.message,
        'Primary provider credentials available for codex.',
      );
    },
  );

  test('HealthCheckService flags empty quality gate command list', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_health_quality_gate_empty_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
policies:
  quality_gate:
    enabled: true
    commands:
      - ""
''');

    final snapshot = HealthCheckService().check(temp.path);
    expect(snapshot.allowlist.ok, isFalse);
    expect(snapshot.allowlist.message, contains('no commands'));
  });

  test('HealthCheckService flags invalid quality gate shell command', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_health_quality_gate_invalid_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
policies:
  shell_allowlist:
    - dart analyze
  quality_gate:
    enabled: true
    commands:
      - dart analyze; rm -rf /
''');

    final snapshot = HealthCheckService().check(temp.path);
    expect(snapshot.allowlist.ok, isFalse);
    expect(snapshot.allowlist.message, contains('invalid'));
  });

  test('HealthCheckService accepts GOOGLE_API_KEY for Gemini', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_health_env_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(
      layout.configPath,
    ).writeAsStringSync('providers:\n  primary: gemini\n');

    final fakeBin = Directory('${temp.path}${Platform.pathSeparator}bin')
      ..createSync(recursive: true);
    final fakeGemini = File('${fakeBin.path}${Platform.pathSeparator}gemini')
      ..writeAsStringSync('#!/bin/sh\necho gemini\n');
    Process.runSync('chmod', ['+x', fakeGemini.path]);

    final snapshot = HealthCheckService().check(
      temp.path,
      environment: {'PATH': fakeBin.path, 'GOOGLE_API_KEY': 'test-key'},
    );
    expect(snapshot.agent.ok, isTrue);
    expect(snapshot.agent.message, contains('Agent executables available.'));
  });

  test('HealthCheckService reports rejected review as not ok', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_health_review_rejected_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    final store = StateStore(layout.statePath);
    store.write(store.read().copyWith(activeTask: ActiveTaskState(reviewStatus: 'rejected')));

    final snapshot = HealthCheckService().check(
      temp.path,
      environment: const {},
    );
    expect(snapshot.review.ok, isFalse);
    expect(snapshot.review.message, contains('Review rejected'));
  });
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode == 0) {
    return;
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: '
    '${result.stderr}',
  );
}
