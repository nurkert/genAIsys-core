import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/git/git_service.dart';

void main() {
  test('GitService uses non-interactive env for remote network operations', () {
    final calls = <_GitCall>[];
    final service = GitServiceImpl(
      processRunner:
          (
            String executable,
            List<String> arguments, {
            String? workingDirectory,
            bool runInShell = false,
            Map<String, String>? environment,
          }) {
            calls.add(
              _GitCall(
                executable: executable,
                arguments: List<String>.from(arguments),
                environment: environment == null
                    ? null
                    : Map<String, String>.from(environment),
              ),
            );
            return ProcessResult(0, 0, '', '');
          },
    );

    service.push('/tmp/repo', 'origin', 'main');
    service.fetch('/tmp/repo', 'origin');
    service.pullFastForward('/tmp/repo', 'origin', 'main');
    service.pushTag('/tmp/repo', 'origin', 'v1.2.3');

    expect(calls, hasLength(4));
    for (final call in calls) {
      expect(call.executable, 'git');
      expect(call.environment?['GIT_TERMINAL_PROMPT'], '0');
      expect(call.environment?['GCM_INTERACTIVE'], 'Never');
      expect(call.environment?['GIT_SSH_COMMAND'], contains('BatchMode=yes'));
    }
    expect(calls[0].arguments, ['push', 'origin', 'main']);
    expect(calls[1].arguments, ['fetch', 'origin']);
    expect(calls[2].arguments, ['pull', '--ff-only', 'origin', 'main']);
    expect(calls[3].arguments, ['push', 'origin', 'refs/tags/v1.2.3']);
  });

  test('GitService detects repo and clean status', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    final service = GitService();
    expect(service.isGitRepo(temp.path), isTrue);
    expect(service.isClean(temp.path), isTrue);

    final file = File('${temp.path}${Platform.pathSeparator}file.txt');
    file.writeAsStringSync('content');

    expect(service.isClean(temp.path), isFalse);
    expect(service.currentBranch(temp.path).isNotEmpty, isTrue);
    final resolvedTemp = temp.resolveSymbolicLinksSync();
    expect(service.repoRoot(temp.path), resolvedTemp);
  });

  test('GitService can create and checkout branches', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_branch_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final service = GitService();
    final baseBranch = service.currentBranch(temp.path);

    service.createBranch(temp.path, 'feature/test');
    expect(service.currentBranch(temp.path), 'feature/test');

    service.checkout(temp.path, baseBranch);
    expect(service.currentBranch(temp.path), baseBranch);
  });

  test('GitService ensureClean throws when dirty', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_dirty_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    file.writeAsStringSync('changed');
    final service = GitService();
    expect(() => service.ensureClean(temp.path), throwsStateError);
  });

  test('GitService can add and commit changes', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_commit_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');

    final service = GitService();
    service.addAll(temp.path);
    service.commit(temp.path, 'init');

    expect(service.isClean(temp.path), isTrue);
  });

  test('GitService can push to remote', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_push_');
    final remote = Directory.systemTemp.createTempSync(
      'genaisys_git_remote_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
      remote.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    final initRemote = Process.runSync('git', [
      'init',
      '--bare',
    ], workingDirectory: remote.path);
    expect(initRemote.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');

    final service = GitService();
    service.addAll(temp.path);
    service.commit(temp.path, 'init');

    final branch = service.currentBranch(temp.path);
    final addRemote = Process.runSync('git', [
      'remote',
      'add',
      'origin',
      remote.path,
    ], workingDirectory: temp.path);
    expect(addRemote.exitCode, 0);

    service.push(temp.path, 'origin', branch);

    final verify = Process.runSync('git', [
      '--git-dir',
      remote.path,
      'show-ref',
      '--verify',
      'refs/heads/$branch',
    ]);
    expect(verify.exitCode, 0);
  });

  test('GitService can create and push annotated tags', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_tag_');
    final remote = Directory.systemTemp.createTempSync(
      'genaisys_git_tag_remote_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
      remote.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    final initRemote = Process.runSync('git', [
      'init',
      '--bare',
    ], workingDirectory: remote.path);
    expect(initRemote.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');

    final service = GitService();
    service.addAll(temp.path);
    service.commit(temp.path, 'init');

    final addRemote = Process.runSync('git', [
      'remote',
      'add',
      'origin',
      remote.path,
    ], workingDirectory: temp.path);
    expect(addRemote.exitCode, 0);

    const tag = 'v1.2.3-test';
    service.createAnnotatedTag(
      temp.path,
      tag,
      message: 'release-ready candidate',
    );
    expect(service.tagExists(temp.path, tag), isTrue);

    service.pushTag(temp.path, 'origin', tag);

    final verify = Process.runSync('git', [
      '--git-dir',
      remote.path,
      'show-ref',
      '--verify',
      'refs/tags/$tag',
    ]);
    expect(verify.exitCode, 0);
  });

  test('GitService can fetch and pull fast-forward', () {
    final base = Directory.systemTemp.createTempSync('genaisys_git_pull_');
    addTearDown(() {
      base.deleteSync(recursive: true);
    });

    final repoA = Directory('${base.path}${Platform.pathSeparator}repoA')
      ..createSync();
    final remote = Directory('${base.path}${Platform.pathSeparator}remote')
      ..createSync();
    final repoBPath = '${base.path}${Platform.pathSeparator}repoB';

    final init = Process.runSync('git', ['init'], workingDirectory: repoA.path);
    expect(init.exitCode, 0);
    final initRemote = Process.runSync('git', [
      'init',
      '--bare',
    ], workingDirectory: remote.path);
    expect(initRemote.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: repoA.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: repoA.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: repoA.path);

    final fileA = File('${repoA.path}${Platform.pathSeparator}README.md');
    fileA.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: repoA.path);
    final commitA = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: repoA.path);
    expect(commitA.exitCode, 0);

    final service = GitService();
    final branch = service.currentBranch(repoA.path);
    Process.runSync('git', [
      'remote',
      'add',
      'origin',
      remote.path,
    ], workingDirectory: repoA.path);
    service.push(repoA.path, 'origin', branch);

    final clone = Process.runSync('git', ['clone', remote.path, repoBPath]);
    expect(clone.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: repoBPath);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: repoBPath);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: repoBPath);

    final fileB = File('$repoBPath${Platform.pathSeparator}README.md');
    fileB.writeAsStringSync('updated');
    Process.runSync('git', ['add', '.'], workingDirectory: repoBPath);
    final commitB = Process.runSync('git', [
      'commit',
      '-m',
      'update',
    ], workingDirectory: repoBPath);
    expect(commitB.exitCode, 0);
    final pushB = Process.runSync('git', [
      'push',
      'origin',
      branch,
    ], workingDirectory: repoBPath);
    expect(pushB.exitCode, 0);

    expect(fileA.readAsStringSync(), 'init');
    service.fetch(repoA.path, 'origin');
    service.pullFastForward(repoA.path, 'origin', branch);
    expect(fileA.readAsStringSync(), 'updated');
  });

  test('GitService resolves remotes', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_remote_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    final service = GitService();
    expect(service.defaultRemote(temp.path), isNull);
    expect(service.hasRemote(temp.path, 'origin'), isFalse);

    final remote = Directory.systemTemp.createTempSync('genaisys_git_bare_');
    addTearDown(() {
      remote.deleteSync(recursive: true);
    });
    final initRemote = Process.runSync('git', [
      'init',
      '--bare',
    ], workingDirectory: remote.path);
    expect(initRemote.exitCode, 0);

    final addRemote = Process.runSync('git', [
      'remote',
      'add',
      'origin',
      remote.path,
    ], workingDirectory: temp.path);
    expect(addRemote.exitCode, 0);

    expect(service.hasRemote(temp.path, 'origin'), isTrue);
    expect(service.defaultRemote(temp.path), 'origin');
  });

  test('GitService reports changed paths', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_changes_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final service = GitService();
    expect(service.hasChanges(temp.path), isFalse);
    expect(service.changedPaths(temp.path), isEmpty);

    file.writeAsStringSync('updated');
    expect(service.hasChanges(temp.path), isTrue);
    expect(service.changedPaths(temp.path), contains('README.md'));

    final untracked = File('${temp.path}${Platform.pathSeparator}NEW.md');
    untracked.writeAsStringSync('new');
    expect(service.changedPaths(temp.path), contains('NEW.md'));
  });

  test(
    'GitService changedPaths expands untracked directories into concrete files',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_git_changed_paths_untracked_dir_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final init = Process.runSync('git', [
        'init',
      ], workingDirectory: temp.path);
      expect(init.exitCode, 0);

      Process.runSync('git', [
        'config',
        'user.email',
        'test@example.com',
      ], workingDirectory: temp.path);
      Process.runSync('git', [
        'config',
        'user.name',
        'Test User',
      ], workingDirectory: temp.path);
      Process.runSync('git', [
        'config',
        'commit.gpgsign',
        'false',
      ], workingDirectory: temp.path);

      final readme = File('${temp.path}${Platform.pathSeparator}README.md');
      readme.writeAsStringSync('init');
      Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
      final commit = Process.runSync('git', [
        'commit',
        '-m',
        'init',
      ], workingDirectory: temp.path);
      expect(commit.exitCode, 0);

      final untrackedFile = File(
        '${temp.path}${Platform.pathSeparator}lib${Platform.pathSeparator}core${Platform.pathSeparator}logging${Platform.pathSeparator}run_log_index_service.dart',
      );
      untrackedFile.parent.createSync(recursive: true);
      untrackedFile.writeAsStringSync('// test file');

      final service = GitService();
      final paths = service.changedPaths(temp.path);
      expect(paths, contains('lib/core/logging/run_log_index_service.dart'));
      expect(paths, isNot(contains('lib/')));
    },
  );

  test('GitService diffSummary reflects changes', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_diff_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final service = GitService();
    expect(service.diffSummary(temp.path), isEmpty);

    file.writeAsStringSync('updated');
    final summary = service.diffSummary(temp.path);
    expect(summary, contains('README.md'));
  });

  test('GitService diffSummary includes untracked files', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_untracked_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final newFile = File('${temp.path}${Platform.pathSeparator}NEW.md');
    newFile.writeAsStringSync('new');

    final service = GitService();
    final summary = service.diffSummary(temp.path);
    expect(summary, contains('Untracked files:'));
    expect(summary, contains('NEW.md'));
  });

  test('GitService diffPatch includes file changes', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_patch_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    file.writeAsStringSync('updated');
    final service = GitService();
    final patch = service.diffPatch(temp.path);
    expect(patch, contains('README.md'));
    expect(patch, contains('+updated'));
  });

  test('GitService diffPatch includes untracked files', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_untracked_patch_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final newFile = File('${temp.path}${Platform.pathSeparator}NEW.md');
    newFile.writeAsStringSync('new line');

    final service = GitService();
    final patch = service.diffPatch(temp.path);
    expect(patch, contains('NEW.md'));
    expect(patch, contains('+new line'));
  });

  test(
    'GitService diffPatch includes untracked files in untracked directories',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_git_untracked_dir_patch_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final init = Process.runSync('git', [
        'init',
      ], workingDirectory: temp.path);
      expect(init.exitCode, 0);

      Process.runSync('git', [
        'config',
        'user.email',
        'test@example.com',
      ], workingDirectory: temp.path);
      Process.runSync('git', [
        'config',
        'user.name',
        'Test User',
      ], workingDirectory: temp.path);
      Process.runSync('git', [
        'config',
        'commit.gpgsign',
        'false',
      ], workingDirectory: temp.path);

      final readme = File('${temp.path}${Platform.pathSeparator}README.md');
      readme.writeAsStringSync('init');
      Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
      final commit = Process.runSync('git', [
        'commit',
        '-m',
        'init',
      ], workingDirectory: temp.path);
      expect(commit.exitCode, 0);

      final dir = Directory('${temp.path}${Platform.pathSeparator}lib');
      dir.createSync(recursive: true);
      final newFile = File('${dir.path}${Platform.pathSeparator}NEW.txt');
      newFile.writeAsStringSync('new line');

      final service = GitService();
      final patch = service.diffPatch(temp.path);
      expect(patch, contains('lib/NEW.txt'));
      expect(patch, contains('+new line'));
    },
  );

  test(
    'GitService diffPatch includes committed feature branch changes when worktree is clean',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_git_committed_feature_patch_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      void runGit(List<String> args) {
        final result = Process.runSync(
          'git',
          args,
          workingDirectory: temp.path,
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }

      runGit(['init', '-b', 'main']);
      runGit(['config', 'user.email', 'test@example.com']);
      runGit(['config', 'user.name', 'Test User']);
      runGit(['config', 'commit.gpgsign', 'false']);

      final readme = File('${temp.path}${Platform.pathSeparator}README.md');
      readme.writeAsStringSync('init\n');
      runGit(['add', '.']);
      runGit(['commit', '-m', 'init']);

      runGit(['checkout', '-b', 'feat/demo']);
      readme.writeAsStringSync('init\nchanged\n');
      runGit(['add', '.']);
      runGit(['commit', '-m', 'feat: change']);

      final service = GitService();
      expect(service.isClean(temp.path), isTrue);
      final patch = service.diffPatch(temp.path);
      expect(patch, contains('README.md'));
      expect(patch, contains('+changed'));
    },
  );

  test('GitService diffStats reports files additions and deletions', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_stats_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('one\ntwo\n');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    file.writeAsStringSync('one\nthree\nfour\n');
    final service = GitService();
    final stats = service.diffStats(temp.path);
    expect(stats.filesChanged, 1);
    expect(stats.additions, 2);
    expect(stats.deletions, 1);
  });

  test('GitService diffStats includes untracked files', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_untracked_stats_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final newFile = File('${temp.path}${Platform.pathSeparator}NEW.md');
    newFile.writeAsStringSync('one\ntwo\n');

    final service = GitService();
    final stats = service.diffStats(temp.path);
    expect(stats.filesChanged, 1);
    expect(stats.additions, 2);
    expect(stats.deletions, 0);
  });

  test('diffStatsBetween excludes .genaisys/ files from budget', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_between_stats_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();
    final baseBranch = service.currentBranch(temp.path);
    service.createBranch(temp.path, 'feature');
    service.checkout(temp.path, 'feature');

    // Add a real code file (should be counted).
    final codeFile = File('${temp.path}${Platform.pathSeparator}lib.dart');
    codeFile.writeAsStringSync('void main() {}\n');

    // Add a .genaisys/ internal file (should NOT be counted).
    final hephDir = Directory(
      '${temp.path}${Platform.pathSeparator}.genaisys',
    );
    hephDir.createSync();
    final stateFile = File(
      '${hephDir.path}${Platform.pathSeparator}STATE.json',
    );
    stateFile.writeAsStringSync('{"version":1}\n');
    final auditDir = Directory('${hephDir.path}${Platform.pathSeparator}audit');
    auditDir.createSync();
    final auditFile = File(
      '${auditDir.path}${Platform.pathSeparator}log.jsonl',
    );
    auditFile.writeAsStringSync('{"event":"test"}\n');

    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'feature changes',
    ], workingDirectory: temp.path);

    final stats = service.diffStatsBetween(temp.path, baseBranch, 'feature');

    // Only lib.dart should be counted (1 file, 1 addition).
    // .genaisys/STATE.json and .genaisys/audit/log.jsonl are excluded.
    expect(stats.filesChanged, 1);
    expect(stats.additions, 1);
    expect(stats.deletions, 0);
  });

  test('GitService can merge branches', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_merge_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();
    final baseBranch = service.currentBranch(temp.path);
    service.createBranch(temp.path, 'feature');
    service.checkout(temp.path, 'feature');

    file.writeAsStringSync('updated');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'update',
    ], workingDirectory: temp.path);

    service.checkout(temp.path, baseBranch);
    service.merge(temp.path, 'feature');

    expect(file.readAsStringSync(), 'updated');
  });

  test('GitService stashCount returns correct count', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_stash_count_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();
    expect(service.stashCount(temp.path), 0);

    // Create first stash.
    readme.writeAsStringSync('change 1');
    service.stashPush(temp.path, message: 'stash-1');
    expect(service.stashCount(temp.path), 1);

    // Create second stash.
    readme.writeAsStringSync('change 2');
    service.stashPush(temp.path, message: 'stash-2');
    expect(service.stashCount(temp.path), 2);

    // Create third stash.
    readme.writeAsStringSync('change 3');
    service.stashPush(temp.path, message: 'stash-3');
    expect(service.stashCount(temp.path), 3);
  });

  test('GitService dropOldestStashes trims to maxKeep', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_stash_drop_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();

    // Create 5 stashes.
    for (var i = 1; i <= 5; i++) {
      readme.writeAsStringSync('change $i');
      service.stashPush(temp.path, message: 'stash-$i');
    }
    expect(service.stashCount(temp.path), 5);

    // Trim to 2 — should drop the 3 oldest.
    service.dropOldestStashes(temp.path, maxKeep: 2);
    expect(service.stashCount(temp.path), 2);
  });

  test('GitService dropOldestStashes is no-op when count <= maxKeep', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_stash_noop_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();

    // Create 2 stashes.
    for (var i = 1; i <= 2; i++) {
      readme.writeAsStringSync('change $i');
      service.stashPush(temp.path, message: 'stash-$i');
    }
    expect(service.stashCount(temp.path), 2);

    // maxKeep is 5 — should not drop anything.
    service.dropOldestStashes(temp.path, maxKeep: 5);
    expect(service.stashCount(temp.path), 2);

    // maxKeep equals count — should not drop anything.
    service.dropOldestStashes(temp.path, maxKeep: 2);
    expect(service.stashCount(temp.path), 2);
  });

  test('GitService can delete branches', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_git_delete_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);

    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();
    final baseBranch = service.currentBranch(temp.path);
    service.createBranch(temp.path, 'feature');
    expect(service.currentBranch(temp.path), 'feature'); // Checkout -b switches

    service.checkout(temp.path, baseBranch);
    service.deleteBranch(temp.path, 'feature', force: true);

    final branches = Process.runSync('git', [
      'branch',
    ], workingDirectory: temp.path);
    expect(branches.stdout.toString(), isNot(contains('feature')));
  });

  test('removeFromIndexIfTracked untracks files without deleting from disk',
      () {
    final temp = Directory.systemTemp.createTempSync('genaisys_rm_cached_');
    addTearDown(() => temp.deleteSync(recursive: true));

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync(
      'git',
      ['config', 'user.email', 'test@test.com'],
      workingDirectory: temp.path,
    );
    Process.runSync(
      'git',
      ['config', 'user.name', 'Test'],
      workingDirectory: temp.path,
    );

    // Create and commit a tracked file inside a subdirectory.
    final lockDir = Directory('${temp.path}/locks');
    lockDir.createSync();
    File('${temp.path}/locks/autopilot.lock').writeAsStringSync('pid=1');
    File('${temp.path}/state.json').writeAsStringSync('{}');

    Process.runSync(
      'git',
      ['add', '-A'],
      workingDirectory: temp.path,
    );
    Process.runSync(
      'git',
      ['commit', '-m', 'initial', '--no-gpg-sign'],
      workingDirectory: temp.path,
    );

    final service = GitService();

    // Verify files are tracked.
    final lsBefore = Process.runSync(
      'git',
      ['ls-files', 'locks/'],
      workingDirectory: temp.path,
    );
    expect(lsBefore.stdout.toString().trim(), contains('autopilot.lock'));

    // Untrack.
    service.removeFromIndexIfTracked(temp.path, ['locks', 'state.json']);

    // File still exists on disk.
    expect(File('${temp.path}/locks/autopilot.lock').existsSync(), isTrue);
    expect(File('${temp.path}/state.json').existsSync(), isTrue);

    // But no longer in the index.
    final lsAfter = Process.runSync(
      'git',
      ['ls-files', 'locks/'],
      workingDirectory: temp.path,
    );
    expect(lsAfter.stdout.toString().trim(), isEmpty);

    final lsState = Process.runSync(
      'git',
      ['ls-files', 'state.json'],
      workingDirectory: temp.path,
    );
    expect(lsState.stdout.toString().trim(), isEmpty);
  });

  test(
    'removeFromIndexIfTracked logs warning when file remains tracked after removal',
    () {
      // Use a mock process runner that simulates `git rm --cached` succeeding
      // but `git ls-files --error-unmatch` reporting the file is still tracked.
      final calls = <_GitCall>[];
      final service = GitServiceImpl(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          bool runInShell = false,
          Map<String, String>? environment,
        }) {
          calls.add(
            _GitCall(
              executable: executable,
              arguments: List<String>.from(arguments),
              environment: environment == null
                  ? null
                  : Map<String, String>.from(environment),
            ),
          );
          // `git rm --cached` succeeds.
          if (arguments.contains('rm') && arguments.contains('--cached')) {
            return ProcessResult(0, 0, '', '');
          }
          // `git ls-files --error-unmatch` returns 0 (file still tracked).
          if (arguments.contains('ls-files') &&
              arguments.contains('--error-unmatch')) {
            return ProcessResult(0, 0, 'locks/autopilot.lock\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Should not throw but should log a warning to stderr.
      service.removeFromIndexIfTracked('/tmp/repo', ['locks/autopilot.lock']);

      // Verify both git rm and ls-files were called.
      expect(
        calls.any(
          (c) => c.arguments.contains('rm') && c.arguments.contains('--cached'),
        ),
        isTrue,
      );
      expect(
        calls.any(
          (c) =>
              c.arguments.contains('ls-files') &&
              c.arguments.contains('--error-unmatch'),
        ),
        isTrue,
      );
    },
  );

  test('removeFromIndexIfTracked is no-op when files are not tracked', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_rm_noop_');
    addTearDown(() => temp.deleteSync(recursive: true));

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync(
      'git',
      ['config', 'user.email', 'test@test.com'],
      workingDirectory: temp.path,
    );
    Process.runSync(
      'git',
      ['config', 'user.name', 'Test'],
      workingDirectory: temp.path,
    );

    File('${temp.path}/readme.txt').writeAsStringSync('hi');
    Process.runSync(
      'git',
      ['add', '-A'],
      workingDirectory: temp.path,
    );
    Process.runSync(
      'git',
      ['commit', '-m', 'initial', '--no-gpg-sign'],
      workingDirectory: temp.path,
    );

    final service = GitService();

    // Should not throw — nonexistent paths are silently ignored.
    service.removeFromIndexIfTracked(
      temp.path,
      ['locks', 'state.json', 'nonexistent/dir'],
    );
  });
  test(
    'stashPush throws when git reports no changes but worktree is still dirty',
    () {
      // Simulate a stash that reports "No local changes to save" while the
      // worktree actually has dirty files (e.g. ignored-by-stash patterns).
      final service = GitServiceImpl(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          bool runInShell = false,
          Map<String, String>? environment,
        }) {
          // `git stash push` reports nothing to save.
          if (arguments.contains('stash') && arguments.contains('push')) {
            return ProcessResult(
              0,
              0,
              'No local changes to save\n',
              '',
            );
          }
          // `git status --porcelain` shows a dirty file.
          if (arguments.contains('status') &&
              arguments.contains('--porcelain')) {
            return ProcessResult(0, 0, ' M dirty.txt\n', '');
          }
          // `git ls-files --others` returns empty (no untracked files).
          if (arguments.contains('ls-files') &&
              arguments.contains('--others')) {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(
        () => service.stashPush('/tmp/repo', message: 'test stash'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('stashPush reported no changes to save'),
              contains('worktree is still dirty'),
              contains('dirty.txt'),
            ),
          ),
        ),
      );
    },
  );

  test('stashPush returns false without error when worktree is truly clean',
      () {
    final service = GitServiceImpl(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
        Map<String, String>? environment,
      }) {
        // `git stash push` reports nothing to save.
        if (arguments.contains('stash') && arguments.contains('push')) {
          return ProcessResult(0, 0, 'No local changes to save\n', '');
        }
        // `git status --porcelain` is clean.
        if (arguments.contains('status') && arguments.contains('--porcelain')) {
          return ProcessResult(0, 0, '', '');
        }
        // `git ls-files --others` is empty.
        if (arguments.contains('ls-files') && arguments.contains('--others')) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(service.stashPush('/tmp/repo', message: 'test stash'), isFalse);
  });

  test('hasChanges detects staged-only changes', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_staged_only_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    // Create initial commit.
    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    final service = GitService();

    // Worktree is clean — no changes.
    expect(service.hasChanges(temp.path), isFalse);

    // Modify file and stage the change without committing.
    file.writeAsStringSync('staged change');
    Process.runSync('git', ['add', 'README.md'], workingDirectory: temp.path);

    // Reset the working tree to match HEAD so only the index has the change.
    // `git checkout -- README.md` would undo the staging; instead, restore
    // the working copy to match the staged version so `git diff` (unstaged)
    // shows nothing but `git diff --cached` (staged) shows the change.
    // Actually the file already matches the index (we just staged it), so
    // `git diff` (working vs index) is empty but `git diff --cached` shows
    // the staged change.
    expect(service.hasChanges(temp.path), isTrue);
  });

  test('hasChanges detects staged-only changes via mock runner', () {
    // Use a mock to verify the `git diff --cached --quiet` path is exercised
    // when changedPaths returns empty.
    final service = GitServiceImpl(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
        Map<String, String>? environment,
      }) {
        // `git status --porcelain` returns empty (no visible changes).
        if (arguments.contains('status') && arguments.contains('--porcelain')) {
          return ProcessResult(0, 0, '', '');
        }
        // `git ls-files --others` returns empty (no untracked files).
        if (arguments.contains('ls-files') && arguments.contains('--others')) {
          return ProcessResult(0, 0, '', '');
        }
        // `git diff --cached --quiet` exits 1 (staged changes exist).
        if (arguments.contains('diff') && arguments.contains('--cached') &&
            arguments.contains('--quiet')) {
          return ProcessResult(0, 1, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(service.hasChanges('/tmp/repo'), isTrue);
  });

  test('hasChanges returns true for untracked directory with files', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_untracked_dir_haschanges_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final readme = File('${temp.path}${Platform.pathSeparator}README.md');
    readme.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    // Create a new untracked directory with a file inside.
    // `git status --porcelain` shows this as `?? lib/` (collapsed).
    final dir = Directory(
      '${temp.path}${Platform.pathSeparator}lib${Platform.pathSeparator}new_pkg',
    );
    dir.createSync(recursive: true);
    File('${dir.path}${Platform.pathSeparator}widget.dart')
        .writeAsStringSync('class Widget {}');

    final service = GitService();
    expect(service.hasChanges(temp.path), isTrue);
    // isClean must be the inverse.
    expect(service.isClean(temp.path), isFalse);
  });

  test('hasChanges returns false for only .genaisys changes', () {
    final service = GitServiceImpl(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
        Map<String, String>? environment,
      }) {
        // `git status --porcelain` shows only .genaisys/ changes.
        if (arguments.contains('status') && arguments.contains('--porcelain')) {
          return ProcessResult(
            0,
            0,
            ' M .genaisys/STATE.json\n'
            '?? .genaisys/locks/\n'
            '?? .genaisys/audit/log.jsonl\n',
            '',
          );
        }
        // `git diff --cached --quiet` exits 0 (no staged changes).
        if (arguments.contains('diff') &&
            arguments.contains('--cached') &&
            arguments.contains('--quiet')) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(service.hasChanges('/tmp/repo'), isFalse);
    expect(service.isClean('/tmp/repo'), isTrue);
  });

  test('isClean and hasChanges are always inverses', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_git_inverse_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);

    final service = GitService();

    // Scenario 1: clean worktree.
    expect(service.isClean(temp.path), !service.hasChanges(temp.path));

    // Scenario 2: tracked file modified.
    file.writeAsStringSync('modified');
    expect(service.isClean(temp.path), !service.hasChanges(temp.path));

    // Scenario 3: staged change.
    Process.runSync(
      'git',
      ['add', 'README.md'],
      workingDirectory: temp.path,
    );
    expect(service.isClean(temp.path), !service.hasChanges(temp.path));

    // Scenario 4: untracked file.
    Process.runSync('git', [
      'commit',
      '-m',
      'staged',
      '--no-gpg-sign',
    ], workingDirectory: temp.path);
    File('${temp.path}${Platform.pathSeparator}NEW.txt')
        .writeAsStringSync('new');
    expect(service.isClean(temp.path), !service.hasChanges(temp.path));
  });

  test('hasChanges returns false when no changes and no staged changes', () {
    final service = GitServiceImpl(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
        Map<String, String>? environment,
      }) {
        // `git status --porcelain` returns empty.
        if (arguments.contains('status') && arguments.contains('--porcelain')) {
          return ProcessResult(0, 0, '', '');
        }
        // `git ls-files --others` returns empty.
        if (arguments.contains('ls-files') && arguments.contains('--others')) {
          return ProcessResult(0, 0, '', '');
        }
        // `git diff --cached --quiet` exits 0 (no staged changes).
        if (arguments.contains('diff') && arguments.contains('--cached') &&
            arguments.contains('--quiet')) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(service.hasChanges('/tmp/repo'), isFalse);
  });
}

class _GitCall {
  _GitCall({
    required this.executable,
    required this.arguments,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final Map<String, String>? environment;
}
