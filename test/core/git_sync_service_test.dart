import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/git_sync_service.dart';

void main() {
  late Directory temp;
  late Directory remoteDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_git_sync_');
    remoteDir = Directory.systemTemp.createTempSync('genaisys_git_remote_');

    // Set up a bare remote repo.
    Process.runSync('git', [
      'init',
      '--bare',
      '-b',
      'main',
    ], workingDirectory: remoteDir.path);

    // Set up local repo.
    Process.runSync('git', ['init', '-b', 'main'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgSign',
      'false',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'remote',
      'add',
      'origin',
      remoteDir.path,
    ], workingDirectory: temp.path);

    // Create initial commit and push.
    File('${temp.path}/init.txt').writeAsStringSync('initial');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'initial',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'push',
      '-u',
      'origin',
      'main',
    ], workingDirectory: temp.path);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
    remoteDir.deleteSync(recursive: true);
  });

  test('fetch_only performs fetch without pull', () {
    final service = GitSyncService();
    final result = service.syncBeforeLoop(temp.path, strategy: 'fetch_only');

    expect(result.synced, isTrue);
    expect(result.conflictsDetected, isFalse);
  });

  test('no remote returns synced=false without error', () {
    // Create a repo without a remote.
    final noRemote = Directory.systemTemp.createTempSync(
      'genaisys_no_remote_',
    );
    addTearDown(() => noRemote.deleteSync(recursive: true));

    Process.runSync('git', ['init'], workingDirectory: noRemote.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: noRemote.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test',
    ], workingDirectory: noRemote.path);

    final service = GitSyncService();
    final result = service.syncBeforeLoop(
      noRemote.path,
      strategy: 'fetch_only',
    );

    expect(result.synced, isFalse);
    expect(result.errorMessage, contains('no_remote'));
  });

  test('pull_ff merges fast-forward changes', () {
    // Create a second clone to simulate remote changes.
    final clone = Directory.systemTemp.createTempSync('genaisys_git_clone_');
    addTearDown(() => clone.deleteSync(recursive: true));

    Process.runSync('git', ['clone', remoteDir.path, clone.path]);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: clone.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test',
    ], workingDirectory: clone.path);
    Process.runSync('git', [
      'config',
      'commit.gpgSign',
      'false',
    ], workingDirectory: clone.path);

    // Add a commit in the clone and push.
    File('${clone.path}/remote_change.txt').writeAsStringSync('remote');
    Process.runSync('git', ['add', '.'], workingDirectory: clone.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'remote change',
    ], workingDirectory: clone.path);
    Process.runSync('git', [
      'push',
      'origin',
      'main',
    ], workingDirectory: clone.path);

    // Now sync the original repo.
    final service = GitSyncService();
    final result = service.syncBeforeLoop(temp.path, strategy: 'pull_ff');

    expect(result.synced, isTrue);
    expect(result.conflictsDetected, isFalse);

    // Verify the file was pulled.
    expect(File('${temp.path}/remote_change.txt').existsSync(), isTrue);
  });

  test('not a git repo returns synced=false', () {
    final notRepo = Directory.systemTemp.createTempSync('genaisys_not_repo_');
    addTearDown(() => notRepo.deleteSync(recursive: true));

    final service = GitSyncService();
    final result = service.syncBeforeLoop(notRepo.path, strategy: 'fetch_only');

    expect(result.synced, isFalse);
    expect(result.errorMessage, contains('not_a_repo'));
  });
}
